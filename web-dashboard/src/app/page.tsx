"use client";
import { useSyncExternalStore } from "react";
import { Dashboard } from "@/components/dashboard";
const subscribe = () => () => {};
export default function Page() {
  const mounted = useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );
  return mounted ? (
    <Dashboard />
  ) : (
    <main className="loading" aria-busy="true">
      جارٍ تحميل مسكن…
    </main>
  );
}
