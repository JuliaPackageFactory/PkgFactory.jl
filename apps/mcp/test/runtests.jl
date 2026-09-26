using PkgFactoryMCP
using Test
import JSON3
import ModelContextProtocol as MCP
import PkgFactory

const CONFIG = Dict{String,Any}("owner" => "octocat", "name" => "DemoPkg.jl",
    "authors" => ["Octocat"], "description" => "A test package")
const ALICE = MCP.AuthenticatedUser(subject="alice", provider="test")
const BOB = MCP.AuthenticatedUser(subject="bob", provider="test")

function rpc(server, state, method, params=Dict(); user=nothing)
    request = JSON3.write(Dict("jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params))
    JSON3.read(MCP.process_message(server, state, request; authenticated_user=user), Dict{String,Any})
end
function client(server)
    state = MCP.ServerState()
    init = rpc(server, state, "initialize", Dict("protocolVersion" => "2025-11-25",
        "capabilities" => Dict(), "clientInfo" => Dict("name" => "test", "version" => "1")))
    @test haskey(init, "result")
    state
end
call(server, state, name, args=Dict(); user=nothing) =
    rpc(server, state, "tools/call", Dict("name" => name, "arguments" => args); user)["result"]
data(result) = result["structuredContent"]

@testset "MCP discovery, preview, and validation" begin
    withenv("GITHUB_TOKEN" => nothing, "GH_TOKEN" => nothing) do
        server = build_server()
        state = client(server)
        tools = rpc(server, state, "tools/list")["result"]["tools"]
        @test Set(t["name"] for t in tools) == Set(["list_templates", "preview_package", "create_package"])
        @test tools[1]["annotations"]["readOnlyHint"]
        @test !tools[3]["annotations"]["readOnlyHint"]
        @test "minimum" in data(call(server, state, "list_templates"))["templates"]
        preview = call(server, state, "preview_package", CONFIG)
        @test !preview["isError"]
        plan = data(preview)
        @test plan["repository"] == "octocat/DemoPkg.jl"
        @test plan["visibility"] == PkgFactory.DEFAULT_VISIBILITY
        @test plan["template"] == PkgFactory.DEFAULT_TEMPLATE
        @test !plan["changes_made"]
        @test "src/DemoPkg.jl" in plan["files"]
        @test length(plan["files"]) == length(PkgFactory.plan_package(CONFIG).files)
        @test data(call(server, state, "preview_package", merge(CONFIG, Dict("visibility" => "public", "resume" => true))))["operation"] == "resume"
        for invalid in (Dict("template" => "../minimum"), Dict("authors" => []),
            Dict("authors" => [1]), Dict("resume" => "true"), Dict("name" => "../../Bad"),
            Dict("visibility" => "secret"), Dict("access_token" => "never-a-tool-argument"))
            result = call(server, state, "preview_package", merge(CONFIG, invalid))
            @test result["isError"]
        end
        missing = copy(CONFIG)
        delete!(missing, "owner")
        @test call(server, state, "preview_package", missing)["isError"]
    end
end

@testset "Execution uses the saved plan and deduplicates retries" begin
    calls = Ref(0)
    captured = Ref{Any}()
    creator = (plan; backend) -> begin
        calls[] += 1
        captured[] = plan
        @test backend isa PkgFactory.GitHubAPI
        Dict("repository" => plan.repository, "url" => "https://github.com/$(plan.repository)", "resumed" => false)
    end
    server = build_server(backend_resolver=ctx -> PkgFactory.GitHubAPI("test-only"), creator=creator)
    state = client(server)
    id = data(call(server, state, "preview_package", CONFIG))["plan_id"]
    args = Dict("plan_id" => id)
    @test call(server, state, "create_package", merge(args, Dict("owner" => "someone-else")))["isError"]
    @test calls[] == 0
    first = call(server, state, "create_package", args)
    @test !first["isError"]
    @test data(first)["url"] == "https://github.com/octocat/DemoPkg.jl"
    @test captured[].config.name == "DemoPkg"
    @test captured[].config.visibility == PkgFactory.DEFAULT_VISIBILITY
    @test call(server, state, "create_package", args) == first
    @test calls[] == 1
    @test data(call(server, state, "create_package", Dict("plan_id" => "unknown")))["code"] == "plan_not_found"
end

@testset "Caller isolation, TTL, and bounded storage" begin
    now = Ref(100.0)
    server = build_server(require_identity=true, clock=() -> now[], plan_ttl=10, max_plans=1,
        backend_resolver=ctx -> PkgFactory.GitHubAPI("test-only"), creator=(p; backend) -> Dict())
    state = client(server)
    @test data(call(server, state, "list_templates"))["code"] == "unauthorized"
    id = data(call(server, state, "preview_package", CONFIG; user=ALICE))["plan_id"]
    @test data(call(server, state, "create_package", Dict("plan_id" => id); user=BOB))["code"] == "plan_not_found"
    @test data(call(server, state, "preview_package", CONFIG; user=ALICE))["code"] == "capacity_exceeded"
    now[] += 11
    @test data(call(server, state, "create_package", Dict("plan_id" => id); user=ALICE))["code"] == "plan_expired"
    @test !call(server, state, "preview_package", CONFIG; user=BOB)["isError"]
    @test_throws ArgumentError build_server(plan_ttl=0)
    @test_throws ArgumentError build_server(max_plans=0)
end

@testset "Backend failure is redacted and cannot be replayed" begin
    calls = Ref(0)
    server = build_server(backend_resolver=ctx -> PkgFactory.GitHubAPI("secret-token"),
        creator=(p; backend) -> (calls[] += 1; error("Authorization: Bearer secret-token")))
    state = client(server)
    id = data(call(server, state, "preview_package", CONFIG))["plan_id"]
    result = call(server, state, "create_package", Dict("plan_id" => id))
    @test result["isError"]
    @test !occursin("secret-token", JSON3.write(result))
    @test data(result)["code"] == "creation_failed"
    @test data(call(server, state, "create_package", Dict("plan_id" => id)))["code"] == "operation_failed"
    @test calls[] == 1
end

@testset "Concurrent duplicate is rejected while running" begin
    started, finish = Channel{Bool}(1), Channel{Bool}(1)
    count = Ref(0)
    server = build_server(backend_resolver=ctx -> PkgFactory.GitHubAPI("test-only"),
        creator=(p; backend) -> begin
            count[] += 1
            put!(started, true)
            take!(finish)
            Dict()
        end)
    state = client(server)
    id = data(call(server, state, "preview_package", CONFIG))["plan_id"]
    args = Dict("plan_id" => id)
    task = @async call(server, state, "create_package", args)
    take!(started)
    try
        @test data(call(server, state, "create_package", args))["code"] == "operation_in_progress"
    finally
        put!(finish, true)
    end
    @test !fetch(task)["isError"]
    @test count[] == 1
end

@testset "Read-only mode and HTTP configuration" begin
    server = build_server(enable_create=false)
    state = client(server)
    @test length(rpc(server, state, "tools/list")["result"]["tools"]) == 2
    @test_throws ArgumentError serve_http()
    @test_throws ArgumentError serve_http(auth=MCP.disable_auth())
    auth = MCP.create_simple_auth(Dict("test-only-mcp-token" => "operator"))
    @test_throws ArgumentError serve_http(; auth, enable_create=true)
    @test_throws ArgumentError serve_http(; auth, port=0)
    @test_throws ArgumentError main(["--transport", "invalid"])
    @test_throws ArgumentError main(["--port"])
    @test_throws ArgumentError main(["--unknown"])
    withenv("MCP_AUTH_TOKEN" => nothing) do
        @test_throws ArgumentError main(["--transport", "http", "--read-only"])
    end
    withenv("MCP_AUTH_TOKEN" => "same", "GITHUB_TOKEN" => "same") do
        @test_throws ArgumentError main(["--transport", "http"])
    end
end

@testset "OAuth operator selection uses exact subject" begin
    delegate = MCP.create_simple_auth(Dict("alice-token" => "alice", "bob-token" => "bob")).validator
    auth = operator_auth(issuer="https://tenant.example/", audience="https://mcp.example/mcp",
        subject="alice", validator=delegate)
    @test MCP.validate_token(auth.validator, "alice-token", auth.config).success
    @test !MCP.validate_token(auth.validator, "bob-token", auth.config).success
    @test !MCP.validate_token(auth.validator, "invalid", auth.config).success
    @test_throws ArgumentError operator_auth(issuer="http://tenant.example", audience="https://mcp.example/mcp", subject="alice")
    @test_throws ArgumentError operator_auth(issuer="https://tenant.example/", audience="https://mcp.example/mcp", subject="")
end

include("transports.jl")

include(joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "github.jl"))
include("creation.jl")
include("cloudflare.jl")
