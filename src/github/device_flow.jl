"""Request an OAuth device code. The caller presents it and controls the polling loop."""
function device_flow_begin(
    client_id::String = GITHUB_OAUTH_CLIENT_ID;
    requester = GitHubTransport(),
)
    response = try
        requester(
            "POST",
            "$(GITHUB_OAUTH_URL)/device/code";
            headers = [
                "Accept" => "application/json",
                "Content-Type" => "application/x-www-form-urlencoded",
                "User-Agent" => "PkgFactory.jl",
            ],
            body = "client_id=$(URIs.escapeuri(client_id))&scope=read:user%20read:org%20repo%20workflow",
            status_exception = false,
        )
    catch err
        err isa InterruptException && rethrow()
        throw(
            GitHubAPIError(
                503,
                "Could not connect to GitHub. Check the network connection and try again.",
            ),
        )
    end
    response.status == 200 || throw(GitHubAPIError(response.status, _github_message(response)))
    return _response_json(response)
end

"""Poll device authorization once. Return pending/slow-down states to the caller."""
function device_flow_poll(
    device_code::String,
    client_id::String = GITHUB_OAUTH_CLIENT_ID;
    requester = GitHubTransport(),
)
    _bounded_text(device_code, "device_code", 1024)
    response = try
        requester(
            "POST",
            "$(GITHUB_OAUTH_URL)/oauth/access_token";
            headers = [
                "Accept" => "application/json",
                "Content-Type" => "application/x-www-form-urlencoded",
                "User-Agent" => "PkgFactory.jl",
            ],
            body = "client_id=$(URIs.escapeuri(client_id))&device_code=$(URIs.escapeuri(device_code))&grant_type=urn:ietf:params:oauth:grant-type:device_code",
            status_exception = false,
        )
    catch err
        err isa InterruptException && rethrow()
        throw(
            GitHubAPIError(
                503,
                "Could not connect to GitHub. Check the network connection and try again.",
            ),
        )
    end
    response.status == 200 || throw(GitHubAPIError(response.status, _github_message(response)))
    return _response_json(response)
end
