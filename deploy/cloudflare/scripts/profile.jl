# Offline, repeatable runtime measurement. Run in the production Docker image
# with --memory=1g --memory-swap=1g --cpus=0.25 --network=none.
# Only GitHub/state storage are replaced. HTTP, templates, keys and encryption run.
const started = time()
const app = only(ARGS)
app in ("web", "mcp") || error("Expected web or mcp")
if app == "mcp"
    using PkgFactoryMCP
else
    using PkgFactoryWeb
end
import PkgFactory
app == "web" && include("/app/apps/shared/Cloudflare.jl")
const HTTP = PkgFactory.HTTP
const JSON3 = PkgFactory.JSON3
include("/fixtures/github.jl")
const secret = repeat("profile-only-", 5)

function report(stage)
    peak_file = isfile("/sys/fs/cgroup/memory.peak") ? "/sys/fs/cgroup/memory.peak" :
        "/sys/fs/cgroup/memory/memory.max_usage_in_bytes"
    println(JSON3.write(Dict("app" => app, "stage" => stage,
        "elapsed_seconds" => round(time() - started; digits=2),
        "process_peak_mib" => round(Sys.maxrss() / 2.0^20; digits=2),
        "container_peak_mib" => isfile(peak_file) ? round(parse(Int, strip(read(peak_file, String))) / 2.0^20; digits=2) : nothing)))
    flush(stdout)
end

const config = Dict("owner" => "ohno", "name" => "MyPackage", "authors" => ["Profile"],
    "description" => "Offline capacity measurement")
const base = "http://127.0.0.1:8080"
const headers = ["Content-Type" => "application/json", "Accept" => "application/json, text/event-stream"]
const requester = Ref{Any}()
requester[] = last(github_fixture())

if app == "mcp"
    server = PkgFactoryMCP.build_server(; require_identity=true,
        backend_resolver=ctx -> PkgFactory.Credential("profile-token"),
        creator=(plan; backend) -> PkgFactory.create_package(backend, plan; requester=requester[]))
    http = PkgFactoryMCP.serve_cloudflare(; origin="https://profile.invalid", secret, server)
    function call_tool(name, arguments=Dict())
        payload = PkgFactory.Base64.base64encode(JSON3.write(Dict("aud" => "pkgfactory-container",
            "sub" => "profile", "github_token" => "profile-token", "exp" => time() + 120)))
        signature = bytes2hex(PkgFactory.SHA.hmac_sha256(Vector{UInt8}(codeunits(secret)), codeunits(payload)))
        auth = [headers; "Authorization" => "Bearer $payload.$signature"]
        response = HTTP.post(base * "/mcp", auth, JSON3.write(Dict("jsonrpc" => "2.0", "id" => 1,
            "method" => "tools/call", "params" => Dict("name" => name, "arguments" => arguments))); readtimeout=180)
        result = JSON3.read(String(response.body), Dict{String,Any})["result"]
        @assert !get(result, "isError", false) result
        JSON3.read(result["content"][1]["text"], Dict{String,Any})
    end
else
    http = PkgFactoryWeb.start("0.0.0.0", 8080; public_origin=base, proxy_token=secret,
        requester=(args...; kwargs...) -> requester[](args...; kwargs...))
    push!(headers, "Authorization" => "Bearer profile-token", "X-PkgFactory-Proxy" => secret)
end

try
    report("listening")
    if app == "mcp"
        call_tool("list_templates")
    else
        @assert HTTP.get(base * "/api/config", headers).status == 200
    end
    report("discovery")
    for template in PkgFactory.list_templates()
        requester[] = last(github_fixture())
        args = merge(config, Dict("template" => template))
        if app == "mcp"
            preview = call_tool("preview_package", args)
            call_tool("create_package", Dict("plan_id" => preview["plan_id"]))
        else
            response = HTTP.post(base * "/api/packages", headers, JSON3.write(args); readtimeout=180)
            @assert response.status == 201
        end
        report("created_" * template)
    end
    # A small burst exercises simultaneous HTTP handling. Retained MCP plans
    # make this slightly more conservative than the remote durable plan store.
    @sync for _ in 1:4
        @async if app == "mcp"
            call_tool("preview_package", merge(config, Dict("template" => "all-in-one")))
        else
            @assert HTTP.get(base * "/api/config", headers).status == 200
        end
    end
    report("burst_complete")
finally
    close(http)
end
