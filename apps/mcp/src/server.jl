struct ToolError <: Exception
    code::String
    message::String
end
fail(code, message) = throw(ToolError(code, message))

mutable struct PlanRecord
    plan::PkgFactory.PackagePlan
    principal::Tuple{String,String}
    expires::Float64
    status::Symbol
    result::Union{Nothing,Dict{String,Any}}
end

"""Bounded, process-local plan store. Restarting the server invalidates its plans."""
struct PlanStore
    records::Dict{String,PlanRecord}
    mutex::ReentrantLock
    ttl::Float64
    capacity::Int
    clock::Function
end
function PlanStore(; ttl=900.0, capacity=256, clock=time)
    isfinite(ttl) && ttl > 0 || throw(ArgumentError("plan_ttl must be positive and finite"))
    capacity > 0 || throw(ArgumentError("max_plans must be positive"))
    PlanStore(Dict{String,PlanRecord}(), ReentrantLock(), Float64(ttl), capacity, clock)
end
Base.show(io::IO, store::PlanStore) = print(io, "PlanStore(capacity=", store.capacity, ")")

function response(data; error=false)
    MCP.CallToolResult(content=[Dict{String,Any}("type" => "text", "text" => JSON3.write(data))],
        structured_content=data, is_error=error)
end
function guarded(f)
    try
        response(f())
    catch err
        err isa InterruptException && rethrow()
        # HTTP exceptions can contain credentials; return only our own safe errors.
        code, message = err isa ToolError ? (err.code, err.message) :
            err isa PkgFactory.InputError ? ("invalid_configuration", err.message) :
            err isa PkgFactory.CreationError ? ("creation_failed", sprint(showerror, err)) :
            ("internal_error", "The operation failed. Inspect server configuration and try again.")
        response(Dict("code" => code, "message" => message); error=true)
    end
end
function principal(ctx, require_identity)
    user = isnothing(ctx) ? nothing : ctx.authenticated_user
    if isnothing(user)
        require_identity && fail("unauthorized", "Authentication is required.")
        return ("stdio", "local")
    end
    (user.provider, user.subject)
end
function check_keys(args, allowed, required=String[])
    all(k -> k in allowed, keys(args)) || fail("invalid_arguments", "Unknown argument.")
    all(k -> haskey(args, k), required) || fail("invalid_arguments", "A required argument is missing.")
end
function string_arg(args, key; default=nothing, limit=2000)
    value = get(args, key, default)
    value isa AbstractString || fail("invalid_arguments", "$key must be a string.")
    value = strip(String(value))
    0 < length(value) <= limit || fail("invalid_arguments", "$key has an invalid length.")
    value
end
function package_config(args)
    PkgFactory.package_spec(args)
end
function preview_package(store, args, who)
    config = package_config(args)
    plan = try
        PkgFactory.plan_package(config)
    catch err
        # preview is offline and has no credentials; its validation message helps
        # the caller correct the package name without exposing a backend error.
        fail("invalid_configuration", err isa PkgFactory.InputError ? err.message : "PkgFactory rejected the configuration.")
    end
    id = string(uuid4())
    lock(store.mutex) do
        now = store.clock()
        filter!(pair -> pair.second.status == :running || pair.second.expires > now, store.records)
        length(store.records) < store.capacity || fail("capacity_exceeded", "Plan storage is full. Try again after plans expire.")
        store.records[id] = PlanRecord(plan, who, now + store.ttl, :pending, nothing)
    end
    Dict{String,Any}("plan_id" => id, "expires_in_seconds" => store.ttl,
        "repository" => plan.repository, "template" => config.template,
        "visibility" => config.visibility, "authors" => collect(config.authors),
        "description" => config.description, "files" => copy(plan.files),
        "operation" => config.resume ? "resume" : "create", "changes_made" => false)
end
function create_package(store, args, who, ctx, backend_resolver, creator)
    check_keys(args, ["plan_id"], ["plan_id"])
    id = string_arg(args, "plan_id"; limit=100)
    record, cached = lock(store.mutex) do
        record = get(store.records, id, nothing)
        (isnothing(record) || record.principal != who) && fail("plan_not_found", "Plan not found. Call preview_package first.")
        record.status == :running && fail("operation_in_progress", "This plan is already being executed.")
        record.expires > store.clock() || fail("plan_expired", "Plan expired. Call preview_package again.")
        record.status == :failed && fail("operation_failed", "A previous attempt failed and may have changed GitHub. Inspect the repository before previewing a resume operation.")
        record.status == :complete && return (record, deepcopy(record.result))
        record.status = :running
        (record, nothing)
    end
    isnothing(cached) || return cached
    result = try
        backend = backend_resolver(ctx)
        backend isa PkgFactory.Credential || fail("authentication_required", "Connect a GitHub account on the server.")
        raw = creator(record.plan; backend=backend)
        merge(Dict{String,Any}(raw), Dict("plan_id" => id))
    catch err
        lock(store.mutex) do
            record.status = :failed
        end
        err isa InterruptException && rethrow()
        err isa PkgFactory.InputError && rethrow()
        err isa PkgFactory.CreationError && rethrow()
        fail("creation_failed", "Creation failed and may have changed GitHub. Check server-side GitHub authentication and the repository, then preview an explicit resume if needed.")
    end
    lock(store.mutex) do
        record.result = result
        record.status = :complete
    end
    deepcopy(result)
