import test from "node:test";
import assert from "node:assert/strict";
import { localOnlyFetch } from "./support/local-only-fetch";

test("test transport rejects production and unauthorized API targets", () => {
  for (const target of ["https://skngodvomygvxemfaefn.supabase.co", "http://example.invalid:56321", "http://127.0.0.1:54322", "https://127.0.0.1:56321", "http://user:password@127.0.0.1:56321"]) {
    assert.throws(() => localOnlyFetch(target));
  }
});
test("external requests are rejected before transport executes", async () => {
  let calls = 0;
  const guarded = localOnlyFetch("http://127.0.0.1:56321", async () => { calls++; return new Response(); });
  await assert.rejects(guarded("https://skngodvomygvxemfaefn.supabase.co/rest/v1/expenses"));
  await assert.rejects(guarded("http://127.0.0.1:55321/rest/v1/expenses"));
  assert.equal(calls, 0);
});
test("local requests cannot follow redirects outside staging", async () => {
  const guarded = localOnlyFetch("http://127.0.0.1:56321", async (_input, init) => {
    assert.equal(init?.redirect, "error"); return new Response("{}", { status: 200 });
  });
  assert.equal((await guarded("http://127.0.0.1:56321/auth/v1/health", { redirect: "follow" })).status, 200);
});
