# PkgFactory.jl

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
GitHub repositories. See the [hosting guide](hosting.md),
[developer guide](developer.md), and [MCP guide](https://github.com/JuliaPackageFactory/PkgFactory.jl/tree/main/apps/mcp).
