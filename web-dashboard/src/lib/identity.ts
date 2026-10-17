export function memberEmail(id: string) {
  return (
    "maskan-" +
    id.replace(/[^A-Za-z0-9_-]/g, "_") +
    "@auth.maskan.app"
  ).toLowerCase();
}
export async function memberSecret(id: string, password: string) {
  const bytes = new TextEncoder().encode(
    "MaskanAuthV2:" + id + ":" + password.trim(),
  );
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}
