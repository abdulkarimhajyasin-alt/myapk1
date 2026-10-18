import test from "node:test";
import assert from "node:assert/strict";
import { createPasswordDigest, verifyPasswordDigest } from "../functions/_shared/password_security.ts";

type Handler = (request: Request) => Promise<Response>;
const handlers: Handler[] = [];
Object.defineProperty(globalThis, "Deno", { value: {
  env: { get: (name: string) => ({ SUPABASE_URL: "http://127.0.0.1:59999", SUPABASE_ANON_KEY: "fixture-anon", SUPABASE_SERVICE_ROLE_KEY: "fixture-service" })[name] },
  serve: (handler: Handler) => handlers.push(handler),
} });
await import("../functions/maskan-password/index.ts");
await import("../functions/maskan-delete-account/index.ts");
const [passwordHandler, deletionHandler] = handlers;
const request = (body: unknown, headers: Record<string, string> = {}) => new Request("http://127.0.0.1:59999/test", {
  method: "POST", headers: { authorization: "Bearer fixture-session", "content-type": "application/json", ...headers }, body: JSON.stringify(body),
});
const response = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status });
const originalFetch = globalThis.fetch;
const originalError = console.error;

test.afterEach(() => { globalThis.fetch = originalFetch; console.error = originalError; });

test("password quota is stable across spoofed IP headers and normalized names", async () => {
  const keys: string[] = [];
  globalThis.fetch = async (input, init) => {
    const path = String(input);
    if (path.endsWith("maskan_password_rate_limit_check")) {
      keys.push(JSON.parse(String(init?.body)).p_key_hash);
      return response([{ allowed: true }]);
    }
    if (path.endsWith("maskan_password_lookup_member")) return response([]);
    if (path.endsWith("maskan_password_rate_limit_failure")) return response(null);
    throw new Error("Unexpected test endpoint");
  };
  for (const ip of ["1.1.1.1", "9.9.9.9"]) {
    const result = await passwordHandler(request({ action: "verify_member", memberPassword: "synthetic-password", networkName: ip === "1.1.1.1" ? "Test  Group" : "test group", memberName: "Test" }, { "x-forwarded-for": ip, "cf-connecting-ip": ip }));
    assert.equal((await result.json()).code, "invalid_credentials");
  }
  assert.equal(keys.length, 2);
  assert.equal(keys[0], keys[1]);
});

test("malformed request errors cannot leak request fragments into logs", async () => {
  const logs: unknown[] = [];
  console.error = (...args) => { logs.push(args); };
  const result = await passwordHandler(new Request("http://127.0.0.1:59999/test", { method: "POST", body: '{"password":"SENSITIVE_TEST_VALUE" broken' }));
  assert.equal((await result.json()).ok, false);
  assert.ok(!JSON.stringify(logs).includes("SENSITIVE_TEST_VALUE"));
  assert.deepEqual(logs, [["maskan-password failure: operation_failed"]]);
});

test("modern password hashing verifies correctly and rejects malformed credentials", async () => {
  const digest = await createPasswordDigest("synthetic-password");
  assert.equal(await verifyPasswordDigest("synthetic-password", digest), true);
  assert.equal(await verifyPasswordDigest("incorrect", digest), false);
  assert.equal(await verifyPasswordDigest("synthetic-password", digest.replace("i=600000", "i=1")), false);
});

test("deletion ignores mutable metadata, reauthenticates, then revokes sessions before Auth deletion", async () => {
  const memberId = "10000000-0000-4000-8000-000000000001";
  const digest = await createPasswordDigest("synthetic-password");
  const calls: string[] = [];
  globalThis.fetch = async (input) => {
    const path = new URL(String(input)).pathname;
    calls.push(path);
    if (path === "/auth/v1/user") return response({ id: "auth-fixture", email: `maskan-${memberId}@auth.maskan.app`, user_metadata: { maskan_member_id: "another-member" } });
    if (path.endsWith("maskan_account_deletion_rate_limit_check")) return response([{ allowed: true }]);
    if (path.endsWith("maskan_account_deletion_context")) return response([{ member_id: memberId, network_id: "network-fixture", network_name: "fixture", member_count: 2, is_owner: false }]);
    if (path.endsWith("maskan_password_lookup_member")) return response([{ auth_user_id: "auth-fixture", credential_version: 2, password_digest: digest }]);
    if (path.includes("/storage/v1/object/list/")) return response([]);
    if (path.endsWith("maskan_authorize_account_deletion") || path.endsWith("maskan_delete_account_data") || path === "/auth/v1/logout" || path === "/auth/v1/admin/users/auth-fixture") return response(null);
    throw new Error("Unexpected test endpoint");
  };
  const result = await deletionHandler(request({ memberPassword: "synthetic-password" }));
  assert.equal(result.status, 200);
  assert.equal((await result.json()).ok, true);
  const index = (suffix: string) => calls.findIndex(path => path.endsWith(suffix));
  assert.ok(index("maskan_password_lookup_member") < index("maskan_authorize_account_deletion"));
  assert.ok(index("maskan_delete_account_data") < index("logout"));
  assert.ok(index("logout") < index("auth-fixture"));
});

test("wrong deletion password never authorizes or deletes anything", async () => {
  const digest = await createPasswordDigest("synthetic-password");
  globalThis.fetch = async (input) => {
    const path = String(input);
    if (path.endsWith("/auth/v1/user")) return response({ id: "fixture", email: "maskan-10000000-0000-4000-8000-000000000001@auth.maskan.app" });
    if (path.endsWith("maskan_account_deletion_rate_limit_check")) return response([{ allowed: true }]);
    if (path.endsWith("maskan_account_deletion_context")) return response([{ member_id: "m", network_id: "n", network_name: "fixture", member_count: 2, is_owner: false }]);
    if (path.endsWith("maskan_password_lookup_member")) return response([{ auth_user_id: "fixture", credential_version: 2, password_digest: digest }]);
    if (path.endsWith("maskan_account_deletion_rate_limit_failure")) return response(null);
    throw new Error("Destructive path must not be called");
  };
  const result = await deletionHandler(request({ memberPassword: "wrong" }));
  assert.equal(result.status, 401);
  assert.equal((await result.json()).code, "invalid_credentials");
});
