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
