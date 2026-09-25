# PkgFactory.jl

[![Colab: open](https://badgen.net/static/Colab/open/007ec6?icon=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNDAiIGhlaWdodD0iMTQwIiB2aWV3Qm94PSIwIDUgMjQgMTQiPjxwYXRoIHN0eWxlPSJmaWxsOiNlODcxMGE7IiBkPSJNMS45NzcsMTYuNzdjLTIuNjY3LTIuMjc3LTIuNjA1LTcuMDc5LDAtOS4zNTdDMi45MTksOC4wNTcsMy41MjIsOS4wNzUsNC40OSw5LjY5MWMtMS4xNTIsMS42LTEuMTQ2LDMuMjAxLTAuMDA0LDQuODAzQzMuNTIyLDE1LjExMSwyLjkxOCwxNi4xMjYsMS45NzcsMTYuNzd6Ii8%2BPHBhdGggc3R5bGU9ImZpbGw6I2Y5YWIwMDsiIGQ9Ik0xMi4yNTcsMTcuMTE0Yy0xLjc2Ny0xLjYzMy0yLjQ4NS0zLjY1OC0yLjExOC02LjAyYzAuNDUxLTIuOTEsMi4xMzktNC44OTMsNC45NDYtNS42NzhjMi41NjUtMC43MTgsNC45NjQtMC4yMTcsNi44NzgsMS44MTljLTAuODg0LDAuNzQzLTEuNzA3LDEuNTQ3LTIuNDM0LDIuNDQ2QzE4LjQ4OCw4LjgyNywxNy4zMTksOC40MzUsMTYsOC44NTZjLTIuNDA0LDAuNzY3LTMuMDQ2LDMuMjQxLTEuNDk0LDUuNjQ0Yy0wLjI0MSwwLjI3NS0wLjQ5MywwLjU0MS0wLjcyMSwwLjgyNkMxMy4yOTUsMTUuOTM5LDEyLjUxMSwxNi4zLDEyLjI1NywxNy4xMTR6Ii8%2BPHBhdGggc3R5bGU9ImZpbGw6I2U4NzEwYTsiIGQ9Ik0xOS41MjksOS42ODJjMC43MjctMC44OTksMS41NS0xLjcwMywyLjQzNC0yLjQ0NmMyLjcwMywyLjc4MywyLjcwMSw3LjAzMS0wLjAwNSw5Ljc2NGMtMi42NDgsMi42NzQtNi45MzYsMi43MjUtOS43MDEsMC4xMTVjMC4yNTQtMC44MTQsMS4wMzgtMS4xNzUsMS41MjgtMS43ODhjMC4yMjgtMC4yODUsMC40OC0wLjU1MiwwLjcyMS0wLjgyNmMxLjA1MywwLjkxNiwyLjI1NCwxLjI2OCwzLjYsMC44M0MyMC41MDIsMTQuNTUxLDIxLjE1MSwxMS45MjcsMTkuNTI5LDkuNjgyeiIvPjxwYXRoIHN0eWxlPSJmaWxsOiNmOWFiMDA7IiBkPSJNNC40OSw5LjY5MUMzLjUyMiw5LjA3NSwyLjkxOSw4LjA1NywxLjk3Nyw3LjQxM2MyLjIwOS0yLjM5OCw1LjcyMS0yLjk0Miw4LjQ3Ni0xLjM1NWMwLjU1NSwwLjMyLDAuNzE5LDAuNjA2LDAuMjg1LDEuMTI4Yy0wLjE1NywwLjE4OC0wLjI1OCwwLjQyMi0wLjM5MSwwLjYzMWMtMC4yOTksMC40Ny0wLjUwOSwxLjA2Ny0wLjkyOSwxLjM3MUM4LjkzMyw5LjUzOSw4LjUyMyw4Ljg0Nyw4LjAyMSw4Ljc0NkM2LjY3Myw4LjQ3NSw1LjUwOSw4Ljc4Nyw0LjQ5LDkuNjkxeiIvPjxwYXRoIHN0eWxlPSJmaWxsOiNmOWFiMDA7IiBkPSJNMS45NzcsMTYuNzdjMC45NDEtMC42NDQsMS41NDUtMS42NTksMi41MDktMi4yNzdjMS4zNzMsMS4xNTIsMi44NSwxLjQzMyw0LjQ1LDAuNDk5YzAuMzMyLTAuMTk0LDAuNTAzLTAuMDg4LDAuNjczLDAuMTljMC4zODYsMC42MzUsMC43NTMsMS4yODUsMS4xODEsMS44OWMwLjM0LDAuNDgsMC4yMjIsMC43MTUtMC4yNTMsMS4wMDZDNy44NCwxOS43Myw0LjIwNSwxOS4xODgsMS45NzcsMTYuNzd6Ii8%2BPC9zdmc%2B&iconWidth=22)](https://colab.research.google.com/github/JuliaPackageFactory/PkgFactory.jl/blob/main/examples/PkgFactory.ipynb)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliapackagefactory.github.io/PkgFactory.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliapackagefactory.github.io/PkgFactory.jl/dev/)
[![Build Status](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaPackageFactory/PkgFactory.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaPackageFactory/PkgFactory.jl)

A UI-independent Julia library with three applications in one repository:

```text
apps/cli ─┐
apps/web ─┼──> PkgFactory (src/, templates/)
apps/mcp ─┘
```

The core validates settings, renders templates, plans changes, creates GitHub
repositories, configures Actions and Documenter, and resumes interrupted setup.
It accepts explicit credentials and never prompts, reads environment variables,
serves routes, or registers MCP tools. Applications do not depend on each other.

## Library

```julia
using PkgFactory

spec = PackageSpec(owner="ohno", name="Example.jl", authors=["Shuhei Ohno"],
    description="An example package", template="minimum", visibility="public")
plan = plan_package(spec)                    # offline, no credentials
files = Dict(plan.contents)                  # exact preview, including package UUID
credential = Credential(ENV["GITHUB_TOKEN"]) # caller supplies credentials
result = create_package(credential, plan)    # the only creation engine
```

Defaults are shared by all applications: `all-in-one`, `public`, an empty
description, `Using PkgFactory.jl` as the commit message, and `resume=false`.
`package_schema()` exposes them to input forms and MCP tools. Always inspect
visibility before executing a plan. Optional secrets belong in
`Credential(token; codecov_token=...)`, never in the plan.

## Applications

From a checkout, install dependencies using Julia 1.12 (required by the MCP SDK
and its workspace). The core, CLI and Web support Julia 1.10+; on older Julia
versions run `scripts/setup.jl cli web` to resolve compatible manifests.

```sh
julia --startup-file=no scripts/setup.jl
julia --project=apps/cli --startup-file=no apps/cli/bin/pkgfactory.jl
julia --project=apps/web --startup-file=no apps/web/bin/pkgfactory-web.jl
julia --project=apps/mcp --startup-file=no apps/mcp/bin/pkgfactory-mcp.jl
```

CLI accepts interactive input or flags (`--help`, `--preview`, `--yes`). It reads
`GITHUB_TOKEN` / `GH_TOKEN`, or runs device login. Preview does not authenticate.
Open the Web UI at `http://127.0.0.1:8000/`; its deploy-ready assets are in
`apps/web/public/`. The Web app handles browser OAuth and HTTP policy.
MCP defaults to stdio and also supports authenticated Streamable HTTP:

```sh
# Set MCP_AUTH_TOKEN separately from GITHUB_TOKEN before starting HTTP.
julia --project=apps/mcp apps/mcp/bin/pkgfactory-mcp.jl --transport http
```

Each application has its own Project and checked-in Manifest, referencing the
core with `path = "../.."`. No global package installation is needed.

## Recovery and migration

After a failure, call `repository_status(token, owner, name)`. Resume with the
same settings and `resume=true`. The core verifies its recovery marker and the
original Project.toml hash; it refuses unrelated or modified repositories.
Failures before the marker commit need manual inspection. Completed resumes
perform no writes. Concurrent operations on the same repository are excluded
within one process; multiple processes need an external lock.

`LocalAPI` and `WebAPI` were removed. Replace `PkgFactory.LocalUI.CLI()` with
`PkgFactoryCLI.main()` in the CLI project, and `PkgFactory.WebUI.start()` with
`PkgFactoryWeb.start()` in the Web project. Interactive device login moved to
`PkgFactoryCLI.github_device_login()`. `GitHubAPI()` no longer reads environment
variables: pass a token explicitly. Noninteractive `PackageConfig`, `preview`,
`GitHubAPI(token)` and `create!` remain aliases for scripts and notebooks.
MCP's former `minimum/private` defaults now follow the core's `all-in-one/public`;
existing MCP clients wanting the old selection should pass both settings.

## Verification

```sh
julia --project=. --startup-file=no -e 'import Pkg; Pkg.test()'
julia --project=apps/cli --startup-file=no -e 'import Pkg; Pkg.test()'
julia --project=apps/web --startup-file=no -e 'import Pkg; Pkg.test()'
julia --project=apps/mcp --startup-file=no -e 'import Pkg; Pkg.test()'
```

Tests use simulated GitHub responses and local transports. They do not create
GitHub repositories. See the [hosting guide](docs/src/hosting.md),
[developer guide](docs/src/developer.md), and [MCP guide](apps/mcp/README.md).
