# User Guide

To create your first package in a browser, follow the [Quick Start](index.md#Quick-Start).

## Interfaces

PkgFactory.jl can be used through:

- **CLI** (local) — create packages from the terminal
- **Web UI** (local & [hosted](https://pkgfactory-web.ohnolab.workers.dev/)) — create and configure packages from a browser
- **MCP** (stdio & Streamable HTTP) — create packages from AI applications

## Local Setup

For CLI:

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
julia +1.12 --project=apps/cli --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia +1.12 --project=apps/cli --startup-file=no apps/cli/bin/pkgfactory.jl
```

For Web UI:

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
julia +1.12 --project=apps/web --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia +1.12 --project=apps/web --startup-file=no apps/web/bin/pkgfactory-web.jl
```

For MCP:

```sh
git clone https://github.com/JuliaPackageFactory/PkgFactory.jl.git
cd PkgFactory.jl
julia +1.12 --project=apps/mcp --startup-file=no -e 'import Pkg; Pkg.instantiate()'
julia +1.12 --project=apps/mcp --startup-file=no apps/mcp/bin/pkgfactory-mcp.jl --read-only
```

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
See [Authentication Design](developer/auth.md#CLI-and-Web-UI:-Device-Flow)
for token handling and the underlying protocol.

The terminal also supports device login. For scripts, supply a GitHub token
that can create repositories and write their files and workflows. A classic PAT
needs `repo` and `workflow`; organization policies or SSO may require additional
authorization. Templates with documentation also need access to deploy keys and
repository secrets.

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

From the PkgFactory checkout in [Get the source](index.md#Get-the-source), run:

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

## MCP interface

The MCP interface is the `PkgFactoryMCP` Julia application in `apps/mcp/`.
It supports local stdio and authenticated Streamable HTTP through
[ModelContextProtocol.jl](https://github.com/JuliaSMLM/ModelContextProtocol.jl).

### Hosted service

Add the service's HTTPS `/mcp` URL to an OAuth-capable MCP client. Confirm the
client name and redirect destination on the consent page, then sign in with
your own GitHub account. Repository operations use that account's permissions.
The hosting configuration is documented in the [Deployment Guide](developer/deployment.md).

### Local stdio

[Get the source](index.md#Get-the-source), then run these commands from the
repository root:

```sh
julia --project=apps/mcp --startup-file=no -e 'using Pkg; Pkg.instantiate()'
julia --project=apps/mcp --startup-file=no apps/mcp/bin/pkgfactory-mcp.jl --read-only
```

The final command waits for MCP messages on stdin. Configure your MCP client to
launch it; this is not an interactive Julia REPL. Omit `--read-only` to enable
repository creation and supply `GITHUB_TOKEN` (or `GH_TOKEN`) in the server's
environment. The token is only read when creation is requested.

For clients using the `mcpServers` configuration format:

```json
{
  "mcpServers": {
    "pkgfactory": {
      "command": "julia",
      "args": [
        "--project=/absolute/path/to/PkgFactory.jl/apps/mcp",
        "--startup-file=no",
        "/absolute/path/to/PkgFactory.jl/apps/mcp/bin/pkgfactory-mcp.jl"
      ]
    }
  }
}
```

Provide credentials through your client's secret/environment settings. On
Windows, forward slashes work in these paths. Logs go to stderr; stdout is
reserved for MCP messages. Allow enough startup time for Julia's first load.

### Tools

| Tool | Input | Result |
| --- | --- | --- |
| `list_templates` | `{}` | Available template names |
| `preview_package` | Package settings | Saved `plan_id`, normalized repository, visibility, and planned filenames |
| `create_package` | `{"plan_id": "..."}` | Repository URL and whether setup was resumed |

Example input to `preview_package`:

```json
{
  "owner": "octocat",
  "name": "MyPackage",
  "authors": ["The Octocat"],
  "description": "A package for my research",
  "template": "minimum",
  "visibility": "private"
}
```

Input fields, defaults, and preview validation follow the shared
[package settings](#Package-settings).

Present the preview to the user and execute only within their authorization.
Creation accepts the saved plan ID, so settings cannot be changed between
preview and execution. The client controls user approval: a plan ID itself is
not proof of human consent.

### Plan lifecycle

Plans expire 15 minutes after preview by default. A completed plan returns its
cached result on a repeat call while retained. An in-flight or failed plan cannot
be executed again. Different previews create different plans; this does not
provide global repository deduplication. For failed creation, follow
[Resuming an interrupted setup](#Resuming-an-interrupted-setup).

Local stdio keeps plans in process memory, so restarting clears them. The hosted
Cloudflare service uses a [durable store](developer/deployment.md#Persistence,-failures,-and-recovery)
with quotas and recovery controls.

Tools execute synchronously. Account for creation time in the client's request
timeout; long-running jobs require a persistent operation store and a worker.

### Julia API

```julia
using PkgFactoryMCP

server = build_server(enable_create = false) # no process started
serve_stdio()                              # blocks until client disconnects
```

The default in-memory store retains up to 256 plans. Configure `plan_ttl` and
`max_plans` in `build_server` to change its lifetime and capacity.

Applications hosting multiple users can call:

```julia
serve_http(
    auth = oauth_middleware,
    resource_metadata = oauth_resource_metadata,
    backend_resolver = ctx -> github_backend_for(ctx.authenticated_user),
    enable_create = true,
)
```

The application implements `github_backend_for` and returns a
`PkgFactory.Credential` holding that user's GitHub token. HTTP does not
implicitly fall back to the server's environment token. Plan access is tied to
the verified identity. Account linking and a durable credential/operation store
are application responsibilities; use the
[Cloudflare integration](developer/deployment.md) for the included implementation.

For application tests and development commands, see
[Development Workflow](developer/index.md#Local-development-and-tests).
Streamable HTTP follows the
[standard transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports).

### Acknowledgments

This application was imported from JuliaPackageFactory/PkgFactoryMCP.jl
at commit `0b16c0d106607e8dbdf47b4245a1d50189eb60a2`. The original
[MIT license](https://github.com/JuliaPackageFactory/PkgFactory.jl/blob/main/apps/mcp/LICENSE) is retained.

## Resuming an interrupted setup

After an error, inspect the repository before trying again. The browser checks
its setup status after a failed creation. From Julia, you can query it with:

```julia
repository_status(credential.access_token, spec.owner, spec.name)
```

The returned `state` is:

| State | Meaning |
| --- | --- |
| `not_found` | GitHub returned 404 for this caller; check the account and permissions |
| `unverified` | No recognized recovery marker; inspect manually |
| `files_committed` | The template commit is recorded; later setup may still be running or have failed |
| `complete` | Setup recorded completion; this does not audit later repository edits or CI |

If the template was committed, use the original settings and select **Resume
interrupted setup** in the browser, add `--resume` to the CLI command, or build
a new `PackageSpec` with `resume=true` in Julia. Keep the owner, name, authors,
description, template, visibility, and commit message unchanged.

The core commits `.pkgfactory.json` atomically with the template. This marker
holds a settings fingerprint, a `Project.toml` digest, and the operation state,
without credentials. The final successful step records `complete` separately.
Resume requires a matching marker and an unchanged `Project.toml`.
It continues the remaining setup without replacing the package
files. A completed matching operation returns its repository URL without writes.
If creation stopped before the template commit, or the repository has no recovery
marker, inspect it manually; automatic resume is refused. PkgFactory does not
delete repositories or roll back changes after a failure.

For documentation templates, recovery installs a new deploy key pair and updates
the Secret before deleting older keys titled `PkgFactory Documenter ...`. Other
deploy keys are preserved. If uploading the Secret fails, the next explicit
resume repairs the pair.
