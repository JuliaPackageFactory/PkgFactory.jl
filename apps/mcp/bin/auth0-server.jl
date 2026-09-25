# Auth0 deployment for a single configured operator. This deliberately does not
# share one GitHub account with every person who can sign in to the tenant.
using PkgFactoryMCP
import PkgFactory
import ModelContextProtocol as MCP

function required_env(name)
    value = strip(get(ENV, name, ""))
    isempty(value) && error("Set $name before starting the Auth0 server")
    value
end

issuer = required_env("AUTH0_ISSUER") # exact issuer including trailing slash
audience = required_env("MCP_RESOURCE_URL") # e.g. https://service.onrender.com/mcp
subject = required_env("MCP_OPERATOR_SUBJECT") # exact Auth0 sub, not email
backend = PkgFactoryMCP.environment_credential()
auth = PkgFactoryMCP.operator_auth(; issuer, audience, subject)
metadata = MCP.ProtectedResourceMetadata(resource=audience, authorization_servers=[issuer])
resolver = ctx -> begin
    user = ctx.authenticated_user
    !isnothing(user) && user.subject == subject || error("Operator not allowed")
    backend
end
PkgFactoryMCP.serve_http(; auth, resource_metadata=metadata,
    backend_resolver=resolver, enable_create=true, host="0.0.0.0",
    port=parse(Int, get(ENV, "PORT", "8080")))
