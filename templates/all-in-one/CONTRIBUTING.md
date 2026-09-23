# Contributing

For substantial changes, open an issue to discuss the approach first. Follow
[ColPrac](https://github.com/SciML/ColPrac) when preparing and reviewing changes.
Include a reproducer for bug reports and regression tests for fixes.

Use Julia 1.12 or later. From the repository root:

```sh
julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs --startup-file=no docs/make.jl
```

The test suite includes Aqua, ExplicitImports, and JET. CI runs JET on stable
Julia on Linux; `JET_TEST=false` skips it for other Julia versions. Documentation
builds run doctests. Open `docs/build/index.html` to preview locally.

Format Julia files using Runic before submitting a PR. Install it once in a
separate environment, then check the working tree:

```sh
julia --project=@runic --startup-file=no -e 'using Pkg; Pkg.add("Runic")'
julia --project=@runic --startup-file=no -e 'using Runic; exit(Runic.main(ARGS))' -- --check .
```

Update docstrings, docs, and CHANGELOG.md when changing public behavior. Keep
benchmark and precompilation workloads representative of real package usage.
If startup latency becomes significant, consider
[PrecompileTools](https://julialang.github.io/PrecompileTools.jl/stable/): add it
as a dependency before using `@setup_workload` / `@compile_workload`, and avoid
network access or user-file writes inside workloads.
