import { localOnlyFetch } from "../support/local-only-fetch";
import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";
import { MaskanRepository } from "../../src/lib/repository";

const url = process.env.MASKAN_TEST_SUPABASE_URL;
assert.equal(url, "http://127.0.0.1:56321", "Staging-only client target");
const key = process.env.MASKAN_TEST_ANON_KEY!;
const group = process.env.MASKAN_STAGING_GROUP!;
const password = process.env.MASKAN_STAGING_PASSWORD!;
assert.ok(group?.startsWith("staging-shared-") && password);
let loseResponse = false;
const repo = new MaskanRepository(createClient(url!, key, {
  auth: { persistSession: false, autoRefreshToken: false },
  global: { fetch: async (input, init) => {
    const target = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
    assert.equal(target.origin, url, "Reject external traffic and redirects");
    const response = await localOnlyFetch(url!)(input, init);
    if (loseResponse && target.pathname === "/rest/v1/expenses" && init?.method === "POST" && response.ok) {
      loseResponse = false;
      await response.arrayBuffer();
      throw new TypeError("Simulated lost response after committed local expense");
    }
    return response;
  } },
}));
async function main() {
try {
  if (process.env.MASKAN_STAGING_PHASE === "seed") {
    await repo.register("create", { networkName: group, memberName: "Web Owner", memberPassword: password,
      networkPassword: password, currencyCode: "USD" }, { networkId: crypto.randomUUID(), memberId: crypto.randomUUID() });
    const s = (await repo.snapshot())!;
    await repo.addExpense(s, s.me.id, 1100, "web shared fixture", crypto.randomUUID());
    const operation = crypto.randomUUID();
    loseResponse = true;
    await assert.rejects(repo.addExpense(s, s.me.id, 2200, "lost response fixture", operation));
    assert.equal(loseResponse, false, "Failure injected only after real commit");
    await repo.addExpense(s, s.me.id, 2200, "lost response fixture", operation);
    assert.equal((await repo.snapshot())!.expenses.filter(e => e.client_generated_id === operation).length, 1);
    console.log("PASS web creates shared group; lost committed response retry yields one expense");
  } else {
    assert.equal(process.env.MASKAN_STAGING_PHASE, "finish");
    await repo.login(group, "Web Owner", password);
    const s = (await repo.snapshot())!;
    assert.ok(s.members.some(m => m.name === "Android Member"));
    assert.ok(s.expenses.some(e => e.note === "android retained fixture"));
    const pending = s.requests.find(r => r.status === "pending");
    assert.ok(pending, "Android legacy request visible on web");
    await repo.approveCycle(s, pending!);
    const closed = (await repo.snapshot())!;
    assert.ok(closed.expenses.every(e => e.archived_at !== null));
    assert.equal(closed.cycles.filter(c => c.status === "active").length, 1);
    assert.ok(closed.notifications.some(n => n.kind === "cycleStarted"));
    console.log("PASS web sees actual Android writes and completes Android reset with server notifications");
    // A separate synthetic nonowner exercises the real deployed-handler source locally.
    await repo.logout();
    await repo.register("join", { networkName: group, memberName: "Deletion Fixture", memberPassword: password,
      networkPassword: password, currencyCode: "USD" }, { networkId: crypto.randomUUID(), memberId: crypto.randomUUID() });
    const deleting = (await repo.snapshot())!;
    const jwt = (await repo.client.auth.getSession()).data.session!.access_token;
    await repo.deleteAccount(password, false);
    const stale = await fetch(url+"/rest/v1/expenses?network_id=eq."+deleting.network.id,
      { headers: { apikey: key, Authorization: "Bearer "+jwt }, redirect: "error" });
    assert.equal(stale.status, 200);
    assert.deepEqual(await stale.json(), []);
    await assert.rejects(repo.login(group, "Deletion Fixture", password));
    console.log("PASS real Edge account deletion; stale token has no group access and login is rejected");
  }
} finally { await repo.client.auth.signOut({ scope: "local" }); }

}
void main().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
