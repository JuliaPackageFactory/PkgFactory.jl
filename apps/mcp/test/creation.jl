@testset "MCP executes the exact saved core plan" begin
    state, requester = github_fixture()
    captured = Ref{Any}()
    server = build_server(backend_resolver=ctx -> PkgFactory.Credential("mcp-token"),
        creator=(plan; backend) -> begin
            captured[] = Dict(plan.contents)
            PkgFactory.create_package(backend, plan; requester)
        end)
    session = client(server)
    args = Dict("owner" => "ohno", "name" => "MyPackage", "authors" => ["Alice"],
        "description" => "Example", "template" => "minimum")
    preview = data(call(server, session, "preview_package", args))
    result = call(server, session, "create_package", Dict("plan_id" => preview["plan_id"]))
    @test !result["isError"]
    @test state["files"]["Project.toml"] == captured[]["Project.toml"]
    @test PkgFactory.repository_status("mcp-token", "ohno", "MyPackage"; requester)["state"] == "complete"
end
