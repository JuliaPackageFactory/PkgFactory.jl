```@meta
CurrentModule = {{{PKG}}}
```

# {{{PKG}}}.jl

[![Julia 1.12+](https://badgen.net/static/Julia/1.12%2B/007ec6?icon=https%3A%2F%2Fraw.githubusercontent.com%2FJuliaLang%2Fjulia-logo-graphics%2Fmaster%2Fimages%2Fjulia-dots.svg)](https://julialang.org/downloads/)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://{{{OWNER}}}.github.io/{{{PKG}}}.jl/dev/)
[![CI](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![coverage](https://codecov.io/gh/{{{OWNER}}}/{{{PKG}}}.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/{{{OWNER}}}/{{{PKG}}}.jl)

{{{DESCR}}}

This package requires Julia 1.12 or later because it uses Pkg workspaces.
See `[compat]` in [Project.toml](https://github.com/{{{OWNER}}}/{{{REPO}}}/blob/main/Project.toml)
for the supported versions.

## Quick Start

Run the following command in the Julia REPL or a notebook:

```julia
import Pkg; Pkg.add(url="https://github.com/{{{OWNER}}}/{{{PKG}}}.jl.git")
```

After installation, run the following to load the package and verify it works:

```@repl
import {{{PKG}}}; {{{PKG}}}.hello()
```

## API Reference

For the generated API index and docstrings, see the [API Reference](api.md).

## Acknowledgments

This package is written in the [Julia programming language](https://julialang.org/), built on an initial project template generated using [PkgFactory.jl](https://github.com/JuliaPackageFactory/PkgFactory.jl). This repository is hosted on [GitHub](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl), and continuous integration is run using [GitHub Actions](https://github.com/{{{OWNER}}}/{{{PKG}}}.jl/actions).
