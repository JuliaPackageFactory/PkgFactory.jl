const CF = PkgFactoryMCP.Cloudflare
const TEST_SECRET = repeat("a", 64)
function gateway_ticket(; subject="alice", token="github-test", expires=time() + 120, secret=TEST_SECRET)
    payload = PkgFactory.Base64.base64encode(JSON3.write(Dict("aud" => "pkgfactory-container",
        "sub" => subject, "github_token" => token, "exp" => expires)))
    payload * "." * bytes2hex(PkgFactory.SHA.hmac_sha256(Vector{UInt8}(codeunits(secret)), codeunits(payload)))
end

@testset "Trusted plan snapshots retain exact UUIDs, files and dates" begin
    original = PkgFactory.plan_package(CONFIG)
    snapshot = JSON3.read(JSON3.write(PkgFactory.plan_snapshot(original)), Dict{String,Any})
    restored = PkgFactory.restore_plan(snapshot)
    @test restored.contents == original.contents
    @test restored.fingerprint == original.fingerprint
    @test restored.spec.authors == original.spec.authors
    bad = deepcopy(snapshot)
    bad["files"]["../escape"] = "invalid"
    @test_throws PkgFactory.InputError PkgFactory.restore_plan(bad)
    bad = deepcopy(snapshot)
    bad["files"]["Project.toml"] *= "\nchanged = true"
    @test_throws PkgFactory.InputError PkgFactory.restore_plan(bad)
    bad = deepcopy(snapshot)
    bad["spec"]["owner"] = "another-account"
    @test_throws PkgFactory.InputError PkgFactory.restore_plan(bad)
end

@testset "Cloudflare tickets reject forgery and expiration" begin
    @test CF.verify_ticket(gateway_ticket(), TEST_SECRET)["sub"] == "alice"
    @test_throws Exception CF.verify_ticket(gateway_ticket(secret=repeat("b", 64)), TEST_SECRET)
    @test_throws Exception CF.verify_ticket(gateway_ticket(expires=time() - 1), TEST_SECRET)
    @test_throws Exception CF.verify_ticket(gateway_ticket(expires=time() + 1000), TEST_SECRET)
    @test_throws ArgumentError CF.StateClient("http://example.com", TEST_SECRET)
    @test_throws ArgumentError CF.StateClient("https://example.com", "short")
    @test !occursin(TEST_SECRET, sprint(show, CF.StateClient("https://example.com", TEST_SECRET)))
end

@testset "Durable plan adapter survives a new server and reuses the saved result" begin
    saved = Dict{String,Any}()
    calls = Ref(0)
    request = (action, data) -> begin
        if action == "plan_put"
            saved[data["id"]] = JSON3.read(JSON3.write(data), Dict{String,Any})
            return Dict("ok" => true)
        end
        record = saved[data["id"]]
        record["principal"] == data["principal"] || error("plan_not_found")
        if action == "plan_claim"
            return Dict("snapshot" => record["snapshot"], "result" => get(record, "result", nothing))
        end
        record["result"] = data["result"]
        Dict("ok" => true)
    end
    creator = (plan; backend) -> begin
        calls[] += 1
        @test Dict(plan.contents) == only(values(saved))["snapshot"]["files"]
        Dict("url" => "https://github.com/octocat/DemoPkg.jl")
    end
    make_server() = build_server(; require_identity=true, creator,
        plan_store=PkgFactoryMCP.CloudflarePlanStore(request, 900.0),
        backend_resolver=ctx -> PkgFactory.Credential("test"))
    first = make_server()
    id = data(call(first, client(first), "preview_package", CONFIG; user=ALICE))["plan_id"]
    restarted = make_server()
    first_result = call(restarted, client(restarted), "create_package", Dict("plan_id" => id); user=ALICE)
    @test !first_result["isError"]
    again = make_server()
    @test call(again, client(again), "create_package", Dict("plan_id" => id); user=ALICE) == first_result
    @test calls[] == 1
end

@testset "Private Cloudflare HTTP uses independent authenticated request state" begin
    listener = Sockets.listen(Sockets.ip"127.0.0.1", 0)
    port = Int(Sockets.getsockname(listener)[2])
    close(listener)
    server = build_server(require_identity=true, enable_create=false)
    http = PkgFactoryMCP.serve_cloudflare(; secret=TEST_SECRET, origin="https://example.com",
        host="127.0.0.1", port, server)
    url = "http://127.0.0.1:$port/mcp"
    headers = ["Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
        "MCP-Protocol-Version" => "2025-11-25", "Authorization" => "Bearer " * gateway_ticket()]
    message = JSON3.write(Dict("jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"))
    try
        # Works without a process-local initialize/session after a cold start.
        response = HTTP.post(url, headers, message; readtimeout=20)
        @test response.status == 200
        @test length(JSON3.read(String(response.body)).result.tools) == 2
        @test isempty(HTTP.header(response, "Mcp-Session-Id", ""))
        @test HTTP.get(url, headers; status_exception=false).status == 405
        @test HTTP.post(url, ["Content-Type" => "application/json"], message; status_exception=false).status == 401
        @test HTTP.post(url, headers, repeat("x", 65537); status_exception=false).status == 413
        notification = JSON3.write(Dict("jsonrpc" => "2.0", "method" => "notifications/initialized"))
        @test HTTP.post(url, headers, notification).status == 202
    finally
        close(http)
    end
end
