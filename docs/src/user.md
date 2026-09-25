# User Guide

To create your first package in a browser, follow the [Quick Start](index.md#Quick-Start).

## Choosing a template

All templates include a Julia module, tests, `Project.toml`, a README, an MIT
license, and GitHub Actions CI. The generated packages require Julia 1.12 or later.

| Template | Included features | Generated example |
| :--- | :--- | :--- |
| `minimum` | Package files and CI | [TemplateMinimum.jl](https://github.com/JuliaPackageFactory/TemplateMinimum.jl) |
| `simple` | Documentation with Documenter, Codecov coverage, and TagBot releases | [TemplateSimple.jl](https://github.com/JuliaPackageFactory/TemplateSimple.jl) |
| `all-in-one` (default) | Documentation, coverage, TagBot, Aqua, JET, ExplicitImports, formatting, Dependabot, citation metadata, and a notebook example | [TemplateAllInOne.jl](https://github.com/JuliaPackageFactory/TemplateAllInOne.jl) |

You can edit the generated files after creation.

## Package settings

These settings apply to the browser, terminal, Julia API, and MCP:

| Setting | What to enter | Default |
| :--- | :--- | :--- |
| Owner | Your GitHub login or an organization where you can create repositories | Required |
| Name | A Julia package name, such as `MyPkg`; the repository becomes `MyPkg.jl` | Required |
| Authors | Names for the package metadata and license; comma-separated in the browser and interactive CLI | Required |
| Description | A short description of the package | Empty |
| Template | `minimum`, `simple`, or `all-in-one` | `all-in-one` |
| Visibility | `public` or `private` | `public` |
| Commit message | Message for the initial template commit | `Using PkgFactory.jl` |
| Resume | Continue an interrupted creation using the original settings | `false` |

PkgFactory accepts names with or without `.jl`. The package name must use ASCII
letters and digits, start with an uppercase letter, include a lowercase letter,
and contain at least five characters. Underscores, hyphens, `Julia` or `julia`,
a `Ju` prefix, and a `jl` ending are rejected.

The browser checks whether the repository name is already in use under the
selected owner. Check General separately if you intend to register the package.
An offline preview validates the inputs and renders files; it does not check
remote availability.

### GitHub authentication

The browser uses GitHub's device login: authorize the displayed code in GitHub
and return to the form. It requests `repo`, `workflow`, `read:user`, and
`read:org` permissions to create repositories, commit workflows, and list owners.
The access token stays in the browser tab's memory and is sent to the server
for GitHub operations. Closing the tab clears that copy; it does not revoke
the authorization in GitHub.

The terminal also supports device login. For scripts, supply a GitHub token
that can create repositories and write their files and workflows. Templates
with documentation also need access to deploy keys and repository secrets.

## After creation

Open the new repository's **Actions** tab to check its first CI run. To start
working locally, replace `OWNER` and `MyPkg` below with your chosen values:

```sh
git clone https://github.com/OWNER/MyPkg.jl.git
cd MyPkg.jl
julia --project=. --startup-file=no -e 'import Pkg; Pkg.instantiate(); Pkg.test()'
```

Edit `src/MyPkg.jl` and add tests in `test/runtests.jl`.

### Documentation and coverage

For `simple` and `all-in-one`, select **Deploy from a branch**, `gh-pages`, and
`/ (root)` in the repository's **Settings → Pages**. PkgFactory creates that
branch and the Documenter key; the generated CI workflow builds and publishes
the documentation. Edit its content under `docs/src/`.

Sign in to [Codecov](https://app.codecov.io/) and grant its
[GitHub App](https://github.com/apps/codecov) access to the new repository.
The generated CI uses [GitHub OIDC](https://github.com/codecov/codecov-action#using-oidc)
for coverage uploads, so no `CODECOV_TOKEN` is needed. These steps do not apply
to `minimum`.

### Registering a release

Creating a repository does not register the package in Julia's General registry.
When the package is ready, follow the
[General registration guide](https://github.com/JuliaRegistries/General#registering-a-package-in-general)
and enable the [Registrator GitHub App](https://github.com/apps/juliaregistrator)
for the repository. The `simple` and `all-in-one` templates include TagBot to
create tags and GitHub releases after registration.

## Terminal interface

From the PkgFactory checkout used in the Quick Start, run:

```sh
julia --project=apps/cli --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia --project=apps/cli --startup-file=no apps/cli/bin/pkgfactory.jl
```

Answer the prompts for package settings, review the file list, and confirm
creation with `y`. Press Enter to accept a displayed default. The CLI reads
`GITHUB_TOKEN`, falling back to `GH_TOKEN` when it is unset; without a token,
it prints instructions for GitHub device login.

To preview a package without authenticating or creating a repository:

```sh
julia --project=apps/cli --startup-file=no apps/cli/bin/pkgfactory.jl --owner octocat --name MyPkg --author "The Octocat" --template minimum --visibility private --preview
```

Remove `--preview` to create it. Repeat `--author` for multiple authors.
Use `--yes` to skip the creation confirmation when scripting, and `--help`
to list all options. Missing required settings are prompted for; omitted
optional settings use the defaults in the table above.

## Julia and notebooks

Install PkgFactory in your Julia environment:

```julia
import Pkg
Pkg.add(url="https://github.com/JuliaPackageFactory/PkgFactory.jl.git")
```

Prepare and inspect the files before creating a repository:

```julia
using PkgFactory

spec = PackageSpec(
    owner="octocat",
    name="MyPkg",
    authors=["The Octocat"],
    description="A package for my research",
    template="simple",
    visibility="public",
)
plan = plan_package(spec)
display(plan)
files = Dict(plan.contents)
println(files["Project.toml"])
```

Planning needs no credentials and makes no network requests. The plan contains
the generated filenames and contents, including the package UUID.

Set `GITHUB_TOKEN` in the Julia process's environment before running the next
cell. This call creates the GitHub repository using the files you previewed:

```julia
credential = Credential(ENV["GITHUB_TOKEN"])
result = create_package(credential, plan)
println(result["url"])
```

See the [example notebook](https://github.com/JuliaPackageFactory/PkgFactory.jl/blob/main/examples/PkgFactory.ipynb)
for the same workflow in Jupyter, and the [API Reference](api.md) for function details.

## Resuming an interrupted setup

After an error, inspect the repository before trying again. The browser checks
its setup status after a failed creation. From Julia, you can query it with:

```julia
repository_status(credential.access_token, spec.owner, spec.name)
```

If the template was committed, use the original settings and select **Resume
interrupted setup** in the browser, add `--resume` to the CLI command, or build
a new `PackageSpec` with `resume=true` in Julia. Keep the owner, name, authors,
description, template, visibility, and commit message unchanged.

Resume requires a matching `.pkgfactory.json` recovery marker and an unchanged
`Project.toml`. It continues the remaining setup without replacing the package
files. A completed matching operation returns its repository URL without writes.
If creation stopped before the template commit, or the repository has no recovery
marker, inspect it manually; automatic resume is refused. PkgFactory does not
delete repositories or roll back changes after a failure.
