# Cloudflare deployment

This directory deploys the existing Julia applications from this monorepo:

- `web/`: Worker Static Assets and a Julia Web container.
- `mcp/`: OAuth 2.1 authorization, Streamable HTTP, and a Julia MCP container.
- The MCP Worker's SQLite-backed `ApplicationState` Durable Object stores exact
  rendered plans, completed results, and repository operation locks shared by both apps.
- Workers KV holds the OAuth library's encrypted grants and browser-bound consent
  transactions. GitHub tokens stay in encrypted OAuth props; they are never MCP
  tool arguments, plan records, or shared operator credentials.

Hosting and authorization-server processing run on Cloudflare. GitHub remains
the upstream identity provider and the destination for generated repositories.
The existing local launchers and Render/Auth0 example remain available separately.

## Prerequisites the account owner supplies

Use this existing project directly. The dashboard's
`npm create cloudflare@latest -- --template=cloudflare/templates/containers-template`
command creates a separate starter project and is not needed here. The first
`wrangler deploy` builds/uploads the image and creates the Container application;
an empty Containers dashboard before that deployment is expected.

1. Enable **Workers Paid** on the Cloudflare account (USD 5/month minimum).
2. Choose the account's `workers.dev` subdomain, or configure custom domains.
3. Install Node.js 22+ and start Docker with Linux container support. Images must
   target `linux/amd64`. A Linux CI runner can build/deploy instead.
4. Register **two GitHub OAuth Apps** at <https://github.com/settings/developers>:

| App | Homepage | Callback | Required settings |
| --- | --- | --- | --- |
| Web | `https://pkgfactory-web.ohnolab.workers.dev` | Same URL | Enable Device Flow; copy Client ID |
| MCP | `https://pkgfactory-mcp.ohnolab.workers.dev` | `https://pkgfactory-mcp.ohnolab.workers.dev/callback` | Copy Client ID and Client Secret |

Use your final hostnames in these settings. The Web app needs no OAuth client
secret. The MCP app requests `repo`, `workflow`, and `read:user`. Each user grants
their own GitHub permissions. Organization policies/SSO may require approval.
No shared GitHub PAT or Auth0 account is needed for this deployment.

## Configure and deploy

Run these commands from `deploy/cloudflare`:

```sh
npm ci
npx wrangler login
npx wrangler whoami
# Only for a different account without the configured OAuth namespace:
npx wrangler kv namespace create OAUTH_KV --config mcp/wrangler.jsonc
```

Update the committed Wrangler files with **non-secret** values:

- Both `MCP_ORIGIN` values: the final MCP HTTPS origin, without a trailing slash.
- Web `PUBLIC_ORIGIN`: the final Web HTTPS origin, without a trailing slash.
- MCP `WEB_ORIGIN`: that same Web origin, used to verify maintenance for recovery.
- MCP `MCP_ALLOWED_ORIGINS`: an array of exact browser client origins allowed to
  call `/mcp` (for example `["http://localhost:6274"]` for a local Inspector).
  The default empty array permits only the MCP site's own origin; clients without
  an `Origin` header remain supported. Do not use wildcards.
- Each `GITHUB_OAUTH_CLIENT_ID`: its respective OAuth App Client ID.
- MCP `kv_namespaces[0].id`: the namespace ID returned above.

The configured hostnames use the existing `ohnolab.workers.dev` subdomain.
The OAuth KV namespace and both GitHub OAuth App Client IDs are configured for
that account. To deploy to another account, create its own KV namespace and
OAuth Apps, then update the namespace ID, both origins and both Client IDs.
For custom domains, add a `routes` entry with `custom_domain: true` to each
configuration, update these origins and GitHub callback settings, and disable
`workers_dev`. Preview URLs are disabled so alternate origins cannot bypass the
configured OAuth audience and browser origin.

Generate **five distinct random secrets**, each at least 32 bytes (for example
64 hexadecimal characters using a password manager). Register them as follows;
only `WEB_STATE_SECRET` has the same value in both Workers:

