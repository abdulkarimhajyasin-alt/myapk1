import assert from "node:assert/strict";

export function localOnlyFetch(api: string, transport: typeof fetch = fetch): typeof fetch {
  const endpoint = new URL(api);
  assert.equal(endpoint.protocol, "http:");
  assert.ok(["127.0.0.1", "localhost", "[::1]"].includes(endpoint.hostname));
  assert.ok(["54321", "55321", "56321"].includes(endpoint.port));
  assert.equal(endpoint.username + endpoint.password, "");
  return async (input, init) => {
    const target = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
    assert.equal(target.origin, endpoint.origin, "External test traffic forbidden");
    assert.equal(target.username + target.password, "");
    return transport(input, { ...init, redirect: "error" });
  };
}
