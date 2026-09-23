# AGENTS.md

## Package

The package name is `{{{PKG}}}`. Use Julia 1.12 or later and run commands from
the repository root. The workspace contains the test environment.

## Commands

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate()'
julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'
```

Keep source changes, regression tests, and public API documentation consistent.
Do not commit generated manifests or coverage output.

## Documentation

```sh
julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

The documentation build runs doctests and writes `docs/build/`. `deploydocs`
deploys only in supported CI environments with credentials.
