import {
  randomToken,
  sha256Hex,
  verifyLegacyPassword,
  verifyPasswordDigest,
} from "../_shared/password_security.ts";

type JsonObject = Record<string, unknown>;
type DeletionContext = JsonObject & {
  member_id: string;
  network_id: string;
  network_name: string;
  member_count: number;
  is_owner: boolean;
};
type Credential = JsonObject & {
  auth_user_id: string | null;
  credential_version: number;
  password_digest: string | null;
  legacy_password_hash: string | null;
  legacy_password_salt: string | null;
};
type RateLimitDecision = JsonObject & {
  allowed: boolean;
  retry_after_seconds: number;
};

class ControlledFailure extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    readonly retryAfterSeconds?: number,
  ) {
    super(code);
  }
}

class RpcFailure extends Error {
  constructor(
    readonly classification: string,
    readonly backendMessage: string,
  ) {
    super(classification);
  }
}

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
};
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const avatarBucket = "member-avatars";

function response(
  body: JsonObject,
  status = 200,
  headers: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json; charset=utf-8",
      ...headers,
    },
  });
}

function requiredString(body: JsonObject, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new ControlledFailure("invalid_request", 400);
  }
  return value.trim();
}

function authorizationHeader(request: Request): string {
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) {
    throw new ControlledFailure("authentication_required", 401);
  }
  return authorization;
}

async function authenticatedUser(request: Request): Promise<JsonObject> {
  const authorization = authorizationHeader(request);
  const result = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { apikey: anonKey, authorization },
  });
  if (!result.ok) {
    throw new ControlledFailure("authentication_required", 401);
  }
  return await result.json() as JsonObject;
}

