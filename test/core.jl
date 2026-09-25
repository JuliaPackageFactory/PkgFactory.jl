@testset "Shared specification, schema and immutable offline plans" begin
    args = Dict{String,Any}("owner" => "ohno", "name" => "Example.jl", "authors" => ["Alice"])
    spec = package_spec(args)
    schema = package_schema()["properties"]
    @test spec.template == schema["template"]["default"]
    @test spec.visibility == schema["visibility"]["default"]
    @test spec.name == "Example"
    args["authors"][1] = "Changed"
    @test spec.authors == ("Alice",)
    for invalid in (Dict("name" => "../Invalid"), Dict("owner" => "../other"),
        Dict("authors" => [1]), Dict("authors" => []), Dict("template" => "../minimum"),
        Dict("visibility" => "internal"), Dict("resume" => 1), Dict("description" => repeat("x", 2001)),
        Dict("extra" => true), Dict("package_name" => "OtherPkg"))
        @test_throws InputError package_spec(merge(args, invalid))
    end
    @test_throws InputError Credential("")
    @test !occursin("secret", repr(Credential("secret"; codecov_token="coverage-secret")))
    @test !hasmethod(Credential, Tuple{})
    for template in list_templates()
        plan = plan_package(PackageSpec(owner="ohno", name="Example", authors=["Alice"], template=template))
        @test plan.repository == "ohno/Example.jl"
        @test "src/Example.jl" in plan.files
        @test plan.contents isa Tuple
        @test haskey(Dict(plan.contents), ".pkgfactory.json")
        empty!(plan.files)
        @test !isempty(plan.files)
        project = Dict(plan.contents)["Project.toml"]
        @test occursin("name = \"Example\"", project)
    end
end
