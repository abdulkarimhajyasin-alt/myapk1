import type { SupabaseClient } from "@supabase/supabase-js";
import { memberEmail, memberSecret } from "./identity";
import { settle } from "./money";
import type {
  Approval,
  Cycle,
  Expense,
  Member,
  Network,
  Notification,
  ResetRequest,
  Snapshot,
} from "./types";

export const currencies: Record<string, string> = {
  USD: "$",
  EUR: "€",
  GBP: "£",
  TRY: "₺",
  SAR: "ر.س",
  AED: "د.إ",
  SYP: "£S",
  IQD: "د.ع",
  JOD: "د.أ",
};
type Result = {
  data?: unknown;
  error: { message: string; code?: string } | null;
};
function checked<T extends Result>(result: T): T["data"] {
  if (result.error)
    throw new Error(
      result.error.message === "expense_operation_conflict"
        ? "operation_conflict"
        : result.error.message === "network_busy_retry"
          ? "network_busy"
          : result.error.message === "stale_expense_cycle"
            ? "cycle_changed"
            : result.error.code === "42501"
              ? "permission_denied"
              : (result.error.code ?? "operation_failed"),
    );
  return result.data as T["data"];
}
export function canEdit(
  expense: Pick<Expense, "added_by_member_id" | "archived_at">,
  memberId: string,
) {
  return (
    expense.added_by_member_id === memberId && expense.archived_at === null
  );
}
export class MaskanRepository {
  warning: string | null = null;
  clearWarning() {
    this.warning = null;
  }
  constructor(readonly client: SupabaseClient) {}
  async action(action: string, body: Record<string, unknown>) {
    const response = await this.client.functions.invoke("maskan-password", {
      body: { action, ...body },
    });
    if (response.error) {
      let code = "operation_failed";
      try {
        code = (await response.error.context.json()).code ?? code;
      } catch {
        /* No sensitive error body is logged. */
      }
      throw new Error(code);
    }
    if (response.data?.ok !== true)
      throw new Error(response.data?.code ?? "operation_failed");
    return response.data as Record<string, string>;
  }
  private async establish(
    memberId: string,
    password: string,
    networkName: string,
    allowCreate: boolean,
  ) {
    const credentials = {
      email: memberEmail(memberId),
      password: await memberSecret(memberId, password),
    };
    const signed = await this.client.auth.signInWithPassword(credentials);
    if (signed.error) {
      if (!allowCreate || signed.error.code !== "invalid_credentials")
        throw new Error("invalid_credentials");
      checked(await this.client.auth.signUp(credentials));
    }
    const session = checked(await this.client.auth.getSession()).session;
    if (!session) throw new Error("session_required");
    checked(
      await this.client.auth.updateUser({
        data: { maskan_member_id: memberId, maskan_network_name: networkName },
      }),
    );
    checked(await this.client.auth.refreshSession());
  }
  async login(networkName: string, memberName: string, memberPassword: string) {
    const result = await this.action("verify_member", {
      networkName: networkName.trim(),
      memberName: memberName.trim(),
      memberPassword,
    });
    await this.establish(
      result.memberId,
      memberPassword,
      result.networkName,
      false,
    );
    checked(
      await this.client.rpc("maskan_claim_member", {
        p_member_id: result.memberId,
        p_claim_token: result.claimToken,
      }),
    );
  }
  async register(
    mode: "create" | "join",
    input: {
      networkName: string;
      memberName: string;
      memberPassword: string;
      networkPassword: string;
      currencyCode: string;
      networkId?: string;
    },
    ids: { memberId: string; networkId: string },
  ) {
    if (
      !input.networkName.trim() ||
      !input.memberName.trim() ||
      !input.networkPassword.trim() ||
      input.memberPassword.trim().length < 4 ||
      !currencies[input.currencyCode]
    )
      throw new Error("invalid_request");
    await this.establish(
      ids.memberId,
      input.memberPassword,
      input.networkName.trim(),
      true,
    );
    await this.action(mode === "create" ? "create_network" : "join_network", {
      ...input,
      memberId: ids.memberId,
      networkId: mode === "create" ? ids.networkId : input.networkId || null,
      currencySymbol: currencies[input.currencyCode],
    });
  }
  // Range through all authorized rows: Supabase's default row cap must not truncate balances.
  async rows<T>(
    table: string,
    networkId: string,
    order = "created_at",
  ): Promise<T[]> {
    const rows: T[] = [];
    for (let offset = 0; ; offset += 500) {
      const page = checked(
        await this.client
          .from(table)
          .select("*")
          .eq("network_id", networkId)
          .order(order)
          .order("id")
          .range(offset, offset + 499),
      );
      if (!page) throw new Error("operation_failed");
      rows.push(...(page as T[]));
      if (page.length < 500) return rows;
    }
  }
  async snapshot(retry = true): Promise<Snapshot | null> {
    const session = checked(await this.client.auth.getSession()).session;
    if (!session) return null;
    // Authoritative database binding; never authorize against user-editable metadata.
    const memberId = checked(
      await this.client.rpc("maskan_current_member_id"),
    ) as string | null;
    if (!memberId) return null;
    const me = checked(
      await this.client
        .from("maskan_network_members")
        .select("*")
        .eq("id", memberId)
        .single(),
    ) as Member;
    const network = checked(
      await this.client
        .from("maskan_networks")
        .select("*")
        .eq("id", me.network_id)
        .single(),
    ) as Network;
    const [members, expenses, cycles, requests, approvals, notifications] =
      await Promise.all([
        this.rows<Member>("maskan_network_members", network.id),
        this.rows<Expense>("expenses", network.id),
        this.rows<Cycle>("expense_cycles", network.id, "cycle_number"),
        this.rows<ResetRequest>("expense_reset_requests", network.id),
        this.rows<Approval>(
          "expense_reset_approvals",
          network.id,
          "approved_at",
        ),
        this.rows<Notification>("network_notifications", network.id),
      ]);
    const after = await this.rows<Cycle>(
      "expense_cycles",
      network.id,
      "cycle_number",
    );
    if (JSON.stringify(cycles) !== JSON.stringify(after)) {
      if (retry) return this.snapshot(false);
      throw new Error("cycle_changed");
    }
    return {
      network,
      me,
      members,
      expenses,
      cycles,
      requests,
      approvals,
      notifications: notifications.reverse(),
    };
  }
  async activeCycle(s: Snapshot) {
    const cycles = await this.rows<Cycle>(
      "expense_cycles",
      s.network.id,
      "cycle_number",
    );
    const active = cycles.filter((c) => c.status !== "closed").at(-1);
    if (active) return active;
    const result = await this.client
      .from("expense_cycles")
      .insert({
        network_id: s.network.id,
        cycle_number: cycles.length + 1,
        status: "active",
      })
      .select()
      .single();
    if (result.error?.code === "23505") {
      const latest = await this.rows<Cycle>(
        "expense_cycles",
        s.network.id,
        "cycle_number",
      );
      const found = latest.filter((c) => c.status !== "closed").at(-1);
      if (found) return found;
    }
    return checked(result) as Cycle;
  }
  private async notify(
    s: Snapshot,
    kind: string,
    expense: Expense | null,
    requestId: string | null = null,
  ) {
    const cycle = kind === "cycleStarted";
    const recipients = s.members.filter((m) => cycle || m.id !== s.me.id);
    if (!recipients.length) return;
    const { error } = await this.client.from("network_notifications").insert(
      recipients.map((m) => ({
        network_id: s.network.id,
        recipient_member_id: m.id,
        actor_member_id: cycle ? null : s.me.id,
        actor_member_name: s.me.name,
        expense_id: expense?.id ?? null,
        amount_cents: expense?.amount_cents ?? 0,
        currency_symbol: s.network.currency_symbol,
        note_snippet: expense?.note?.slice(0, 80) ?? null,
        kind,
        reset_request_id: requestId,
        is_read: false,
      })),
    );
    if (error)
      this.warning =
        "حُفظت العملية، لكن تعذر إرسال بعض الإشعارات. حدّث البيانات للتحقق.";
  }
  async addExpense(
    s: Snapshot,
    payerId: string,
    amount: number,
    note: string,
    operationId: string,
  ) {
    this.warning = null;
    if (
      !Number.isSafeInteger(amount) ||
      amount <= 0 ||
      note.trim().length > 200
    )
      throw new Error("invalid_amount");
    if (!operationId.trim()) throw new Error("invalid_request");
    const payer = s.members.find((m) => m.id === payerId);
    if (!payer) throw new Error("permission_denied");
    const cycle = await this.activeCycle(s);
    const original = s.cycles.filter((c) => c.status !== "closed").at(-1);
    if (original && original.id !== cycle.id) throw new Error("cycle_changed");
    const payload = {
      network_id: s.network.id,
      paid_by_member_id: payer.id,
      paid_by_member_name: payer.name,
      added_by_member_id: s.me.id,
      added_by_member_name: s.me.name,
      amount_cents: amount,
      note: note.trim() || null,
      cycle_id: cycle.id,
      client_generated_id: operationId,
    };
    const insert = () =>
      this.client.from("expenses").insert(payload).select().single();
    let result = await insert();
    for (
      let attempt = 0;
      attempt < 2 &&
      result.error?.code === "40001" &&
      result.error.message === "network_busy_retry";
      attempt++
    ) {
      await new Promise((resolve) => setTimeout(resolve, 100 * (attempt + 1)));
      // Reuse the operation ID and original cycle; never move a stale write to a new cycle.
      result = await insert();
    }
    if (result.error?.code === "23505") {
      const existing = checked(
        await this.client
          .from("expenses")
          .select("*")
          .eq("network_id", s.network.id)
          .eq("client_generated_id", operationId)
          .single(),
      ) as Expense;
      if (
        existing.network_id !== s.network.id ||
        existing.cycle_id !== cycle.id ||
        existing.client_generated_id !== operationId ||
        existing.added_by_member_id !== s.me.id ||
        existing.amount_cents !== amount ||
        existing.paid_by_member_id !== payer.id ||
        existing.note !== payload.note
      )
        throw new Error("operation_conflict");
      return;
    }
    await this.notify(s, "expense", checked(result) as Expense);
  }
  async editExpense(
    s: Snapshot,
    expense: Expense,
    amount: number,
    note: string,
  ) {
    this.warning = null;
    if (!canEdit(expense, s.me.id)) throw new Error("permission_denied");
    if (
      !Number.isSafeInteger(amount) ||
      amount <= 0 ||
      note.trim().length > 200
    )
      throw new Error("invalid_amount");
    const changed = checked(
      await this.client
        .from("expenses")
        .update({ amount_cents: amount, note: note.trim() || null })
        .eq("id", expense.id)
        .eq("network_id", s.network.id)
        .eq("added_by_member_id", s.me.id)
        .is("archived_at", null)
        .select()
        .single(),
    ) as Expense;
    await this.notify(s, "expenseUpdated", changed);
  }
  async deleteExpense(s: Snapshot, expense: Expense) {
    if (!canEdit(expense, s.me.id)) throw new Error("permission_denied");
    checked(
      await this.client
        .from("expenses")
        .delete()
        .eq("id", expense.id)
        .eq("network_id", s.network.id)
        .eq("added_by_member_id", s.me.id)
        .is("archived_at", null)
        .select("id")
        .single(),
    );
  }
  async requestCycle(s: Snapshot) {
    this.warning = null;
    if (s.me.id !== s.network.created_by_member_id) {
      const cycle = await this.activeCycle(s);
      const result = await this.client.rpc("maskan_request_expense_reset", {
        p_network_id: s.network.id,
        p_cycle_id: cycle.id,
      });
      if (!result.error) return;
      // Compatibility while the reviewed migration has not yet been deployed.
      // Permission, validation and network errors must never trigger a second write.
      if (result.error.code !== "PGRST202") checked(result);
    }
    const requests = await this.rows<ResetRequest>(
      "expense_reset_requests",
      s.network.id,
    );
    if (requests.some((r) => r.status === "pending"))
      throw new Error("pending_request");
    const cycle = await this.activeCycle(s);
    if (s.me.id === s.network.created_by_member_id) {
      checked(
        await this.client.rpc("maskan_complete_expense_cycle", {
          p_network_id: s.network.id,
          p_cycle_id: cycle.id,
          p_reset_request_id: null,
        }),
      );
      await this.notify(s, "cycleStarted", null);
      return;
    }
    const members = await this.rows<Member>(
      "maskan_network_members",
      s.network.id,
    );
    const request = checked(
      await this.client
        .from("expense_reset_requests")
        .insert({
          network_id: s.network.id,
          cycle_id: cycle.id,
          requested_by_member_id: s.me.id,
          requested_by_member_name: s.me.name,
          status: "pending",
          required_member_ids: members.map((m) => m.id),
          required_member_names: members.map((m) => m.name),
        })
        .select()
        .single(),
    ) as ResetRequest;
    await this.approveCycle(s, request);
    // Production denies direct cycle updates. The pending request is authoritative;
    // the existing completion RPC closes the cycle after unanimous approval.
    await this.notify(s, "resetRequest", null, request.id);
  }
  async approveCycle(s: Snapshot, request: ResetRequest) {
    this.warning = null;
    const result = await this.client.rpc("maskan_approve_expense_reset", {
      p_network_id: s.network.id,
      p_reset_request_id: request.id,
    });
    if (!result.error) return;
    if (result.error.code !== "PGRST202") checked(result);
    if (
      request.status !== "pending" ||
      !request.required_member_ids.includes(s.me.id)
    )
      throw new Error("permission_denied");
    // INSERT-ignore avoids an UPDATE permission requirement on repeat approvals.
    checked(
      await this.client.from("expense_reset_approvals").upsert(
        {
          network_id: s.network.id,
          reset_request_id: request.id,
          member_id: s.me.id,
          member_name: s.me.name,
        },
        { onConflict: "reset_request_id,member_id", ignoreDuplicates: true },
      ),
    );
    const approvals = await this.rows<Approval>(
      "expense_reset_approvals",
      s.network.id,
      "approved_at",
    );
    if (
      !request.required_member_ids.every((id) =>
        approvals.some(
          (a) => a.reset_request_id === request.id && a.member_id === id,
        ),
      )
    )
      return;
    const done = checked(
      await this.client.rpc("maskan_complete_expense_cycle", {
        p_network_id: s.network.id,
        p_cycle_id: request.cycle_id,
        p_reset_request_id: request.id,
      }),
    );
    if (done === true) await this.notify(s, "cycleStarted", null, request.id);
  }
  async markRead(s: Snapshot, id: string) {
    checked(
      await this.client
        .from("network_notifications")
        .update({ is_read: true })
        .eq("id", id)
        .eq("recipient_member_id", s.me.id)
        .select("id")
        .single(),
    );
  }
  async deleteNotification(s: Snapshot, id: string) {
    checked(
      await this.client
        .from("network_notifications")
        .delete()
        .eq("id", id)
        .eq("recipient_member_id", s.me.id)
        .select("id")
        .single(),
    );
  }
  async profile(s: Snapshot, initials: string, color: string) {
    if (
      !initials.trim() ||
      initials.trim().length > 3 ||
      !/^#[0-9a-f]{6}$/i.test(color)
    )
      throw new Error("invalid_request");
    checked(
      await this.client
        .from("network_members")
        .update({ avatar_initials: initials.trim(), avatar_color: color })
        .eq("id", s.me.id)
        .select("id")
        .single(),
    );
  }
  async resetPassword(s: Snapshot, targetId: string, newPassword: string) {
    if (
      s.network.created_by_member_id !== s.me.id ||
      targetId === s.me.id ||
      !s.members.some((m) => m.id === targetId)
    )
      throw new Error("permission_denied");
    if (newPassword.trim().length < 4) throw new Error("invalid_request");
    await this.action("reset_member_password", {
      networkId: s.network.id,
      adminMemberId: s.me.id,
      targetMemberId: targetId,
      newPassword: newPassword.trim(),
    });
  }
  async leave(s: Snapshot) {
    if (settle(s.members, s.expenses).total > 0)
      throw new Error("permission_denied");
    checked(
      await this.client.rpc("maskan_leave_network", {
        p_network_id: s.network.id,
      }),
    );
    await this.logout();
  }
  async deleteAccount(password: string, confirmNetworkDeletion: boolean) {
    const response = await this.client.functions.invoke(
      "maskan-delete-account",
      { body: { memberPassword: password, confirmNetworkDeletion } },
    );
    if (response.error || response.data?.ok !== true) {
      let code = response.data?.code ?? "operation_failed";
      try {
        code = (await response.error?.context.json())?.code ?? code;
      } catch {
        /* Keep error text generic. */
      }
      throw new Error(code);
    }
    await this.logout();
  }
  async logout() {
    checked(await this.client.auth.signOut({ scope: "local" }));
  }
}
