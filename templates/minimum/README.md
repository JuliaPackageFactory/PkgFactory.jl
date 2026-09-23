# {{{PKG}}}.jl

[![CI](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml?query=branch%3Amain)

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

## Development

Clone the repository, move into its directory, and run the test suite with:

```shell
git clone https://github.com/{{{OWNER}}}/{{{REPO}}}.git
cd {{{PKG}}}.jl
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
```

## Compatibility and registration

This package requires Julia 1.12 or later because it uses Pkg workspaces for its
test environment. See `[compat]` in [Project.toml](Project.toml) for the supported
versions. Before publishing, review `authors` (for example, `"Jane Doe <jane@example.com>"`)
and the package version in that file.

To register in [General](https://github.com/JuliaRegistries/General), install the
[Registrator GitHub App](https://github.com/JuliaRegistries/Registrator.jl#via-the-github-app),
then comment `@JuliaRegistrator register` on the commit containing the version to
release. Address any registry checks before registration is merged.
