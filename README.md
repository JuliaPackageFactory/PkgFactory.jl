# PkgFactory.jl

[![Colab: open](https://badgen.net/static/Colab/open/007ec6?icon=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNDAiIGhlaWdodD0iMTQwIiB2aWV3Qm94PSIwIDUgMjQgMTQiPjxwYXRoIHN0eWxlPSJmaWxsOiNlODcxMGE7IiBkPSJNMS45NzcsMTYuNzdjLTIuNjY3LTIuMjc3LTIuNjA1LTcuMDc5LDAtOS4zNTdDMi45MTksOC4wNTcsMy41MjIsOS4wNzUsNC40OSw5LjY5MWMtMS4xNTIsMS42LTEuMTQ2LDMuMjAxLTAuMDA0LDQuODAzQzMuNTIyLDE1LjExMSwyLjkxOCwxNi4xMjYsMS45NzcsMTYuNzd6Ii8%2BPHBhdGggc3R5bGU9ImZpbGw6I2Y5YWIwMDsiIGQ9Ik0xMi4yNTcsMTcuMTE0Yy0xLjc2Ny0xLjYzMy0yLjQ4NS0zLjY1OC0yLjExOC02LjAyYzAuNDUxLTIuOTEsMi4xMzktNC44OTMsNC45NDYtNS42NzhjMi41NjUtMC43MTgsNC45NjQtMC4yMTcsNi44NzgsMS44MTljLTAuODg0LDAuNzQzLTEuNzA3LDEuNTQ3LTIuNDM0LDIuNDQ2QzE4LjQ4OCw4LjgyNywxNy4zMTksOC40MzUsMTYsOC44NTZjLTIuNDA0LDAuNzY3LTMuMDQ2LDMuMjQxLTEuNDk0LDUuNjQ0Yy0wLjI0MSwwLjI3NS0wLjQ5MywwLjU0MS0wLjcyMSwwLjgyNkMxMy4yOTUsMTUuOTM5LDEyLjUxMSwxNi4zLDEyLjI1NywxNy4xMTR6Ii8%2BPHBhdGggc3R5bGU9ImZpbGw6I2U4NzEwYTsiIGQ9Ik0xOS41MjksOS42ODJjMC43MjctMC44OTksMS41NS0xLjcwMywyLjQzNC0yLjQ0NmMyLjcwMywyLjc4MywyLjcwMSw3LjAzMS0wLjAwNSw5Ljc2NGMtMi42NDgsMi42NzQtNi45MzYsMi43MjUtOS43MDEsMC4xMTVjMC4yNTQtMC44MTQsMS4wMzgtMS4xNzUsMS41MjgtMS43ODhjMC4yMjgtMC4yODUsMC40OC0wLjU1MiwwLjcyMS0wLjgyNmMxLjA1MywwLjkxNiwyLjI1NCwxLjI2OCwzLjYsMC44M0MyMC41MDIsMTQuNTUxLDIxLjE1MSwxMS45MjcsMTkuNTI5LDkuNjgyeiIvPjxwYXRoIHN0eWxlPSJmaWxsOiNmOWFiMDA7IiBkPSJNNC40OSw5LjY5MUMzLjUyMiw5LjA3NSwyLjkxOSw4LjA1NywxLjk3Nyw3LjQxM2MyLjIwOS0yLjM5OCw1LjcyMS0yLjk0Miw4LjQ3Ni0xLjM1NWMwLjU1NSwwLjMyLDAuNzE5LDAuNjA2LDAuMjg1LDEuMTI4Yy0wLjE1NywwLjE4OC0wLjI1OCwwLjQyMi0wLjM5MSwwLjYzMWMtMC4yOTksMC40Ny0wLjUwOSwxLjA2Ny0wLjkyOSwxLjM3MUM4LjkzMyw5LjUzOSw4LjUyMyw4Ljg0Nyw4LjAyMSw4Ljc0NkM2LjY3Myw4LjQ3NSw1LjUwOSw4Ljc4Nyw0LjQ5LDkuNjkxeiIvPjxwYXRoIHN0eWxlPSJmaWxsOiNmOWFiMDA7IiBkPSJNMS45NzcsMTYuNzdjMC45NDEtMC42NDQsMS41NDUtMS42NTksMi41MDktMi4yNzdjMS4zNzMsMS4xNTIsMi44NSwxLjQzMyw0LjQ1LDAuNDk5YzAuMzMyLTAuMTk0LDAuNTAzLTAuMDg4LDAuNjczLDAuMTljMC4zODYsMC42MzUsMC43NTMsMS4yODUsMS4xODEsMS44OWMwLjM0LDAuNDgsMC4yMjIsMC43MTUtMC4yNTMsMS4wMDZDNy44NCwxOS43Myw0LjIwNSwxOS4xODgsMS45NzcsMTYuNzd6Ii8%2BPC9zdmc%2B&iconWidth=22)](https://colab.research.google.com/github/JuliaPackageFactory/PkgFactory.jl/blob/main/examples/PkgFactory.ipynb)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliapackagefactory.github.io/PkgFactory.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliapackagefactory.github.io/PkgFactory.jl/dev/)
[![Build Status](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaPackageFactory/PkgFactory.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaPackageFactory/PkgFactory.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaPackageFactory/PkgFactory.jl)

PkgFactory creates a Julia package and its GitHub repository from a template,
including tests and GitHub Actions. Choose `minimum` for a small starting point,
`simple` for documentation and coverage, or `all-in-one` for additional quality
checks and maintenance tools.

## Quick Start

Install Julia 1.12 or later and Git. The default template also needs OpenSSH's
`ssh-keygen` on your PATH to create a documentation deploy key.

Run these commands in a terminal:

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
julia --project=apps/web --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=apps/web --startup-file=no apps/web/bin/pkgfactory-web.jl
```

Open [http://127.0.0.1:8000/](http://127.0.0.1:8000/), connect your GitHub
account, and enter the repository owner, package name, and authors. Choose a
template and visibility, then click **Generate & commit package**. The result
links to your new repository.

See the [User Guide](docs/src/user.md) for template details, package settings,
and what to do after creation.

## Other ways to use PkgFactory

- [Terminal](docs/src/user.md#terminal-interface): answer prompts or pass command-line options.
- [Julia and notebooks](docs/src/user.md#julia-and-notebooks): preview files and create a repository from a script.
- [MCP](apps/mcp/README.md): create packages from an MCP client.

## Documentation

- [Documentation home](https://juliapackagefactory.github.io/PkgFactory.jl/dev/)
- [API Reference](https://juliapackagefactory.github.io/PkgFactory.jl/dev/api/)
- [Web UI Hosting](docs/src/hosting.md)
- [Developer Guide](docs/src/developer.md)
