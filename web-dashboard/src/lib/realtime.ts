import type { SupabaseClient } from "@supabase/supabase-js";
// Events invalidate snapshots; they never increment totals or apply optimistic financial writes.
export function watchNetwork(
  client: SupabaseClient,
  networkId: string,
  memberId: string,
  refresh: () => Promise<void>,
  status: (value: string) => void,
) {
  let stopped = false,
    busy = false,
    pending = false;
  let debounce: ReturnType<typeof setTimeout> | undefined;
  const run = async () => {
    if (stopped) return;
    if (busy) {
      pending = true;
      return;
    }
    busy = true;
    try {
      await refresh();
    } finally {
      busy = false;
      if (pending && !stopped) {
        pending = false;
        schedule();
      }
    }
  };
  const schedule = () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => void run(), 350);
  };
  const channel = client.channel("maskan-web-" + networkId + "-" + memberId);
  for (const table of [
    "network_members",
    "expenses",
    "expense_cycles",
    "expense_reset_requests",
    "expense_reset_approvals",
  ]) {
    channel.on(
      "postgres_changes",
      {
        event: "*",
        schema: "public",
        table,
        filter: "network_id=eq." + networkId,
      },
      schedule,
    );
  }
  channel.on(
    "postgres_changes",
    {
      event: "*",
      schema: "public",
      table: "network_notifications",
      filter: "recipient_member_id=eq." + memberId,
    },
    schedule,
  );
  channel.subscribe((value) => {
    if (stopped) return;
    status(value === "SUBSCRIBED" ? "متصل" : "تحديث دوري");
    if (value === "SUBSCRIBED") schedule();
  });
  const resume = () => {
    if (document.visibilityState === "visible") schedule();
  };
  const online = () => {
    status("جارٍ الاتصال");
    schedule();
  };
  const offline = () => status("غير متصل");
  const interval = setInterval(() => {
    if (document.visibilityState === "visible" && navigator.onLine) schedule();
  }, 20000);
  window.addEventListener("online", online);
  window.addEventListener("offline", offline);
  document.addEventListener("visibilitychange", resume);
  return () => {
    stopped = true;
    clearTimeout(debounce);
    clearInterval(interval);
    window.removeEventListener("online", online);
    window.removeEventListener("offline", offline);
    document.removeEventListener("visibilitychange", resume);
    void client.removeChannel(channel);
  };
}
