# Resolve local core dependencies from any working directory (Julia 1.10+).
import Pkg
root = normpath(joinpath(@__DIR__, ".."))
apps = isempty(ARGS) ? ["cli", "web", "mcp"] : ARGS
for app in apps
    app in ("cli", "web", "mcp") || error("Unknown application: $app")
    Pkg.activate(joinpath(root, "apps", app))
    # Relative paths keep checked-in manifests portable across checkouts.
    cd(joinpath(root, "apps", app)) do
        Pkg.develop(Pkg.PackageSpec(path="../.."))
        Pkg.instantiate()
        # Pkg on Windows rewrites [sources] using backslashes. Store portable
        # TOML paths so the same checkout also works on Linux and in containers.
        project = joinpath(pwd(), "Project.toml")
        write(project, replace(read(project, String), "..\\\\.." => "../.."))
    end
end
