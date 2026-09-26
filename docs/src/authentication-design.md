# Authentication Design

Use `gh` for the planned Local CLI and Local Web UI, and OAuth + PKCE for the planned Online Web UI. **Current** refers to committed code on GitHub; **Planned** means not yet adopted; **-** means not selected. The local OAuth prototype is not adopted.

| Method | Pros | Cons | Decision |
| :--- | :--- | :--- | :--- |
| GitHub CLI (`gh`) | No manual copying; no authentication server | Requires authenticated `gh`; shared login lacks user isolation | Planned: Local CLI, Local Web UI |
| OAuth + PKCE (local callback) | No manual copying | Bundled secret is public; callback restrictions | - |
| OAuth + PKCE (HTTPS callback) | No manual copying; per-user login | Requires authentication server and secret management | Planned: Online Web UI |
| Device Flow | No client secret or callback | Requires manual copying | Current: Local CLI, Local Web UI ([a61ac52](https://github.com/JuliaPackageFactory/PkgFactory.jl/commit/a61ac5222353efa447776348f3ac98498a87ff4b)) |
| Personal Access Token (PAT) | No callback; supports automation | Requires manual copying and token management | Current: Local CLI, Local MCP ([a61ac52](https://github.com/JuliaPackageFactory/PkgFactory.jl/commit/a61ac5222353efa447776348f3ac98498a87ff4b)) |

“Authentication server” means a server run by the operator. “Manual copying” refers to app authentication codes or tokens, excluding GitHub login and MFA. Commit links point to the latest verified GitHub `main` snapshot containing each implementation, checked on 2026-09-26.
