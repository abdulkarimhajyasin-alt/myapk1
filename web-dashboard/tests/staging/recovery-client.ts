import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";

const origin = "http://127.0.0.1:57321";
assert.equal(process.env.MASKAN_RECOVERY_URL, origin);
const token = process.env.MASKAN_RECOVERY_TOKEN!;
const network = process.env.MASKAN_RECOVERY_NETWORK!;
const expected = Number(process.env.MASKAN_RECOVERY_EXPENSES);
const transport: typeof fetch = async (input, init) => {
  const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
  assert.equal(url.origin, origin);
  assert.equal(url.username + url.password, "");
  assert.ok(url.pathname.startsWith("/rest/v1/"));
  assert.equal((init?.method ?? "GET").toUpperCase(), "GET");
  url.pathname = url.pathname.slice("/rest/v1".length);
  return fetch(url, { ...init, redirect: "error" });
};
async function main() {
for (let connection = 0; connection < 2; connection++) {
  const client = createClient(origin, "synthetic-recovery-key", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` }, fetch: transport },
  });
  const result = await client.from("expenses").select("id", { count: "exact", head: false }).eq("network_id", network);
  assert.equal(result.error, null);
  assert.equal(result.count, expected);
  const outsider = await client.from("expenses").select("id").neq("network_id", network);
  assert.equal(outsider.error, null);
  assert.deepEqual(outsider.data, []);
  await client.removeAllChannels();
}
console.log("PASS web Supabase client connects and reconnects to restored database; RLS rejects other groups");

}
main().catch(() => { console.error("FAIL isolated recovery web client"); process.exitCode = 1; });
