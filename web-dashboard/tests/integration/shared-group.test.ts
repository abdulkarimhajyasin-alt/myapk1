import test from "node:test";
import assert from "node:assert/strict";
import { createClient } from "@supabase/supabase-js";
import { MaskanRepository } from "../../src/lib/repository";
import { settle } from "../../src/lib/money";
const url = process.env.MASKAN_TEST_SUPABASE_URL;
const key = process.env.MASKAN_TEST_ANON_KEY;
test(
  "isolated backend: four clients, auth, membership isolation, duplicate writes, expenses, and cycles",
  {
    skip:
      !url || !key
        ? "Requires a disposable local Supabase instance with migrations and both Edge Functions"
        : false,
    timeout: 120000,
  },
  async () => {
    const endpoint = new URL(url!);
    assert.ok(
      ["localhost", "127.0.0.1", "[::1]"].includes(endpoint.hostname),
      "Refusing to mutate a remote or production database",
    );
    assert.equal(endpoint.protocol, "http:");
    assert.ok(["54321", "55321"].includes(endpoint.port));
    const make = () =>
      new MaskanRepository(
        createClient(url!, key!, {
          auth: { persistSession: false, autoRefreshToken: false },
        }),
      );
    // Client 0 uses the same AuthV2 and REST contract as Android; this is not a physical device test.
    const clients = Array.from({ length: 4 }, make);
    const outsiders = make();
    const prefix = "web-test-" + crypto.randomUUID();
    const input = {
      networkName: prefix,
      memberName: "Owner",
      memberPassword: "test-secret-123",
      networkPassword: "group-secret-123",
      currencyCode: "USD",
    };
    try {
      await clients[0].register("create", input, {
        networkId: crypto.randomUUID(),
        memberId: crypto.randomUUID(),
      });
      for (let i = 1; i < 4; i++)
        await clients[i].register(
          "join",
          { ...input, memberName: "Member " + i },
          { networkId: crypto.randomUUID(), memberId: crypto.randomUUID() },
        );
      await outsiders.register(
        "create",
        { ...input, networkName: prefix + "-isolated" },
        { networkId: crypto.randomUUID(), memberId: crypto.randomUUID() },
      );
      const snapshots = await Promise.all(clients.map((c) => c.snapshot()));
      assert.ok(snapshots.every((s) => s?.members.length === 4));
      const group = snapshots[0]!;
      const forbidden = await outsiders.client
        .from("expenses")
        .select("*")
        .eq("network_id", group.network.id);
      assert.equal(forbidden.error, null);
      assert.deepEqual(forbidden.data, []);
      const outsiderSnapshot = (await outsiders.snapshot())!;
      await outsiders.client.auth.updateUser({
        data: { maskan_member_id: group.me.id },
      });
      const binding = await outsiders.client.rpc("maskan_current_member_id");
      assert.equal(
        binding.data,
        outsiderSnapshot.me.id,
        "User metadata cannot escalate membership",
      );
      const operationId = crypto.randomUUID();
      await Promise.all([
        clients[0].addExpense(
          group,
          group.me.id,
          4000,
          "integration",
          operationId,
        ),
        clients[0].addExpense(
          group,
          group.me.id,
          4000,
          "integration",
          operationId,
        ),
      ]);
      for (const client of clients) {
        const s = (await client.snapshot())!;
        assert.equal(
          s.expenses.filter((e) => e.client_generated_id === operationId)
            .length,
          1,
        );
        assert.equal(settle(s.members, s.expenses).share, 1000);
      }
      for (const [payer, amount, note] of [
        [group.me.id, 4001, "integration"],
        [group.members[1].id, 4000, "integration"],
        [group.me.id, 4000, "different"],
      ] as const) {
        await assert.rejects(
          clients[0].addExpense(group, payer, amount, note, operationId),
          /operation_conflict/,
        );
      }
      const otherMember = (await clients[1].snapshot())!;
      await assert.rejects(
        clients[1].addExpense(
          otherMember,
          group.me.id,
          4000,
          "integration",
          operationId,
        ),
        /operation_conflict/,
      );
      const conflictingId = crypto.randomUUID();
      const competing = await Promise.allSettled([
        clients[0].addExpense(group, group.me.id, 4100, "race", conflictingId),
        clients[0].addExpense(group, group.me.id, 4200, "race", conflictingId),
      ]);
      assert.equal(competing.filter((result) => result.status === "fulfilled").length, 1);
      const rejected = competing.find((result) => result.status === "rejected");
      assert.ok(rejected && rejected.status === "rejected");
      assert.match(String(rejected.reason), /operation_conflict/);
      const conflictRows = (await clients[0].snapshot())!.expenses.filter(
        (expense) => expense.client_generated_id === conflictingId,
      );
      assert.equal(conflictRows.length, 1);
      await clients[0].deleteExpense(group, conflictRows[0]);
      const independentIds = [crypto.randomUUID(), crypto.randomUUID()];
      await Promise.all(
        independentIds.map((id) =>
          clients[0].addExpense(group, group.me.id, 4000, "integration", id),
        ),
      );
      const independent = (await clients[0].snapshot())!.expenses.filter(
        (expense) => independentIds.includes(expense.client_generated_id!),
      );
      assert.equal(
        independent.length,
        2,
        "Identical contents with different operation IDs are separate expenses",
      );
      for (const expense of independent)
        await clients[0].deleteExpense(group, expense);
      const saved = (await clients[0].snapshot())!.expenses.find(
        (e) => e.client_generated_id === operationId,
      )!;
      const editDenied = await clients[1].client
        .from("expenses")
        .update({ amount_cents: 1 })
        .eq("id", saved.id)
        .select("id");
      assert.ok(editDenied.error || editDenied.data?.length === 0);
      await clients[0].editExpense(group, saved, 8000, "updated");
      assert.equal(
        settle(
          (await clients[2].snapshot())!.members,
          (await clients[2].snapshot())!.expenses,
        ).share,
        2000,
      );
      const member = (await clients[1].snapshot())!;
      await clients[1].requestCycle(member);
      for (let i = 0; i < 4; i++) {
        const s = (await clients[i].snapshot())!;
        const pending = s.requests.find((r) => r.status === "pending");
        if (pending) await clients[i].approveCycle(s, pending);
      }
      for (const client of clients) {
        const s = (await client.snapshot())!;
        assert.equal(settle(s.members, s.expenses).total, 0);
        assert.ok(s.expenses.some((e) => e.archived_at !== null));
      }
      const nextCycle = (await clients[0].snapshot())!;
      await assert.rejects(
        clients[0].addExpense(
          nextCycle,
          group.me.id,
          4000,
          "integration",
          operationId,
        ),
        /operation_conflict/,
      );
      await clients[3].logout();
      await assert.rejects(() =>
        clients[3].login(prefix, "Member 3", "wrong-password"),
      );
      await clients[3].login(prefix, "Member 3", input.memberPassword);
      assert.ok(await clients[3].snapshot());
    } finally {
      await Promise.all(
        [...clients, outsiders].map((c) =>
          c.client.auth.signOut({ scope: "local" }),
        ),
      );
      // Intentionally retain fixtures; reset the disposable local database outside this test.
    }
  },
);
