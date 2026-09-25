# PkgFactoryMCP.jl

[![CI](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml)

Create Julia package repositories from an AI application using
[PkgFactory.jl](https://github.com/JuliaPackageFactory/PkgFactory.jl) and
[ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl).
Requires Julia 1.12 or newer. Supports stdio and authenticated Streamable HTTP.

## Quick start

Clone the repository and instantiate its project. The pinned `[sources]` entries
install the required PkgFactory API and MCP implementation; this checkout workflow
also works while PkgFactory is not in the General registry.

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
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

The defaults are **all-in-one** and **public**, shared with the core. `name` may end in `.jl`.
`resume` is an optional boolean, defaulting to `false`. Preview validates settings
without GitHub access; it does not check whether a remote repository exists.

Present the preview to the user and execute only within their authorization.
Creation accepts the saved plan ID, so settings cannot be changed between
preview and execution. The client controls user approval: a plan ID itself is
not proof of human consent. Tokens are never tool arguments.

Completed plans return the same result on retry while retained. Plans expire
after 15 minutes by default and do not survive server restart. After a failed
creation, inspect GitHub before making a new preview with `resume: true`.

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
them; browser-based OAuth clients should use the Auth0 launcher.

A Dockerfile, a Render Blueprint, and `apps/mcp/bin/auth0-server.jl` are included for an
**Auth0-authenticated, single-operator HTTPS deployment**. See
[hosting and recovery](docs/hosting.md) for setup and limitations. Deploying to
Render and creating Auth0/GitHub credentials are separate setup steps.

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
are application responsibilities; the current package keeps plans in memory.

## Development

```sh
julia --project=apps/mcp --startup-file=no -e 'using Pkg; Pkg.test()'
```

Tests cover protocol discovery, configuration validation, plan execution,
duplicate calls, user isolation, expiration, error redaction, real stdio, and
real HTTP authentication. GitHub-changing operations use a mock backend.

See the [Developer Guide](../../docs/src/developer.md) for the repository layout
and shared development workflow. Package validation, defaults, template
generation, creation, and recovery are provided by the local core. The MCP plan
store handles caller identity, expiration, and duplicate tool calls.

Streamable HTTP uses the [MCP SDK](https://github.com/JuliaSMLM/ModelContextProtocol.jl)
and the [standard transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

## Acknowledgments

Generated from the `minimum` template of
[PkgFactory.jl](https://github.com/JuliaPackageFactory/PkgFactory.jl). MIT licensed.

This application was imported from JuliaPackageFactory/PkgFactoryMCP.jl
at commit `0b16c0d106607e8dbdf47b4245a1d50189eb60a2` (MIT license retained).
