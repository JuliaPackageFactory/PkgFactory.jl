import test from "node:test";
import assert from "node:assert/strict";
import { build } from "esbuild";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const origin = "https://mcp.example.com";
const secret = "mcp-state-".repeat(8);
const webSecret = "web-state-".repeat(8);
const recoverySecret = "recovery-".repeat(8);
const ticketSecret = "ticket-only-".repeat(8);
const proxySecret = "web-proxy-".repeat(8);
const browserOrigin = "http://localhost:6274";
const fixture = async ({ maintenance = false, webMaintenance = false } = {}) => {
  const result = await build({ stdin: {
    contents: `import worker, { ApplicationState } from './mcp/worker.js';
      export { ApplicationState };
      const limiter = { limit: async () => ({ success: true }) };
      export default { fetch(req, env, ctx) {
        return worker.fetch(req, { ...env, EDGE_LIMIT: limiter, AUTH_LIMIT: limiter, USER_LIMIT: limiter }, ctx);
      } };`,
    resolveDir: fileURLToPath(new URL("../../", import.meta.url)),
  }, bundle: true, format: "esm", platform: "neutral", mainFields: ["module", "main"], target: "es2022", write: false,
    external: ["cloudflare:*", "node:*"], conditions: ["workerd", "worker", "browser"] });
  return new Miniflare(convertV4MiniflareOptions({ workers: [{ name: "test", modules: true, script: result.outputFiles[0].text,
    compatibilityDate: "2026-09-26", compatibilityFlags: ["nodejs_compat", "global_fetch_strictly_public"],
    bindings: { MCP_ORIGIN: origin, WEB_ORIGIN: "https://web.example.com",
      MCP_STATE_SECRET: secret, WEB_STATE_SECRET: webSecret, STATE_RECOVERY_SECRET: recoverySecret,
      MCP_TICKET_SECRET: ticketSecret, MCP_ALLOWED_ORIGINS: [browserOrigin], MAINTENANCE: String(maintenance),
      GITHUB_OAUTH_CLIENT_ID: "test-client",
      GITHUB_OAUTH_CLIENT_SECRET: "test-only-secret" },
    kvNamespaces: ["OAUTH_KV"],
    durableObjects: { APPLICATION_STATE: { className: "ApplicationState", useSQLite: true } },
    outboundService: async request => {
      const url = new URL(request.url);
      if (url.href === "https://web.example.com/api/health")
        return Response.json({ status: webMaintenance ? "maintenance" : "ok" }, { status: webMaintenance ? 503 : 200 });
      if (url.href === "https://github.com/login/oauth/access_token") {
        const form = new URLSearchParams(await request.text());
        assert.equal(form.get("code"), "github-code");
        assert.ok(form.get("code_verifier"));
        return Response.json({ access_token: "fixture-github-token", scope: "repo,workflow,read:user" });
      }
      if (url.href === "https://api.github.com/user") {
        assert.equal(request.headers.get("Authorization"), "Bearer fixture-github-token");
        return Response.json({ id: 123, login: "fixture" });
      }
      throw new Error("Unexpected external request: " + url.origin + url.pathname);
    },
  }] }));
};

