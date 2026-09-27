# Deployment Overview

Choose a deployment guide for the interface and hosting environment you operate:

| Guide | Target |
| --- | --- |
| [Standalone Web](web.md) | One Julia Web server behind your HTTPS reverse proxy |
| [Cloudflare](cloudflare.md) | Web and MCP Workers with Julia Containers |
| [Render](render.md) | An MCP service deployed with a Docker Blueprint and Auth0 |

For local use, start with the [Quick Start](../index.md#Quick-Start),
[terminal interface](../user.md#Terminal-interface), or [MCP Guide](../mcp.md).
The [repository layout](../developer.md#Repository-layout) identifies the
application code, launchers, and provider configuration files.

## Acceptance checks

Before admitting users, exercise the chosen HTTPS interface and authentication
flow with authorized test accounts. Check concurrent users, revoked credentials,
GitHub throttling, lost responses, and a restart during creation. Inspect the
created repositories and their workflows, and follow the
[recovery procedure](../user.md#Resuming-an-interrupted-setup) for interrupted work.

Measure cold starts, request latency, and peak memory under expected load before
choosing resource limits. The [local tests](../developer.md#Local-development-and-tests)
use simulated GitHub responses; they cannot establish that a deployed service's
credentials, domains, or upstream permissions are configured correctly.
