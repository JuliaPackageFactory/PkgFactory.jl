module PkgFactoryCLI

import PkgFactory
export main, github_device_login
include("auth.jl")

const HELP = """
Usage: julia --project=apps/cli apps/cli/bin/pkgfactory.jl [options]
  --owner OWNER --name NAME --author AUTHOR [--author AUTHOR ...]
  --description TEXT --template TEMPLATE --visibility public|private
  --commit-message TEXT --resume --preview --yes --help
Omitted required settings are prompted interactively. Optional defaults come
from PkgFactory.package_schema(). --preview never authenticates or changes GitHub.
Credentials: GITHUB_TOKEN / GH_TOKEN, or interactive GitHub device login.
Optional Codecov credential: CODECOV_TOKEN.
"""

function parse_arguments(args)
    settings = Dict{String,Any}()
    preview, yes = false, false
    fields = Set(keys(PkgFactory.package_schema()["properties"]))
    i = 1
    while i <= length(args)
        option = args[i]
        if option == "--preview"
            preview = true
        elseif option == "--yes"
            yes = true
        elseif option == "--resume"
            settings["resume"] = true
        else
            startswith(option, "--") || throw(ArgumentError("Expected an option, got $option"))
            key = replace(option[3:end], '-' => '_')
            key == "author" || key in fields || throw(ArgumentError("Unknown option: $option"))
            i < length(args) || throw(ArgumentError("$option requires a value"))
            i += 1
            if key == "author"
                push!(get!(settings, "authors", String[]), args[i])
            else
                settings[key] = args[i]
            end
        end
        i += 1
    end
    (; settings, preview, yes)
end

function prompt(input, output, label)
    print(output, label, ": ")
    flush(output)
    eof(input) && throw(ArgumentError("Missing $label; supply command-line arguments or interactive input."))
    strip(readline(input))
end

"""Collect arguments and credentials, then call the core planning and creation API."""
function main(args=ARGS; input=stdin, output=stdout, env=ENV,
    requester=PkgFactory.GitHubTransport(), key_generator=PkgFactory._generate_keys,
    login=github_device_login)
    "--help" in args && (print(output, HELP); return nothing)
    parsed = parse_arguments(args)
    settings = parsed.settings
    for key in PkgFactory.package_schema()["required"]
        haskey(settings, key) && continue
        value = prompt(input, output, key == "authors" ? "authors (comma separated)" : key)
        settings[key] = key == "authors" ? strip.(split(value, ',')) : value
    end
    if isempty(args)
        schema = PkgFactory.package_schema()["properties"]
        for key in ("description", "template", "visibility", "commit_message")
            value = prompt(input, output, "$key [$(schema[key]["default"])]")
            isempty(value) || (settings[key] = value)
        end
        settings["resume"] = lowercase(prompt(input, output, "Resume interrupted setup? [y/N]")) in ("y", "yes")
    end
    plan = PkgFactory.plan_package(PkgFactory.package_spec(settings))
    println(output, plan)
    foreach(path -> println(output, "  ", path), plan.files)
    parsed.preview && return plan
    if !parsed.yes
        lowercase(prompt(input, output, "Create this repository? [y/N]")) in ("y", "yes") || return nothing
    end
    token = get(env, "GITHUB_TOKEN", get(env, "GH_TOKEN", ""))
    backend = isempty(strip(token)) ? login(; requester, output) : PkgFactory.Credential(token)
    credential = PkgFactory.Credential(backend.access_token; codecov_token=get(env, "CODECOV_TOKEN", ""))
    result = PkgFactory.create_package(credential, plan; requester, key_generator)
    println(output, result["url"])
    result
end

end
