using PkgFactory
using Test
import Git
import TOML

@testset "verify_owner_name" begin
    @test "OK" == PkgFactory.Verifications.verify_owner_name("ohno")
    @test "OK" != PkgFactory.Verifications.verify_owner_name("")
end

@testset "verify_package_name" begin
    @test "OK" == PkgFactory.Verifications.verify_package_name("Physics")
    @test "OK" != PkgFactory.Verifications.verify_package_name("")
    @test "OK" != PkgFactory.Verifications.verify_package_name("JuliaPkg")
    @test "OK" != PkgFactory.Verifications.verify_package_name("JustInTime")
    @test "OK" != PkgFactory.Verifications.verify_package_name("algebra")
    @test "OK" != PkgFactory.Verifications.verify_package_name("Linear_algebra")
    @test "OK" != PkgFactory.Verifications.verify_package_name("Math+Physics")
    @test "OK" != PkgFactory.Verifications.verify_package_name("Eigen京")
    @test "OK" != PkgFactory.Verifications.verify_package_name("VMC")
    @test "OK" != PkgFactory.Verifications.verify_package_name("Cake")
    @test "OK" != PkgFactory.Verifications.verify_package_name("juliaCI")
    @test "OK" != PkgFactory.Verifications.verify_package_name("Jump")
    @test "OK" != PkgFactory.Verifications.verify_package_name("VMCjl")
    @test "OK" != PkgFactory.Verifications.verify_package_name("VMC.jl")
end

@testset "get_template_path" begin
    path_dir = PkgFactory.Templates.get_template_path("all-in-one")
    @test isdir(path_dir)
    @test occursin("all-in-one", path_dir)
end

@testset "list_templates" begin
    template_names = PkgFactory.Templates.list_templates()
    @test template_names == sort(template_names)
    @test "all-in-one" in template_names
    @test "minimum" in template_names
    @test "simple" in template_names
end

@testset "list_files" begin
    path_dir = PkgFactory.Templates.get_template_path("all-in-one")
    path_files = PkgFactory.Templates.list_files(path_dir)
    @test 0 < length(path_files)
    @test 0 < sum(occursin("README.md", path_file) for path_file in path_files)
    @test 0 < sum(occursin("LICENSE", path_file) for path_file in path_files)
    @test 0 == sum(occursin("aaaaa", path_file) for path_file in path_files)
end

@testset "read_file" begin
    path_dir = PkgFactory.Templates.get_template_path("all-in-one")
    path_files = PkgFactory.Templates.list_files(path_dir)
    path_file =
        path_files[findfirst(occursin("README.md", path_file) for path_file in path_files)]
    text = PkgFactory.Templates.read_file(path_file)
    @test 0 < length(path_file)
    @test occursin("README.md", path_file)
    @test 0 < length(text)
end

@testset "generate_template_files_dict" begin
    owner_name = "ohno"
    repo_name = "MyPkg.jl"
    author_names = ["Shuhei Ohno"]
    package_description = "My special package"
    template_name = "all-in-one"
    paths_and_contents = PkgFactory.Templates.generate_template_files_dict(
        owner_name,
        repo_name,
        author_names,
        package_description,
        template_name,
    )
    @test 0 < length(paths_and_contents)
    @test 0 < length(paths_and_contents["README.md"])
    @test occursin("MyPkg.jl", paths_and_contents["README.md"])
    @test occursin("Shuhei Ohno", paths_and_contents["LICENSE"])
    @test occursin("My special package", paths_and_contents["README.md"])
end

@testset "generated package identity" begin
    for template in list_templates()
        files = PkgFactory.Templates.generate_template_files_dict(
            "ohno", "MyPkg.jl", ["Shuhei Ohno"], "My special package", template,
        )
        @test haskey(files, "src/MyPkg.jl")
        project = TOML.parse(files["Project.toml"])
        @test project["name"] == "MyPkg"
        @test project["authors"] == ["Shuhei Ohno"]
        for child in project["workspace"]["projects"]
            @test TOML.parse(files["$child/Project.toml"])["deps"]["MyPkg"] == project["uuid"]
        end
    end

    existing_uuid = "12345678-1234-5678-1234-567812345678"
    files = PkgFactory.Templates.generate_template_files_dict(
        "ohno", "MyPkg.jl", ["Shuhei Ohno"], "My special package", "simple";
        package_uuid = existing_uuid,
    )
    @test TOML.parse(files["Project.toml"])["uuid"] == existing_uuid
    for child in ("docs", "test")
        @test TOML.parse(files["$child/Project.toml"])["deps"]["MyPkg"] == existing_uuid
    end
