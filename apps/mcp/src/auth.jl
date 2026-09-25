function environment_credential()
    PkgFactory.Credential(get(ENV, "GITHUB_TOKEN", get(ENV, "GH_TOKEN", ""));
        codecov_token=get(ENV, "CODECOV_TOKEN", ""))
end

struct SubjectValidator{V<:MCP.TokenValidator} <: MCP.TokenValidator
    delegate::V
    subject::String
end
function MCP.validate_token(validator::SubjectValidator, token::AbstractString, config::MCP.OAuthConfig)
    result = MCP.validate_token(validator.delegate, token, config)
    result.success || return result
    result.user.subject == validator.subject || return MCP.AuthResult("Operator not allowed", :insufficient_scope)
    result
end

"""
    operator_auth(; issuer, audience, subject)

Create OAuth authentication for one exact subject, using the issuer's JWKS.
Suitable for the single-operator Auth0 deployment. MCP and GitHub tokens remain
separate. The issuer must match the token exactly, including any trailing slash.
"""
function operator_auth(; issuer::String, audience::String, subject::String,
    validator=MCP.JWKSValidator(rstrip(issuer, '/') * "/.well-known/jwks.json"))
    startswith(issuer, "https://") || throw(ArgumentError("issuer must use HTTPS"))
    startswith(audience, "https://") || throw(ArgumentError("audience must use HTTPS"))
    isempty(strip(subject)) && throw(ArgumentError("subject must not be empty"))
    MCP.create_auth_middleware(MCP.OAuthConfig(; issuer, audience),
        validator=SubjectValidator(validator, subject))
end