```sh
npx wrangler secret put MCP_TICKET_SECRET --config mcp/wrangler.jsonc
npx wrangler secret put MCP_STATE_SECRET --config mcp/wrangler.jsonc
npx wrangler secret put WEB_STATE_SECRET --config mcp/wrangler.jsonc
npx wrangler secret put WEB_STATE_SECRET --config web/wrangler.jsonc
npx wrangler secret put WEB_PROXY_SECRET --config web/wrangler.jsonc
npx wrangler secret put STATE_RECOVERY_SECRET --config mcp/wrangler.jsonc
npx wrangler secret put GITHUB_OAUTH_CLIENT_SECRET --config mcp/wrangler.jsonc
```

Wrangler prompts for the value; do not put secrets in command arguments, git,
GitHub issue text, or chat. The keys grant separate permissions:

| Secret | Purpose | Passed to container |
| --- | --- | --- |
| `MCP_TICKET_SECRET` | Sign/verify short-lived MCP tickets | MCP only |
| `MCP_STATE_SECRET` | MCP plan storage and MCP repository locks | MCP only |
| `WEB_STATE_SECRET` | Acquire/release Web repository locks only | Web only |
| `WEB_PROXY_SECRET` | Authenticate Web gateway forwarding | Web only |
| `STATE_RECOVERY_SECRET` | Operator recovery only | Neither |

Web cannot claim MCP plans, release MCP-owned locks, or run recovery with either
of its keys. Keep the recovery key in an operator password manager. Rotating a
container key requires redeploying its application so the container receives the
new value; rotating `WEB_STATE_SECRET` requires updating both Workers and the Web
container.

When upgrading from `INTERNAL_SECRET`, put both apps into maintenance first,
let active operations finish, and stop both containers. Register the new keys,
deploy both applications, verify their health, then leave maintenance mode.
There is no fallback to the old shared key; remove it from both Workers after
migration. Existing plans and locks stay in the same Durable Object. Recover
any old stuck locks before admitting new operations.

```sh
npm test
npm run test:integration
npm run check
npm run deploy:mcp
npm run deploy:web
```

`check` validates and bundles the Workers without deploying or building images.
`deploy:*` builds the images using the **repository root as Docker context**, then
publishes the Worker/container. The MCP deployment must be ready before Web
creation can use its shared operation store. All deployments use the same
checkout, including uncommitted changes if run locally; use a reviewed commit.

The `Cloudflare` GitHub Actions workflow tests Workers and builds both Linux
images on relevant changes. It does not publish them. For unattended deployment,
use Cloudflare account-scoped CI credentials instead of `wrangler login` and
follow Cloudflare's [Containers deployment guide](https://developers.cloudflare.com/containers/guides/deploy-containers/).

## Verify the deployed service

OAuth discovery, dynamic registration, and token endpoints accept browser CORS
requests through the OAuth provider. `/mcp`, including preflights, validates
`MCP_ALLOWED_ORIGINS`; consent and callback routes keep the same-origin policy
and browser-bound CSRF checks. Bearer tokens are still required for MCP calls.

1. Open the Web origin, sign in with GitHub, and check the owner/template list.
2. Connect an OAuth-capable MCP client to `MCP_ORIGIN/mcp`. Discovery supports
   dynamic client registration and Client ID Metadata Documents. Confirm the
   client name/destination on the consent page, then sign in with GitHub.
3. List tools and preview a `minimum` package. Wait more than five idle minutes,
   then execute the saved plan **within its 15-minute lifetime**. The exact files
   and UUID must survive a container restart.
4. Use two GitHub accounts to verify isolation. An account must not execute
   another account's `plan_id`. Repeating a completed plan returns its saved result.
5. Perform one explicitly authorized package creation with each interface, and
   inspect the generated repository and workflow results. These live checks
   change GitHub; automated tests use simulated GitHub responses.

Streamable HTTP uses stateless POST requests and JSON responses. The optional
GET/SSE channel returns 405. No MCP session ID needs to survive a container
restart. Direct cross-origin browser fetches to MCP are refused; OAuth desktop
or server-side MCP clients work without an Origin header. The Web UI uses its
own same-origin API.

`/health` on MCP and `/api/health` on Web check the **gateway**, without waking
Julia. Exercise tool discovery/Web configuration to check container readiness.
The initial request can take longer while Julia loads; container readiness waits
up to 120 seconds. The images use `--compile=min --heap-size-hint=600M` to reduce
Julia's startup compilation and leave memory for native code and subprocesses.
Package caches are built with `JULIA_CPU_TARGET=generic`, so a different CPU on
Cloudflare can reuse them without recompiling at startup. The container profile
first loads the application with `--cpu-target=generic --compiled-modules=strict`
to verify that the shipped caches work without generating replacements.

