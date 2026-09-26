include(joinpath(@__DIR__, "..", "..", "shared", "Cloudflare.jl"))

"""Plan storage backed by the Cloudflare application's Durable Object."""
struct CloudflarePlanStore
    request::Function
    ttl::Float64
end
CloudflarePlanStore(client::Cloudflare.StateClient; ttl=900.0) =
    CloudflarePlanStore((action, data) -> Cloudflare.state_request(client, action, data), Float64(ttl))

struct CloudflarePlanRecord
    plan::PkgFactory.PackagePlan
    principal::Tuple{String,String}
    claim::String
end

function save_plan!(store::CloudflarePlanStore, id, plan, who)
    store.request("plan_put", Dict("id" => id, "principal" => collect(who),
        "snapshot" => PkgFactory.plan_snapshot(plan), "ttl" => store.ttl))
end
function claim_plan!(store::CloudflarePlanStore, id, who)
    claim = string(uuid4())
    saved = store.request("plan_claim", Dict("id" => id, "principal" => collect(who), "claim" => claim))
    record = CloudflarePlanRecord(PkgFactory.restore_plan(saved["snapshot"]), who, claim)
    (record, get(saved, "result", nothing))
end
function finish_plan!(store::CloudflarePlanStore, id, record, status, result=nothing)
    store.request("plan_finish", Dict("id" => id, "principal" => collect(record.principal),
        "claim" => record.claim, "status" => String(status), "result" => result))
end

function cloudflare_server(client; plan_store=CloudflarePlanStore(client),
    creator=(plan; backend) -> Cloudflare.with_repository_operation(client, plan) do
        PkgFactory.create_package(backend, plan)
    end)
    build_server(; plan_store, require_identity=true, creator,
        backend_resolver=ctx -> PkgFactory.Credential(ctx.authenticated_user.claims["github_token"]))
end

function cloudflare_request(server, request, secret)
    HTTP = PkgFactory.HTTP
    path = split(String(request.target), '?'; limit=2)[1]
    path == "/health" && request.method == "GET" && return HTTP.Response(200, "ok")
    path == "/mcp" || return HTTP.Response(404)
    request.method == "POST" || return HTTP.Response(405, ["Allow" => "POST"])
    authorization = HTTP.header(request, "Authorization", "")
    payload = try
        startswith(authorization, "Bearer ") || error("Missing ticket")
        Cloudflare.verify_ticket(authorization[8:end], secret)
    catch
        return HTTP.Response(401)
    end
    startswith(HTTP.header(request, "Content-Type", ""), "application/json") || return HTTP.Response(415)
    version = HTTP.header(request, "MCP-Protocol-Version", "2025-03-26")
    MCP.is_supported_version(version) || return HTTP.Response(400, "Unsupported MCP protocol version")
    # This deployment uses stateless Streamable HTTP with JSON replies. Every
    # request has separate protocol/auth state; no shared SSE broadcast channel.
    state = MCP.ServerState()
    state.protocol_version = String(version)
    user = MCP.AuthenticatedUser(subject=payload["sub"], provider="github", claims=payload)
    reply = MCP.process_message(server, state, String(request.body); authenticated_user=user)
    isnothing(reply) && return HTTP.Response(202)
    HTTP.Response(200, ["Content-Type" => "application/json", "Cache-Control" => "no-store",
        "MCP-Protocol-Version" => state.protocol_version], reply)
end

"""Serve the private Container endpoint behind the authenticated Cloudflare Worker."""
function serve_cloudflare(; origin=get(ENV, "MCP_ORIGIN", ""),
    ticket_secret=get(ENV, "MCP_TICKET_SECRET", ""), state_secret=get(ENV, "MCP_STATE_SECRET", ""),
    host="0.0.0.0", port=8080, server=nothing)
    ncodeunits(ticket_secret) >= 32 || throw(ArgumentError("MCP_TICKET_SECRET must contain at least 32 bytes"))
    client = Cloudflare.StateClient(origin, state_secret)
    server = isnothing(server) ? cloudflare_server(client) : server
    HTTP = PkgFactory.HTTP
    HTTP.serve!(String(host), Int(port); stream=true, readtimeout=60, max_connections=128) do stream
        request = stream.message
        response = try
            body = UInt8[]
            while !eof(stream)
                append!(body, read(stream, min(8192, 65537 - length(body))))
                length(body) > 65536 && break
            end
            if length(body) > 65536
                HTTP.Response(413)
            else
                request.body = body
                cloudflare_request(server, request, ticket_secret)
            end
        catch err
            err isa InterruptException && rethrow()
            HTTP.Response(500, "The request failed. Check repository status before retrying.")
        end
        # HTTP.jl may print a request after a connection error; remove credentials.
        request.body = UInt8[]
        empty!(request.headers)
        request.target = "/redacted"
        request.response = response
        response.request = request
        HTTP.setheader(stream, "Connection" => "close")
        try
            HTTP.startwrite(stream)
            write(stream, response.body)
            HTTP.closewrite(stream)
        catch err
            err isa InterruptException && rethrow()
        finally
            close(stream)
        end
    end
end
