import {
  createPasswordDigest,
  randomToken,
  sha256Hex,
  verifyLegacyPassword,
  verifyPasswordDigest,
} from "../_shared/password_security.ts";

type JsonObject = Record<string, unknown>;
type Credential = JsonObject & {
  credential_version: number;
  auth_password_version: number;
  password_digest: string | null;
  legacy_password_hash: string | null;
  legacy_password_salt: string | null;
};

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
};
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function response(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json; charset=utf-8" },
  });
}

function requiredString(body: JsonObject, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.trim() === "") throw new Error("invalid_request");
  return value.trim();
}

async function rpc<T>(name: string, params: JsonObject): Promise<T> {
  const result = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(params),
  });
  if (!result.ok) {
    let backendCode = "unknown";
    try {
      const payload = await result.json() as JsonObject;
      if (typeof payload.code === "string") backendCode = payload.code;
    } catch { /* Keep the generic classification. */ }
    throw new Error(`rpc_${result.status}_${backendCode}`);
  }
  const text = await result.text();
  return (text === "" ? undefined : JSON.parse(text)) as T;
}

async function authenticatedUser(request: Request): Promise<JsonObject> {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) throw new Error("authentication_required");
  const result = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization },
  });
  if (!result.ok) throw new Error("authentication_required");
  return await result.json() as JsonObject;
}

function memberEmail(memberId: string): string {
  return `maskan-${memberId.replace(/[^A-Za-z0-9_-]/gu, "_")}@auth.maskan.app`.toLowerCase();
}

async function authPassword(memberId: string, memberPassword: string): Promise<string> {
  return await sha256Hex(`MaskanAuthV2:${memberId}:${memberPassword.trim()}`);
}

async function updateAuthUser(
  userId: string,
  memberId: string,
  memberPassword: string,
  networkName: string,
): Promise<void> {
  const result = await fetch(`${supabaseUrl}/auth/v1/admin/users/${userId}`, {
    method: "PUT",
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      password: await authPassword(memberId, memberPassword),
      user_metadata: { maskan_network_name: networkName, maskan_member_id: memberId },
    }),
  });
  if (!result.ok) throw new Error("auth_sync_failed");
}

async function createAuthUser(
  memberId: string,
  memberPassword: string,
  networkName: string,
): Promise<string> {
  const result = await fetch(`${supabaseUrl}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      authorization: `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      email: memberEmail(memberId),
      password: await authPassword(memberId, memberPassword),
      email_confirm: true,
      user_metadata: { maskan_network_name: networkName, maskan_member_id: memberId },
    }),
  });
  if (!result.ok) {
    // Another verified concurrent login may have created the deterministic
    // technical identity after our lookup. Converge on it without exposing
    // whether an account existed to the caller.
    const existing = await rpc<string | null>("maskan_password_find_auth_user", {
      p_email: memberEmail(memberId),
    });
    if (existing === null) throw new Error("auth_sync_failed");
    await updateAuthUser(existing, memberId, memberPassword, networkName);
    return existing;
  }
  return requiredString(await result.json() as JsonObject, "id");
}

async function synchronizeMemberAuth(
  memberId: string,
  memberPassword: string,
  networkName: string,
  boundAuthUserId: string | null,
): Promise<string> {
  let authUserId = boundAuthUserId;
  if (authUserId === null) {
    authUserId = await rpc<string | null>("maskan_password_find_auth_user", {
      p_email: memberEmail(memberId),
    });
  }
  if (authUserId === null) return await createAuthUser(memberId, memberPassword, networkName);
  await updateAuthUser(authUserId, memberId, memberPassword, networkName);
  return authUserId;
}

