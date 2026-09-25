const WA = PkgFactory
webjson(status, value) = WA.HTTP.Response(status, WA.JSON3.write(value))
@testset "Bounded transport and encoded OAuth parameters" begin
    options = Ref{Any}()
    transport = WA.GitHubTransport(request=(args...; kwargs...) -> (options[] = kwargs; webjson(200, Dict())),
        connect_timeout=2, read_timeout=3)
    transport("POST", "https://api.github.com/example"; status_exception=false)
    @test options[][:connect_timeout] == 2
    @test options[][:readtimeout] == 3
    @test options[][:retry] === false
    @test options[][:redirect] === false
    payload = Ref("")
    WA.device_flow_poll("code&client_id=evil", "expected";
        requester=(args...; body, kwargs...) -> (payload[] = body; webjson(200, Dict())))
    @test occursin("code%26client_id%3Devil", payload[])
    @test !occursin("&client_id=evil", payload[])
    @test_throws InterruptException WA._request_json("GET", "https://api.github.com/user";
        requester=(args...; kwargs...) -> throw(InterruptException()))
end

@testset "Repository exclusion is concurrent and released on failure" begin
    entered, release = Channel{Nothing}(1), Channel{Nothing}(1)
    task = @async WA._with_repository_lock("ohno", "MyPackage.jl") do
        put!(entered, nothing)
        take!(release)
    end
    take!(entered)
    @test_throws WA.GitHubAPIError WA._with_repository_lock(() -> nothing, "OHNO", "mypackage.jl")
    @test WA._with_repository_lock(() -> :other, "another", "MyPackage.jl") == :other
    put!(release, nothing)
    wait(task)
    @test_throws ErrorException WA._with_repository_lock(() -> error("failure"), "ohno", "MyPackage.jl")
    @test WA._with_repository_lock(() -> :released, "ohno", "MyPackage.jl") == :released
end

@testset "Real keys without system OpenSSH" begin
    # Isolate PATH changes from the test runner and any other Julia tasks.
    mktempdir() do directory
        empty_path = mkdir(joinpath(directory, "empty path"))
        key_temp = mkdir(joinpath(directory, "keys with spaces"))
        script = joinpath(@__DIR__, "key_generation.jl")
        project = dirname(Base.active_project())
        command = `$(Base.julia_cmd()) --startup-file=no --project=$project $script`
        run(addenv(command, "PATH" => empty_path,
            "TMPDIR" => key_temp, "TMP" => key_temp, "TEMP" => key_temp))
        @test isempty(readdir(key_temp))
        @test isempty(readdir(empty_path))
    end
end

include("fixtures/github.jl")

@testset "GitHub partial failure, recovery and unrelated repositories" begin
    state, requester = github_fixture()
    args = ("token", "ohno", "MyPackage", ["Alice"], "Example")
    key_generator = () -> ("ssh-rsa example-$(state["next_id"])", "private-material")
    state["fail_secret"] = true
    err = try
        WA.create_package(args...; requester, key_generator)
        nothing
    catch err
        err
    end
    @test err isa WA.CreationError
    @test err.stage == "documentation"
    @test !occursin("private-material", sprint(showerror, err))
    @test WA.repository_status("token", "ohno", "MyPackage"; requester)["state"] == "files_committed"
    @test length(state["keys"]) == 1
    state["fail_secret"] = false
    result = WA.create_package(args...; requester, key_generator, resume=true)
    @test result["resumed"]
    @test state["secret"]
    @test length(state["keys"]) == 1
    @test state["keys"][1]["id"] == 2
    @test WA.repository_status("token", "ohno", "MyPackage"; requester)["state"] == "complete"
    writes = state["writes"]
    WA.create_package(args...; requester, key_generator, resume=true)
    @test state["writes"] == writes
    @test_throws WA.InputError WA.create_package(args...; requester, resume=true, template_name="minimum")
    state["files"]["Project.toml"] *= "\n# edited"
    @test_throws WA.InputError WA.create_package(args...; requester, resume=true)
    @test state["writes"] == writes
    empty!(state["files"])
    @test WA.repository_status("token", "ohno", "MyPackage"; requester)["state"] == "unverified"
    @test_throws WA.InputError WA.create_package(args...; requester, resume=true)
    @test state["writes"] == writes
end


@testset "Creation commits the exact preview and resumes without regenerating files" begin
    state, requester = github_fixture()
    spec = PackageSpec(owner="ohno", name="MyPackage", authors=["Alice"], description="Example", template="minimum")
    plan = plan_package(spec)
    preview_files = Dict(plan.contents)
    result = create_package(Credential("token"), plan; requester)
    @test !result["resumed"]
    @test all(state["files"][path] == content for (path, content) in preview_files if path != PkgFactory.MARKER_PATH)
    @test repository_status("token", "ohno", "MyPackage"; requester)["state"] == "complete"
    writes = state["writes"]
    original_project = state["files"]["Project.toml"]
    resume = plan_package(PackageSpec(owner="ohno", name="MyPackage", authors=["Alice"],
        description="Example", template="minimum", resume=true))
    @test create_package(Credential("token"), resume; requester)["resumed"]
    @test state["writes"] == writes
    @test state["files"]["Project.toml"] == original_project
end
