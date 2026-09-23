using TOML
using UUIDs

function snapshot_head(git, directory)
    output = IOBuffer()
    process = run(pipeline(ignorestatus(`$git -C $directory rev-parse --verify --quiet HEAD`); stdout = output))
    process.exitcode == 0 && return strip(String(take!(output)))
    process.exitcode == 1 && return nothing
    error("Failed to read the E2E checkout's HEAD.")
end

function snapshot_uuid(git, directory, name; previous_name = nothing)
    isnothing(snapshot_head(git, directory)) && return string(uuid4())
    project = TOML.parsefile(joinpath(directory, "Project.toml"))
    (project["name"] == name || project["name"] == previous_name) ||
        error("Expected package $name in the E2E checkout.")
    return string(UUID(project["uuid"]))
end

function publish_template_snapshot(git, directory, files, message)
    isempty(strip(read(`$git -C $directory status --porcelain`, String))) ||
        error("Refusing to publish from a dirty E2E checkout.")
    # These dedicated repositories are complete generated snapshots. Remove
    # tracked files absent from the new template, including old package names.
    tracked = split(read(`$git -C $directory ls-files -z`, String), '\0'; keepempty = false)
    stale = sort!(collect(setdiff(tracked, keys(files))))
    isempty(stale) || run(`$git -C $directory rm -- $stale`)
    for (path, content) in files
        target = joinpath(directory, split(path, '/')...)
        mkpath(dirname(target))
        write(target, content)
    end
    paths = sort!(collect(keys(files)))
    run(`$git -C $directory add -- $paths`)
    diff = run(ignorestatus(`$git -C $directory diff --cached --quiet`))
    diff.exitcode == 0 && return false
    diff.exitcode == 1 || error("Failed to inspect E2E snapshot changes.")
    run(`$git -C $directory commit -m $message`)
    # A concurrent remote update fails here rather than replacing its history.
    run(`$git -C $directory push origin HEAD:main`)
    return true
end
