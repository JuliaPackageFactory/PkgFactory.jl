# {{{PKG}}}.jl

[![Julia 1.12+](https://badgen.net/static/Julia/1.12%2B/007ec6?icon=https%3A%2F%2Fraw.githubusercontent.com%2FJuliaLang%2Fjulia-logo-graphics%2Fmaster%2Fimages%2Fjulia-dots.svg)](https://julialang.org/downloads/)
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
