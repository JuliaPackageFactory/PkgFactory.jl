const ACTIVE_REPOSITORIES = Set{String}()
const REPOSITORY_MUTEX = ReentrantLock()
function _with_repository_lock(f, owner, repo)
    key = lowercase("$owner/$repo")
    lock(REPOSITORY_MUTEX) do
        key in ACTIVE_REPOSITORIES && throw(GitHubAPIError(409, "Repository operation already in progress."))
        length(ACTIVE_REPOSITORIES) < 8 || throw(GitHubAPIError(429, "Creation capacity reached."))
        push!(ACTIVE_REPOSITORIES, key)
    end
    try
        f()
    finally
        lock(REPOSITORY_MUTEX) do
            delete!(ACTIVE_REPOSITORIES, key)
        end
    end
end

const MARKER_PATH = ".pkgfactory.json"
function _fingerprint(owner, repo, authors, description, template, visibility, message)
    bytes2hex(SHA.sha256(JSON3.write([lowercase(owner), lowercase(repo), authors,
        description, template, visibility, message])))
end

function _marker(token, owner, repo; requester=GitHubTransport())
    file, status = _request_json("GET", "$GITHUB_API_URL/repos/$owner/$repo/contents/$MARKER_PATH";
        token, expected=(200, 404), requester)
    status == 404 && return nothing
    data = try
        JSON3.read(String(Base64.base64decode(replace(file["content"], r"\s" => ""))), Dict{String,Any})
    catch
        throw(InputError("Invalid PkgFactory recovery marker. Inspect the repository manually."))
    end
    get(data, "version", nothing) == 1 || throw(InputError("Unsupported recovery marker."))
    return (data=data, sha=String(file["sha"]))
end

function repository_status(token::AbstractString, owner::String, repo::String; requester=GitHubTransport())
    _validate_owner(owner)
    _bounded_text(repo, "package_name", 100)
    Verifications.verify_package_name(_package_name(repo)) == "OK" || throw(InputError("Invalid package name."))
    repo = _normalize_repo_name(repo)
    _, status = _repository(token, owner, repo; requester)
    status == 404 && return Dict("repository" => "$owner/$repo", "state" => "not_found")
    marker = _marker(token, owner, repo; requester)
    state = isnothing(marker) ? "unverified" : get(marker.data, "state", "unverified")
    state in ("files_committed", "complete") || (state = "unverified")
    return Dict("repository" => "$owner/$repo", "state" => state)
end
