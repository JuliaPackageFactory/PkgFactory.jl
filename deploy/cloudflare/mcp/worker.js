import { Container, getContainer } from "@cloudflare/containers";
import { DurableObject } from "cloudflare:workers";
import OAuthProvider, { insufficientScope } from "@cloudflare/workers-oauth-provider";
import { forwardedHeaders, json, limited, origin, readBody, requireDistinctSecrets, sameSecret, ticket } from "../shared/http.js";
import { StateError, stateAction } from "../shared/state.js";
import { oauthRoutes, refreshGitHub } from "./oauth.js";

export class McpContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "5m";
  constructor(ctx, env) {
    super(ctx, env);
    this.envVars = { MCP_ORIGIN: env.MCP_ORIGIN,
      MCP_TICKET_SECRET: env.MCP_TICKET_SECRET, MCP_STATE_SECRET: env.MCP_STATE_SECRET };
  }
  async fetch(request) {
    await this.startAndWaitForPorts({ cancellationOptions: { portReadyTimeoutMS: 120000 } });
    return this.containerFetch(request);
  }
}

export class ApplicationState extends DurableObject {
  async fetch(request) {
    try {
      const { action, data } = await request.json();
      const result = await this.ctx.storage.transaction(tx => stateAction(tx, action, data));
      return json(result);
    } catch (error) {
      return json({ code: error instanceof StateError ? error.code : "state_unavailable" },
        error instanceof StateError ? 409 : 503);
    }
  }
}

const apiHandler = {
  async fetch(request, env, ctx) {
    if (new URL(request.url).pathname !== "/mcp") return json({ error: "Not found" }, 404);
    if (!ctx.auth.scope.includes("pkgfactory")) return insufficientScope(ctx.auth, ["pkgfactory"]);
    // JSON responses are a standard Streamable HTTP mode. GET SSE is deliberately
    // unavailable: a connection must never subscribe to another user's replies.
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { Allow: "POST" } });
    if (!await limited(env.USER_LIMIT, ctx.props.userId)) return json({ error: "Too many requests" }, 429);
    const headers = forwardedHeaders(request);
    headers.set("Authorization", "Bearer " + await ticket(env.MCP_TICKET_SECRET, ctx.props));
    const response = await getContainer(env.MCP_CONTAINER, "mcp").fetch(
      new Request(request, { headers, redirect: "manual" }));
    const publicHeaders = new Headers(response.headers);
    publicHeaders.delete("mcp-session-id");
    publicHeaders.set("Cache-Control", "no-store");
    return new Response(response.body, { status: response.status, headers: publicHeaders });
  },
};

function provider(env) {
  return new OAuthProvider({ apiRoute: "/mcp", apiHandler,
    defaultHandler: { fetch: oauthRoutes }, authorizeEndpoint: "/authorize",
    tokenEndpoint: "/oauth/token", clientRegistrationEndpoint: "/oauth/register",
    scopesSupported: ["pkgfactory"], accessTokenTTL: 3600, refreshTokenTTL: 2592000,
    clientRegistrationTTL: 2592000, clientIdMetadataDocumentEnabled: true,
    allowImplicitFlow: false, allowPlainPKCE: false,
    resourceMetadata: { resource: env.MCP_ORIGIN + "/mcp",
      authorization_servers: [env.MCP_ORIGIN], scopes_supported: ["pkgfactory"] },
    tokenExchangeCallback: refreshGitHub,
  });
}

async function internalState(request, env) {
  if (request.method !== "POST") return json({ error: "Not found" }, 404);
  const authorization = request.headers.get("Authorization") || "";
  let role;
  for (const [candidate, secret] of [["mcp", env.MCP_STATE_SECRET], ["web", env.WEB_STATE_SECRET],
    ["recovery", env.STATE_RECOVERY_SECRET]]) {
    if (await sameSecret(authorization, "Bearer " + secret)) role = candidate;
  }
  if (!role) return json({ error: "Not found" }, 404);
  const message = JSON.parse(new TextDecoder().decode(await readBody(request, 120000)));
  const { action, data } = message;
  const locking = action === "acquire" || action === "release";
  const allowed = role === "recovery" ? action === "recover" :
    locking || (role === "mcp" && ["plan_put", "plan_claim", "plan_finish"].includes(action));
  if (!allowed) return json({ code: "forbidden" }, 403);
  // A Web credential cannot release an MCP lock, even if its operation ID leaks.
  if (locking) {
    if (typeof data?.operation !== "string") return json({ code: "invalid_operation" }, 400);
    data.operation = role + ":" + data.operation;
  }
  if (action === "recover") {
    if (env.MAINTENANCE !== "true") return json({ error: "Enable maintenance before recovery" }, 409);
    const web = await fetch(origin(env.WEB_ORIGIN) + "/api/health", {
      redirect: "manual", signal: AbortSignal.timeout(5000),
    });
    if (web.status !== 503 || (await web.json()).status !== "maintenance")
      return json({ error: "Enable Web maintenance before recovery" }, 409);
  }
  return env.APPLICATION_STATE.get(env.APPLICATION_STATE.idFromName("application")).fetch(
    new Request("https://state.internal/", { method: "POST", body: JSON.stringify(message) }));
}

function allowedOrigin(request, env, path) {
  const browserOrigin = request.headers.get("Origin");
  if (browserOrigin === null || browserOrigin === env.MCP_ORIGIN) return true;
  // OAuth discovery, registration and tokens use the provider's CORS handling;
  // consent/callback routes still require our own origin.
  if (["/oauth/token", "/oauth/register", "/.well-known/oauth-authorization-server",
    "/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp"].includes(path)) return true;
  if (path !== "/mcp") return false;
  try {
    const url = new URL(browserOrigin);
    return ["http:", "https:"].includes(url.protocol) && url.origin === browserOrigin &&
      Array.isArray(env.MCP_ALLOWED_ORIGINS) && env.MCP_ALLOWED_ORIGINS.includes(browserOrigin);
  } catch { return false; }
}

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      if (url.origin !== origin(env.MCP_ORIGIN)) return json({ error: "Invalid host" }, 403);
      requireDistinctSecrets(env.MCP_TICKET_SECRET, env.MCP_STATE_SECRET, env.WEB_STATE_SECRET, env.STATE_RECOVERY_SECRET);
      if (url.pathname === "/internal/state") return await internalState(request, env);
      if (url.pathname === "/health" && request.method === "GET") return json({ status: "ok" });
      if (env.MAINTENANCE === "true") return json({ error: "Maintenance in progress" }, 503);
      if (!allowedOrigin(request, env, url.pathname))
        return json({ error: "Origin is not allowed" }, 403);
      const ip = request.headers.get("CF-Connecting-IP") || "unknown";
      if (!await limited(env.EDGE_LIMIT, ip)) return json({ error: "Too many requests" }, 429);
      if (["/authorize", "/oauth/register", "/callback"].includes(url.pathname) && !await limited(env.AUTH_LIMIT, ip))
        return json({ error: "Too many sign-in requests" }, 429);
      if (request.method === "POST") request = new Request(request, { body: await readBody(request) });
      return await provider(env).fetch(request, env, ctx);
    } catch (error) {
      return json({ error: error instanceof RangeError ? "Request too large" : "Service unavailable" },
        error instanceof RangeError ? 413 : 503);
    }
  },
};
