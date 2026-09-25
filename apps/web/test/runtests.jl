using Test, PkgFactoryWeb
import PkgFactory
const WA = PkgFactory
const WU = PkgFactoryWeb
webjson(status, value) = WA.HTTP.Response(status, WA.JSON3.write(value))
webpost(path, body; token="test-token") = WA.HTTP.Request("POST", path,
    ["Content-Type" => "application/json", "Authorization" => "Bearer $token"], WA.JSON3.write(body))

@testset "web UI HTTP routes" begin
    root = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/"),
    )
    @test root.status == 200
    @test occursin("PkgFactory", String(root.body))
    @test occursin("Create repository", String(root.body))
    @test occursin("Generate package template", String(root.body))
    @test occursin("value=\"MyPkg\"", String(root.body))
    @test occursin("workflow, profile", String(root.body))
    @test occursin("PkgFactory recovery marker", String(root.body))
    @test occursin("default-src", PkgFactoryWeb.HTTP.header(
        root,
        "Content-Security-Policy",
    ))

    stylesheet = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/style.css"),
    )
    javascript = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/app.js"),
    )
    @test stylesheet.status == 200
    @test occursin("prefers-color-scheme", String(stylesheet.body))
    @test javascript.status == 200
    @test occursin("connectGitHub", String(javascript.body))
    @test occursin("requiredScopes", String(javascript.body))
    @test occursin("setDefaultAuthor(owners[0])", String(javascript.body))
    @test occursin("checkPackageAvailability", String(javascript.body))
    @test occursin("package-availability", String(root.body))

    logo = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/assets/logo.svg"),
    )
    @test logo.status == 200
    @test PkgFactoryWeb.HTTP.header(logo, "Content-Type") == "image/svg+xml; charset=utf-8"
    @test String(logo.body) == read(joinpath(@__DIR__, "..", "public", "assets", "logo.svg"), String)

    config = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/api/config");
        client_id = "test-client",
    )
    config_body = PkgFactory.JSON3.read(String(config.body), Dict{String,Any})
    @test config.status == 200
    @test config_body["client_id"] == "test-client"
    @test "all-in-one" in config_body["templates"]

    unauthorized = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request("GET", "/api/github/owners"),
    )
    @test unauthorized.status == 401
    @test occursin("authentication is required", String(unauthorized.body))

    availability_requester = function (method, url; headers, body, status_exception)
        @test method == "GET"
        @test endswith(url, "/repos/ohno/MyPackage.jl")
        return PkgFactory.HTTP.Response(
            404,
            PkgFactory.JSON3.write(Dict("message" => "Not Found")),
        )
    end
    availability = PkgFactoryWeb.handle_request(
        PkgFactoryWeb.HTTP.Request(
            "POST",
            "/api/github/repository-availability",
            ["Authorization" => "Bearer token", "Content-Type" => "application/json"],
            PkgFactory.JSON3.write(
                Dict("owner" => "ohno", "package_name" => "MyPackage"),
            ),
        );
        requester = availability_requester,
    )
    availability_body = PkgFactory.JSON3.read(
        String(availability.body),
        Dict{String,Any},
    )
    @test availability.status == 200
    @test availability_body["available"]
    @test availability_body["repository"] == "ohno/MyPackage.jl"
end

