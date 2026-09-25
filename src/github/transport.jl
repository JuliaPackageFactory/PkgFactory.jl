"""Bounded GitHub transport. Writes are never automatically retried or redirected."""
struct GitHubTransport{F}
    request::F
    connect_timeout::Int
    read_timeout::Int
end
function GitHubTransport(; request=HTTP.request, connect_timeout=10, read_timeout=30)
    connect_timeout > 0 && read_timeout > 0 || throw(ArgumentError("Timeouts must be positive"))
    GitHubTransport(request, Int(connect_timeout), Int(read_timeout))
end
function (transport::GitHubTransport)(method, url; kwargs...)
    transport.request(method, url; connect_timeout=transport.connect_timeout,
        readtimeout=transport.read_timeout, retry=false, redirect=false, kwargs...)
end

function _response_json(response)
    isempty(response.body) && return Dict{String,Any}()
    text = String(response.body)
    return startswith(strip(text), "[") ? JSON3.read(text, Vector{Any}) :
           JSON3.read(text, Dict{String,Any})
end

function _github_message(response)::String
    body = try
        _response_json(response)
    catch
        Dict{String,Any}()
    end
    message =
        body isa AbstractDict ?
        get(body, "message", "GitHub returned an unexpected response.") :
        "GitHub returned an unexpected response."
    return "GitHub API request failed ($(response.status)): $(message)"
end

function _request_json(
    method::String,
    url::String;
    token::AbstractString = "",
    body = nothing,
    expected::Tuple = (200,),
    requester = GitHubTransport(),
)
    headers = Pair{String,String}[
        "Accept" => "application/vnd.github+json",
        "User-Agent" => "PkgFactory.jl",
        "X-GitHub-Api-Version" => GITHUB_API_VERSION,
    ]
    isempty(token) || push!(headers, "Authorization" => "Bearer $(token)")
    payload = ""
    if !isnothing(body)
        push!(headers, "Content-Type" => "application/json")
        payload = JSON3.write(body)
    end
    response = try
        requester(
            method,
            url;
            headers = headers,
            body = payload,
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
    response.status in expected || throw(
        GitHubAPIError(
            response.status,
            "$(_github_message(response)) ($(method) $(replace(url, GITHUB_API_URL => "")))",
            tryparse(Int, HTTP.header(response, "Retry-After", "")),
        ),
    )
    return _response_json(response), response.status
end
