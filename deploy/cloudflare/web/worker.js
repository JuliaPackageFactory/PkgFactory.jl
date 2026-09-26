import { Container, getContainer } from "@cloudflare/containers";
import { forwardedHeaders, json, limited, origin, readBody, requireDistinctSecrets } from "../shared/http.js";

export class WebContainer extends Container {
  defaultPort = 8080;
  sleepAfter = "5m";
  constructor(ctx, env) {
    super(ctx, env);
    this.envVars = { PUBLIC_ORIGIN: env.PUBLIC_ORIGIN, MCP_ORIGIN: env.MCP_ORIGIN,
      GITHUB_OAUTH_CLIENT_ID: env.GITHUB_OAUTH_CLIENT_ID,
      WEB_STATE_SECRET: env.WEB_STATE_SECRET, WEB_PROXY_SECRET: env.WEB_PROXY_SECRET };
  }
  async fetch(request) {
    await this.startAndWaitForPorts({ cancellationOptions: { portReadyTimeoutMS: 120000 } });
    return this.containerFetch(request);
  }
}

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      if (url.origin !== origin(env.PUBLIC_ORIGIN)) return json({ error: "Invalid host" }, 403);
      if (!url.pathname.startsWith("/api/")) return env.ASSETS.fetch(request);
      requireDistinctSecrets(env.WEB_STATE_SECRET, env.WEB_PROXY_SECRET);
      if (url.pathname === "/api/health" && request.method === "GET")
        return json({ status: env.MAINTENANCE === "true" ? "maintenance" : "ok", component: "gateway" },
          env.MAINTENANCE === "true" ? 503 : 200);
      if (env.MAINTENANCE === "true") return json({ error: "Maintenance in progress" }, 503);
      if (request.headers.has("Origin") && request.headers.get("Origin") !== env.PUBLIC_ORIGIN)
        return json({ error: "Origin is not allowed" }, 403);
      const ip = request.headers.get("CF-Connecting-IP") || "unknown";
      if (!await limited(env.EDGE_LIMIT, ip)) return json({ error: "Too many requests" }, 429);
      const headers = forwardedHeaders(request);
      headers.set("X-Real-IP", ip);
      headers.set("X-PkgFactory-Proxy", env.WEB_PROXY_SECRET);
      const body = ["GET", "HEAD"].includes(request.method) ? undefined : await readBody(request);
      return await getContainer(env.WEB_CONTAINER, "web").fetch(new Request(request, { headers, body, redirect: "manual" }));
    } catch (error) {
      return json({ error: error instanceof RangeError ? "Request too large" :
        "Service unavailable. Check repository status before retrying a creation." }, error instanceof RangeError ? 413 : 503);
    }
  },
};
