# Template Design

Templates live in `templates/`. For a feature comparison and generated examples,
see [Choosing a template](../user.md#Choosing-a-template). This page explains
the design choices to preserve when editing the presets.

## Julia and CI

All three templates use Julia 1.12+ workspaces and declare their sample API with
`public`. The minimum template keeps a single CI job using the `min` selector;
simple and all-in-one also test stable and prerelease Julia. All-in-one adds a
Windows PR job and runs quality checks through the package test suite, with
dedicated Aqua and JET workflows for their status badges.

Docs and doctests run together, including for fork PRs; Documenter decides
whether it can deploy. Local builds use `.html` links.

## Maintenance automation

All-in-one uses Dependabot for Julia and Actions dependencies. Do not add a
second dependency-update bot for the same projects. Simple and all-in-one use
TagBot with the `DOCUMENTER_KEY` secret for registered releases. Simple leaves
dependency-update automation to its maintainers; minimum also leaves release
automation to its maintainers.

## Preset scope

Keep the presets small and usable without choosing organization policies. A code
of conduct and security policy need real reporting contacts and maintainer
commitments; generated placeholders would misrepresent those commitments. Logos
and favicons should belong to the new package.

External-link checks, dependency lower-bound checks, invalidation monitoring,
precompilation workloads, and an alternative test runner can be added when the
package has code that benefits from them. The greeting example does not justify
enabling those extra jobs or dependencies by default.

The `.gitignore` differences are intentional: only documentation templates need
`docs/build/`, and only all-in-one includes notebooks. Shared line-ending and
editor settings are consistent across presets.

The `.pkgfactory.json` file is a repository-creation recovery marker. Updating
existing packages from templates would need a separate design and file format.

## Validating changes

Run the core tests described in the [Developer Guide](../developer.md#Local-development-and-tests).
To publish and test the generated examples, use the separate
[Template Repository Tests](template-tests.md) workflow.