end

@testset "all-in-one Colab notebook" begin
    files = PkgFactory.Templates.generate_template_files_dict(
        "example-owner", "NotebookPkg.jl", ["Example Author"], "Notebook tests", "all-in-one",
    )
    path = "examples/NotebookPkg.ipynb"
    plan = PkgFactory.preview(PkgFactory.PackageConfig(
        owner = "example-owner", name = "NotebookPkg.jl",
        authors = ["Example Author"], description = "Notebook tests", template = "all-in-one",
    ))
    @test plan.files == sort([collect(keys(files)); PkgFactory.MARKER_PATH])
    @test filter(key -> endswith(key, ".ipynb"), plan.files) == [path]
    notebook = PkgFactory.JSON3.read(files[path], Dict{String,Any})
    @test notebook["nbformat"] == 4
    @test notebook["metadata"]["kernelspec"]["language"] == "julia"
    @test notebook["metadata"]["language_info"]["name"] == "julia"
    @test !occursin("{{{", files[path])
    cells = notebook["cells"]
    @test length(unique(cell["id"] for cell in cells)) == length(cells)
    code_cells = filter(cell -> cell["cell_type"] == "code", cells)
    for cell in code_cells
        @test isempty(cell["outputs"])
        @test isnothing(cell["execution_count"])
        source = join(cell["source"])
        @test Meta.parseall(source) isa Expr
        @test !occursin(r"(?m)^!|^%|^pip ", source)
    end
    setup = join(code_cells[2]["source"])
    @test occursin("Pkg.add(url=\"https://github.com/example-owner/NotebookPkg.jl.git\", rev=\"main\")", setup)
    @test occursin("import NotebookPkg", join(code_cells[3]["source"]))
    @test occursin("NotebookPkg.hello()", join(code_cells[4]["source"]))
    for template in ("simple", "minimum")
        basic = PkgFactory.Templates.generate_template_files_dict(
            "example-owner", "NotebookPkg.jl", ["Example Author"], "Notebook tests", template,
        )
        @test !any(endswith(key, ".ipynb") for key in keys(basic))
    end
end

@testset "OAuth device flow" begin
    calls = NamedTuple[]
    requester = function (method, url; headers, body, status_exception)
        push!(calls, (; method, url, headers, body, status_exception))
        response = if endswith(url, "/device/code")
            Dict(
                "device_code" => "device-code",
                "user_code" => "ABCD-1234",
                "verification_uri" => "https://github.com/login/device",
                "expires_in" => 900,
                "interval" => 5,
            )
        else
            Dict(
                "access_token" => "github-token",
                "token_type" => "bearer",
                "scope" => "read:user,repo",
            )
        end
        return PkgFactory.HTTP.Response(
            200,
            PkgFactory.JSON3.write(response),
        )
    end

    device = PkgFactory.device_flow_begin("client-id"; requester = requester)
    @test device["user_code"] == "ABCD-1234"
    @test occursin("client_id=client-id", calls[1].body)
    @test occursin(
        "scope=read:user%20read:org%20repo%20workflow",
        calls[1].body,
    )

    token = PkgFactory.device_flow_poll(
        "device-code",
        "client-id";
        requester = requester,
    )
    @test token["access_token"] == "github-token"
    @test occursin("device_code=device-code", calls[2].body)

    connection_error = try
        PkgFactory.device_flow_begin(
            "client-id";
            requester = (args...; kwargs...) -> error("internal network detail"),
        )
        nothing
    catch error
        error
    end
    @test connection_error isa PkgFactory.GitHubAPIError
    @test connection_error.status == 503
    @test !occursin("internal network detail", sprint(showerror, connection_error))
end

