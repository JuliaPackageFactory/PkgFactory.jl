# Render

## Configure the service

The included [Blueprint](https://github.com/JuliaPackageFactory/PkgFactory.jl/blob/main/deploy/mcp/render/render.yaml)
uses [this Dockerfile](https://github.com/JuliaPackageFactory/PkgFactory.jl/blob/main/deploy/mcp/render/Dockerfile) with the
repository root as its build context. It deploys one Julia instance, with Render
terminating HTTPS and forwarding HTTP to the container. Set up the service as a
Docker web service and select `deploy/mcp/render/render.yaml` as the Blueprint
path. The Blueprint uses a TCP readiness check
because MCP endpoints require authentication.

1. Create an Auth0 API whose identifier is the final HTTPS `/mcp` URL.
2. Follow Auth0's MCP setup, including Resource Parameter Compatibility Profile,
   authorization code + PKCE, and a supported client registration method (CIMD,
   DCR, or preregistration for the intended client).
3. Set `AUTH0_ISSUER` to the exact issuer, normally ending in `/`, and
   `MCP_RESOURCE_URL` to that API identifier. The launcher fetches signing keys
   from the issuer's `/.well-known/jwks.json` endpoint.
4. Set `MCP_OPERATOR_SUBJECT` to the operator's exact Auth0 `sub`. Requests from
   other subjects are denied, even if signed by the same Auth0 tenant.
5. Set `GITHUB_TOKEN` in Render's secret environment settings with the
   [repository permissions](../user.md#GitHub-authentication) required by PkgFactory.
6. Connect the MCP client to `https://YOUR-SERVICE.onrender.com/mcp`. Complete the
   Auth0 login flow, then follow the [MCP tool workflow](../mcp.md#Tools).

`apps/mcp/bin/auth0-server.jl` is a **single-operator** deployment. The Auth0 token permits
access to MCP; the separate GitHub token permits repository operations. The
incoming MCP token is never forwarded to GitHub.

## Operation

Keep `numInstances: 1`: this launcher uses the
[standalone MCP plan store](../mcp.md#Plan-lifecycle). Use the
[Cloudflare deployment](cloudflare.md) when persistent shared plans and per-user
GitHub authorization are required, or implement the
[custom HTTP backend](../mcp.md#Julia-API).

Complete the [deployment acceptance checks](index.md#Acceptance-checks), including
request timeouts and resource limits, before making the service available.

## References

- [ModelContextProtocol.jl HTTP transport](https://juliasmlm.github.io/ModelContextProtocol.jl/stable/transports/)
- [Auth0 MCP setup](https://auth0.com/ai/docs/mcp/get-started/authorization-for-your-mcp-server)
- [Render Docker services](https://render.com/docs/docker)
- [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
