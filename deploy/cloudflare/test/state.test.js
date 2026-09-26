import test from "node:test";
import assert from "node:assert/strict";
import { stateAction } from "../shared/state.js";

class Storage {
  constructor(data = new Map()) { this.data = data; }
  async get(key) { return structuredClone(this.data.get(key)); }
  async put(key, value) { this.data.set(key, structuredClone(value)); }
  async delete(key) { return this.data.delete(key); }
  async list({ prefix, limit }) {
    return new Map([...this.data].filter(([key]) => key.startsWith(prefix)).slice(0, limit).map(([k, v]) => [k, structuredClone(v)]));
  }
}
const principal = ["github", "123"];
const snapshot = { version: 1, spec: { owner: "Alice", name: "Example" }, files: { "Project.toml": 'uuid = "saved-uuid"' } };
const put = (s, id = "plan", now = 0) => stateAction(s, "plan_put", { id, principal, snapshot, ttl: 900 }, now);
const claim = { id: "plan", principal, claim: "attempt" };

test("a restart preserves the exact preview and cached result; another user cannot claim it", async () => {
  const first = new Storage();
  await put(first);
  const restarted = new Storage(first.data);
  await assert.rejects(stateAction(restarted, "plan_claim", { ...claim, principal: ["github", "456"] }, 1), /plan_not_found/);
  assert.deepEqual((await stateAction(restarted, "plan_claim", claim, 1)).snapshot, snapshot);
  await assert.rejects(stateAction(restarted, "plan_claim", claim, 2), /operation_in_progress/);
  await assert.rejects(stateAction(restarted, "plan_finish", { ...claim, claim: "other", status: "complete", result: {} }, 3), /invalid_claim/);
  await stateAction(restarted, "plan_finish", { ...claim, status: "complete", result: { url: "https://github.com/Alice/Example.jl" } }, 3);
  const cached = await stateAction(new Storage(first.data), "plan_claim", claim, 4);
  assert.equal(cached.result.url, "https://github.com/Alice/Example.jl");
});

test("expired/failed plans and bounded capacity fail without executing again", async () => {
  const s = new Storage();
  await put(s);
  await assert.rejects(stateAction(s, "plan_claim", claim, 900001), /plan_expired/);
  await put(s, "replacement", 900002);
  assert.equal(s.data.has("plan:plan"), false);
  await stateAction(s, "plan_claim", { ...claim, id: "replacement" }, 900003);
  await stateAction(s, "plan_finish", { ...claim, id: "replacement", status: "failed" }, 900004);
  await assert.rejects(stateAction(s, "plan_claim", { ...claim, id: "replacement" }, 900005), /operation_failed/);
  for (let i = 0; i < 255; i++) await put(s, `p${i}`, 900006);
  await assert.rejects(put(s, "overflow", 900007), /capacity_exceeded/);
});

test("Web and MCP exclusion survives restarts and does not expire under a live writer", async () => {
  const s = new Storage();
  const web = { repository: "alice/example.jl", operation: "web-request" };
  await stateAction(s, "acquire", web, 0);
  const next = new Storage(s.data);
  await assert.rejects(stateAction(next, "acquire", { ...web, operation: "mcp-request" }, 86400000), /repository_busy/);
  await assert.rejects(stateAction(next, "release", { ...web, operation: "mcp-request" }), /operation_mismatch/);
  await stateAction(next, "release", web);
  await stateAction(next, "acquire", { ...web, operation: "mcp-request" });
});

test("operator recovery invalidates interrupted plans and unlocks only the selected repository", async () => {
  const s = new Storage();
  await put(s);
  await stateAction(s, "plan_claim", claim, 1);
  await stateAction(s, "acquire", { repository: "alice/example.jl", operation: "lost" });
  await stateAction(s, "acquire", { repository: "alice/other.jl", operation: "live" });
  await assert.rejects(stateAction(s, "recover", { repository: "alice/example.jl" }), /invalid_recovery/);
  await stateAction(s, "recover", { repository: "alice/example.jl", containers_stopped: true }, 2);
  await assert.rejects(stateAction(s, "plan_claim", claim, 3), /operation_failed/);
  assert.equal(s.data.has("lock:alice/example.jl"), false);
  assert.equal(s.data.has("lock:alice/other.jl"), true);
});
