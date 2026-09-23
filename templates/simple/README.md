# {{{PKG}}}.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/dev/)
[![CI](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![coverage](https://codecov.io/gh/{{{OWNER}}}/{{{PKG}}}.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/{{{OWNER}}}/{{{PKG}}}.jl)

{{{DESCR}}}

## Quick Start

Run the following command in the Julia REPL or a notebook:

```julia
import Pkg; Pkg.add(url="https://github.com/{{{OWNER}}}/{{{PKG}}}.jl.git")
```

After installation, load the package and verify it works:

```julia
julia> import {{{PKG}}}; {{{PKG}}}.hello()
"Hello, World!"
```

## Documentation

- Home: https://{{{OWNER}}}.github.io/{{{PKG}}}.jl
- Examples: https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/dev/examples/
- API Reference: https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/dev/api

## Compatibility and registration

This package requires Julia 1.12 or later because it uses Pkg workspaces for its
test environment. See `[compat]` in [Project.toml](Project.toml) for the supported
versions. Before publishing, review `authors` (for example, `"Jane Doe <jane@example.com>"`)
and the package version in that file.

To register in [General](https://github.com/JuliaRegistries/General), install the
[Registrator GitHub App](https://github.com/JuliaRegistries/Registrator.jl#via-the-github-app),
then comment `@JuliaRegistrator register` on the commit containing the version to
release. Address any registry checks before registration is merged.

## Documentation setup

PkgFactory configures a write-enabled deploy key and the `DOCUMENTER_KEY` Actions
secret when creating the repository. If copying this template manually, follow
[Documenter authentication](https://documenter.juliadocs.org/stable/man/hosting/#Authentication).
Enable GitHub Pages from the `gh-pages` branch. Fork pull requests build and test
the docs without deployment credentials.

For a local preview, run from the repository root:

```sh
julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

Open `docs/build/index.html`. The build also runs the doctests.
