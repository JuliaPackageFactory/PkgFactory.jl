# AGENTS.md

## Overview

- PkgFactory.jl generates new Julia packages from templates and bootstraps their GitHub repositories.
- The package name is `PkgFactory` (see Project.toml) regardless of the repository directory name.
- Julia 1.12+ (see `[compat]` in `Project.toml`). Check `.github/workflows/CI.yml` for the versions and platforms actually tested; template CI workflows describe generated packages, not PkgFactory itself.

## Commands

Run all commands from the repository root. Install the project dependencies when setting up a checkout:

```sh
julia --project=. --startup-file=no -e 'import Pkg; Pkg.instantiate()'
```

Run the full test suite:

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
```

Generate documentation:

```sh
julia --project=docs --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

`docs/make.jl` calls both `makedocs` and `deploydocs`; CI supplies the deployment credentials. Documentation output is written to `docs/build/`.

Optional development REPL (install Revise separately if desired):

```sh
julia --project=. --startup-file=no -i -e 'using PkgFactory'
```

## Monorepo applications

- Core code in `src/` must not collect input or contain CLI, Web, or MCP handlers.
- Applications in `apps/cli`, `apps/web`, and `apps/mcp` depend only on the core,
  never on each other. Shared settings, defaults, validation and creation belong
  in `PackageSpec`, `package_schema`, `plan_package` and `create_package`.
- Initialize each application with `julia --project=apps/APP --startup-file=no -e 'import Pkg; Pkg.instantiate()'`.
  The core and all applications require Julia 1.12+.
- Test each application with `julia --project=apps/APP --startup-file=no -e 'import Pkg; Pkg.test()'`.
- Keep each app's Manifest committed with a relative `../..` core dependency.
- Web assets belong in `apps/web/public/`. MCP supports stdio and Streamable HTTP.
