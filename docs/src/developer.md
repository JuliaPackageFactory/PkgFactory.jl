# Developer Guide

This guide covers development of PkgFactory itself. To work on a generated
package, see the [User Guide](user.md).

- This page covers the repository layout, local tests, and documentation builds.
- [Template Design](developer/templates.md) explains the presets and their design choices.
- [Template Repository Tests](developer/template-tests.md) covers publishing and testing the generated examples on GitHub.

Run all commands from the repository root. The core and applications require
Julia 1.12 or later.

## Repository layout

| Path | Purpose |
| :--- | :--- |
| `src/` | Package settings, validation, template rendering, planning, creation, and recovery |
| `apps/cli/` | Terminal interface and device login |
| `apps/web/` | Web server and browser assets under `public/` |
| `apps/mcp/` | MCP server with stdio and Streamable HTTP transports |
| `templates/` | Generated package presets |
| `test/` | Core tests and template repository test helpers |
| `docs/` | This documentation |

Keep shared behavior in `PackageSpec`, `package_schema`, `plan_package`, and
`create_package`. Applications collect input, manage authentication, and present
results. They depend on the core and do not depend on each other. The core
accepts explicit credentials and does not prompt for input, read environment
variables, serve routes, or register MCP tools.

The root workspace includes `test` and `docs`. Each application has a separate
workspace containing its own `test` project and a committed Manifest. Applications
resolve the local core through `[sources]` with a relative `../..` path; they
are not members of the root workspace.

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

## Building documentation

```sh
julia --project=docs --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=docs --startup-file=no docs/build.jl
```

The local build writes to `docs/build/`. Register new pages in `docs/build.jl`.
CI uses `docs/make.jl`, which also calls `deploydocs`.

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
