module E2ESnapshotTests
using PkgFactory
using Test
include("sync.jl")

@testset "initial snapshot in an empty repository" begin
    git = PkgFactory.LocalAPI.git_executable()
    mktempdir() do root
        remote = joinpath(root, "empty.git")
        checkout = joinpath(root, "checkout")
        run(`$git init --bare --initial-branch=main $remote`)
        run(`$git -c init.defaultBranch=main clone --single-branch $remote $checkout`)
        run(`$git -C $checkout config user.name E2E`)
        run(`$git -C $checkout config user.email e2e@example.invalid`)
        run(`$git -C $checkout config core.autocrlf false`)
        @test isnothing(snapshot_head(git, checkout))
        uuid = snapshot_uuid(git, checkout, "Minimum")
        project = "name = \"Minimum\"\nuuid = \"$uuid\"\n"
        files = Dict("Project.toml" => project)
        @test publish_template_snapshot(git, checkout, files, "Initial template")
        @test snapshot_uuid(git, checkout, "Minimum") == uuid
        @test snapshot_head(git, checkout) == strip(read(`$git --git-dir=$remote rev-parse main`, String))
        @test !publish_template_snapshot(git, checkout, files, "Unchanged")
        @test_throws ErrorException snapshot_uuid(git, checkout, "OtherPackage")
        write(joinpath(checkout, "Project.toml"), "name = \"Minimum\"\nuuid = \"invalid\"\n")
        @test_throws ArgumentError snapshot_uuid(git, checkout, "Minimum")
    end
end

@testset "renamed template repositories preserve UUID and history" begin
    git = PkgFactory.LocalAPI.git_executable()
    for (suffix, template) in [("Minimum", "minimum"), ("Simple", "simple"), ("AllInOne", "all-in-one")]
        @testset "$template" begin
            mktempdir() do root
                remote = joinpath(root, "remote.git")
                checkout = joinpath(root, "checkout")
                run(`$git init --bare --initial-branch=main $remote`)
                run(`$git -c init.defaultBranch=main clone --single-branch $remote $checkout`)
                run(`$git -C $checkout config user.name E2E`)
                run(`$git -C $checkout config user.email e2e@example.invalid`)
                run(`$git -C $checkout config core.autocrlf false`)
                previous_name = "PkgFactory$suffix"
                name = "Template$suffix"
                package_uuid = snapshot_uuid(git, checkout, previous_name)
                generate(pkg) = PkgFactory.Templates.generate_template_files_dict(
                    "JuliaPackageFactory", "$pkg.jl", ["PkgFactory CI"], "E2E", template; package_uuid,
                )
                @test publish_template_snapshot(git, checkout, generate(previous_name), "Before rename")
                old_sha = snapshot_head(git, checkout)
                @test_throws ErrorException snapshot_uuid(git, checkout, name)
                @test_throws ErrorException snapshot_uuid(git, checkout, name; previous_name = "Unrelated")
                @test snapshot_uuid(git, checkout, name; previous_name) == package_uuid
                files = generate(name)
                @test publish_template_snapshot(git, checkout, files, "Rename package")
                @test snapshot_uuid(git, checkout, name) == package_uuid
                @test success(`$git -C $checkout merge-base --is-ancestor $old_sha HEAD`)
                @test snapshot_head(git, checkout) == strip(read(`$git --git-dir=$remote rev-parse main`, String))
                @test all(read(joinpath(checkout, split(path, '/')...), String) == content for (path, content) in files)
                @test !ispath(joinpath(checkout, "src", "$previous_name.jl"))
                @test !ispath(joinpath(checkout, "examples", "$previous_name.ipynb"))
                @test Set(split(read(`$git -C $checkout ls-files -z`, String), '\0'; keepempty = false)) == Set(keys(files))
                @test !publish_template_snapshot(git, checkout, files, "Unchanged")
            end
        end
    end
end

@testset "E2E snapshot publishing with local Git" begin
    git = PkgFactory.LocalAPI.git_executable()
    mktempdir() do root
        remote = joinpath(root, "remote.git")
        checkout = joinpath(root, "checkout")
        run(`$git init --bare --initial-branch=main $remote`)
        run(`$git init --initial-branch=main $checkout`)
        run(`$git -C $checkout config user.name E2E`)
        run(`$git -C $checkout config user.email e2e@example.invalid`)
        run(`$git -C $checkout config core.autocrlf false`)
        project = "name = \"Minimum\"\nuuid = \"12345678-1234-5678-1234-567812345678\"\n"
        write(joinpath(checkout, "Project.toml"), project)
        write(joinpath(checkout, "README.md"), "old template\n")
        write(joinpath(checkout, "obsolete.txt"), "removed from template\n")
        run(`$git -C $checkout add .`)
        run(`$git -C $checkout commit -m Initial`)
        run(`$git -C $checkout remote add origin $remote`)
        run(`$git -C $checkout push -u origin main`)
        head() = strip(read(`$git -C $checkout rev-parse HEAD`, String))
        remote_head() = strip(read(`$git --git-dir=$remote rev-parse main`, String))
        old_sha = head()
        files = Dict("Project.toml" => project, "README.md" => "new template\n",
            "src/Minimum.jl" => "module Minimum\nend\n")
        @test publish_template_snapshot(git, checkout, files, "Update from source SHA")
        new_sha = head()
        @test new_sha != old_sha
        @test strip(read(`$git -C $checkout rev-parse HEAD^`, String)) == old_sha
        @test remote_head() == new_sha
        @test read(joinpath(checkout, "Project.toml"), String) == project
        @test !ispath(joinpath(checkout, "obsolete.txt"))
        @test read(joinpath(checkout, "src", "Minimum.jl"), String) == files["src/Minimum.jl"]
        @test !publish_template_snapshot(git, checkout, files, "No changes")
        @test head() == new_sha

        # Deletion alone must be committed and pushed, even when every retained
        # file is unchanged (e.g. removal of a redundant quality workflow).
        pop!(files, "src/Minimum.jl")
        @test publish_template_snapshot(git, checkout, files, "Remove obsolete source")
        @test !ispath(joinpath(checkout, "src", "Minimum.jl"))
        @test head() != new_sha
        new_sha = head()
        @test remote_head() == new_sha

        write(joinpath(checkout, "README.md"), "uncommitted edit\n")
        @test_throws ErrorException publish_template_snapshot(git, checkout, files, "Must fail")
        @test remote_head() == new_sha
        run(`$git -C $checkout restore README.md`)

        # Another writer advances the remote; publishing from the stale checkout
        # must fail without losing the other writer's commit.
        other = joinpath(root, "other")
        run(`$git clone --branch main $remote $other`)
        run(`$git -C $other config user.name Other`)
        run(`$git -C $other config user.email other@example.invalid`)
        write(joinpath(other, "other.txt"), "concurrent update\n")
        run(`$git -C $other add .`)
        run(`$git -C $other commit -m Concurrent`)
        run(`$git -C $other push origin main`)
        concurrent_sha = remote_head()
        files["README.md"] = "later template\n"
        @test_throws ProcessFailedException publish_template_snapshot(git, checkout, files, "Stale update")
        @test remote_head() == concurrent_sha
    end
end
end
