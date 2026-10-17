import { createClient, type SupabaseClient } from "@supabase/supabase-js";
let client: SupabaseClient | undefined;
export function getClient() {
  if (client) return client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (
    !url ||
    !key ||
    key.startsWith("replace-") ||
    key.startsWith("sb_secret_")
  )
    throw new Error("configuration_required");
  if (key.startsWith("sb_publishable_"))
    throw new Error("legacy_anon_required");
  if (key.startsWith("eyJ")) {
    try {
      if (
        JSON.parse(
          atob(key.split(".")[1].replaceAll("-", "+").replaceAll("_", "/")),
        ).role !== "anon"
      )
        throw new Error();
    } catch {
      throw new Error("configuration_required");
    }
  } else if (!key.startsWith("sb_publishable_"))
    throw new Error("configuration_required");
  client = createClient(url, key, {
    global: {
      fetch: (input, init) => fetch(input, { ...init, cache: "no-store" }),
    },
    auth: {
      storage: window.sessionStorage,
      storageKey: "maskan-web-session",
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
    },
  });
  return client;
}
