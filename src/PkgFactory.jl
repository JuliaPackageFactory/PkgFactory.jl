"""UI-independent planning, creation and recovery of Julia package repositories."""
module PkgFactory

import Base64, Dates, DocStringExtensions, HTTP, JSON3, SHA, Sodium, URIs, UUIDs
import OpenSSH_jll: ssh_keygen

export PackageSpec, PackagePlan, Credential, plan_package, plan_snapshot, restore_plan, create_package,
    package_spec, package_schema, list_templates, repository_status,
    repository_availability, get_repository_owners, device_flow_begin, device_flow_poll,
    PkgFactoryError, InputError, CreationError, GitHubAPIError, GitHubTransport

const GITHUB_API_URL = "https://api.github.com"
const GITHUB_OAUTH_URL = "https://github.com/login"
const GITHUB_API_VERSION = "2022-11-28"
const GITHUB_OAUTH_CLIENT_ID = "Ov23libqpCkC6Z5pSlFG"

include("errors.jl")
include("Verifications.jl")
include("templates.jl")
include("spec.jl")
include("plan.jl")
include("github/transport.jl")
include("github/rest.jl")
include("github/device_flow.jl")
include("github/crypto.jl")
include("status.jl")
include("apply.jl")

end
