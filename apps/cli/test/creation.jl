@testset "CLI calls the common creation engine" begin
    state, requester = github_fixture()
    output = IOBuffer()
    result = main(["--owner", "ohno", "--name", "MyPackage", "--author", "Alice",
        "--description", "Example", "--template", "minimum", "--yes"];
        env=Dict("GITHUB_TOKEN" => "cli-token"), input=IOBuffer(), output, requester)
    @test result["repository"] == "ohno/MyPackage.jl"
    @test haskey(state["files"], "Project.toml")
    @test !occursin("cli-token", String(take!(output)))
    @test PkgFactory.repository_status("cli-token", "ohno", "MyPackage"; requester)["state"] == "complete"
end