test("real Worker publishes OAuth discovery, challenges MCP, and binds consent to the browser", async () => {
  const mf = await fixture();
  try {
    const discovery = await mf.dispatchFetch(origin + "/.well-known/oauth-protected-resource/mcp",
      { headers: { Origin: browserOrigin } });
    assert.equal(discovery.status, 200);
    assert.equal(discovery.headers.get("access-control-allow-origin"), browserOrigin);
    assert.equal((await discovery.json()).resource, origin + "/mcp");
    const challenge = await mf.dispatchFetch(origin + "/mcp", { method: "POST",
      headers: { "Content-Type": "application/json", Origin: browserOrigin }, body: "{}" });
    assert.equal(challenge.status, 401);
    assert.match(challenge.headers.get("www-authenticate"), /resource_metadata/);
    assert.equal(challenge.headers.get("access-control-allow-origin"), browserOrigin);
    for (const path of ["/oauth/register", "/oauth/token", "/mcp"]) {
      const preflight = await mf.dispatchFetch(origin + path, { method: "OPTIONS",
        headers: { Origin: browserOrigin, "Access-Control-Request-Method": "POST",
          "Access-Control-Request-Headers": "authorization,content-type,mcp-protocol-version" } });
      assert.equal(preflight.status, 204);
      assert.equal(preflight.headers.get("access-control-allow-origin"), browserOrigin);
    }
    for (const method of ["POST", "OPTIONS"]) {
      assert.equal((await mf.dispatchFetch(origin + "/mcp", { method,
        headers: { Origin: "https://unlisted.example" } })).status, 403);
      assert.equal((await mf.dispatchFetch(origin + "/authorize", { method,
        headers: { Origin: browserOrigin } })).status, 403);
    }
    const registration = await mf.dispatchFetch(origin + "/oauth/register", { method: "POST",
      headers: { "Content-Type": "application/json", Origin: browserOrigin }, body: JSON.stringify({ client_name: '<script>alert("xss")</script>',
        redirect_uris: ["https://client.example/callback"], grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"], token_endpoint_auth_method: "none" }) });
    assert.equal(registration.status, 201);
    assert.equal(registration.headers.get("access-control-allow-origin"), browserOrigin);
    const client = await registration.json();
    const query = new URLSearchParams({ client_id: client.client_id, redirect_uri: "https://client.example/callback",
      response_type: "code", scope: "pkgfactory", resource: origin + "/mcp", state: "client-state",
      code_challenge: createHash("sha256").update("v".repeat(64)).digest("base64url"), code_challenge_method: "S256" });
    const consent = await mf.dispatchFetch(origin + "/authorize?" + query);
    assert.equal(consent.status, 200);
    const html = await consent.text();
    assert.match(html, /client.example/);
    assert.equal(html.includes('<script>alert("xss")</script>'), false);
    assert.equal(consent.headers.get("x-frame-options"), "DENY");
    const handle = html.match(/name="handle" value="([^"]+)"/)[1];
    const form = new URLSearchParams({ handle, decision: "approve" });
    const forged = await mf.dispatchFetch(origin + "/authorize", { method: "POST", body: form });
    assert.equal(forged.status, 400);
    const cookie = consent.headers.getSetCookie().map(c => c.split(";")[0]).join("; ");
    const approved = await mf.dispatchFetch(origin + "/authorize", { method: "POST",
      headers: { Cookie: cookie }, body: form, redirect: "manual" });
    assert.equal(approved.status, 302);
    const github = new URL(approved.headers.get("Location"));
    assert.equal(github.origin, "https://github.com");
    assert.equal(github.searchParams.get("redirect_uri"), origin + "/callback");
    assert.equal(github.searchParams.get("code_challenge_method"), "S256");
    assert.ok(github.searchParams.get("state"));
    const forgedCallback = await mf.dispatchFetch(origin + "/callback?state=" + github.searchParams.get("state") + "&code=stolen");
    assert.equal(forgedCallback.status, 400);
    const upstreamCookie = approved.headers.getSetCookie().map(c => c.split(";")[0]).join("; ");
    const callback = await mf.dispatchFetch(origin + "/callback?state=" + github.searchParams.get("state") + "&code=github-code",
      { headers: { Cookie: upstreamCookie }, redirect: "manual" });
    assert.equal(callback.status, 302);
    const destination = new URL(callback.headers.get("Location"));
    assert.equal(destination.origin, "https://client.example");
    assert.equal(destination.searchParams.get("state"), "client-state");
    const tokens = await mf.dispatchFetch(origin + "/oauth/token", { method: "POST",
      headers: { Origin: browserOrigin }, body: new URLSearchParams({
      grant_type: "authorization_code", code: destination.searchParams.get("code"), client_id: client.client_id,
      redirect_uri: "https://client.example/callback", code_verifier: "v".repeat(64), resource: origin + "/mcp",
    }) });
    assert.equal(tokens.status, 200);
    assert.equal(tokens.headers.get("access-control-allow-origin"), browserOrigin);
    const grant = await tokens.json();
    assert.ok(grant.access_token);
    assert.equal((await mf.dispatchFetch(origin + "/mcp", {
      headers: { Authorization: "Bearer " + grant.access_token },
    })).status, 405); // Authenticated stateless transport has no GET/SSE endpoint.
    const refresh = await mf.dispatchFetch(origin + "/oauth/token", { method: "POST", body: new URLSearchParams({
      grant_type: "refresh_token", refresh_token: grant.refresh_token, client_id: client.client_id,
      resource: origin + "/mcp", scope: " ",
    }) });
    assert.equal(refresh.status, 200);
    const narrowed = await refresh.json();
    const forbidden = await mf.dispatchFetch(origin + "/mcp", { method: "POST",
      headers: { Origin: browserOrigin, Authorization: "Bearer " + narrowed.access_token,
        "Content-Type": "application/json" }, body: "{}" });
    assert.equal(forbidden.status, 403);
    assert.match(forbidden.headers.get("www-authenticate"), /error="insufficient_scope"/);
    assert.match(forbidden.headers.get("www-authenticate"), /scope="pkgfactory"/);
    assert.match(forbidden.headers.get("www-authenticate"), /resource_metadata=/);
    assert.equal(forbidden.headers.get("access-control-allow-origin"), browserOrigin);
  } finally { await mf.dispose(); }
});

test("Web health reports maintenance and forwarding carries only its proxy credential", async () => {
  const result = await build({ stdin: {
    contents: `import worker from './web/worker.js';
      const limiter = { limit: async () => ({ success: true }) };
      const container = { idFromName: name => name, get: () => ({ fetch: async req =>
        Response.json({ proxy: req.headers.get('X-PkgFactory-Proxy'),
          authorization: req.headers.get('Authorization') }) }) };
      export default { fetch(req, env) {
        return worker.fetch(req, { ...env, EDGE_LIMIT: limiter, WEB_CONTAINER: container,
          MAINTENANCE: new URL(req.url).searchParams.get('maintenance') || 'false' });
      } };`, resolveDir: fileURLToPath(new URL("../../", import.meta.url)),
  }, bundle: true, format: "esm", platform: "neutral", mainFields: ["module", "main"], target: "es2022", write: false,
    external: ["cloudflare:*", "node:*"], conditions: ["workerd", "worker", "browser"] });
  const mf = new Miniflare(convertV4MiniflareOptions({ workers: [{ name: "web", modules: true,
    script: result.outputFiles[0].text, compatibilityDate: "2026-09-26", compatibilityFlags: ["nodejs_compat"],
    bindings: { PUBLIC_ORIGIN: "https://web.example.com", WEB_STATE_SECRET: webSecret, WEB_PROXY_SECRET: proxySecret },
  }] }));
  try {
    const health = await mf.dispatchFetch("https://web.example.com/api/health?maintenance=true");
    assert.equal(health.status, 503);
    assert.equal((await health.json()).status, "maintenance");
    assert.equal((await mf.dispatchFetch("https://web.example.com/api/config?maintenance=true")).status, 503);
    const forwarded = await mf.dispatchFetch("https://web.example.com/api/packages", { method: "POST",
      headers: { "X-PkgFactory-Proxy": "spoofed", Authorization: "Bearer user-github-token" }, body: "{}" });
    assert.equal(forwarded.status, 200);
    assert.deepEqual(await forwarded.json(), { proxy: proxySecret, authorization: "Bearer user-github-token" });
  } finally { await mf.dispose(); }
});

test("state credentials restrict Web to its own locks and keep recovery operator-only", async () => {
  const mf = await fixture();
  try {
    const send = (key, action, data) => mf.dispatchFetch(origin + "/internal/state", { method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ action, data }) });
    const operation = { repository: "alice/example.jl", operation: "same-id" };
    for (const key of [ticketSecret, proxySecret])
      assert.equal((await send(key, "acquire", operation)).status, 404);
    for (const action of ["plan_put", "plan_claim", "plan_finish", "recover"])
      assert.equal((await send(webSecret, action, {})).status, 403);
    assert.equal((await send(secret, "recover", {})).status, 403);
    assert.equal((await send(recoverySecret, "plan_claim", {})).status, 403);
    assert.equal((await send(secret, "acquire", operation)).status, 200);
    const release = await send(webSecret, "release", operation);
    assert.equal(release.status, 409);
    assert.equal((await release.json()).code, "operation_mismatch");
    assert.equal((await send(webSecret, "acquire", operation)).status, 409);
    assert.equal((await send(secret, "release", operation)).status, 200);
    assert.equal((await send(webSecret, "acquire", operation)).status, 200);
    assert.equal((await send(webSecret, "release", operation)).status, 200);
    assert.equal((await send(recoverySecret, "recover", {
      repository: operation.repository, containers_stopped: true,
    })).status, 409);
  } finally { await mf.dispose(); }
});

test("recovery checks both maintenance modes and still requires explicit stopped confirmation", async () => {
  for (const webMaintenance of [false, true]) {
    const mf = await fixture({ maintenance: true, webMaintenance });
    try {
      const recover = containers_stopped => mf.dispatchFetch(origin + "/internal/state", { method: "POST",
        headers: { Authorization: `Bearer ${recoverySecret}`, "Content-Type": "application/json" },
        body: JSON.stringify({ action: "recover", data: { repository: "alice/example.jl", containers_stopped } }) });
      assert.equal((await recover(false)).status, 409);
      assert.equal((await recover(true)).status, webMaintenance ? 200 : 409);
    } finally { await mf.dispose(); }
  }
});

test("Durable Object transactions serialize concurrent claims and reject unauthenticated storage access", async () => {
  const mf = await fixture();
  try {
    const send = (action, data) => mf.dispatchFetch(origin + "/internal/state", { method: "POST",
      headers: { Authorization: `Bearer ${secret}`, "Content-Type": "application/json" },
      body: JSON.stringify({ action, data }) });
    assert.equal((await mf.dispatchFetch(origin + "/internal/state", { method: "POST", body: "{}" })).status, 404);
    const principal = ["github", "123"];
    assert.equal((await send("plan_put", { id: "one", principal, ttl: 900,
      snapshot: { version: 1, spec: {}, files: {} } })).status, 200);
    const claims = await Promise.all(["a", "b"].map(claim => send("plan_claim", { id: "one", principal, claim })));
    assert.deepEqual(claims.map(r => r.status).sort(), [200, 409]);
    const foreign = await send("plan_claim", { id: "one", principal: ["github", "999"], claim: "c" });
    assert.equal((await foreign.json()).code, "plan_not_found");
  } finally { await mf.dispose(); }
});
