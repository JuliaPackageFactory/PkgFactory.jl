# Standalone Web

## One server behind HTTPS

Prepare the checkout and Web dependencies using the [Quick Start](../index.md#Quick-Start).
Run `julia --project=apps/web --startup-file=no` from the repository root for the
Julia commands below. This deployment runs one Julia process behind an HTTPS
reverse proxy. Keep the Julia port private. For the login flow and token
handling, see [Authentication Design](../authentication-design.md#CLI-and-Web-UI:-Device-Flow).
Set `PUBLIC_ORIGIN` to the exact browser origin (scheme and host, with a port if
nonstandard), and use a dedicated GitHub OAuth application's client ID with
device flow enabled:

```sh
export PUBLIC_ORIGIN=https://packages.example.com
export GITHUB_OAUTH_CLIENT_ID=YOUR_CLIENT_ID
```

```julia
using PkgFactoryWeb
import PkgFactory
PkgFactoryWeb.start("127.0.0.1", 8000;
    trusted_proxies=["127.0.0.1", "::1"],
    requester=PkgFactory.GitHubTransport(connect_timeout=10, read_timeout=30))
```

For a Caddy proxy on the same host:

```caddyfile
packages.example.com {
    reverse_proxy 127.0.0.1:8000 {
        header_up X-Real-IP {remote_host}
    }
}
```

Only list immediate proxies you control in `trusted_proxies`. They must overwrite
`X-Real-IP`; client-supplied forwarding headers are otherwise ignored. With a
container network, use the actual proxy address and bind the application only
within that private network. Without trusted proxy configuration, requests share
the proxy's IP-based allowance.

The application limits request bodies to 64 KiB, including chunked uploads, and
limits active connections to 128 and concurrent repository operations to eight.
It accepts JSON objects for POST endpoints.
Origin headers must match `PUBLIC_ORIGIN`; API clients without Origin still need
GitHub authorization for repository operations. CSP and X-Frame-Options prevent
embedding the UI on other sites.

The following fixed-window limits apply per 60 seconds:

| Scope | Limit |
| --- | ---: |
| API requests per client IP (excluding health checks) | 120 |
| OAuth starts per client IP | 6 |
| OAuth polls per client IP | 60 |
| Creation attempts per token fingerprint | 5 |

Rate-limit responses use HTTP 429. The in-memory counters are bounded and reset
on restart. Deploy a single process: neither counters nor repository exclusion
coordinate across replicas. An external operation store/lock and distributed
rate limiting are required before scaling out. These controls bound individual
clients; use the hosting provider's network protections for distributed traffic.

GitHub calls have connect/read timeouts and do not automatically retry writes or
follow redirects. A browser timeout does not cancel an operation already accepted
by the server. Request logs contain only a generated request ID, a known route,
HTTP status and duration. Do not enable proxy logging of Authorization headers,
request bodies or OAuth response bodies. `/api/health` is a liveness endpoint,
not a test of GitHub availability.

## Repository status

`POST /api/github/repository-status` takes `owner` and `package_name` plus the
caller's GitHub Bearer token. Its states and the steps for continuing an
interrupted creation are documented in
[Resuming an interrupted setup](../user.md#Resuming-an-interrupted-setup).

Complete the [deployment acceptance checks](index.md#Acceptance-checks) before
opening this service to users.