## Persistence, failures, and recovery

Both apps initially route to one named container each, with `max_instances: 1`
and a five-minute idle timeout. No always-on keepalive is configured. Static Web
requests and MCP OAuth discovery do not start Julia. Sleep and deployments clear
container memory/disk, but not Durable Object storage.

Plans live for 15 minutes, at most 16 retained plans per authenticated principal
and 256 across all users, with a 100 KB snapshot
limit. Successful results remain available for 15 minutes after completion.
Expired inactive plans are cleaned up when a new preview is stored. Failed
plans cannot be retried; preview an explicit resume after inspecting GitHub.
Interrupted running plans remain blocked for operator recovery.

Repository locks apply across Web and MCP and do not expire automatically. This
prevents a slow or disconnected first request from writing concurrently with a
retry. A crash, lost lock-release response, or state-service outage can leave a
lock behind. No request automatically replays GitHub writes.

Cleanup and plan-recording errors never replace a successful creation result or
the original creation error. Successful responses retain the repository URL and
may include `warnings`: `repository_lock_release_failed` means lock release was
not confirmed; `plan_completion_record_failed` means the completed MCP result
was not confirmed in storage. MCP keeps `isError: false`, and Web displays the
warning beside its success result. Do not create again to clear either warning.
Have the operator inspect GitHub and recover only if needed. A lost write response
may mean the state was already saved; otherwise the running plan stays blocked.
State errors such as `plan_expired`, `plan_not_found`, `operation_in_progress`,
`operation_failed`, `capacity_exceeded`, and `repository_busy` retain distinct MCP
codes. Transport or unrecognized state errors use `state_unavailable`.

To recover a stuck operation:

1. Set `MAINTENANCE = "true"` in the `vars` of **both** Wrangler files and deploy
   both Workers with `--containers-rollout=none`. New API requests now return 503.
2. In the Cloudflare dashboard, stop both application containers and verify that
   they have fully stopped. A client timeout alone is not proof that work stopped.
3. Inspect the target GitHub repository. Supply `MCP_ORIGIN` and `STATE_RECOVERY_SECRET`
   through your local environment, then run:

   ```sh
   node scripts/recover.js OWNER/REPO.jl --confirm-containers-stopped
   ```

4. This clears only that repository's lock and marks its interrupted plans failed.
   Remove maintenance mode and redeploy both Workers. Create a new preview with
   `resume: true` if GitHub shows a recoverable PkgFactory repository; otherwise
   resolve the partial state manually. Core recovery never adopts an unrelated repo.

The recovery endpoint requires the operator key and checks MCP maintenance plus
the Web gateway's `/api/health` maintenance response. Container shutdown is still
an operator check: `--confirm-containers-stopped` is an explicit attestation, not
a Cloudflare control-plane verification. Keep both apps in maintenance throughout
recovery; a health response cannot prove that an earlier request stopped running.

Do not delete the `ApplicationState` namespace or change its class/name during
ordinary releases. That would discard plan history and repository exclusion.
Rate limits are applied at the edge and inside Web; they are not a monthly cost
cap. Logs are disabled by default to avoid recording OAuth callback URLs or
credentials. Enable only redacted operational logging if adding observability.

## Cost estimate (rates checked 2026-09-26)

The configuration uses **two `basic` instances** (each 1 GiB RAM,
0.25 vCPU, 4 GB disk). Memory/disk are charged for provisioned capacity while
running; CPU is charged for actual use. Idle containers stop after five minutes.
Cloudflare Containers **do not support swap**. Saving a rendered plan in the
Durable Object allows Julia to shut down completely between visits; restarting
does not require keeping its heap or a swap file alive.

| Item | Included in Workers Paid | Additional usage |
| --- | --- | --- |
| Base plan | Account-wide | USD 5/month |
| Container memory | 25 GiB-hours/month | USD 0.009/GiB-hour |
| Container CPU | 6.25 vCPU-hours/month | USD 0.072/vCPU-hour |
| Container disk | 200 GB-hours/month | USD 0.000252/GB-hour |

