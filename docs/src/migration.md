# Updating Older Scripts

Use this page if your code calls an earlier PkgFactory interface. For a new
package, start with the [Quick Start](index.md#Quick-Start).

## Browser and terminal entry points

The browser and terminal now run from separate projects in a PkgFactory
checkout. Replace `PkgFactory.WebUI.start()` with the launch command in the
[Quick Start](index.md#Quick-Start), and `PkgFactory.LocalUI.CLI()` with the
[terminal command](user.md#Terminal-interface).

Within those projects, the Julia entry points are `PkgFactoryWeb.start()` and
`PkgFactoryCLI.main()`. Interactive device login is available as
`PkgFactoryCLI.github_device_login()` in the CLI project.

## Scripts and notebooks

`LocalAPI` and `WebAPI` have been removed. Use `PackageSpec`, `plan_package`,
and `create_package` as shown in [Julia and notebooks](user.md#Julia-and-notebooks).

The noninteractive names `PackageConfig`, `preview`, `GitHubAPI(token)`, and
`create!` remain available under `PkgFactory` for existing scripts.
`GitHubAPI()` no longer reads environment variables; pass a token explicitly,
for example `PkgFactory.GitHubAPI(ENV["GITHUB_TOKEN"])`.

## MCP defaults

MCP now defaults to `template="all-in-one"` and `visibility="public"`.
To retain the former selection, pass `template="minimum"` and
`visibility="private"` explicitly. See the
[MCP guide](https://github.com/JuliaPackageFactory/PkgFactory.jl/tree/main/apps/mcp)
for client configuration.
