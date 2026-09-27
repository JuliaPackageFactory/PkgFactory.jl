# MCP Guide

The MCP interface is the `PkgFactoryMCP` Julia application in `apps/mcp/`.
It supports stdio and authenticated Streamable HTTP through
[ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl).

## Quick start

[Get the source](index.md#Get-the-source), then run these commands from the
repository root:

```sh
julia --project=apps/mcp --startup-file=no -e 'using Pkg; Pkg.instantiate()'
julia --project=apps/mcp --startup-file=no apps/mcp/bin/pkgfactory-mcp.jl --read-only
```

The final command waits for MCP messages on stdin. Configure your MCP client to
launch it; this is not an interactive Julia REPL. Omit `--read-only` to enable
repository creation and supply `GITHUB_TOKEN` (or `GH_TOKEN`) in the server's
environment. The token is only read when creation is requested.

For clients using the `mcpServers` configuration format:

```json
{
  "mcpServers": {
    "pkgfactory": {
      "command": "julia",
      "args": [
        "--project=/absolute/path/to/PkgFactory.jl/apps/mcp",
        "--startup-file=no",
        "/absolute/path/to/PkgFactory.jl/apps/mcp/bin/pkgfactory-mcp.jl"
      ]
    }
  }
}
```

Provide credentials through your client's secret/environment settings. On
Windows, forward slashes work in these paths. Logs go to stderr; stdout is
reserved for MCP messages. Allow enough startup time for Julia's first load.

## Tools

| Tool | Input | Result |
| --- | --- | --- |
| `list_templates` | `{}` | Available template names |
| `preview_package` | Package settings | Saved `plan_id`, normalized repository, visibility, and planned filenames |
| `create_package` | `{"plan_id": "..."}` | Repository URL and whether setup was resumed |

Example input to `preview_package`:

```json
{
  "owner": "octocat",
  "name": "MyPackage",
  "authors": ["The Octocat"],
  "description": "A package for my research",
  "template": "minimum",
  "visibility": "private"
}
```

Input fields, defaults, and preview validation follow the shared
[package settings](user.md#Package-settings).

Present the preview to the user and execute only within their authorization.
Creation accepts the saved plan ID, so settings cannot be changed between
preview and execution. The client controls user approval: a plan ID itself is
not proof of human consent.

## Plan lifecycle

Plans expire 15 minutes after preview by default. A completed plan returns its
cached result on a repeat call while retained. An in-flight or failed plan cannot
be executed again. Different previews create different plans; this does not
provide global repository deduplication. For failed creation, follow
[Resuming an interrupted setup](user.md#Resuming-an-interrupted-setup).

The standalone stdio, HTTP, and Render launchers store plans in process memory,
with up to 256 records. Restarting or redeploying invalidates them, and replicas
do not share them. Configure `plan_ttl` and `max_plans` in `build_server` to change
these defaults. Cloudflare uses a [durable store](deployment/cloudflare.md#Persistence,-failures,-and-recovery)
with additional quotas and recovery controls.

Tools execute synchronously. Long-running jobs require a persistent operation
store and a worker; account for creation time in the client's request timeout.

## HTTP and HTTPS

For one trusted operator, set **different** `MCP_AUTH_TOKEN` and `GITHUB_TOKEN`
secrets, then start:

```sh
julia --project=apps/mcp --startup-file=no apps/mcp/bin/pkgfactory-mcp.jl --transport http --port 8080
```

Connect to `http://127.0.0.1:8080/mcp` with
`Authorization: Bearer <MCP_AUTH_TOKEN>`. Add `--read-only` to omit creation.
To make the service reachable outside the machine, bind with `--host 0.0.0.0`
and place it behind a trusted HTTPS proxy. The HTTP launcher requires auth even
on loopback. Static bearer tokens work only with clients that support supplying
them. For hosted OAuth services, choose a target in the
[Deployment Overview](deployment/index.md).

## Julia API

```julia
using PkgFactoryMCP

server = build_server(enable_create = false) # no process started
serve_stdio()                              # blocks until client disconnects
```

Applications hosting multiple users can call:

```julia
serve_http(
    auth = oauth_middleware,
    resource_metadata = oauth_resource_metadata,
    backend_resolver = ctx -> github_backend_for(ctx.authenticated_user),
    enable_create = true,
)
```

The application implements `github_backend_for` and returns a
`PkgFactory.Credential` holding that user's GitHub token. HTTP does not
implicitly fall back to the server's environment token. Plan access is tied to
the verified identity. Account linking and a durable credential/operation store
are application responsibilities; use the
[Cloudflare integration](deployment/cloudflare.md) for the included implementation.

For application tests and development commands, see
[Development Workflow](developer.md#Local-development-and-tests).
Streamable HTTP follows the
[standard transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Acknowledgments

This application was imported from JuliaPackageFactory/PkgFactoryMCP.jl
at commit `0b16c0d106607e8dbdf47b4245a1d50189eb60a2`. The original
[MIT license](https://github.com/JuliaPackageFactory/PkgFactory.jl/blob/main/apps/mcp/LICENSE) is retained.
