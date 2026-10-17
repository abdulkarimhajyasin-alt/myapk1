import type { Expense, Member } from "./types";
export function parseCents(input: string): number {
  const normalized = input.trim().replaceAll(",", ".");
  if (!/^\d+(\.\d{1,2})?$/.test(normalized)) throw new Error("invalid_amount");
  const [whole, fraction = ""] = normalized.split(".");
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, "0"));
  if (!Number.isSafeInteger(cents) || cents <= 0)
    throw new Error("invalid_amount");
  return cents;
}
export function money(cents: number, symbol: string): string {
  return (
    new Intl.NumberFormat("ar", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(cents / 100) +
    " " +
    symbol
  );
}
// Preserve Flutter's fractional-cent equal share and half-cent settlement threshold.
export function settle(
  members: Pick<Member, "id" | "name">[],
  expenses: Pick<
    Expense,
    "paid_by_member_id" | "amount_cents" | "archived_at"
  >[],
) {
  const paid = new Map(members.map((m) => [m.id, 0]));
  for (const e of expenses) {
    if (!Number.isSafeInteger(e.amount_cents) || e.amount_cents <= 0)
      throw new Error("invalid_amount");
    if (
      e.archived_at === null &&
      e.paid_by_member_id &&
      paid.has(e.paid_by_member_id)
    ) {
      const sum = paid.get(e.paid_by_member_id)! + e.amount_cents;
      if (!Number.isSafeInteger(sum)) throw new Error("amount_overflow");
      paid.set(e.paid_by_member_id, sum);
    }
  }
  const total = [...paid.values()].reduce((a, b) => a + b, 0);
  if (!Number.isSafeInteger(total)) throw new Error("amount_overflow");
  const share = members.length ? total / members.length : 0;
  const balances = members.map((m) => ({
    ...m,
    paid: paid.get(m.id)!,
    balance: paid.get(m.id)! - share,
  }));
  const debtors = balances
    .filter((m) => m.balance < -0.5)
    .map((m) => ({ id: m.id, amount: -m.balance }));
  const creditors = balances
    .filter((m) => m.balance > 0.5)
    .map((m) => ({ id: m.id, amount: m.balance }));
  const payments: { from: string; to: string; amount: number }[] = [];
  let d = 0,
    c = 0;
  while (d < debtors.length && c < creditors.length) {
    const amount = Math.min(debtors[d].amount, creditors[c].amount);
    if (amount > 0.5)
      payments.push({ from: debtors[d].id, to: creditors[c].id, amount });
    debtors[d].amount -= amount;
    creditors[c].amount -= amount;
    if (debtors[d].amount <= 0.5) d++;
    if (creditors[c].amount <= 0.5) c++;
  }
  return { total, share, balances, payments };
}
