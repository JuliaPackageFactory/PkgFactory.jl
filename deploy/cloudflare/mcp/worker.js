import { Container, getContainer } from "@cloudflare/containers";
import { DurableObject } from "cloudflare:workers";
import OAuthProvider from "@cloudflare/workers-oauth-provider";
import { forwardedHeaders, json, limited, origin, readBody, sameSecret, ticket } from "../shared/http.js";
import { StateError, stateAction } from "../shared/state.js";
import { oauthRoutes, refreshGitHub } from "./oauth.js";

export class McpContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "5m";
  constructor(ctx, env) {
    super(ctx, env);
    this.envVars = { MCP_ORIGIN: env.MCP_ORIGIN, INTERNAL_SECRET: env.INTERNAL_SECRET };
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
    if (!ctx.auth?.scope.includes("pkgfactory")) return json({ error: "insufficient_scope" }, 403);
    // JSON responses are a standard Streamable HTTP mode. GET SSE is deliberately
    // unavailable: a connection must never subscribe to another user's replies.
    if (request.method !== "POST") return new Response(null, { status: 405, headers: { Allow: "POST" } });
    if (!await limited(env.USER_LIMIT, ctx.props.userId)) return json({ error: "Too many requests" }, 429);
    const headers = forwardedHeaders(request);
    headers.set("Authorization", "Bearer " + await ticket(env.INTERNAL_SECRET, ctx.props));
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

export default {
  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      if (url.origin !== origin(env.MCP_ORIGIN)) return json({ error: "Invalid host" }, 403);
      if (!env.INTERNAL_SECRET || env.INTERNAL_SECRET.length < 32) throw new Error("Missing secret");
      if (url.pathname === "/internal/state") {
        if (request.method !== "POST" || !await sameSecret(
          request.headers.get("Authorization") || "", "Bearer " + env.INTERNAL_SECRET))
          return json({ error: "Not found" }, 404);
        const body = await readBody(request, 120000);
        const message = JSON.parse(new TextDecoder().decode(body));
        if (message.action === "recover" && env.MAINTENANCE !== "true")
          return json({ error: "Enable maintenance before recovery" }, 409);
        return env.APPLICATION_STATE.get(env.APPLICATION_STATE.idFromName("application")).fetch(
          new Request("https://state.internal/", { method: "POST", body }));
      }
      if (url.pathname === "/health" && request.method === "GET") return json({ status: "ok" });
      if (env.MAINTENANCE === "true") return json({ error: "Maintenance in progress" }, 503);
      if (request.headers.has("Origin") && request.headers.get("Origin") !== env.MCP_ORIGIN)
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
