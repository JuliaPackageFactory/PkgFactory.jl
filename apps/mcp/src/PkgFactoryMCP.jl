module PkgFactoryMCP

import JSON3
import ModelContextProtocol as MCP
import PkgFactory
using UUIDs: uuid4

export build_server, serve_stdio, serve_http, operator_auth, main

include("server.jl")
include("auth.jl")
include("cli.jl")

end
