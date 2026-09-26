// Run only after maintenance has stopped both containers. Secrets come from the
// environment; this script never writes or prints them.
const repository = process.argv[2]?.toLowerCase();
if (!/^[a-z0-9-]+\/[a-z0-9_.-]+$/.test(repository || "") ||
    !process.argv.includes("--confirm-containers-stopped")) {
  throw new Error("Usage: node scripts/recover.js OWNER/REPO.jl --confirm-containers-stopped");
}
const { MCP_ORIGIN, INTERNAL_SECRET } = process.env;
if (!MCP_ORIGIN?.startsWith("https://") || !INTERNAL_SECRET || INTERNAL_SECRET.length < 32)
  throw new Error("Set MCP_ORIGIN and INTERNAL_SECRET in the environment");
const result = await fetch(MCP_ORIGIN + "/internal/state", {
  method: "POST", redirect: "error", headers: {
    Authorization: `Bearer ${INTERNAL_SECRET}`, "Content-Type": "application/json",
  }, body: JSON.stringify({ action: "recover", data: { repository, containers_stopped: true } }),
});
if (!result.ok) throw new Error(`Recovery refused (HTTP ${result.status})`);
console.log("Lock cleared. Inspect GitHub, then use a new preview with resume=true if appropriate.");
