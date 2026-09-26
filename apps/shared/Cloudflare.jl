"""Cloudflare application adapters; the core remains independent of hosting."""
module Cloudflare
import PkgFactory
const HTTP = PkgFactory.HTTP
const JSON3 = PkgFactory.JSON3

struct StateError <: Exception
    code::String
    message::String
end
Base.showerror(io::IO, err::StateError) = print(io, err.message)
const STATE_MESSAGES = Dict(
    "plan_not_found" => "Plan not found. Call preview_package first.",
    "plan_expired" => "Plan expired. Call preview_package again.",
    "operation_in_progress" => "This plan is already being executed.",
    "operation_failed" => "A previous attempt failed and may have changed GitHub. Inspect the repository before previewing a resume operation.",
    "capacity_exceeded" => "Plan or operation storage is full. Try again after plans expire or operations finish.",
    "repository_busy" => "This repository already has an operation in progress. Wait for completion or ask the operator to inspect it.",
    "state_unavailable" => "Cloudflare state is unavailable. Check repository status before retrying.",
)
state_error(code) = haskey(STATE_MESSAGES, code) ? StateError(code, STATE_MESSAGES[code]) :
    StateError("state_unavailable", STATE_MESSAGES["state_unavailable"])

function with_warning(result, code, message)
    merge(Dict{String,Any}(result), Dict("warnings" =>
        [get(result, "warnings", Any[]); Dict("code" => code, "message" => message)]))
end

struct StateClient
    origin::String
    secret::String
    function StateClient(origin, secret)
        occursin(r"^https://[^/?#]+$", origin) || throw(ArgumentError("State origin must be an HTTPS origin"))
        ncodeunits(secret) >= 32 || throw(ArgumentError("State secret must contain at least 32 bytes"))
        new(String(origin), String(secret))
    end
end
Base.show(io::IO, ::StateClient) = print(io, "StateClient(<redacted>)")

function state_request(client::StateClient, action, data; post=HTTP.post)
    response = try
        post(client.origin * "/internal/state", [
            "Authorization" => "Bearer " * client.secret,
            "Content-Type" => "application/json"],
            JSON3.write(Dict("action" => action, "data" => data));
            status_exception=false, retry=false, redirect=false, connect_timeout=10, readtimeout=30)
    catch err
        err isa InterruptException && rethrow()
        throw(state_error("state_unavailable"))
    end
    result = try
        JSON3.read(String(response.body), Dict{String,Any})
    catch err
        err isa InterruptException && rethrow()
        throw(state_error("state_unavailable"))
    end
    response.status == 200 || throw(state_error(get(result, "code", "state_unavailable")))
    result
end

with_repository_operation(f, client::StateClient, plan) =
    with_repository_operation(f, (action, data) -> state_request(client, action, data), plan)

function with_repository_operation(f, request::Function, plan)
    # No expiring lease: a timed-out client must not admit a second writer while
    # the first container is still changing GitHub. Crashes need operator recovery.
    operation = string(PkgFactory.UUIDs.uuid4())
    data = Dict("repository" => lowercase(plan.repository), "operation" => operation)
    request("acquire", data)
    released = false
    result = try
        f()
    finally
        # Cleanup must not replace either successful GitHub work or its original
        # exception. Never log the transport exception: it can contain secrets.
        try
            request("release", data)
            released = true
        catch
            @warn "Cloudflare repository lock release was not confirmed; operator inspection may be required."
        end
    end
    released ? result : with_warning(result, "repository_lock_release_failed",
        "Creation completed, but releasing the repository lock was not confirmed. Do not repeat creation; ask the operator to inspect the lock.")
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
    # Allow a container clock up to 30 seconds behind the gateway, without
    # accepting tickets after their signed expiration time.
    now < payload["exp"] <= now + 210 || error("Expired ticket")
    payload["sub"] isa String && !isempty(payload["sub"]) || error("Invalid subject")
    payload["github_token"] isa String && !isempty(payload["github_token"]) || error("Missing credential")
    payload
end
end
