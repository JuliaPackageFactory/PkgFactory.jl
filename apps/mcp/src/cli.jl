const HELP = """
PkgFactoryMCP — Julia package creation over MCP

Usage: julia --project=apps/mcp apps/mcp/bin/pkgfactory-mcp.jl [options]
  --transport stdio|http   Default: stdio
  --host HOST              HTTP bind address (default: 127.0.0.1)
  --port PORT              HTTP port (default: PORT environment variable or 8080)
  --read-only              Expose only list_templates and preview_package
  --help                   Show this help

stdio creation uses GITHUB_TOKEN (or GH_TOKEN) on the server.
HTTP requires a separate MCP_AUTH_TOKEN and is for one trusted user with this
launcher. --read-only does not require GitHub credentials.
Use serve_http with OAuth and a per-user backend_resolver for multiple users.
"""

"""Command-line entry point; see `main(["--help"])`."""
function main(args=ARGS)
    "--help" in args && (println(HELP); return nothing)
    transport, host = "stdio", "127.0.0.1"
    port = get(ENV, "PORT", "8080")
    read_only = false
    i = 1
    while i <= length(args)
        option = args[i]
        if option == "--read-only"
            read_only = true
        elseif option in ("--transport", "--host", "--port")
            i < length(args) || throw(ArgumentError("$option requires a value"))
            i += 1
            option == "--transport" && (transport = args[i])
            option == "--host" && (host = args[i])
            option == "--port" && (port = args[i])
        else
            throw(ArgumentError("Unknown option: $option"))
        end
        i += 1
    end
    transport in ("stdio", "http") || throw(ArgumentError("transport must be stdio or http"))
    transport == "stdio" && return serve_stdio(; enable_create=!read_only)
    token = strip(get(ENV, "MCP_AUTH_TOKEN", ""))
    isempty(token) && throw(ArgumentError("Set MCP_AUTH_TOKEN for HTTP authentication"))
    github_token = strip(get(ENV, "GITHUB_TOKEN", get(ENV, "GH_TOKEN", "")))
    token == github_token && throw(ArgumentError("MCP_AUTH_TOKEN must differ from the GitHub token"))
    backend = if read_only
        nothing
    else
        isempty(github_token) && throw(ArgumentError("Set GITHUB_TOKEN or use --read-only"))
        environment_credential()
    end
    auth = MCP.create_simple_auth(Dict(token => "operator"))
    resolver = ctx -> begin
        principal(ctx, true) == ("api_key", "operator") || fail("unauthorized", "Unknown operator.")
        backend
    end
    parsed_port = tryparse(Int, port)
    isnothing(parsed_port) && throw(ArgumentError("port must be an integer"))
    serve_http(; auth, backend_resolver=resolver, enable_create=!read_only, host, port=parsed_port)
end
