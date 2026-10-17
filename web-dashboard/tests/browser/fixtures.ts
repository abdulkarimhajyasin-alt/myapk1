import type { Page } from "@playwright/test";

export async function mockDashboard(page: Page, longContent = false) {
  const now = new Date().toISOString();
  const user = {
    id: "auth-a",
    aud: "authenticated",
    role: "authenticated",
    email: "test@example.invalid",
    app_metadata: {},
    user_metadata: {},
    created_at: now,
  };
  const payload = Buffer.from(
    JSON.stringify({
      sub: user.id,
      role: "authenticated",
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString("base64url");
  await page.addInitScript(
    ({ user, payload }) => {
      sessionStorage.setItem(
        "maskan-web-session",
        JSON.stringify({
          access_token: "eyJhbGciOiJIUzI1NiJ9." + payload + ".fixture",
          refresh_token: "fixture-refresh",
          token_type: "bearer",
          expires_in: 3600,
          expires_at: Math.floor(Date.now() / 1000) + 3600,
          user,
        }),
      );
    },
    { user, payload },
  );
  await page.routeWebSocket(/maskan-test\.supabase\.co/, (socket) =>
    socket.close(),
  );
  const network = {
    id: "network-a",
    name: longContent ? "اسممجموعة".repeat(12) : "بيت الاختبار",
    currency_code: "USD",
    currency_symbol: "$",
    created_by_member_id: "a",
    created_at: now,
  };
  const members = ["a", "b", "c", "d"].map((id, i) => ({
    id,
    network_id: network.id,
    name: longContent ? "اسمعضوطويل".repeat(10) + i : "عضو " + (i + 1),
    created_at: now,
    avatar_initials: null,
    avatar_color: i === 0 ? "#d8eebe" : null,
  }));
  const cycle = {
    id: "cycle-a",
    network_id: network.id,
    cycle_number: 1,
    status: "active",
    started_at: now,
    closed_at: null,
  };
  const expense = {
    id: "expense-a",
    network_id: network.id,
    paid_by_member_id: "a",
    paid_by_member_name: members[0].name,
    added_by_member_id: "a",
    added_by_member_name: members[0].name,
    amount_cents: longContent ? 900000000000000 : 4000,
    note: longContent ? "ملاحظةطويلة".repeat(18) : "مشتريات البيت",
    cycle_id: cycle.id,
    archived_at: null,
    client_generated_id: "fixture-op",
    created_at: now,
  };
  const expenseRows = [expense];
  let expenseInserts = 0;
  await page.route("https://maskan-test.supabase.co/**", async (route) => {
    const request = route.request(),
      url = new URL(request.url());
    let body: unknown = [];
    if (url.pathname.includes("rpc/maskan_current_member_id")) body = "a";
    else if (url.pathname.endsWith("/maskan_networks")) body = network;
    else if (url.pathname.endsWith("/maskan_network_members"))
      body = url.searchParams.has("id") ? members[0] : members;
    else if (url.pathname.endsWith("/expense_cycles")) body = [cycle];
    else if (url.pathname.endsWith("/network_notifications"))
      body = longContent
        ? [
            {
              id: "notice-a",
              actor_member_name: members[1].name,
              kind: "expense",
              amount_cents: expense.amount_cents,
              note_snippet: expense.note.slice(0, 80),
              is_read: false,
              created_at: now,
            },
          ]
        : [];
    else if (url.pathname.endsWith("/expenses")) {
      if (request.method() === "POST") {
        expenseInserts++;
        const added = {
          ...expense,
          ...request.postDataJSON(),
          id: "expense-b",
        };
        expenseRows.push(added);
        body = added;
      } else body = expenseRows;
    } else if (url.pathname.endsWith("/user")) body = user;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(body),
    });
  });
  return { expenseRows, getExpenseInserts: () => expenseInserts };
}
