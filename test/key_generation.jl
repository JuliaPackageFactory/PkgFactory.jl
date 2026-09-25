# Run in a separate Julia process with an empty PATH, including during import.
using PkgFactory
using Test
using Logging

@testset "Bundled OpenSSH: private, concurrent, PATH-independent" begin
    @test isnothing(Sys.which("ssh-keygen"))
    original = pwd()
    original_path = ENV["PATH"]
    original_files = readdir()
    pairs = Tuple{String,String}[]
    logger = Test.TestLogger(min_level=Logging.Debug)
    mktempdir() do directory
        out, err = joinpath(directory, "stdout"), joinpath(directory, "stderr")
        redirect_stdio(stdout=out, stderr=err) do
            Logging.with_logger(logger) do
                # @sync waits for both calls even if one fails.
                tasks = Task[]
                @sync for _ in 1:2
                    push!(tasks, @async PkgFactory._generate_keys())
                end
                append!(pairs, fetch.(tasks))
            end
        end
        # Assert booleans so a regression cannot print captured private material.
        quiet_stdout = isempty(read(out))
        quiet_stderr = isempty(read(err))
        @test quiet_stdout
        @test quiet_stderr
    end
    quiet_logs = isempty(logger.logs)
    @test quiet_logs
    @test pwd() == original
    @test ENV["PATH"] == original_path
    @test readdir() == original_files
    @test pairs[1][1] != pairs[2][1]
    for (public_key, encoded_private_key) in pairs
        @test startswith(public_key, "ssh-rsa ")
        @test endswith(public_key, " Documenter")
        private_key = PkgFactory.Base64.base64decode(encoded_private_key)
        valid_private_key = occursin("PRIVATE KEY", String(copy(private_key)))
        @test valid_private_key
        mktempdir() do directory
            file = joinpath(directory, "key")
            write(file, private_key)
            if Sys.iswindows()
                # Recreating the private file loses ssh-keygen's restrictive ACL.
                # These Windows utilities are addressed without consulting PATH.
                system32 = joinpath(ENV["SYSTEMROOT"], "System32")
                owner = readchomp(`$(joinpath(system32, "whoami.exe"))`)
                grant = owner * ":(F)"
                run(pipeline(`$(joinpath(system32, "icacls.exe")) $file /inheritance:r /grant:r $grant`;
                    stdout=devnull, stderr=devnull))
            else
                chmod(file, 0o600)
            end
            # Verify with the artifact too, without a system OpenSSH installation.
            derived = read(`$(PkgFactory.ssh_keygen()) -y -P "" -f $file`, String)
            @test split(derived)[2] == split(public_key)[2]
            fingerprint = read(`$(PkgFactory.ssh_keygen()) -l -f $file`, String)
            @test startswith(fingerprint, "4096 ")
        end
    end
end
