"""Internal implementation shared by every application."""
function _create_package(
    credential::Credential,
    plan::PackagePlan;
    requester = GitHubTransport(),
    key_generator = _generate_keys,
    stage = Ref("validation"),
)
    spec = plan.spec
    access_token, codecov_token = credential.access_token, credential.codecov_token
    owner_name, repo_name = spec.owner, _normalize_repo_name(spec.name)
    package_description = spec.description
    template_name, visibility = spec.template, spec.visibility
    commit_message, resume = spec.commit_message, spec.resume
    fingerprint = plan.fingerprint
    stage[] = "repository_lookup"

    viewer, _ = _request_json(
        "GET",
        "$(GITHUB_API_URL)/user";
        token = access_token,
        requester = requester,
    )
    repository, repository_status = _repository(
        access_token,
        owner_name,
        repo_name;
        requester = requester,
    )
    if repository_status == 200 && !resume
        throw(GitHubAPIError(409, "Repository already exists. Inspect its status before resuming."))
    elseif repository_status == 404
        stage[] = "repository_creation"
        repository = _create_repository(
            access_token,
            owner_name,
            repo_name,
            package_description,
            visibility,
            String(viewer["login"]);
            requester = requester,
        )
    end

    stage[] = "recovery_validation"
    marker = repository_status == 200 ? _marker(access_token, owner_name, repo_name; requester) : nothing
    if repository_status == 200
        isnothing(marker) && throw(InputError("No PkgFactory recovery marker. Inspect the repository manually; automatic resume is refused."))
        get(marker.data, "fingerprint", "") == fingerprint ||
            throw(InputError("Settings differ from the original PkgFactory operation."))
    end
    default_branch = String(get(repository, "default_branch", "main"))
    project_file = _project_file(
        access_token,
        owner_name,
        repo_name;
        requester = requester,
    )
    if !isnothing(marker)
        !isnothing(project_file) && get(marker.data, "project_sha256", "") == bytes2hex(SHA.sha256(project_file)) ||
            throw(InputError("Project.toml changed since package generation; automatic resume is refused."))
        get(marker.data, "state", "") in ("files_committed", "complete") || throw(InputError("Invalid recovery state."))
        if marker.data["state"] == "complete"
            return Dict("repository" => "$owner_name/$repo_name", "url" => "https://github.com/$owner_name/$repo_name", "resumed" => true)
        end
    end
    stage[] = "template_commit"
    commit_sha = if isnothing(project_file)
        files = Dict(plan.contents)
        _commit_template(
            access_token,
            owner_name,
            repo_name,
            default_branch,
            files,
            commit_message;
            requester = requester,
        )
    else
        package_name = _package_name(repo_name)
        occursin("name = \"$(package_name)\"", project_file) || error(
            "The existing repository does not contain the expected package, \"$(package_name)\".",
        )
        _branch_head(
            access_token,
            owner_name,
            repo_name,
            default_branch;
            requester = requester,
        )
    end

    stage[] = "default_branch"
    _ensure_main_branch(
        access_token,
        owner_name,
        repo_name,
        default_branch,
        commit_sha;
        requester = requester,
    )
    if template_name != "minimum"
        stage[] = "documentation"
        _ensure_gh_pages(
            access_token,
            owner_name,
            repo_name,
            commit_sha;
            requester = requester,
        )
        _ensure_documenter_key(
            access_token,
            owner_name,
            repo_name;
            requester = requester,
            key_generator = key_generator,
        )
    end
    if template_name != "minimum" && !isempty(strip(codecov_token))
        stage[] = "coverage_secret"
        _set_repository_secret(
            access_token,
            owner_name,
            repo_name,
            "CODECOV_TOKEN",
            String(codecov_token);
            requester = requester,
        )
    end

    stage[] = "completion_record"
    marker = _marker(access_token, owner_name, repo_name; requester)
    isnothing(marker) && throw(InputError("Recovery marker is missing."))
    marker.data["state"] = "complete"
    _request_json("PUT", "$GITHUB_API_URL/repos/$owner_name/$repo_name/contents/$MARKER_PATH";
        token=access_token, body=Dict("message" => "Record completed PkgFactory setup",
            "content" => Base64.base64encode(JSON3.write(marker.data)), "sha" => marker.sha), requester)
    return Dict(
        "repository" => "$(owner_name)/$(repo_name)",
        "url" => "https://github.com/$(owner_name)/$(repo_name)",
        "resumed" => repository_status == 200,
    )
end

"""Execute an immutable plan using explicit credentials.
Creation and resume share one implementation. Failures report a safe, typed
`CreationError` with the stopped stage. Inspect `repository_status` before resuming.
Operations on the same repository are excluded within this process.
"""
function create_package(credential::Credential, plan::PackagePlan;
    requester=GitHubTransport(), key_generator=_generate_keys)
    stage = Ref("validation")
    _with_repository_lock(plan.spec.owner, _normalize_repo_name(plan.spec.name)) do
        try
            _create_package(credential, plan; requester, key_generator, stage)
        catch err
            err isa InterruptException && rethrow()
            err isa InputError && rethrow()
            throw(CreationError(stage[], err isa GitHubAPIError ? err.status : 500))
        end
    end
end

# Positional migration entry point, delegated to the same plan/apply pipeline.
function create_package(token::AbstractString, owner::String, name::String,
    authors::Vector{String}, description::String, codecov_token::AbstractString="";
    template_name=DEFAULT_TEMPLATE, visibility=DEFAULT_VISIBILITY,
    commit_message=DEFAULT_COMMIT_MESSAGE, resume=false, kwargs...)
    spec = PackageSpec(; owner, name, authors, description, template=template_name,
        visibility, commit_message, resume)
    create_package(Credential(token; codecov_token), plan_package(spec); kwargs...)
end
