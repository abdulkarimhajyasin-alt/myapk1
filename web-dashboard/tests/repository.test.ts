import test from "node:test";
import assert from "node:assert/strict";
import type { SupabaseClient } from "@supabase/supabase-js";
import { MaskanRepository } from "../src/lib/repository";
import type { Snapshot } from "../src/lib/types";
test("login verifies the app password before technical sign-in and claims membership last", async () => {
  const calls: string[] = [];
  const fake = {
    functions: {
      invoke: async (_: string, input: { body: { action: string } }) => {
        calls.push(input.body.action);
        return {
          data: {
            ok: true,
            memberId: "m",
            networkName: "N",
            claimToken: "claim",
          },
          error: null,
        };
      },
    },
    auth: {
      signInWithPassword: async () => {
        calls.push("sign-in");
        return { error: null };
      },
      getSession: async () => ({ data: { session: {} }, error: null }),
      updateUser: async () => {
        calls.push("metadata");
        return { data: {}, error: null };
      },
      refreshSession: async () => ({ data: {}, error: null }),
    },
    rpc: async (name: string) => {
      calls.push(name);
      return { data: null, error: null };
    },
  };
  await new MaskanRepository(fake as unknown as SupabaseClient).login(
    "N",
    "M",
    "password",
  );
  assert.deepEqual(calls, [
    "verify_member",
    "sign-in",
    "metadata",
    "maskan_claim_member",
  ]);
});
test("invalid application password never attempts Supabase sign-in", async () => {
  let signed = false;
  const fake = {
    functions: {
      invoke: async () => ({
        data: { ok: false, code: "invalid_credentials" },
        error: null,
      }),
    },
    auth: {
      signInWithPassword: async () => {
        signed = true;
      },
    },
  };
  await assert.rejects(
    new MaskanRepository(fake as unknown as SupabaseClient).login(
      "N",
      "M",
      "wrong",
    ),
    /invalid_credentials/,
  );
  assert.equal(signed, false);
});
test("pagination does not silently truncate a large authorized group", async () => {
  const ranges: number[] = [];
  const chain = {
    select: () => chain,
    eq: () => chain,
    order: () => chain,
    range: async (from: number) => {
      ranges.push(from);
      return {
        data: Array.from({ length: from === 0 ? 500 : 3 }, (_, i) => ({
          id: String(from + i),
        })),
        error: null,
      };
    },
  };
  const fake = { from: () => chain };
  const rows = await new MaskanRepository(
    fake as unknown as SupabaseClient,
  ).rows("expenses", "network");
  assert.equal(rows.length, 503);
  assert.deepEqual(ranges, [0, 500]);
});
test("owner-only reset validation prevents invoking the privileged Edge action", async () => {
  let invoked = false;
  const fake = {
    functions: {
      invoke: async () => {
        invoked = true;
      },
    },
  };
  const snapshot = {
    network: { created_by_member_id: "owner" },
    me: { id: "other" },
    members: [{ id: "target" }],
  } as Snapshot;
  await assert.rejects(
    new MaskanRepository(fake as unknown as SupabaseClient).resetPassword(
      snapshot,
      "target",
      "new-pass",
    ),
    /permission_denied/,
  );
  assert.equal(invoked, false);
});

test("atomic approval never falls back after an authorization error", async () => {
  let writes = 0;
  const fake = {
    rpc: async () => ({
      data: null,
      error: { code: "42501", message: "denied" },
    }),
    from: () => {
      writes++;
      throw new Error("unexpected fallback");
    },
  };
  await assert.rejects(
    new MaskanRepository(fake as unknown as SupabaseClient).approveCycle(
      { network: { id: "network" } } as Snapshot,
      { id: "request" } as Snapshot["requests"][number],
    ),
  );
  assert.equal(writes, 0);
});

test("atomic approval success needs no client notification or follow-up write", async () => {
  const names: string[] = [];
  const fake = {
    rpc: async (name: string) => {
      names.push(name);
      return { data: true, error: null };
    },
    from: () => {
      throw new Error("unexpected follow-up write");
    },
  };
  await new MaskanRepository(fake as unknown as SupabaseClient).approveCycle(
    { network: { id: "network" } } as Snapshot,
    { id: "request" } as Snapshot["requests"][number],
  );
  assert.deepEqual(names, ["maskan_approve_expense_reset"]);
});

for (const [message, expectedAttempts] of [
  ["network_busy_retry", 3],
  ["stale_expense_cycle", 1],
] as const) {
  test(`expense conflict ${message} preserves original operation and cycle`, async () => {
    const payloads: unknown[] = [];
    const cycle = {
      id: "cycle-original",
      status: "active",
    } as Snapshot["cycles"][number];
    const chain = {
      insert: (payload: unknown) => {
        payloads.push(structuredClone(payload));
        return chain;
      },
      select: () => chain,
      single: async () => ({ data: null, error: { code: "40001", message } }),
    };
    const repository = new MaskanRepository({
      from: () => chain,
    } as unknown as SupabaseClient);
    repository.activeCycle = async () => cycle;
    const member = { id: "member", name: "Fixture" } as Snapshot["me"];
    const snapshot = {
      network: { id: "network" },
      me: member,
      members: [member],
      cycles: [cycle],
    } as Snapshot;
    await assert.rejects(
      repository.addExpense(
        snapshot,
        member.id,
        100,
        "test",
        "operation-original",
      ),
    );
    assert.equal(payloads.length, expectedAttempts);
    assert.ok(
      payloads.every(
        (payload) => JSON.stringify(payload) === JSON.stringify(payloads[0]),
      ),
    );
    assert.equal(
      (payloads[0] as { client_generated_id: string }).client_generated_id,
      "operation-original",
    );
    assert.equal(
      (payloads[0] as { cycle_id: string }).cycle_id,
      "cycle-original",
    );
  });
}
