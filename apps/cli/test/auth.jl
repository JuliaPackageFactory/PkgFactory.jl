@testset "notebook GitHub device login" begin
    polls = Ref(0)
    requester = function (method, url; headers, body, status_exception)
        response = if endswith(url, "/device/code")
            Dict(
                "device_code" => "device-code",
                "user_code" => "ABCD-1234",
                "verification_uri" => "https://github.com/login/device",
                "expires_in" => 900,
                "interval" => 1,
            )
        else
            polls[] += 1
            polls[] == 1 ? Dict("error" => "authorization_pending") : Dict(
                "access_token" => "oauth-secret-token",
                "token_type" => "bearer",
                "scope" => "read:user,repo,workflow",
            )
        end
        return PkgFactory.HTTP.Response(
            200,
            PkgFactory.JSON3.write(response),
        )
    end
    delays = Int[]
    output = IOBuffer()
    backend = PkgFactoryCLI.github_device_login(
        requester = requester,
        sleeper = delay -> push!(delays, delay),
        output = output,
    )
    login_text = String(take!(output))
    @test backend isa PkgFactory.GitHubAPI
    @test backend.access_token == "oauth-secret-token"
    @test delays == [5, 5]
    @test occursin("ABCD-1234", login_text)
    @test occursin("authorization completed", login_text)
    @test !occursin("oauth-secret-token", login_text)

    missing_scope_requester = function (method, url; headers, body, status_exception)
        response = endswith(url, "/device/code") ? Dict(
            "device_code" => "device-code",
            "user_code" => "ABCD-1234",
            "verification_uri" => "https://github.com/login/device",
            "expires_in" => 900,
            "interval" => 5,
        ) : Dict(
            "access_token" => "oauth-secret-token",
            "scope" => "read:user,repo",
        )
        return PkgFactory.HTTP.Response(
            200,
            PkgFactory.JSON3.write(response),
        )
    end
    @test_throws ErrorException PkgFactoryCLI.github_device_login(
        requester = missing_scope_requester,
        sleeper = _ -> nothing,
        output = IOBuffer(),
    )
end