end
config_schema() = PkgFactory.package_schema()

"""
    build_server(; backend_resolver, enable_create=true, require_identity=false,
                   plan_ttl=900, max_plans=256)

Construct a server without opening a transport. `backend_resolver(ctx)` returns a
PkgFactory.Credential for the caller. The default reads GITHUB_TOKEN / GH_TOKEN
when a stdio client requests creation. Plans are bounded and process-local.
"""
function build_server(; backend_resolver=ctx -> environment_credential(), enable_create=true,
    require_identity=false, plan_ttl=900.0, max_plans=256, clock=time,
    creator=(plan; backend) -> PkgFactory.create_package(backend, plan))
    store = PlanStore(; ttl=plan_ttl, capacity=max_plans, clock=clock)
    read_annotations = Dict{String,Any}("readOnlyHint" => true, "openWorldHint" => false)
    tools = MCP.MCPTool[
        MCP.MCPTool(name="list_templates", description="List available PkgFactory templates. No GitHub access or changes.",
            input_schema=Dict("type" => "object", "properties" => Dict(), "additionalProperties" => false),
            annotations=read_annotations, handler=(args, ctx) -> guarded() do
                principal(ctx, require_identity)
                check_keys(args, String[])
                Dict("templates" => PkgFactory.Templates.list_templates())
            end),
        MCP.MCPTool(name="preview_package", description="Validate package settings and return a saved plan with the repository, visibility, and file list. Does not contact GitHub. Present the plan to the user before executing it.",
            input_schema=config_schema(), annotations=read_annotations,
            handler=(args, ctx) -> guarded() do
                preview_package(store, args, principal(ctx, require_identity))
            end)]
    if enable_create
        push!(tools, MCP.MCPTool(name="create_package",
            description="Execute an authorized preview plan. Creates or resumes a GitHub repository and commits template files; non-minimum templates also configure Pages and documentation keys. Use only when the user authorized the displayed plan. Retry with the same plan_id to retrieve a completed result.",
            input_schema=Dict("type" => "object", "properties" => Dict("plan_id" => Dict("type" => "string")),
                "required" => ["plan_id"], "additionalProperties" => false),
            annotations=Dict{String,Any}("readOnlyHint" => false, "destructiveHint" => true,
                "idempotentHint" => false, "openWorldHint" => true),
            handler=(args, ctx) -> guarded() do
                create_package(store, args, principal(ctx, require_identity), ctx, backend_resolver, creator)
            end))
    end
    MCP.mcp_server(name="pkgfactory", version=string(pkgversion(@__MODULE__)),
        description="Create Julia packages with PkgFactory. Preview, then execute the authorized plan.", tools=tools)
end

"""Start a local stdio server. Logs use stderr; stdout carries MCP messages."""
serve_stdio(; kwargs...) = MCP.start!(build_server(; kwargs...))

"""
    serve_http(; auth, backend_resolver=nothing, enable_create=false, host="127.0.0.1",
                 port=8080, resource_metadata=nothing, kwargs...)

Serve Streamable HTTP at /mcp behind a trusted HTTPS proxy. Enabled MCP auth is
required. Creation requires an explicit backend resolver; HTTP never implicitly
uses a shared GITHUB_TOKEN. Supply OAuth metadata for browser-based clients.
"""
function serve_http(; auth=nothing, backend_resolver=nothing, enable_create=false,
    host="127.0.0.1", port=8080, resource_metadata=nothing, allowed_origins=String[], kwargs...)
    auth isa MCP.AuthMiddleware && auth.enabled || throw(ArgumentError("Enabled HTTP authentication is required"))
    enable_create && isnothing(backend_resolver) && throw(ArgumentError("HTTP creation requires an explicit backend_resolver"))
    1 <= port <= 65535 || throw(ArgumentError("port must be between 1 and 65535"))
    server = build_server(; backend_resolver, enable_create, require_identity=true, kwargs...)
    transport = MCP.HttpTransport(; host=String(host), port=Int(port), endpoint="/mcp",
        auth, resource_metadata, allowed_origins)
    MCP.connect(transport)
    MCP.start!(server; transport)
end
