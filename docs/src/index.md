# PkgFactory.jl

Create your first package through the Web UI using the steps below.

## Quick Start

You need Julia 1.12 or later, Git, and a GitHub account. Documentation deploy keys
use the automatically installed `OpenSSH_jll` dependency. No separate OpenSSH
installation or PATH configuration is needed in any application.

### Get the source

Download the repository in a terminal:

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
```

### Start the Web UI

```sh
julia --project=apps/web --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=apps/web --startup-file=no apps/web/bin/pkgfactory-web.jl
```

1. Open [http://127.0.0.1:8000/](http://127.0.0.1:8000/) and connect GitHub.
   Follow the link shown by the app and enter the one-time code.
2. Choose the repository owner and enter a package name such as `MyPkg` and
   the authors. Choose a template and visibility using the
   [package settings](user.md#Package-settings).
3. Click **Generate & commit package**, then open the repository link.

Continue with [After creation](user.md#After-creation) to work on the package and finish
setting up its services.

Keep the terminal running while using the Web UI; press Ctrl+C to stop it.
On later runs, start it with the last command above from the same directory.

## Workflows

Guides to Julia package development include [How to develop a Julia package](https://julialang.org/contribute/developing_package/), [Modern Julia Workflows — Sharing your code](https://modernjuliaworkflows.org/sharing/), [Pkg.jl — Creating Packages](https://pkgdocs.julialang.org/v1/creating-packages/), and [Julia — Workflow Tips](https://docs.julialang.org/en/v1/manual/workflow-tips/). In Japanese, additional information can be found on [Qiita](https://qiita.com/search?q=Julia+%E3%83%91%E3%83%83%E3%82%B1%E3%83%BC%E3%82%B8) and [Zenn](https://zenn.dev/search?q=Julia%2520%25E3%2583%2591%25E3%2583%2583%25E3%2582%25B1%25E3%2583%25BC%25E3%2582%25B8&mode=semantic). PkgFactory.jl automates the following steps:

1. Validate the package settings and generate package files (on memory, not on disk) and GitHub Actions workflows from the selected template.
2. Create a GitHub repository and commit the generated files to `main`.
3. Create the `gh-pages` branch for documentation.
4. Generate an SSH key pair and register the public key as a deploy key with write access.
5. Store the base64-encoded private key as the `DOCUMENTER_KEY` repository secret.

The generated GitHub Actions workflows run tests, upload coverage to Codecov, and build and deploy documentation with Documenter.jl, depending on the selected template.