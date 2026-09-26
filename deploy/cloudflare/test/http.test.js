import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { forwardedHeaders, origin, readBody, sameSecret, ticket } from "../shared/http.js";

test("gateway tickets are signed, short-lived, and keep users separate", async () => {
  const secret = "a".repeat(64);
  const token = await ticket(secret, { userId: "123", githubToken: "test-only" }, 1000000);
  const [payload, signature] = token.split(".");
  assert.equal(signature, createHmac("sha256", secret).update(payload).digest("hex"));
  assert.deepEqual(JSON.parse(Buffer.from(payload, "base64")), {
    aud: "pkgfactory-container", sub: "123", github_token: "test-only", exp: 1180,
  });
  assert.equal(await sameSecret(secret, secret), true);
  assert.equal(await sameSecret("forged", secret), false);
  await assert.rejects(ticket("short", { userId: "123", githubToken: "test" }));
});

test("forwarding removes spoofed identity, IP, session and cookie headers", () => {
  const headers = forwardedHeaders(new Request("https://example.com", { headers: {
    "X-PkgFactory-Proxy": "forged", "X-Real-IP": "spoofed", "X-Forwarded-For": "spoofed",
    Cookie: "private", "Mcp-Session-Id": "another-user", Authorization: "Bearer legitimate",
  } }));
  for (const name of ["x-pkgfactory-proxy", "x-real-ip", "x-forwarded-for", "cookie", "mcp-session-id"])
    assert.equal(headers.has(name), false);
  assert.equal(headers.get("Authorization"), "Bearer legitimate");
});

test("chunked bodies cannot bypass the size limit", async () => {
  const body = new ReadableStream({ start(c) { c.enqueue(new Uint8Array(40000)); c.enqueue(new Uint8Array(40000)); c.close(); } });
  await assert.rejects(readBody(new Request("https://example.com", { method: "POST", body, duplex: "half" })), RangeError);
  assert.throws(() => origin("https://example.com/"));
  assert.throws(() => origin("http://example.com"));
});