@testset "GitHub repository owners" begin
    requester = function (method, url; headers, body, status_exception)
        @test method == "GET"
        @test any(header -> header == ("Authorization" => "Bearer token"), headers)
        response =
            endswith(url, "/user") ?
            Dict("login" => "ohno", "name" => "Shuhei OHNO") :
            [Dict("login" => "ZetaOrg"), Dict("login" => "AlphaOrg")]
        return PkgFactory.HTTP.Response(
            200,
            PkgFactory.JSON3.write(response),
        )
    end

    owners = PkgFactory.get_repository_owners("token"; requester = requester)
    @test getindex.(owners, "login") == ["ohno", "AlphaOrg", "ZetaOrg"]
    @test getindex.(owners, "kind") == ["user", "organization", "organization"]

    personal_only_requester = function (method, url; headers, body, status_exception)
        response = endswith(url, "/user") ? Dict("login" => "ohno", "name" => nothing) :
                   Dict("message" => "Resource not accessible by integration")
        status = endswith(url, "/user") ? 200 : 403
        return PkgFactory.HTTP.Response(
            status,
            PkgFactory.JSON3.write(response),
        )
    end
    personal_only = PkgFactory.get_repository_owners(
        "token";
        requester = personal_only_requester,
    )
    @test personal_only == [
        Dict{String,Any}("login" => "ohno", "name" => "ohno", "kind" => "user"),
    ]
end

@testset "GitHub repository availability" begin
    statuses = [404, 200]
    requester = function (method, url; headers, body, status_exception)
        @test method == "GET"
        @test endswith(url, "/repos/ohno/MyPackage.jl")
        status = popfirst!(statuses)
        response = status == 404 ? Dict("message" => "Not Found") : Dict("name" => "MyPackage.jl")
        return PkgFactory.HTTP.Response(
            status,
            PkgFactory.JSON3.write(response),
        )
    end

    available = PkgFactory.repository_availability(
        "token",
        "ohno",
        "MyPackage";
        requester = requester,
    )
    existing = PkgFactory.repository_availability(
        "token",
        "ohno",
        "MyPackage.jl";
        requester = requester,
    )
    @test available == Dict("available" => true, "repository" => "ohno/MyPackage.jl")
    @test existing == Dict("available" => false, "repository" => "ohno/MyPackage.jl")
    @test_throws PkgFactory.InputError PkgFactory.repository_availability(
        "token",
        "ohno",
        "lowercase";
        requester = requester,
    )
end

@testset "GitHub branch initialization delay" begin
    attempts = Ref(0)
    delays = Float64[]
    requester = function (method, url; headers, body, status_exception)
        attempts[] += 1
        status, response =
            attempts[] < 3 ?
            (404, Dict("message" => "Not Found")) :
            (200, Dict("object" => Dict("sha" => "initial-sha")))
        return PkgFactory.HTTP.Response(
            status,
            PkgFactory.JSON3.write(response),
        )
    end
    sha = PkgFactory._branch_head(
        "token",
        "ohno",
        "MyPackage.jl",
        "main";
        requester = requester,
        sleeper = delay -> push!(delays, delay),
    )
    @test sha == "initial-sha"
    @test attempts[] == 3
    @test delays == [1.0, 2.0]

    error = try
        PkgFactory._branch_head(
            "token",
            "ohno",
            "MyPackage.jl",
            "missing";
            requester = (args...; kwargs...) -> PkgFactory.HTTP.Response(
                404,
                PkgFactory.JSON3.write(Dict("message" => "Not Found")),
            ),
            attempts = 1,
            sleeper = _ -> nothing,
        )
        nothing
    catch caught
        caught
    end
    @test error isa PkgFactory.GitHubAPIError
    @test occursin("GET /repos/ohno/MyPackage.jl/git/ref/heads/missing", error.message)
end