async function rpc<T>(
  name: string,
  params: JsonObject,
  authorization: string,
  apiKey: string,
): Promise<T> {
  const result = await fetch(`${supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: apiKey,
      authorization,
      "content-type": "application/json",
    },
    body: JSON.stringify(params),
  });
  if (!result.ok) {
    let backendCode = "unknown";
    let backendMessage = "unknown";
    try {
      const payload = await result.json() as JsonObject;
      if (typeof payload.code === "string") backendCode = payload.code;
      if (typeof payload.message === "string") {
        backendMessage = payload.message;
      }
    } catch {
      // The controlled classification below is sufficient for logs and clients.
    }
    throw new RpcFailure(
      `rpc_${name}_${result.status}_${backendCode}`,
      backendMessage,
    );
  }
  const text = await result.text();
  return (text === "" ? undefined : JSON.parse(text)) as T;
}

async function userRpc<T>(
  request: Request,
  name: string,
  params: JsonObject = {},
): Promise<T> {
  return await rpc<T>(
    name,
    params,
    authorizationHeader(request),
    anonKey,
  );
}

async function serviceRpc<T>(
  name: string,
  params: JsonObject,
): Promise<T> {
  return await rpc<T>(
    name,
    params,
    `Bearer ${serviceRoleKey}`,
    serviceRoleKey,
  );
}

function userMetadata(user: JsonObject): JsonObject {
  const metadata = user.user_metadata;
  return metadata !== null && typeof metadata === "object"
    ? metadata as JsonObject
    : {};
}

async function accountContext(
  request: Request,
): Promise<DeletionContext | null> {
  try {
    const rows = await userRpc<DeletionContext[]>(
      request,
      "maskan_account_deletion_context",
    );
    return rows[0] ?? null;
  } catch (error) {
    if (
      error instanceof RpcFailure &&
      error.backendMessage === "account_not_found"
    ) {
      return null;
    }
    throw error;
  }
}

async function enforceRateLimit(request: Request): Promise<void> {
  const rows = await userRpc<RateLimitDecision[]>(
    request,
    "maskan_account_deletion_rate_limit_check",
  );
  const decision = rows[0];
  if (decision === undefined || decision.allowed !== true) {
    throw new ControlledFailure(
      "rate_limited",
      429,
      Math.max(1, Number(decision?.retry_after_seconds ?? 300)),
    );
  }
}

async function recordFailedReauthentication(request: Request): Promise<void> {
  await userRpc<void>(
    request,
    "maskan_account_deletion_rate_limit_failure",
  );
}

function authPassword(memberId: string, memberPassword: string): Promise<string> {
  return sha256Hex(
    `MaskanAuthV2:${memberId}:${memberPassword.trim()}`,
  );
}

async function reauthenticate(
  user: JsonObject,
  memberId: string,
  memberPassword: string,
): Promise<boolean> {
  const email = requiredString(user, "email");
  const result = await fetch(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: {
        apikey: anonKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        email,
        password: await authPassword(memberId, memberPassword),
      }),
    },
  );
  if (!result.ok) return false;
  const payload = await result.json() as JsonObject;
  const verifiedUser = payload.user;
  return verifiedUser !== null &&
    typeof verifiedUser === "object" &&
    (verifiedUser as JsonObject).id === user.id;
}

async function verifyApplicationCredential(
  context: DeletionContext,
  authUserId: string,
  memberPassword: string,
): Promise<boolean> {
  const rows = await serviceRpc<Credential[]>(
    "maskan_password_lookup_member",
    {
      p_network_name: context.network_name,
      p_member_name: "",
      p_member_id: context.member_id,
    },
  );
  const credential = rows[0];
  if (
    credential === undefined ||
    credential.auth_user_id !== authUserId
  ) {
    return false;
  }
  if (credential.credential_version >= 2) {
    return credential.password_digest !== null &&
      await verifyPasswordDigest(
        memberPassword,
        credential.password_digest,
      );
  }
  return credential.legacy_password_hash !== null &&
    credential.legacy_password_salt !== null &&
    verifyLegacyPassword(
      memberPassword,
      credential.legacy_password_salt,
      credential.legacy_password_hash,
    );
}

function storageHeaders(): HeadersInit {
  return {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
    "content-type": "application/json",
  };
}

async function deleteAvatarObjects(
  networkId: string,
  memberId: string,
): Promise<void> {
  const prefix = `${networkId}/${memberId}`;
  for (let batch = 0; batch < 1000; batch += 1) {
    const listed = await fetch(
      `${supabaseUrl}/storage/v1/object/list/${avatarBucket}`,
      {
        method: "POST",
        headers: storageHeaders(),
        body: JSON.stringify({
          prefix,
          limit: 100,
          offset: 0,
          sortBy: { column: "name", order: "asc" },
        }),
      },
    );
    if (!listed.ok) throw new ControlledFailure("storage_delete_failed", 500);
    const entries = await listed.json() as JsonObject[];
    const paths = entries
      .map((entry) => entry.name)
      .filter((name): name is string =>
        typeof name === "string" && name.trim() !== ""
      )
      .map((name) => `${prefix}/${name}`);
    if (paths.length === 0) return;

    const removed = await fetch(
      `${supabaseUrl}/storage/v1/object/${avatarBucket}`,
      {
        method: "DELETE",
        headers: storageHeaders(),
        body: JSON.stringify({ prefixes: paths }),
      },
    );
    if (!removed.ok) throw new ControlledFailure("storage_delete_failed", 500);
  }
  throw new ControlledFailure("storage_delete_failed", 500);
}

async function authorizeDeletion(
  authUserId: string,
): Promise<string> {
  const token = randomToken();
  await serviceRpc<void>("maskan_authorize_account_deletion", {
    p_auth_user_id: authUserId,
    p_token_hash: await sha256Hex(token),
  });
  return token;
}

async function deleteDatabaseData(
  request: Request,
  deletionToken: string,
  confirmNetworkDeletion: boolean,
): Promise<void> {
  try {
    await userRpc<JsonObject[]>(request, "maskan_delete_account_data", {
      p_deletion_token: deletionToken,
      p_confirm_network_deletion: confirmNetworkDeletion,
    });
  } catch (error) {
    if (error instanceof RpcFailure) {
      if (error.backendMessage === "owner_transfer_required") {
        throw new ControlledFailure("owner_transfer_required", 409);
      }
      if (error.backendMessage === "network_confirmation_required") {
        throw new ControlledFailure("network_confirmation_required", 409);
      }
      if (error.backendMessage === "reauthentication_required") {
        throw new ControlledFailure("reauthentication_required", 401);
      }
    }
    throw error;
  }
}

async function deleteAuthUser(authUserId: string): Promise<void> {
  const result = await fetch(
    `${supabaseUrl}/auth/v1/admin/users/${encodeURIComponent(authUserId)}`,
    {
      method: "DELETE",
      headers: {
        apikey: serviceRoleKey,
        authorization: `Bearer ${serviceRoleKey}`,
      },
    },
  );
  if (!result.ok) throw new ControlledFailure("auth_delete_failed", 500);
}

async function deleteAccount(
  request: Request,
  body: JsonObject,
): Promise<JsonObject> {
  const user = await authenticatedUser(request);
  const authUserId = requiredString(user, "id");
  const memberPassword = requiredString(body, "memberPassword");
  const confirmNetworkDeletion = body.confirmNetworkDeletion === true;

  await enforceRateLimit(request);
  const context = await accountContext(request);
  const metadataMemberId = requiredString(
    userMetadata(user),
    "maskan_member_id",
  );
  const memberId = context?.member_id ?? metadataMemberId;
  if (context !== null && context.member_id !== metadataMemberId) {
    throw new ControlledFailure("account_identity_mismatch", 409);
  }
  if (context?.is_owner === true && Number(context.member_count) > 1) {
    throw new ControlledFailure("owner_transfer_required", 409);
  }
  if (
    context !== null &&
    Number(context.member_count) === 1 &&
    !confirmNetworkDeletion
  ) {
    throw new ControlledFailure("network_confirmation_required", 409);
  }

  const reauthenticated = context === null
    ? await reauthenticate(user, memberId, memberPassword)
    : await verifyApplicationCredential(
      context,
      authUserId,
      memberPassword,
    );
  if (!reauthenticated) {
    await recordFailedReauthentication(request);
    throw new ControlledFailure("invalid_credentials", 401);
  }

  if (context !== null) {
    await deleteAvatarObjects(context.network_id, context.member_id);
    const deletionToken = await authorizeDeletion(authUserId);
    await deleteDatabaseData(
      request,
      deletionToken,
      confirmNetworkDeletion,
    );
  }

  // If a previous attempt removed database data but failed at Auth deletion,
  // context is null and this retry safely completes the remaining Auth step.
  await deleteAuthUser(authUserId);
  return { ok: true };
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response({ ok: false, code: "invalid_request" }, 400);
  }
  if (supabaseUrl === "" || anonKey === "" || serviceRoleKey === "") {
    console.error(
      "maskan-delete-account failure: runtime_configuration_missing",
    );
    return response({ ok: false, code: "operation_failed" }, 500);
  }

  try {
    const body = await request.json() as JsonObject;
    return response(await deleteAccount(request, body));
  } catch (error) {
    if (error instanceof ControlledFailure) {
      const headers = error.retryAfterSeconds === undefined
        ? {}
        : { "retry-after": String(error.retryAfterSeconds) };
      return response(
        {
          ok: false,
          code: error.code,
          ...(error.retryAfterSeconds === undefined
            ? {}
            : { retryAfterSeconds: error.retryAfterSeconds }),
        },
        error.status,
        headers,
      );
    }
    // Never log request bodies, passwords, tokens, user ids, storage paths,
    // backend response bodies, or credential material.
    const classification = error instanceof RpcFailure
      ? error.classification
      : "unclassified";
    console.error(`maskan-delete-account failure: ${classification}`);
    return response({ ok: false, code: "operation_failed" }, 500);
  }
});
