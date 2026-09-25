@testset "Web calls the common creation engine and exposes its defaults" begin
    state, requester = github_fixture()
    body = Dict("owner" => "ohno", "name" => "MyPackage", "authors" => ["Alice"],
        "description" => "Example", "template" => "minimum")
    result = WU.handle_request(webpost("/api/packages", body); requester, policy=WU.WebPolicy())
    @test result.status == 201
    @test haskey(state["files"], "Project.toml")
    @test PkgFactory.repository_status("token", "ohno", "MyPackage"; requester)["state"] == "complete"
    config = WU.handle_request(WA.HTTP.Request("GET", "/api/config"))
    data = WA.JSON3.read(String(config.body), Dict{String,Any})
    @test data["package_schema"] == PkgFactory.package_schema()
end
