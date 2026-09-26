import { AuthorizationError, CimdFetchError, OAuthError } from "@cloudflare/workers-oauth-provider";
import { escapeHTML as e, json } from "../shared/http.js";

export function consentPage(client, request, handle) {
  const host = new URL(request.redirectUri).hostname;
  const local = /^(localhost|127(\.\d{1,3}){3}|\[::1\])$/.test(host);
  const source = request.clientId.startsWith("https:")
    ? `Client domain: ${e(new URL(request.clientId).hostname)}`
    : "This client registered itself; its name has not been verified.";
  return `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Connect PkgFactory</title><h1>Connect ${e(client?.clientName || request.clientId)}?</h1>
<p>${source}</p><p>Access will be returned to <strong>${e(host)}</strong>.</p>
${local ? "<p>Continue only if you started this sign-in from an app on your computer.</p>" : ""}
<p>This allows the client to preview and create Julia package repositories using your GitHub account.
GitHub will request repository and workflow permissions. Approve individual package creation in your MCP client.</p>
<p>Requested access: ${request.scope.map(e).join(", ")}</p>
<form method="post" action="/authorize"><input type="hidden" name="handle" value="${e(handle)}">
<button name="decision" value="approve">Continue to GitHub</button>
<button name="decision" value="deny">Cancel</button></form></html>`;
}

async function githubUser(token) {
  return fetch("https://api.github.com/user", { headers: {
    Authorization: `Bearer ${token}`, Accept: "application/vnd.github+json",
    "User-Agent": "PkgFactory", "X-GitHub-Api-Version": "2022-11-28",
  }, redirect: "manual", signal: AbortSignal.timeout(15000) });
}

export async function refreshGitHub({ grantType, props }) {
  if (grantType !== "refresh_token") return;
  let response;
  try { response = await githubUser(props.githubToken); }
  catch { throw new OAuthError("temporarily_unavailable", { description: "GitHub is unavailable", statusCode: 503 }); }
  if (response.status === 401) throw new OAuthError("invalid_grant", { description: "Reconnect your GitHub account" });
  if (!response.ok) throw new OAuthError("temporarily_unavailable", { description: "GitHub is unavailable", statusCode: 503 });
  const user = await response.json();
  if (String(user.id) !== props.userId) throw new OAuthError("invalid_grant", { description: "GitHub account changed" });
}

export async function oauthRoutes(request, env) {
  const url = new URL(request.url);
  const oauth = env.OAUTH_PROVIDER;
  try {
    if (url.pathname === "/authorize" && request.method === "GET") {
      const authRequest = await oauth.parseAuthRequest(request);
      const client = await oauth.lookupClient(authRequest.clientId);
      const consent = await oauth.beginConsent(authRequest);
      consent.headers.set("Content-Type", "text/html; charset=utf-8");
      consent.headers.set("Referrer-Policy", "no-referrer");
      consent.headers.set("Content-Security-Policy", "default-src 'none'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");
      return new Response(consentPage(client, authRequest, consent.handle), { headers: consent.headers });
    }
    if (url.pathname === "/authorize" && request.method === "POST") {
      const form = await request.formData();
      const handle = String(form.get("handle"));
      if (form.get("decision") !== "approve") {
        const denied = await oauth.denyConsent(request, handle);
        return new Response(null, { status: 302, headers: denied.headers });
      }
      const approved = await oauth.approveConsent(request, handle, { scope: ["pkgfactory"] });
      const verifier = crypto.randomUUID() + crypto.randomUUID();
      const { state, headers } = await oauth.beginUpstream(approved.request, {
        data: { verifier }, headers: approved.headers,
      });
      const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
      const challenge = btoa(String.fromCharCode(...hash)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
      const github = new URL("https://github.com/login/oauth/authorize");
      github.search = new URLSearchParams({ client_id: env.GITHUB_OAUTH_CLIENT_ID,
        redirect_uri: env.MCP_ORIGIN + "/callback", scope: "repo workflow read:user",
        state, code_challenge: challenge, code_challenge_method: "S256" }).toString();
      headers.set("Location", github.href);
      return new Response(null, { status: 302, headers });
    }
    if (url.pathname === "/callback" && request.method === "GET") {
      const { request: original, data, headers } = await oauth.finishUpstream(request);
      if (url.searchParams.has("error")) {
        const denied = new URL(original.redirectUri);
        denied.searchParams.set("error", "access_denied");
        if (original.state) denied.searchParams.set("state", original.state);
        denied.searchParams.set("iss", env.MCP_ORIGIN);
        headers.set("Location", denied.href);
        return new Response(null, { status: 302, headers });
      }
      const code = url.searchParams.get("code");
      if (!code) return json({ error: "GitHub authorization code is missing" }, 400);
      const upstream = await fetch("https://github.com/login/oauth/access_token", {
        method: "POST", headers: { Accept: "application/json", "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ client_id: env.GITHUB_OAUTH_CLIENT_ID,
          client_secret: env.GITHUB_OAUTH_CLIENT_SECRET, code, code_verifier: data.verifier,
          redirect_uri: env.MCP_ORIGIN + "/callback" }), redirect: "manual", signal: AbortSignal.timeout(15000),
      });
      const tokens = await upstream.json();
      if (!upstream.ok || typeof tokens.access_token !== "string") return json({ error: "GitHub sign-in failed. Start again." }, 400);
      const scopes = String(tokens.scope || "").split(/[ ,]+/);
      if (!scopes.includes("repo") || !scopes.includes("workflow")) return json({ error: "GitHub repository and workflow permissions are required." }, 403);
      const response = await githubUser(tokens.access_token);
      if (!response.ok) return json({ error: "GitHub account could not be verified" }, 502);
      const user = await response.json();
      if (!Number.isSafeInteger(user.id)) return json({ error: "Invalid GitHub identity" }, 502);
      const { redirectTo } = await oauth.completeAuthorization({ request: original,
        userId: String(user.id), metadata: {}, scope: original.scope,
        props: { userId: String(user.id), githubToken: tokens.access_token },
      });
      headers.set("Location", redirectTo);
      return new Response(null, { status: 302, headers });
    }
    return json({ error: "Not found" }, 404);
  } catch (error) {
    if (error instanceof AuthorizationError || error instanceof CimdFetchError)
      return json({ error: "Authorization is invalid or expired. Start sign-in again." }, 400);
    throw error;
  }
}
