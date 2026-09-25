# Run through E2E.yml to publish templates to existing repositories.
using PkgFactory
using Test

include("sync.jl")


function required_env(name)
    value = String(strip(get(ENV, name, "")))
    isempty(value) && error("Set $name before running the repository E2E test.")
    return value
end

function main()
    required_env("GH_TOKEN")
    owner = required_env("PKGFACTORY_E2E_OWNER")
    name = required_env("PKGFACTORY_E2E_PACKAGE")
    templates = Dict(
        "TemplateMinimum" => "minimum",
        "TemplateSimple" => "simple",
        "TemplateAllInOne" => "all-in-one",
    )
    haskey(templates, name) || error("Unsupported E2E package: $name")
    PkgFactory.Verifications.verify_owner_name(owner) == "OK" || error("Invalid E2E owner")
    template = templates[name]
    repo = "$name.jl"
    full_name = "$owner/$repo"
    authors = ["Shuhei Ohno"]
    citation_authors = [(family_names = "Ohno", given_names = "Shuhei")]
    description = "Integration tests for the `$template` template of [PkgFactory.jl](https://github.com/JuliaPackageFactory/PkgFactory.jl)."
    gh = `gh`
    git = `git`
    source_sha = required_env("GITHUB_SHA")
    occursin(r"^[0-9a-f]{40}$", source_sha) || error("Invalid source commit SHA")

    PkgFactory.repository_availability(ENV["GH_TOKEN"], owner, repo)["available"] &&
        error("Create $full_name before running E2E.")
    user = PkgFactory.JSON3.read(read(`$gh api user`, String))
    email = "$(user.id)+$(user.login)@users.noreply.github.com"
    run(`$gh auth setup-git`)

    # Keep this checkout for the next workflow step, which runs without the PAT.
    destination = joinpath(mktempdir(; cleanup = false), repo)
    run(`$git -c core.autocrlf=false -c init.defaultBranch=main clone --single-branch https://github.com/$full_name.git $destination`)
    branch = strip(read(`$git -C $destination symbolic-ref --short HEAD`, String))
    branch == "main" || error("Expected main as the default branch of $full_name.")
    old_sha = snapshot_head(git, destination)
    # The repositories were renamed before their generated packages. Accept
    # only the corresponding old name, preserving the existing package UUID.
    previous_name = replace(name, r"^Template" => "PkgFactory")
    package_uuid = snapshot_uuid(git, destination, name; previous_name)
    expected = PkgFactory.Templates.generate_template_files_dict(
        owner, repo, authors, description, template; package_uuid, citation_authors,
    )
    run(`$git -C $destination config user.name $(user.login)`)
    run(`$git -C $destination config user.email $email`)
    publish_template_snapshot(git, destination, expected, "Update $name from PkgFactory $source_sha")
    new_sha = snapshot_head(git, destination)

    @testset "$full_name" begin
        tracked = split(read(`$git -C $destination ls-files -z`, String), '\0'; keepempty = false)
        @test Set(tracked) == Set(keys(expected))
        @test snapshot_uuid(git, destination, name) == package_uuid
        remote_ref = split(read(`$git -C $destination ls-remote origin refs/heads/main`, String))
        @test first(remote_ref) == new_sha
        if !isnothing(old_sha)
            @test success(`$git -C $destination merge-base --is-ancestor $old_sha $new_sha`)
        end
        for (path, content) in expected
            @testset "$path" begin
                actual = joinpath(destination, split(path, '/')...)
                @test isfile(actual)
                @test read(actual, String) == content
            end
        end
    end

    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "package_path=$destination")
        end
    end
    if haskey(ENV, "GITHUB_STEP_SUMMARY")
        open(ENV["GITHUB_STEP_SUMMARY"], "a") do io
            url = "https://github.com/$full_name"
            println(io, "### [$full_name]($url)")
            println(io, "PkgFactory source: `$source_sha`")
            println(io, "\nGenerated commit: [$new_sha]($url/commit/$new_sha)")
            if isnothing(old_sha)
                println(io, "\nPublished the initial template commit.")
            elseif old_sha == new_sha
                println(io, "\nTemplate unchanged; no commit added.")
            else
                println(io, "\n[Changes from previous generation]($url/compare/$old_sha...$new_sha)")
            end
        end
    end
end

main()