async function verifyAndUpgrade(
  credential: Credential,
  password: string,
  upgradeRpc: "maskan_password_upgrade_member" | "maskan_password_upgrade_network",
  idKey: "p_member_id" | "p_network_id",
  id: string,
): Promise<string | null> {
  if (credential.credential_version >= 2) {
    if (credential.password_digest === null) return null;
    return await verifyPasswordDigest(password, credential.password_digest)
      ? credential.password_digest
      : null;
  }
  if (
    credential.legacy_password_hash === null || credential.legacy_password_salt === null ||
    !verifyLegacyPassword(password, credential.legacy_password_salt, credential.legacy_password_hash)
  ) return null;
  const modernDigest = await createPasswordDigest(password);
  const upgraded = await rpc<boolean>(upgradeRpc, {
    [idKey]: id,
    p_expected_legacy_hash: credential.legacy_password_hash,
    p_modern_digest: modernDigest,
  });
  if (upgraded) return modernDigest;

  const rows = idKey === "p_member_id"
    ? await rpc<Credential[]>("maskan_password_lookup_member", {
      p_network_name: String(credential.network_name),
      p_member_name: "",
      p_member_id: id,
    })
    : await rpc<Credential[]>("maskan_password_lookup_network", {
      p_network_id: id,
      p_network_name: "",
    });
  const current = rows[0];
  if (current?.credential_version >= 2 && current.password_digest !== null &&
    await verifyPasswordDigest(password, current.password_digest)) return current.password_digest;
  return null;
}

async function createNetwork(request: Request, body: JsonObject): Promise<JsonObject> {
  const user = await authenticatedUser(request);
  try {
    const rows = await rpc<JsonObject[]>("maskan_password_create_network", {
      p_auth_user_id: requiredString(user, "id"),
      p_network_id: requiredString(body, "networkId"),
      p_member_id: requiredString(body, "memberId"),
      p_network_name: requiredString(body, "networkName"),
      p_member_name: requiredString(body, "memberName"),
      p_network_password_digest: await createPasswordDigest(requiredString(body, "networkPassword")),
      p_member_password_digest: await createPasswordDigest(requiredString(body, "memberPassword")),
      p_currency_code: requiredString(body, "currencyCode"),
      p_currency_symbol: requiredString(body, "currencySymbol"),
    });
    return { ok: true, ...rows[0] };
  } catch (error) {
    if (error instanceof Error && error.message.endsWith("_23505")) {
      return { ok: false, code: "duplicate_network" };
    }
    throw error;
  }
}

async function joinNetwork(request: Request, body: JsonObject): Promise<JsonObject> {
  const user = await authenticatedUser(request);
  const requestedId = typeof body.networkId === "string" && body.networkId.trim() !== ""
    ? body.networkId.trim()
    : null;
  const credentialRows = await rpc<Credential[]>("maskan_password_lookup_network", {
    p_network_id: requestedId,
    p_network_name: requiredString(body, "networkName"),
  });
  const credential = credentialRows[0];
  if (credential === undefined) return { ok: false, code: "invalid_credentials" };
  const digest = await verifyAndUpgrade(
    credential,
    requiredString(body, "networkPassword"),
    "maskan_password_upgrade_network",
    "p_network_id",
    String(credential.network_id),
  );
  if (digest === null) return { ok: false, code: "invalid_credentials" };
  try {
    const rows = await rpc<JsonObject[]>("maskan_password_join_network", {
      p_auth_user_id: requiredString(user, "id"),
      p_network_id: String(credential.network_id),
      p_member_id: requiredString(body, "memberId"),
      p_member_name: requiredString(body, "memberName"),
      p_member_password_digest: await createPasswordDigest(requiredString(body, "memberPassword")),
      p_verified_network_digest: digest,
    });
    return { ok: true, ...rows[0] };
  } catch (error) {
    if (error instanceof Error && error.message.endsWith("_23505")) {
      return { ok: false, code: "duplicate_member" };
    }
    throw error;
  }
}

