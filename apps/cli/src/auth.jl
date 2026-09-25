function github_device_login(;
    client_id::String = PkgFactory.GITHUB_OAUTH_CLIENT_ID,
    requester = PkgFactory.GitHubTransport(),
    sleeper = sleep,
    output::IO = stdout,
)
    device = PkgFactory.device_flow_begin(client_id; requester = requester)
    verification_uri = String(device["verification_uri"])
    user_code = String(device["user_code"])
    println(output, "Open $(verification_uri) and enter code $(user_code).")
    println(output, "Waiting for GitHub authorization…")
    flush(output)

    interval = max(Int(get(device, "interval", 5)), 5)
    expires_in = max(Int(get(device, "expires_in", 900)), 1)
    deadline = time() + expires_in
    while time() < deadline
        sleeper(interval)
        result = PkgFactory.device_flow_poll(
            String(device["device_code"]),
            client_id;
            requester = requester,
        )
        if haskey(result, "access_token")
            granted_scopes = Set(filter(
                !isempty,
                split(String(get(result, "scope", "")), r"[\s,]+"),
            ))
            missing_scopes = setdiff(Set(["repo", "workflow"]), granted_scopes)
            isempty(missing_scopes) || error(
                "GitHub did not grant the required $(join(sort!(collect(missing_scopes)), ", ")) permission.",
            )
            println(output, "GitHub authorization completed.")
            flush(output)
            return PkgFactory.Credential(String(result["access_token"]))
        end

        oauth_error = String(get(result, "error", ""))
        oauth_error == "authorization_pending" && continue
        if oauth_error == "slow_down"
            interval += max(Int(get(result, "interval", 5)), 5)
            continue
        end
        error(String(get(result, "error_description", "GitHub authorization failed.")))
    end
    error("GitHub authorization expired before it was completed.")
end
