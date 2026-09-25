import HTTP
import Sockets

@testset "Real stdio transport" begin
    root = dirname(@__DIR__)
    messages = [
        Dict("jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
            "params" => Dict("protocolVersion" => "2025-11-25", "capabilities" => Dict(),
                "clientInfo" => Dict("name" => "stdio-test", "version" => "1"))),
        Dict("jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"),
        Dict("jsonrpc" => "2.0", "id" => 3, "method" => "tools/call",
            "params" => Dict("name" => "preview_package", "arguments" => CONFIG)),
    ]
    input = join(JSON3.write.(messages), "\n") * "\n"
    command = `$(Base.julia_cmd()) --startup-file=no --project=$root $(joinpath(root, "bin", "pkgfactory-mcp.jl")) --read-only`
    output = read(pipeline(command; stdin=IOBuffer(input)), String)
    replies = JSON3.read.(filter(!isempty, split(output, '\n')), Ref(Dict{String,Any}))
    @test length(replies) == 3
    @test length(replies[2]["result"]["tools"]) == 2
    @test replies[3]["result"]["structuredContent"]["repository"] == "octocat/DemoPkg.jl"
end

@testset "Real HTTP transport enforces authentication" begin
    listener = Sockets.listen(Sockets.ip"127.0.0.1", 0)
    port = Int(Sockets.getsockname(listener)[2])
    close(listener)
    auth = MCP.create_simple_auth(Dict("http-test-token" => "operator"))
    server = build_server(enable_create=false, require_identity=true)
    transport = MCP.HttpTransport(host="127.0.0.1", port=port, endpoint="/mcp", auth=auth)
    MCP.connect(transport)
    task = @async MCP.start!(server; transport)
    url = "http://127.0.0.1:$port/mcp"
    headers = ["Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
        "Connection" => "close"]
    request = JSON3.write(Dict("jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
        "params" => Dict("protocolVersion" => "2025-11-25", "capabilities" => Dict(),
            "clientInfo" => Dict("name" => "http-test", "version" => "1"))))
    try
        unauthorized = HTTP.post(url, headers, request; status_exception=false, readtimeout=15)
        @test unauthorized.status == 401
        println("HTTP: unauthenticated request rejected")
        authorized = HTTP.post(url, [headers; "Authorization" => "Bearer http-test-token"], request; readtimeout=15)
        @test authorized.status == 200
        println("HTTP: authenticated initialization succeeded")
        @test haskey(JSON3.read(String(authorized.body)), :result)
        tools_request = JSON3.write(Dict("jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"))
        tools = HTTP.post(url, [headers; "Authorization" => "Bearer http-test-token"], tools_request; readtimeout=15)
        @test length(JSON3.read(String(tools.body)).result.tools) == 2
        println("HTTP: tool discovery succeeded")
    finally
        # In MCP 0.6.1 stop! only changes server.active. Closing the transport
        # also releases the receive loop blocked on its request queue.
        MCP.close(transport)
        wait(task)
    end
end
