"""Cloudflare application adapters; the core remains independent of hosting."""
module Cloudflare
import PkgFactory
const HTTP = PkgFactory.HTTP
const JSON3 = PkgFactory.JSON3

struct StateClient
    origin::String
    secret::String
    function StateClient(origin, secret)
        occursin(r"^https://[^/?#]+$", origin) || throw(ArgumentError("State origin must be an HTTPS origin"))
        ncodeunits(secret) >= 32 || throw(ArgumentError("INTERNAL_SECRET must contain at least 32 bytes"))
        new(String(origin), String(secret))
    end
end
Base.show(io::IO, ::StateClient) = print(io, "StateClient(<redacted>)")

function state_request(client::StateClient, action, data)
    response = try
        HTTP.post(client.origin * "/internal/state", [
            "Authorization" => "Bearer " * client.secret,
            "Content-Type" => "application/json"],
            JSON3.write(Dict("action" => action, "data" => data));
            status_exception=false, retry=false, redirect=false, connect_timeout=10, readtimeout=30)
    catch
        throw(PkgFactory.InputError("Cloudflare state is unavailable. Check repository status before retrying."))
    end
    result = try
        JSON3.read(String(response.body), Dict{String,Any})
    catch
        throw(PkgFactory.InputError("Cloudflare state returned an invalid response."))
    end
    response.status == 200 || throw(PkgFactory.InputError(
        "Cloudflare state rejected the operation ($(get(result, "code", "unavailable"))). Check repository status before retrying."))
    result
end

function with_repository_operation(f, client::StateClient, plan)
    # No expiring lease: a timed-out client must not admit a second writer while
    # the first container is still changing GitHub. Crashes need operator recovery.
    operation = string(PkgFactory.UUIDs.uuid4())
    data = Dict("repository" => lowercase(plan.repository), "operation" => operation)
    state_request(client, "acquire", data)
    try
        f()
    finally
        state_request(client, "release", data)
    end
end

function constant_equal(a::AbstractString, b::AbstractString)
    aa, bb = codeunits(a), codeunits(b)
    length(aa) == length(bb) || return false
    difference = UInt8(0)
    for i in eachindex(aa)
        difference |= aa[i] ⊻ bb[i]
    end
    difference == 0
end

function verify_ticket(token, secret; clock=time)
    ncodeunits(token) <= 12000 || error("Invalid ticket")
    parts = split(token, '.'; limit=2)
    length(parts) == 2 || error("Invalid ticket")
    signature = bytes2hex(PkgFactory.SHA.hmac_sha256(Vector{UInt8}(codeunits(secret)), codeunits(parts[1])))
    constant_equal(signature, parts[2]) || error("Invalid ticket")
    payload = JSON3.read(String(PkgFactory.Base64.base64decode(parts[1])), Dict{String,Any})
    payload["aud"] == "pkgfactory-container" || error("Invalid ticket")
    now = clock()
    now < payload["exp"] <= now + 180 || error("Expired ticket")
    payload["sub"] isa String && !isempty(payload["sub"]) || error("Invalid subject")
    payload["github_token"] isa String && !isempty(payload["github_token"]) || error("Missing credential")
    payload
end
end
