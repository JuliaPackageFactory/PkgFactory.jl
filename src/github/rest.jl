"""List the authenticated user and organizations visible to an explicit GitHub token."""
function get_repository_owners(access_token::AbstractString; requester = GitHubTransport())
    viewer, _ = _request_json(
        "GET",
        "$(GITHUB_API_URL)/user";
        token = access_token,
        requester = requester,
    )
    login = String(viewer["login"])
    display_name = isnothing(get(viewer, "name", nothing)) ? login : String(viewer["name"])
    owners = Dict{String,Any}[
        Dict("login" => login, "name" => display_name, "kind" => "user"),
    ]

    organizations = try
        response, _ = _request_json(
            "GET",
            "$(GITHUB_API_URL)/user/orgs?per_page=100";
            token = access_token,
            requester = requester,
        )
        response
    catch error
        error isa GitHubAPIError && error.status == 403 || rethrow()
        Any[]
    end
    for organization in organizations
        organization_login = String(organization["login"])
        push!(
            owners,
            Dict(
                "login" => organization_login,
                "name" => organization_login,
                "kind" => "organization",
            ),
        )
    end
    length(owners) > 1 &&
        sort!(view(owners, 2:length(owners)); by = owner -> lowercase(owner["login"]))
    return owners
end

function _repository(access_token, owner_name, repo_name; requester = GitHubTransport())
    return _request_json(
        "GET",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)";
        token = access_token,
        expected = (200, 404),
        requester = requester,
    )
end

"""Validate a repository name and query whether it is available without making changes."""
function repository_availability(
    access_token::String,
    owner_name::String,
    repo_name::String;
    requester = GitHubTransport(),
)
    _validate_owner(owner_name)
    _bounded_text(repo_name, "package_name", 100)
    package_name = _package_name(repo_name)
    package_check = Verifications.verify_package_name(package_name)
    package_check == "OK" || throw(InputError("Invalid package name."))
    normalized_repo_name = _normalize_repo_name(repo_name)
    _, status = _repository(
        access_token,
        owner_name,
        normalized_repo_name;
        requester = requester,
    )
    return Dict(
        "available" => status == 404,
        "repository" => "$(owner_name)/$(normalized_repo_name)",
    )
end

function _create_repository(
    access_token,
    owner_name,
    repo_name,
    description,
    visibility,
    viewer_login;
    requester = GitHubTransport(),
)
    endpoint =
        owner_name == viewer_login ? "$(GITHUB_API_URL)/user/repos" :
        "$(GITHUB_API_URL)/orgs/$(owner_name)/repos"
    response, _ = _request_json(
        "POST",
        endpoint;
        token = access_token,
        body = Dict(
            "name" => repo_name,
            "description" => description,
            "homepage" => "https://$(owner_name).github.io/$(repo_name)",
            "private" => visibility == "private",
            "auto_init" => true,
        ),
        expected = (201,),
        requester = requester,
    )
    return response
end

function _project_file(access_token, owner_name, repo_name; requester = GitHubTransport())
    response, status = _request_json(
        "GET",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/contents/Project.toml";
        token = access_token,
        expected = (200, 404),
        requester = requester,
    )
    status == 404 && return nothing
    encoded = replace(String(response["content"]), r"\s" => "")
    return String(Base64.base64decode(encoded))
end

function _branch_head(
    access_token,
    owner_name,
    repo_name,
    branch;
    requester = GitHubTransport(),
    attempts::Int = 6,
    sleeper = sleep,
)
    attempts > 0 || error("Branch lookup attempts must be positive.")
    endpoint = "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/ref/heads/$(branch)"
    for attempt in 1:attempts
        try
            response, _ = _request_json(
                "GET",
                endpoint;
                token = access_token,
                requester = requester,
            )
            return String(response["object"]["sha"])
        catch error
            retryable = error isa GitHubAPIError && error.status == 404
            retryable && attempt < attempts || rethrow()
            sleeper(min(2.0^(attempt - 1), 5.0))
        end
    end
    error("The default branch could not be loaded.")
end

function _commit_template(
    access_token,
    owner_name,
    repo_name,
    branch,
    paths_and_contents,
    commit_message;
    requester = GitHubTransport(),
)
    parent_sha = _branch_head(
        access_token,
        owner_name,
        repo_name,
        branch;
        requester = requester,
    )
    commit, _ = _request_json(
        "GET",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/commits/$(parent_sha)";
        token = access_token,
        requester = requester,
    )
    entries = [
        Dict(
            "path" => path,
            "mode" => "100644",
            "type" => "blob",
            "content" => content,
        ) for (path, content) in sort!(collect(paths_and_contents); by = first)
    ]
    tree, _ = _request_json(
        "POST",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/trees";
        token = access_token,
        body = Dict("base_tree" => commit["tree"]["sha"], "tree" => entries),
        expected = (201,),
        requester = requester,
    )
    new_commit, _ = _request_json(
        "POST",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/commits";
        token = access_token,
        body = Dict(
            "message" => commit_message,
            "tree" => tree["sha"],
            "parents" => [parent_sha],
        ),
        expected = (201,),
        requester = requester,
    )
    _request_json(
        "PATCH",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/refs/heads/$(branch)";
        token = access_token,
        body = Dict("sha" => new_commit["sha"], "force" => false),
        requester = requester,
    )
    return String(new_commit["sha"])
end

function _ensure_main_branch(
    access_token,
    owner_name,
    repo_name,
    current_branch,
    commit_sha;
    requester = GitHubTransport(),
)
    current_branch == "main" && return
    existing, status = _request_json("GET", "$GITHUB_API_URL/repos/$owner_name/$repo_name/git/ref/heads/main";
        token=access_token, expected=(200, 404), requester)
    if status == 200
        existing["object"]["sha"] == commit_sha || throw(InputError("Existing main branch has a different commit."))
    else
        _request_json(
            "POST",
            "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/refs";
            token = access_token,
            body = Dict("ref" => "refs/heads/main", "sha" => commit_sha),
            expected = (201,),
            requester = requester,
        )
    end
    _request_json(
        "PATCH",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)";
        token = access_token,
        body = Dict("default_branch" => "main"),
        requester = requester,
    )
end

function _ensure_gh_pages(access_token, owner_name, repo_name, commit_sha; requester = GitHubTransport())
    _, status = _request_json(
        "GET",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/ref/heads/gh-pages";
        token = access_token,
        expected = (200, 404),
        requester = requester,
    )
    status == 200 && return
    _request_json(
        "POST",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/git/refs";
        token = access_token,
        body = Dict("ref" => "refs/heads/gh-pages", "sha" => commit_sha),
        expected = (201,),
        requester = requester,
    )
end
