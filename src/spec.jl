function _bounded_text(value, field, limit; empty=false)
    value isa AbstractString || throw(InputError("$field must be a string."))
    (empty || !isempty(strip(value))) && ncodeunits(value) <= limit ||
        throw(InputError("$field has an invalid length."))
    return String(value)
end
function _validate_owner(owner)
    _bounded_text(owner, "owner", 100)
    # Validate URL path components without imposing rules on GitHub account types.
    occursin(r"^[A-Za-z0-9][A-Za-z0-9-]*$", owner) ||
        throw(InputError("owner must contain only ASCII letters, digits and hyphens."))
end
function _normalize_repo_name(repo_name::String)::String
    repo_name = strip(repo_name)
    return endswith(repo_name, ".jl") ? repo_name : "$(repo_name).jl"
end

_package_name(repo::String) = replace(_normalize_repo_name(repo), r"\.jl$" => "")

function _verify_inputs(
    owner_name::String,
    repo_name::String,
    author_names::Vector{String},
    visibility::String,
    template_name::String,
)
    _validate_owner(owner_name)
    _bounded_text(repo_name, "package_name", 100)
    package_check = Verifications.verify_package_name(_package_name(repo_name))
    package_check == "OK" || throw(InputError("Invalid package name."))
    1 <= length(author_names) <= 20 || throw(InputError("authors must contain 1 to 20 names."))
    foreach(author -> _bounded_text(author, "author", 200), author_names)
    visibility in ("public", "private") ||
        throw(InputError("Visibility must be public or private."))
    template_name in Templates.list_templates() ||
        throw(InputError("Unknown package template."))
    return _normalize_repo_name(repo_name)
end

const DEFAULT_TEMPLATE = "all-in-one"
const DEFAULT_VISIBILITY = "public"
const DEFAULT_COMMIT_MESSAGE = "Using PkgFactory.jl"

"""Validated package settings. Secrets are supplied separately in `Credential`.
`name` accepts a Julia package name with or without the `.jl` repository suffix.
"""
struct PackageSpec
    owner::String
    name::String
    authors::Tuple{Vararg{String}}
    description::String
    template::String
    visibility::String
    commit_message::String
    resume::Bool
    function PackageSpec(; owner, name, authors, description="", template=DEFAULT_TEMPLATE,
        visibility=DEFAULT_VISIBILITY, commit_message=DEFAULT_COMMIT_MESSAGE, resume=false)
        owner = String(strip(_bounded_text(owner, "owner", 100)))
        name = _package_name(_bounded_text(name, "name", 100))
        authors isa AbstractVector || authors isa Tuple || throw(InputError("authors must be an array."))
        1 <= length(authors) <= 20 || throw(InputError("authors must contain 1 to 20 names."))
        authors = [String(strip(_bounded_text(a, "author", 200))) for a in authors]
        description = _bounded_text(description, "description", 2000; empty=true)
        template = _bounded_text(template, "template", 100)
        visibility = _bounded_text(visibility, "visibility", 10)
        commit_message = _bounded_text(commit_message, "commit_message", 500)
        resume isa Bool || throw(InputError("resume must be a boolean."))
        _verify_inputs(owner, name, authors, visibility, template)
        new(owner, name, Tuple(authors), description, template, visibility, commit_message, resume)
    end
end

"""Explicit GitHub and optional Codecov credentials; display always redacts secrets.
This type never reads environment variables or starts an interactive login.
"""
struct Credential
    access_token::String
    codecov_token::String
    function Credential(token; codecov_token="")
        new(strip(_bounded_text(token, "access_token", 4096)),
            _bounded_text(codecov_token, "codecov_token", 4096; empty=true))
    end
end
Base.show(io::IO, ::Credential) = print(io, "Credential(<redacted>)")
Base.show(io::IO, ::MIME"text/plain", credential::Credential) = show(io, credential)

"""Decode settings from a string-keyed mapping using the shared defaults and validation.
`package_name` is accepted as an alias for `name` for existing Web API clients.
"""
function package_spec(args::AbstractDict)
    allowed = ("owner", "name", "package_name", "authors", "description", "template",
        "visibility", "commit_message", "resume", "codecov_token")
    all(k -> k in allowed, keys(args)) || throw(InputError("Unknown package setting."))
    all(k -> haskey(args, k), ("owner", "authors")) || throw(InputError("owner and authors are required."))
    haskey(args, "name") && haskey(args, "package_name") && throw(InputError("Supply only one package name."))
    haskey(args, "name") || haskey(args, "package_name") || throw(InputError("name is required."))
    haskey(args, "codecov_token") && _bounded_text(args["codecov_token"], "codecov_token", 4096; empty=true)
    PackageSpec(; owner=args["owner"], name=get(args, "name", get(args, "package_name", nothing)),
        authors=args["authors"], description=get(args, "description", ""),
        template=get(args, "template", DEFAULT_TEMPLATE), visibility=get(args, "visibility", DEFAULT_VISIBILITY),
        commit_message=get(args, "commit_message", DEFAULT_COMMIT_MESSAGE), resume=get(args, "resume", false))
end

"""JSON schema for package settings, including the same defaults used by `PackageSpec`."""
function package_schema()
    Dict{String,Any}("type" => "object", "additionalProperties" => false,
        "required" => ["owner", "name", "authors"], "properties" => Dict{String,Any}(
            "owner" => Dict("type" => "string", "maxLength" => 100),
            "name" => Dict("type" => "string", "maxLength" => 100),
            "authors" => Dict("type" => "array", "minItems" => 1, "maxItems" => 20,
                "items" => Dict("type" => "string", "minLength" => 1, "maxLength" => 200)),
            "description" => Dict("type" => "string", "default" => "", "maxLength" => 2000),
            "template" => Dict("type" => "string", "enum" => Templates.list_templates(), "default" => DEFAULT_TEMPLATE),
            "visibility" => Dict("type" => "string", "enum" => ["public", "private"], "default" => DEFAULT_VISIBILITY),
            "commit_message" => Dict("type" => "string", "default" => DEFAULT_COMMIT_MESSAGE, "maxLength" => 500),
            "resume" => Dict("type" => "boolean", "default" => false)))
end
