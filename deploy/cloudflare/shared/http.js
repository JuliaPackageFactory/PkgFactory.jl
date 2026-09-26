export const json = (data, status = 200) => Response.json(data, {
  status, headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" },
});

export function origin(value) {
  const url = new URL(value);
  if (url.protocol !== "https:" || url.origin !== value || url.username || url.password)
    throw new Error("Configure an HTTPS origin without a trailing slash");
  return value;
}

export async function readBody(request, limit = 65536) {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > limit) {
      await reader.cancel();
      throw new RangeError("Request too large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return bytes;
}

export async function sameSecret(actual, expected) {
  if (typeof expected !== "string" || expected.length < 32) return false;
  const digest = async value => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
  const [a, b] = await Promise.all([digest(actual), digest(expected)]);
  return a.reduce((difference, byte, i) => difference | (byte ^ b[i]), 0) === 0;
}

export async function ticket(secret, props, now = Date.now()) {
  if (typeof secret !== "string" || secret.length < 32 || !props.userId || !props.githubToken)
    throw new Error("Missing gateway credentials");
  const text = JSON.stringify({ aud: "pkgfactory-container", sub: props.userId,
    github_token: props.githubToken, exp: Math.floor(now / 1000) + 180 });
  const payload = btoa(String.fromCharCode(...new TextEncoder().encode(text)));
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload)));
  return payload + "." + [...signature].map(b => b.toString(16).padStart(2, "0")).join("");
}

export function forwardedHeaders(request) {
  const headers = new Headers(request.headers);
  for (const name of [...headers.keys()]) {
    if (name.startsWith("x-pkgfactory-") || name.startsWith("x-forwarded-") ||
        ["cookie", "forwarded", "x-real-ip", "mcp-session-id", "connection", "host", "content-length"].includes(name))
      headers.delete(name);
  }
  return headers;
}

export const escapeHTML = value => String(value).replace(/[&<>"']/g, c => `&#${c.charCodeAt(0)};`);

export async function limited(binding, key) {
  return (await binding.limit({ key })).success;
}