For a 30-day month, assuming other projects have not consumed the allowances,
and combined actual CPU use remains within 6.25 vCPU-hours/month:

| Each app's running time per day | Base + container memory/disk | Container Durable Object duration | Estimated monthly total |
| --- | ---: | ---: | ---: |
| 20 minutes | USD 5.00 | USD 0.00 | **USD 5.00** |
| 1 hour | USD 5.33 | USD 0.00 | **USD 5.33** |
| 24 hours, mostly idle | USD 19.14 | USD 3.29 | **USD 22.43** |

Running time includes startup and the five-minute wait before sleep, not just
the seconds spent generating a package. Periodic requests from an MCP client
can keep the container awake; check actual running time after connecting it.
The DO estimate conservatively keeps
each container's 128 MB Durable Object active for its entire running time, with
400,000 GB-seconds included and USD 12.50 per additional million GB-seconds.
The separate plan store adds brief operations; request/storage overages are not
included in this table. Every additional vCPU-hour over 6.25 costs USD 0.072.
At continuous full CPU use, the two basic instances could consume 360 vCPU-hours
in 30 days: about **USD 47.90** including the estimated DO duration, before other
overages. The 24-hour idle estimate is not a busy-service estimate.

The earlier **USD 59.47** figure was the base + memory/disk subtotal for two
4 GiB `standard-1` instances kept running all month. It is not the cost of the
smaller sleeping configuration now shipped.

For light use, Workers, KV, Durable Objects and egress will usually stay within
their included allowances, but this is an estimate, not a cap. Taxes, exchange
rates, domain registration, build overages, other apps on the account, and
unexpected traffic are additional. Local measurements support the basic size;
check cold starts and real concurrency after deployment. Configure billing
notifications in Cloudflare.

Recalculate the base/container subtotal with:

```sh
node scripts/pricing.js 1 1 basic 2
# arguments: running hours per app/day, active vCPU-hours/month, size, app count
node scripts/pricing.js 24 1 basic 2
```

Sources: [Containers pricing](https://developers.cloudflare.com/containers/platform/pricing/),
[Workers and KV pricing](https://developers.cloudflare.com/workers/platform/pricing/),
[Durable Objects pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/),
[no-swap FAQ](https://developers.cloudflare.com/containers/faq/#what-happens-if-i-run-out-of-memory).

## Reproduce the local memory measurement

From the repository root, with Docker Desktop in Linux mode:

```sh
docker build --platform linux/amd64 -f deploy/cloudflare/mcp/Dockerfile -t pkgfactory-mcp:cloudflare .
docker build --platform linux/amd64 -f deploy/cloudflare/web/Dockerfile -t pkgfactory-web:cloudflare .
node deploy/cloudflare/scripts/profile.js mcp
node deploy/cloudflare/scripts/profile.js web
```

The script uses the image's actual Julia command-line flags and enforces
`--memory=1g --memory-swap=1g --cpus=0.25`. Equal memory/swap values disable swap.
Networking is disabled; loopback HTTP remains available. It exercises each
template through the actual private HTTP server, real SSH key generation and
secret encryption, with simulated GitHub responses. MCP plan storage is in
memory for this isolated test; workerd tests separately cover durable claims,
caller isolation, OAuth consent, PKCE, token exchange and refresh.

Measurements on Docker Desktop/Linux amd64, 2026-09-26:

| Runtime | Listening after | Peak process RSS | Peak cgroup memory |
| --- | ---: | ---: | ---: |
| MCP, default Julia compiler (comparison) | 52.1 s | 729.5 MiB | 505.0 MiB |
| MCP, shipped compiler/heap settings | 6.5 s | 485.8 MiB | 260.8 MiB |
| Web, shipped compiler/heap settings | 12.0 s | 448.6 MiB | 229.8 MiB |

Both optimized runs completed all three templates and a four-request burst
without an OOM. RSS and cgroup peaks differ because of shared/mapped pages and
Linux accounting; they are not interchangeable measurements. These are local
smoke measurements, not Cloudflare production latency or a high-concurrency
capacity guarantee. The heap hint is a GC hint, not a hard process memory cap.
Cold image loading, real GitHub latency and concurrent users need live validation.
