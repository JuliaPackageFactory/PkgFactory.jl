# Development Workflow

This guide covers development of PkgFactory itself. To work on a generated
package, see the [User Guide](user.md).

This page covers the repository layout, local tests, and documentation builds.
To operate a hosted service, use the [Deployment Overview](deployment/index.md).

Run all commands from the repository root unless a command changes directory.

## Repository layout

| Path | Purpose |
| :--- | :--- |
| `src/` | Package settings, validation, template rendering, planning, creation, and recovery |
| `apps/cli/` | Terminal interface and device login |
| `apps/web/` | Web server and browser assets under `public/` |
| `apps/mcp/` | MCP server with stdio and Streamable HTTP transports |
| `templates/` | Generated package presets |
| `apps/shared/` | Optional Cloudflare application adapters |
| `deploy/web/` | Web deployment definitions, grouped by hosting provider |
| `deploy/mcp/` | MCP deployment definitions, grouped by hosting provider |
| `deploy/shared/` | Hosting code shared by deployments |
| `deploy/scripts/` | Deployment operations and profiling tools |
| `deploy/test/` | Deployment unit and integration tests |
| `test/` | Core tests and template repository test helpers |
| `docs/` | This documentation |

### Naming and ownership

Julia package entrypoints match the package and module names in `Project.toml`:
`PkgFactory.jl`, `PkgFactoryCLI.jl`, `PkgFactoryWeb.jl`, and `PkgFactoryMCP.jl`.
All other Julia source files use lowercase `snake_case`, such as
`verification.jl`, `policy.jl`, and `github/device_flow.jl`. Modules and types
keep Julia's capitalized naming convention: `Verification`, `Templates`, and
`WebPolicy`.

Name files after their responsibility. Use singular or uncountable names for a
single concept (`spec`, `plan`, `verification`) and plurals for collections
(`templates`, `errors`). Executable launchers in `bin/` use lowercase command
names with hyphens. Keep ecosystem filenames such as `Project.toml`,
`Dockerfile`, and `README.md` in their standard form.

Keep application implementations and launchers in `apps/<app>/`, and hosting
definitions in `deploy/<app>/<provider>/`. Shared application adapters belong
in `apps/shared/`; shared deployment code belongs in `deploy/shared/<provider>/`.
Deployment scripts and tests follow the same provider grouping. See the
[Deployment Overview](deployment/index.md)
for the available targets and commands.

Keep shared behavior in `PackageSpec`, `package_schema`, `plan_package`, and
`create_package`. Applications collect input, manage authentication, and present
results. They depend on the core and do not depend on each other. The core
accepts explicit credentials and does not prompt for input, read environment
variables, serve routes, or register MCP tools.

The root workspace includes `test` and `docs`. Each application has a separate
workspace containing its own `test` project and a committed Manifest. Applications
resolve the local core through `[sources]` with a relative `../..` path; they
are not members of the root workspace.

[`DocumenterTools.genkeys`](https://github.com/JuliaDocs/DocumenterTools.jl/blob/v0.1.21/src/genkeys.jl)
is an interactive API that prints the private key and changes the process working
directory. PkgFactory instead calls the same `OpenSSH_jll.ssh_keygen()` executable
with an absolute filename in a fresh temporary directory for each call. It returns
the public key and Base64-encoded private key without logging either, and removes
temporary files when the call finishes or fails.

## Local development and tests

Install dependencies and test the core:

```sh
julia --project=. --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=. --startup-file=no -e 'import Pkg; Pkg.test()'
```

For each application, replace `APP` with `cli`, `web`, or `mcp`:

```sh
julia --project=apps/APP --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=apps/APP --startup-file=no -e 'import Pkg; Pkg.test()'
```

Default tests use simulated GitHub responses and local transports. They do not
create GitHub repositories. Run browser input tests with
`node apps/web/test/browser.cjs`. The separate
[template repository tests](developer/template-tests.md) publish to GitHub.

To open a development REPL:

```sh
julia --project=. --startup-file=no -i -e 'using PkgFactory'
```

### Deployment tests

Test the Cloudflare deployment from its shared Node project:

```sh
cd deploy
npm ci
npm test
npm run test:integration
npm run check
cd ..
```

`check` bundles both Workers without deploying them or building container images.
For the container checks used by CI, see
[Reproduce the local memory measurement](deployment/cloudflare.md#Reproduce-the-local-memory-measurement).

## Building documentation

```sh
julia --project=docs --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=docs --startup-file=no docs/build.jl
```

The local build writes to `docs/build/`. Register new pages in
`docs/navigation.jl` and update the README's Documentation list to match its
titles, order, hierarchy, and published URLs. The build checks that list against
the navigation before rendering. CI uses `docs/make.jl`, which also calls
`deploydocs`.

Keep guide content in `docs/src/`. Each procedure or explanation has one
canonical page; other pages link to it. The root README provides the entry
points, and `apps/` and `deploy/` contain implementation and configuration
without copies of their guides. Template READMEs belong to the generated
packages and follow those packages' documentation structure.

### Deployment

The documentation job authenticates with `GITHUB_TOKEN` to push the versioned
site to `gh-pages`. It does not use `DOCUMENTER_KEY`, because deploy keys are
disabled for this repository. Keep GitHub Pages configured to deploy from
`gh-pages` at `/ (root)`.

The `gh-pages` update starts the repository's Pages deployment. Do not also
request a build through the Pages API: that creates a second deployment for
the same commit. Pull requests build and test the docs without publishing.

## Dependency maintenance

```sh
julia --project=. --startup-file=no -e 'import Pkg; Pkg.update(); Pkg.resolve(); Pkg.instantiate()'
```

For an application, use `--project=apps/APP` instead. Commit its updated Manifest
and keep the core dependency's path relative to the application (`../..`).
