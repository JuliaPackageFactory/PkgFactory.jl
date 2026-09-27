export class StateError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const fail = code => { throw new StateError(code); };
const text = (value, max = 200) => typeof value === "string" && value.length > 0 && value.length <= max;
const validPrincipal = value => Array.isArray(value) && value.length === 2 && value.every(v => text(v));
const samePrincipal = (a, b) => validPrincipal(a) && validPrincipal(b) && a.every((v, i) => v === b[i]);

// Run inside one storage transaction. No network I/O or credentials are stored.
export async function stateAction(storage, action, data, now = Date.now()) {
  if (!data || typeof data !== "object") fail("invalid_request");
  if (action === "recover") {
    // Operator-only API. The recovery tool requires both applications to be in
    // maintenance mode and their containers stopped before clearing a lock.
    if (data.containers_stopped !== true || !text(data.repository) ||
        !/^[a-z0-9-]+\/[a-z0-9_.-]+$/.test(data.repository)) fail("invalid_recovery");
    await storage.delete(`lock:${data.repository}`);
    for (const [key, plan] of await storage.list({ prefix: "plan:", limit: 257 })) {
      const spec = plan.snapshot.spec;
      const name = spec.name.endsWith(".jl") ? spec.name : spec.name + ".jl";
      if (plan.status === "running" && `${spec.owner}/${name}`.toLowerCase() === data.repository) {
        plan.status = "failed";
        plan.expires = now + 900000;
        await storage.put(key, plan);
      }
    }
    return { ok: true };
  }
  if (action === "acquire" || action === "release") {
    if (!text(data.repository) || !/^[a-z0-9-]+\/[a-z0-9_.-]+$/.test(data.repository) ||
        !text(data.operation, 100)) fail("invalid_operation");
    const key = `lock:${data.repository}`;
    const lock = await storage.get(key);
    if (action === "acquire") {
      if (lock && lock.operation !== data.operation) fail("repository_busy");
      if (!lock && (await storage.list({ prefix: "lock:", limit: 129 })).size >= 128) fail("capacity_exceeded");
      await storage.put(key, { operation: data.operation, started: now });
    } else {
      if (lock && lock.operation !== data.operation) fail("operation_mismatch");
      await storage.delete(key);
    }
    return { ok: true };
  }
  if (!text(data.id, 100) || !validPrincipal(data.principal)) fail("invalid_plan");
  const key = `plan:${data.id}`;
  let record = await storage.get(key);
  if (action === "plan_put") {
    if (record) fail("plan_exists");
    if (!Number.isFinite(data.ttl) || data.ttl <= 0 || data.ttl > 3600 || data.snapshot?.version !== 1)
      fail("invalid_plan");
    if (new TextEncoder().encode(JSON.stringify(data.snapshot)).length > 100000) fail("plan_too_large");
    const plans = await storage.list({ prefix: "plan:", limit: 257 });
    let retained = 0, owned = 0;
    for (const [oldKey, old] of plans) {
      if (old.status !== "running" && old.expires <= now) await storage.delete(oldKey);
      else {
        retained++;
        if (samePrincipal(old.principal, data.principal)) owned++;
      }
    }
    if (retained >= 256 || owned >= 16) fail("capacity_exceeded");
    record = { principal: data.principal, snapshot: data.snapshot,
      expires: now + data.ttl * 1000, status: "pending" };
    await storage.put(key, record);
    return { ok: true };
  }
  if (!record || !samePrincipal(record.principal, data.principal)) fail("plan_not_found");
  if (action === "plan_claim") {
    if (record.status === "running") fail("operation_in_progress");
    if (record.expires <= now) fail("plan_expired");
    if (record.status === "failed") fail("operation_failed");
    if (record.status === "complete") return { snapshot: record.snapshot, result: record.result };
    if (!text(data.claim, 100)) fail("invalid_claim");
    record.status = "running";
    record.claim = data.claim;
    await storage.put(key, record);
    return { snapshot: record.snapshot };
  }
  if (action === "plan_finish") {
    if (record.status !== "running" || record.claim !== data.claim ||
        !["complete", "failed"].includes(data.status)) fail("invalid_claim");
    if (data.status === "complete" && (!data.result || typeof data.result !== "object")) fail("invalid_result");
    record.status = data.status;
    record.result = data.result;
    // Keep successful results for another 15 minutes, including long operations.
    record.expires = now + 900000;
    await storage.put(key, record);
    return { ok: true };
  }
  fail("unknown_action");
}
