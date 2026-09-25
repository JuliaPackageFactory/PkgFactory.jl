# HTTPS hosting

The package supports a local stdio process and an authenticated Streamable HTTP
server at `/mcp`. It does not provision cloud accounts or issue OAuth tokens.

## Render + Docker + Auth0

The included `apps/mcp/render.yaml` (build context: monorepo root) deploys one Julia instance, with Render terminating
HTTPS and forwarding HTTP to the container. Set up the service as a Docker web
service using the Blueprint. The paid plan is a starting point; measure memory
and latency before adjusting it. The Blueprint uses a TCP readiness check
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
5. Set `GITHUB_TOKEN` in Render's secret environment settings. For the existing
   PkgFactory workflow, a classic token needs `repo` and `workflow`; organization
   policy or SSO may require additional authorization. Never put tokens in git,
   tool arguments, URLs, or client-visible results.
6. Connect the MCP client to `https://YOUR-SERVICE.onrender.com/mcp`. Complete the
   Auth0 login flow, list tools, then preview before creating a repository.

`apps/mcp/bin/auth0-server.jl` is a **single-operator** deployment. The Auth0 token permits
access to MCP; the separate GitHub token permits repository operations. The
incoming MCP token is never forwarded to GitHub.

## Multiple users

Use `serve_http(auth=..., resource_metadata=..., backend_resolver=...,
enable_create=true)`. The resolver receives `ctx.authenticated_user`; use its
verified provider/subject to retrieve that user's GitHub credential. Plans are
bound to this identity. A multi-user service additionally needs a GitHub OAuth
account-linking flow and encrypted credential storage (PostgreSQL is the
recommended persistent store). Those application services are not included in
this package. Do not replace the resolver with one shared administrator token.

## Operations and recovery

- Defaults come from the core: `all-in-one` and **public**. Pass `private`
  explicitly for a private repository and inspect the saved plan before creation.
- Plans expire after 15 minutes and storage is limited to 256 records by default.
  Configure `plan_ttl` / `max_plans` when constructing the server.
- A completed plan returns its cached result on a repeat call during its lifetime.
  An in-flight or failed plan cannot be executed again. Different previews create
  different plans, so this is not global repository deduplication.
- Plans and results are held in memory. Restart/deploy invalidates them; multiple
  replicas do not share them. Keep one instance for this initial deployment.
- GitHub changes are not transactional. After a failure, inspect the repository
  before making a new preview with `resume=true`. That flag uses PkgFactory's
  existing recovery behavior; it is not an automatic rollback or retry.
- Tools execute synchronously. Measure creation time against the client's timeout.
  Long-running or durable jobs require a persistent operation store and worker.
- Configure platform resource limits and client/user rate limits before opening
  a multi-user service. Log operational metadata, never access tokens.

## References

- [ModelContextProtocol.jl HTTP transport](https://juliasmlm.github.io/ModelContextProtocol.jl/stable/transports/)
- [Auth0 MCP setup](https://auth0.com/ai/docs/mcp/get-started/authorization-for-your-mcp-server)
- [Render Docker services](https://render.com/docs/docker)
- [MCP authorization](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization)