async function verifyMember(body: JsonObject): Promise<JsonObject> {
  const password = requiredString(body, "memberPassword");
  const rows = await rpc<Credential[]>("maskan_password_lookup_member", {
    p_network_name: requiredString(body, "networkName"),
    p_member_name: requiredString(body, "memberName"),
    p_member_id: null,
  });
  const credential = rows[0];
  if (credential === undefined) return { ok: false, code: "invalid_credentials" };
  if (await verifyAndUpgrade(
    credential,
    password,
    "maskan_password_upgrade_member",
    "p_member_id",
    String(credential.member_id),
  ) === null) return { ok: false, code: "invalid_credentials" };

  const effectiveCredentialVersion = Math.max(credential.credential_version, 2);
  let authUserId = credential.auth_user_id === null ? null : String(credential.auth_user_id);
  if (authUserId === null || credential.auth_password_version < effectiveCredentialVersion) {
    authUserId = await synchronizeMemberAuth(String(credential.member_id), password, String(credential.network_name), authUserId);
    await rpc<void>("maskan_password_mark_auth_synced", {
      p_member_id: String(credential.member_id), p_credential_version: effectiveCredentialVersion,
    });
  }
  if (authUserId === null) throw new Error("auth_sync_failed");
  const claimToken = randomToken();
  await rpc<void>("maskan_password_issue_claim", {
    p_member_id: String(credential.member_id),
    p_auth_user_id: authUserId,
    p_token_hash: await sha256Hex(claimToken),
  });
  return {
    ok: true,
    networkId: credential.network_id,
    networkName: credential.network_name,
    memberId: credential.member_id,
    memberName: credential.member_name,
    claimToken,
  };
}

async function resetMember(request: Request, body: JsonObject): Promise<JsonObject> {
  const user = await authenticatedUser(request);
  const callerId = requiredString(user, "id");
  const networkId = requiredString(body, "networkId");
  const adminMemberId = requiredString(body, "adminMemberId");
  const targetMemberId = requiredString(body, "targetMemberId");
  const password = requiredString(body, "newPassword");
  if (password.length < 4) return { ok: false, code: "password_too_short" };
  const contexts = await rpc<JsonObject[]>("maskan_password_reset_context", {
    p_caller_auth_user_id: callerId,
    p_network_id: networkId,
    p_admin_member_id: adminMemberId,
    p_target_member_id: targetMemberId,
  });
  const context = contexts[0];
  if (context === undefined) return { ok: false, code: "reset_denied" };
  const rows = await rpc<JsonObject[]>("maskan_password_reset_member", {
    p_caller_auth_user_id: callerId,
    p_network_id: networkId,
    p_admin_member_id: adminMemberId,
    p_target_member_id: targetMemberId,
    p_modern_digest: await createPasswordDigest(password),
  });
  const member = rows[0];
  if (member === undefined) throw new Error("reset_failed");
  await synchronizeMemberAuth(
    targetMemberId, password, String(context.network_name),
    context.target_auth_user_id === null ? null : String(context.target_auth_user_id),
  );
  await rpc<void>("maskan_password_mark_auth_synced", {
    p_member_id: targetMemberId,
    p_credential_version: Number(member.credential_version),
  });
  return { ok: true, member };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST" || supabaseUrl === "" || anonKey === "" || serviceRoleKey === "") {
    return response({ ok: false, code: "invalid_request" }, 400);
  }
  try {
    const body = await request.json() as JsonObject;
    const action = requiredString(body, "action");
    if (action === "create_network") return response(await createNetwork(request, body));
    if (action === "join_network") return response(await joinNetwork(request, body));
    if (action === "verify_member") return response(await verifyMember(body));
    if (action === "reset_member_password") return response(await resetMember(request, body));
    return response({ ok: false, code: "invalid_request" }, 400);
  } catch (error) {
    // Log only a controlled internal classification. Request bodies,
    // plaintext passwords, tokens, digests, and backend response bodies are
    // intentionally never included.
    console.error(`maskan-password failure: ${error instanceof Error ? error.message : "unknown"}`);
    const code = error instanceof Error && error.message === "authentication_required"
      ? "authentication_required"
      : "operation_failed";
    return response({ ok: false, code });
  }
});
