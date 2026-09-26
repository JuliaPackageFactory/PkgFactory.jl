using PkgFactoryWeb
import PkgFactory
include(joinpath(@__DIR__, "..", "..", "shared", "Cloudflare.jl"))
client = Cloudflare.StateClient(ENV["MCP_ORIGIN"], ENV["INTERNAL_SECRET"])
creator = (credential, plan; kwargs...) -> Cloudflare.with_repository_operation(client, plan) do
    PkgFactory.create_package(credential, plan; kwargs...)
end
wait(PkgFactoryWeb.start("0.0.0.0", 8080; creator, proxy_token=ENV["INTERNAL_SECRET"],
    requester=PkgFactory.GitHubTransport(connect_timeout=10, read_timeout=30)))