@testset "Public Web UI validation and error boundaries" begin
    policy = WU.WebPolicy(public_origin="https://packages.example")
    rejected = (args...; kwargs...) -> error("Network must not be called")
    config = Dict("owner" => "ohno", "package_name" => "MyPackage", "authors" => ["Alice"], "description" => "Example")
    for (key, value) in [("owner", "../elsewhere?x=1"), ("authors", [42]),
        ("authors", fill("Alice", 21)), ("resume", 1), ("description", repeat("a", 2001)), ("extra", "unknown")]
        req = webpost("/api/packages", merge(config, Dict(key => value)))
        result = WU.handle_request(req; policy=WU.WebPolicy(), requester=rejected)
        @test result.status == 400
    end
    req = webpost("/api/oauth/device", Dict())
    push!(req.headers, "Origin" => "https://attacker.example")
    @test WU.handle_request(req; policy, requester=rejected).status == 403
    @test WU.handle_request(WA.HTTP.Request("POST", "/api/oauth/device", [], "{}"); requester=rejected).status == 415
    @test WU.handle_request(webpost("/api/oauth/device", Dict("x" => repeat("a", 70000))); requester=rejected).status == 413
    req = WA.HTTP.Request("GET", "/api/github/owners", ["Authorization" => "Bearer top-secret"])
    result = WU.handle_request(req; requester=(args...; kwargs...) -> error("top-secret backend details"))
    @test result.status == 503
    @test !occursin("top-secret", String(result.body))
    @test WU._error_response(ErrorException("private-key-material")).status == 500
    @test !occursin("private-key-material", String(WU._error_response(ErrorException("private-key-material")).body))
    root = WU.handle_request(WA.HTTP.Request("GET", "/"))
    @test occursin("frame-ancestors 'none'", WA.HTTP.header(root, "Content-Security-Policy"))
    @test WA.HTTP.header(root, "X-Frame-Options") == "DENY"
end

@testset "OAuth rate limits expire without retaining credentials" begin
    clock = Ref(0.0)
    policy = WU.WebPolicy(clock=() -> clock[])
    calls = Ref(0)
    requester = (args...; kwargs...) -> (calls[] += 1; webjson(200, Dict("user_code" => "ABC")))
    for _ in 1:6
        @test WU.handle_request(webpost("/api/oauth/device", Dict()); policy, client_ip="a", requester).status == 200
    end
    response = WU.handle_request(webpost("/api/oauth/device", Dict()); policy, client_ip="a", requester)
    @test response.status == 429
    @test WA.HTTP.header(response, "Retry-After") == "60"
    @test calls[] == 6
    @test WU.handle_request(webpost("/api/oauth/device", Dict()); policy, client_ip="b", requester).status == 200
    clock[] = 61
    @test WU.handle_request(webpost("/api/oauth/device", Dict()); policy, client_ip="a", requester).status == 200
end

@testset "Real HTTP limits and caller isolation" begin
    sockets = WU.Sockets
    listener = sockets.listen(sockets.IPv4("127.0.0.1"), 0)
    port = Int(sockets.getsockname(listener)[2])
    close(listener)
    requester = function(method, url; headers, kwargs...)
        token = only(filter(h -> first(h) == "Authorization", headers))[2]
        login = replace(token, "Bearer " => "")
        return webjson(200, endswith(url, "/user") ? Dict("login" => login, "name" => login) : Any[])
    end
    server = WU.start("127.0.0.1", port; max_body_bytes=64, requester)
    try
        url = "http://127.0.0.1:$port"
        tasks = map(["alice", "bob"]) do login
            @async WA.HTTP.get(url * "/api/github/owners", ["Authorization" => "Bearer $login"]; readtimeout=10)
        end
        for (login, task) in zip(["alice", "bob"], tasks)
            @test WA.JSON3.read(String(fetch(task).body))["owners"][1]["login"] == login
        end
        oversized = WA.HTTP.post(url * "/api/oauth/device", ["Content-Type" => "application/json"], repeat("x", 65);
            status_exception=false, readtimeout=10)
        @test oversized.status == 413
        # No Content-Length: enforce the limit while consuming chunked bodies.
        sock = sockets.connect(sockets.IPv4("127.0.0.1"), port)
        try
            write(sock, "POST /api/oauth/device HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n41\r\n" * repeat("x", 65) * "\r\n0\r\n\r\n")
            @test occursin("413", readline(sock))
        finally
            close(sock)
        end
        origin = WA.HTTP.post(url * "/api/oauth/device",
            ["Content-Type" => "application/json", "Origin" => "https://other.example"], "{}";
            status_exception=false, readtimeout=10)
        @test origin.status == 403
    finally
        close(server)
    end
end

include(joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "github.jl"))
include("creation.jl")
