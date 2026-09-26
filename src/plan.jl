"""An immutable snapshot of validated settings and the exact files to commit.
Construct with `plan_package`. Planning performs no network requests.
"""
struct PackagePlan
    spec::PackageSpec
    repository::String
    contents::Tuple{Vararg{Pair{String,String}}}
    fingerprint::String
    function PackagePlan(spec::PackageSpec)
        files = Templates.generate_template_files_dict(spec.owner, _normalize_repo_name(spec.name),
            collect(spec.authors), spec.description, spec.template)
        fingerprint = _fingerprint(spec.owner, _normalize_repo_name(spec.name), collect(spec.authors),
            spec.description, spec.template, spec.visibility, spec.commit_message)
        files[MARKER_PATH] = JSON3.write(Dict("version" => 1, "fingerprint" => fingerprint,
            "state" => "files_committed", "project_sha256" => bytes2hex(SHA.sha256(files["Project.toml"]))))
        new(spec, "$(spec.owner)/$(_normalize_repo_name(spec.name))",
            Tuple(sort!(collect(files); by=first)), fingerprint)
    end
    # Restore trusted application storage without rendering a new UUID or date.
    function PackagePlan(spec::PackageSpec, files::Dict{String,String})
        all(path -> !isempty(path) && !startswith(path, "/") &&
            !occursin('\\', path) && !occursin(':', path) &&
            all(part -> part ∉ ("", ".", ".."), split(path, '/')), keys(files)) ||
            throw(InputError("Invalid saved plan paths."))
        haskey(files, "Project.toml") && haskey(files, MARKER_PATH) ||
            throw(InputError("Saved plan is incomplete."))
        fingerprint = _fingerprint(spec.owner, _normalize_repo_name(spec.name), collect(spec.authors),
            spec.description, spec.template, spec.visibility, spec.commit_message)
        marker = JSON3.read(files[MARKER_PATH], Dict{String,Any})
        get(marker, "fingerprint", nothing) == fingerprint &&
            get(marker, "state", nothing) == "files_committed" &&
            get(marker, "project_sha256", nothing) == bytes2hex(SHA.sha256(files["Project.toml"])) ||
            throw(InputError("Saved plan does not match its settings."))
        new(spec, "$(spec.owner)/$(_normalize_repo_name(spec.name))",
            Tuple(sort!(collect(files); by=first)), fingerprint)
    end
end

"""Encode the exact rendered plan for trusted application storage, without credentials."""
function plan_snapshot(plan::PackagePlan)
    spec = plan.spec
    settings = Dict{String,Any}(String(key) => getfield(spec, key) for key in fieldnames(PackageSpec))
    settings["authors"] = collect(spec.authors)
    Dict("version" => 1, "spec" => settings, "files" => Dict(plan.contents))
end

"""Restore a snapshot from trusted storage. Never accept snapshots from API clients."""
function restore_plan(snapshot::AbstractDict)
    get(snapshot, "version", nothing) == 1 || throw(InputError("Unsupported saved plan version."))
    PackagePlan(package_spec(snapshot["spec"]), Dict{String,String}(snapshot["files"]))
end

"""Validate settings and render a package once, without credentials or side effects."""
plan_package(spec::PackageSpec) = PackagePlan(spec)
plan_package(args::AbstractDict) = plan_package(package_spec(args))
list_templates() = Templates.list_templates()

function Base.getproperty(plan::PackagePlan, key::Symbol)
    key === :config && return getfield(plan, :spec)
    key === :files && return first.(collect(getfield(plan, :contents)))
    getfield(plan, key)
end
function Base.show(io::IO, plan::PackagePlan)
    print(io, "PackagePlan(", repr(plan.repository), ", template=", repr(plan.spec.template),
        ", visibility=", repr(plan.spec.visibility), ", files=", length(plan.contents), ")")
end

# Noninteractive migration aliases for existing scripts and notebooks.
const PackageConfig = PackageSpec
const GitHubAPI = Credential
preview(spec::PackageSpec) = plan_package(spec)
create!(plan::PackagePlan, backend::Credential; kwargs...) = create_package(backend, plan; kwargs...)
create!(plan::PackagePlan; backend::Credential, kwargs...) = create_package(backend, plan; kwargs...)
create!(spec::PackageSpec, backend::Credential; kwargs...) = create_package(backend, plan_package(spec); kwargs...)
create!(spec::PackageSpec; backend::Credential, kwargs...) = create!(spec, backend; kwargs...)
