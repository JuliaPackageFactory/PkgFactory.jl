function _set_repository_secret(
    access_token,
    owner_name,
    repo_name,
    secret_name,
    secret_value;
    requester = GitHubTransport(),
)
    public_key, _ = _request_json(
        "GET",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/actions/secrets/public-key";
        token = access_token,
        requester = requester,
    )
    encrypted = Sodium.seal(collect(codeunits(String(secret_value))), public_key["key"])
    _request_json(
        "PUT",
        "$(GITHUB_API_URL)/repos/$(owner_name)/$(repo_name)/actions/secrets/$(secret_name)";
        token = access_token,
        body = Dict(
            "encrypted_value" => encrypted,
            "key_id" => public_key["key_id"],
        ),
        expected = (201, 204),
        requester = requester,
    )
end

function _generate_keys()
    return mktempdir() do directory
        filename = joinpath(directory, "documenter")
        # DocumenterTools.genkeys prints the private key and changes the process
        # working directory. Use its bundled executable directly so keys stay
        # private and concurrent calls use independent absolute filenames.
        command = `$(ssh_keygen()) -q -t rsa -b 4096 -N "" -C Documenter -f $filename`
        # A ProcessFailedException would display the JLL command's environment.
        success(pipeline(command; stdout=devnull, stderr=devnull)) ||
            error("Failed to generate the documentation deploy key.")
        (chomp(read(filename * ".pub", String)), Base64.base64encode(read(filename)))
    end
end

function _ensure_documenter_key(
    access_token,
    owner_name,
    repo_name;
    requester = GitHubTransport(),
    key_generator = _generate_keys,
)
    # Only remove keys created by this workflow. Always rotate on an explicit
    # resume: GitHub does not expose secret contents, so presence cannot prove
    # that an existing public key and secret form a pair.
    managed = Any[]
    for page in 1:10
        keys, _ = _request_json("GET",
            "$GITHUB_API_URL/repos/$owner_name/$repo_name/keys?per_page=100&page=$page";
            token=access_token, requester)
        append!(managed, filter(key -> startswith(get(key, "title", ""), "PkgFactory Documenter "), keys))
        length(keys) < 100 && break
        page == 10 && throw(InputError("Too many deploy keys; inspect the repository manually."))
    end
    public_key, private_key = key_generator()
    _request_json("POST", "$GITHUB_API_URL/repos/$owner_name/$repo_name/keys";
        token=access_token,
        body=Dict("title" => "PkgFactory Documenter $(UUIDs.uuid4())", "key" => public_key, "read_only" => false),
        expected=(201,), requester)
    _set_repository_secret(access_token, owner_name, repo_name, "DOCUMENTER_KEY", private_key; requester)
    # Leave both keys in place if secret upload fails or its result is unknown.
    # The next resume installs a fresh matching pair before cleaning old keys.
    for key in managed
        _request_json("DELETE", "$GITHUB_API_URL/repos/$owner_name/$repo_name/keys/$(key["id"])";
            token=access_token, expected=(204, 404), requester)
    end
end