@testset "create package through GitHub API ($template)" for template in ("all-in-one", "simple", "minimum")
    calls = NamedTuple[]
    requester = function (method, url; headers, body, status_exception)
        push!(calls, (; method, url, body))
        status, response = if method == "GET" && endswith(url, "/user")
            200, Dict("login" => "ohno")
        elseif method == "GET" && endswith(url, "/repos/ohno/MyPackage.jl")
            404, Dict("message" => "Not Found")
        elseif method == "POST" && endswith(url, "/user/repos")
            201, Dict("name" => "MyPackage.jl", "default_branch" => "main")
        elseif method == "GET" && endswith(url, "/contents/Project.toml")
            404, Dict("message" => "Not Found")
        elseif method == "GET" && endswith(url, "/git/ref/heads/main")
            200, Dict("object" => Dict("sha" => "parent-sha"))
        elseif method == "GET" && endswith(url, "/git/commits/parent-sha")
            200, Dict("tree" => Dict("sha" => "base-tree"))
        elseif method == "POST" && endswith(url, "/git/trees")
            201, Dict("sha" => "new-tree")
        elseif method == "POST" && endswith(url, "/git/commits")
            201, Dict("sha" => "package-commit")
        elseif method == "PATCH" && endswith(url, "/git/refs/heads/main")
            200, Dict("object" => Dict("sha" => "package-commit"))
        elseif method == "GET" && endswith(url, "/git/ref/heads/gh-pages")
            404, Dict("message" => "Not Found")
        elseif method == "POST" && endswith(url, "/git/refs")
            201, Dict("ref" => "refs/heads/gh-pages")
        elseif method == "GET" && endswith(url, "/keys?per_page=100&page=1")
            200, Any[]
        elseif method == "POST" && endswith(url, "/keys")
            201, Dict("id" => 1)
        elseif method == "GET" && endswith(url, "/actions/secrets/public-key")
            200, Dict("key" => PkgFactory.Base64.base64encode(zeros(UInt8, 32)), "key_id" => "key-id")
        elseif method == "PUT" && endswith(url, "/actions/secrets/DOCUMENTER_KEY")
            204, Dict()
        elseif method == "GET" && endswith(url, "/contents/.pkgfactory.json")
            tree_call = only(filter(call -> endswith(call.url, "/git/trees"), calls))
            tree = PkgFactory.JSON3.read(tree_call.body, Dict{String,Any})
            marker = only(filter(entry -> entry["path"] == ".pkgfactory.json", tree["tree"]))["content"]
            200, Dict("content" => PkgFactory.Base64.base64encode(marker), "sha" => "marker-sha")
        elseif method == "PUT" && endswith(url, "/contents/.pkgfactory.json")
            200, Dict()
        else
            error("Unexpected GitHub request: $(method) $(url)")
        end
        return PkgFactory.HTTP.Response(
            status,
            PkgFactory.JSON3.write(response),
        )
    end

    result = PkgFactory.create_package(
        "token",
        "ohno",
        "MyPackage",
        ["Alice Smith"],
        "A package created in the browser",
        template == "minimum" ? "unused-codecov-token" : "";
        template_name = template,
        requester = requester,
        key_generator = () -> ("ssh-rsa test-key", "test-private-key"),
    )

    @test result["repository"] == "ohno/MyPackage.jl"
    @test result["url"] == "https://github.com/ohno/MyPackage.jl"
    @test !result["resumed"]
    @test any(call -> call.method == "POST" && endswith(call.url, "/user/repos"), calls)
    tree_call = only(filter(call -> endswith(call.url, "/git/trees"), calls))
    tree_body = PkgFactory.JSON3.read(tree_call.body, Dict{String,Any})
    @test tree_body["base_tree"] == "base-tree"
    @test any(entry -> entry["path"] == "Project.toml", tree_body["tree"])
    if template == "minimum"
        @test !any(call -> occursin("gh-pages", call.url) ||
                          endswith(call.url, "/git/refs") ||
                          occursin("/keys", call.url) ||
                          occursin("/actions/secrets", call.url), calls)
    else
        pages_call = only(filter(
            call -> call.method == "POST" && endswith(call.url, "/git/refs"),
            calls,
        ))
        @test occursin("refs/heads/gh-pages", pages_call.body)
        @test any(call -> endswith(call.url, "/keys?per_page=100&page=1"), calls)
    end
end

@testset "repository secret encryption" begin
    encrypted_request = Ref("")
    public_key = PkgFactory.Base64.base64encode(zeros(UInt8, 32))
    requester = function (method, url; headers, body, status_exception)
        if method == "GET"
            return PkgFactory.HTTP.Response(
                200,
                PkgFactory.JSON3.write(
                    Dict("key" => public_key, "key_id" => "key-id"),
                ),
            )
        end
        encrypted_request[] = body
        return PkgFactory.HTTP.Response(201, "")
    end

    PkgFactory._set_repository_secret(
        "token",
        "ohno",
        "MyPackage.jl",
        "TEST_SECRET",
        "secret";
        requester = requester,
    )
    request_body =
        PkgFactory.JSON3.read(encrypted_request[], Dict{String,Any})
    ciphertext =
        PkgFactory.Base64.base64decode(request_body["encrypted_value"])
    @test request_body["key_id"] == "key-id"
    @test length(ciphertext) == 6 + 48
end


include("core.jl")
include("recovery.jl")
include("e2e/sync_tests.jl")
include("citation.jl")
