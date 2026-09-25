# Template Repository Tests

The **Template repositories E2E** workflow publishes generated snapshots to
three dedicated GitHub repositories and runs their package tests. It is separate
from the [local test suite](../developer.md#Local-development-and-tests) and only
publishes from `main`.

## Repository setup

Create these repositories under the same owner as PkgFactory.jl
(`JuliaPackageFactory`) before the first run:

| Template | Repository |
| :--- | :--- |
| `minimum` | `TemplateMinimum.jl` |
| `simple` | `TemplateSimple.jl` |
| `all-in-one` | `TemplateAllInOne.jl` |

Use `main` as the default branch. An empty repository receives its first commit;
repositories with commits must have a matching `Project.toml` on `main`.
Subsequent runs preserve the package UUID and Git history.

The workflow derives `PKGFACTORY_E2E_OWNER` from `github.repository_owner`; no
Actions variable is required.

### Authentication

Set the `PKGFACTORY_E2E_TOKEN` secret under **Settings → Secrets and variables →
Actions**. Use a fine-grained PAT with `JuliaPackageFactory` as its resource owner,
limited to the three template repositories. It needs **Contents: Read and write**,
**Workflows: Read and write**, and **Metadata: Read-only**.

No Administration, Secrets, or Actions permissions are needed. This workflow does
not create repositories, change repository settings, or configure deploy keys
or secrets.

## Running the workflow

Changes under `templates/`, to `src/templates.jl`, under `test/e2e/`, or to
`.github/workflows/E2E.yml` pushed to `main` automatically run the workflow. You
can also use **Actions → Template repositories E2E → Run workflow** on `main`.

The E2E script renders the templates, commits changed files, checks that the
remote received the commit, and runs each generated package's tests. Commits
record the source PkgFactory SHA; the job summary links to the changes.

These dedicated repositories are complete generated snapshots: tracked files
absent from the current template are removed. Do not maintain custom files in
them. Identical output creates no commit. Concurrent remote edits cause the
push to fail without rewriting history. Local tests exercise the publishing
helper against temporary Git repositories.

## Documentation and coverage

The workflow does not wait for the generated repositories' own workflows.
Documentation deployment in `TemplateSimple.jl` and `TemplateAllInOne.jl`
requires a deploy key and `DOCUMENTER_KEY`, configured separately.

Simple and AllInOne upload coverage using GitHub OIDC. No `CODECOV_TOKEN` secret
is needed in the template repositories. Sign in to Codecov and give its GitHub
App access to both repositories. Coverage is uploaded by their own CI workflows;
the PkgFactory E2E workflow does not upload coverage on their behalf.
