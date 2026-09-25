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
