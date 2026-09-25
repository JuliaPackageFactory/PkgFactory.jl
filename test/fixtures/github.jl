fixture_json(status, value) = PkgFactory.HTTP.Response(status, PkgFactory.JSON3.write(value))

# In-memory GitHub state with actual template generation and secret encryption.
function github_fixture()
    state = Dict{String,Any}("exists" => false, "files" => Dict{String,String}(),
        "pending" => Dict{String,String}(), "keys" => Any[], "secret" => false,
        "fail_secret" => false, "next_id" => 0, "writes" => 0)
    requester = function(method, url; body="", kwargs...)
        data = isempty(body) ? Dict{String,Any}() : PkgFactory.JSON3.read(body, Dict{String,Any})
        method == "GET" || (state["writes"] += 1)
        if endswith(url, "/user")
            return fixture_json(200, Dict("login" => "ohno"))
        elseif endswith(url, "/repos/ohno/MyPackage.jl")
            return fixture_json(state["exists"] ? 200 : 404, Dict("default_branch" => "main"))
        elseif endswith(url, "/user/repos")
            state["exists"] = true
            return fixture_json(201, Dict("default_branch" => "main"))
        elseif occursin("/contents/", url)
            path = split(url, "/contents/")[2]
            if method == "PUT"
                state["files"][path] = String(PkgFactory.Base64.base64decode(data["content"]))
                return fixture_json(200, Dict())
            end
            haskey(state["files"], path) || return fixture_json(404, Dict())
            return fixture_json(200, Dict("sha" => "file-sha", "content" => PkgFactory.Base64.base64encode(state["files"][path])))
        elseif endswith(url, "/git/ref/heads/main") || endswith(url, "/git/ref/heads/gh-pages")
            return fixture_json(200, Dict("object" => Dict("sha" => "head")))
        elseif endswith(url, "/git/commits/head")
            return fixture_json(200, Dict("tree" => Dict("sha" => "tree")))
        elseif endswith(url, "/git/trees")
            state["pending"] = Dict(entry["path"] => entry["content"] for entry in data["tree"])
            return fixture_json(201, Dict("sha" => "new-tree"))
        elseif endswith(url, "/git/commits")
            return fixture_json(201, Dict("sha" => "new-commit"))
        elseif endswith(url, "/git/refs/heads/main")
            merge!(state["files"], state["pending"])
            return fixture_json(200, Dict())
        elseif occursin("/keys?", url)
            return fixture_json(200, state["keys"])
        elseif method == "POST" && endswith(url, "/keys")
            state["next_id"] += 1
            key = merge(data, Dict("id" => state["next_id"]))
            push!(state["keys"], key)
            return fixture_json(201, key)
        elseif method == "DELETE" && occursin("/keys/", url)
            id = parse(Int, last(split(url, '/')))
            filter!(key -> key["id"] != id, state["keys"])
            return PkgFactory.HTTP.Response(204)
        elseif endswith(url, "/actions/secrets/public-key")
            return fixture_json(200, Dict("key" => PkgFactory.Base64.base64encode(zeros(UInt8, 32)), "key_id" => "key-id"))
        elseif endswith(url, "/actions/secrets/DOCUMENTER_KEY")
            state["fail_secret"] && return fixture_json(503, Dict("message" => "failure"))
            state["secret"] = true
            return PkgFactory.HTTP.Response(204)
        end
        error("Unexpected fixture request: $method $url")
    end
    return state, requester
end
