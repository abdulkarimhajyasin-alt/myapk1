import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { parseCents, settle } from "../src/lib/money";
import { memberEmail, memberSecret } from "../src/lib/identity";
import { canEdit } from "../src/lib/repository";

test("money parser matches Android decimal and comma fixtures without rounding", () => {
  for (const [input, expected] of [
    ["20", 2000],
    ["20.5", 2050],
    ["20.55", 2055],
    ["20,55", 2055],
  ] as const)
    assert.equal(parseCents(input), expected);
  for (const input of [
    "",
    "0",
    "-5",
    "10.999",
    "1e3",
    "Infinity",
    "9007199254740993",
    "1,234.56",
  ])
    assert.throws(() => parseCents(input));
});
test("settlement matches Android payer to receiver golden fixture", () => {
  const members = [
    { id: "a", name: "Ali" },
    { id: "b", name: "Ahmad" },
  ];
  const expenses = [
    { paid_by_member_id: "a", amount_cents: 6000, archived_at: null },
    { paid_by_member_id: "b", amount_cents: 2000, archived_at: null },
  ];
  const result = settle(members, expenses);
  assert.equal(result.total, 8000);
  assert.equal(result.share, 4000);
  assert.deepEqual(result.payments, [{ from: "b", to: "a", amount: 2000 }]);
});
test("archived and orphaned expenses follow Android hydration rules", () => {
  const result = settle(
    [
      { id: "a", name: "A" },
      { id: "b", name: "B" },
    ],
    [
      { paid_by_member_id: "a", amount_cents: 101, archived_at: null },
      { paid_by_member_id: "a", amount_cents: 2000, archived_at: "2026-01-01" },
      { paid_by_member_id: null, amount_cents: 9000, archived_at: null },
    ],
  );
  assert.equal(result.total, 101);
  assert.equal(result.share, 50.5);
  assert.equal(result.payments[0].amount, 50.5);
});
test("equal shares preserve fractional cents and conservation for four members", () => {
  const members = ["a", "b", "c", "d"].map((id) => ({ id, name: id }));
  for (let total = 1; total < 500; total++) {
    const result = settle(members, [
      { paid_by_member_id: "a", amount_cents: total, archived_at: null },
    ]);
    assert.equal(
      result.balances.reduce((sum, m) => sum + m.balance, 0),
      0,
    );
    assert.equal(result.share, total / 4);
    assert.ok(result.payments.every((p) => p.amount > 0.5));
  }
  assert.deepEqual(settle([], []), {
    total: 0,
    share: 0,
    balances: [],
    payments: [],
  });
});
test("unsafe integer totals fail visibly instead of corrupting balances", () => {
  assert.throws(() =>
    settle(
      [{ id: "a", name: "A" }],
      [
        {
          paid_by_member_id: "a",
          amount_cents: Number.MAX_SAFE_INTEGER + 1,
          archived_at: null,
        },
      ],
    ),
  );
});
test("technical Supabase identity is byte compatible with Flutter AuthV2", async () => {
  const id = "ef834f03-cfd5-41a6-8c24-3b2b451da3a0";
  assert.equal(memberEmail(id), "maskan-" + id + "@auth.maskan.app");
  const expected = createHash("sha256")
    .update("MaskanAuthV2:" + id + ":كلمة مرور")
    .digest("hex");
  assert.equal(await memberSecret(id, "  كلمة مرور  "), expected);
});
test("only author can edit an unarchived expense", () => {
  assert.equal(
    canEdit({ added_by_member_id: "a", archived_at: null }, "a"),
    true,
  );
  assert.equal(
    canEdit({ added_by_member_id: "a", archived_at: null }, "b"),
    false,
  );
  assert.equal(
    canEdit({ added_by_member_id: "a", archived_at: "2026-01-01" }, "a"),
    false,
  );
});
