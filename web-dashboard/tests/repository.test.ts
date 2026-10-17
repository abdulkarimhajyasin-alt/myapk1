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
