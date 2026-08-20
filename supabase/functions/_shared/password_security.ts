export const PBKDF2_ITERATIONS = 600_000;
export const PBKDF2_KEY_BYTES = 32;
export const PBKDF2_SALT_BYTES = 16;
export const MODERN_ALGORITHM = "pbkdf2-hmac-sha256-v1";

const encoder = new TextEncoder();

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function fromBase64Url(value: string): Uint8Array {
  const padded = value.replaceAll("-", "+").replaceAll("_", "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function constantTimeEqual(left: Uint8Array, right: Uint8Array): boolean {
  let difference = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    difference |= (left[index % left.length] ?? 0) ^ (right[index % right.length] ?? 0);
  }
  return difference === 0;
}

async function derive(password: string, salt: Uint8Array): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password.trim()),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt,
      iterations: PBKDF2_ITERATIONS,
    },
    key,
    PBKDF2_KEY_BYTES * 8,
  );
  return new Uint8Array(bits);
}

export async function createPasswordDigest(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(PBKDF2_SALT_BYTES));
  const digest = await derive(password, salt);
  return `$maskan$pbkdf2-sha256$v=1$i=${PBKDF2_ITERATIONS}$l=${PBKDF2_KEY_BYTES}` +
    `$${base64Url(salt)}$${base64Url(digest)}`;
}

export async function verifyPasswordDigest(
  password: string,
  encoded: string,
): Promise<boolean> {
  const parts = encoded.split("$");
  if (
    parts.length !== 8 || parts[1] !== "maskan" ||
    parts[2] !== "pbkdf2-sha256" || parts[3] !== "v=1" ||
    parts[4] !== `i=${PBKDF2_ITERATIONS}` ||
    parts[5] !== `l=${PBKDF2_KEY_BYTES}`
  ) return false;
  try {
    const salt = fromBase64Url(parts[6]);
    const expected = fromBase64Url(parts[7]);
    if (salt.length !== PBKDF2_SALT_BYTES || expected.length !== PBKDF2_KEY_BYTES) {
      return false;
    }
    return constantTimeEqual(await derive(password, salt), expected);
  } catch {
    return false;
  }
}

// Compatibility only: this exactly matches the old Dart 63-bit FNV routine.
// It must never be used to create a new credential.
export function verifyLegacyPassword(
  password: string,
  salt: string,
  expectedHash: string,
): boolean {
  const mask = 0x7fff_ffff_ffff_ffffn;
  const prime = 0x100000001b3n;
  let hash = 0xcbf29ce484222325n;
  const value = `${salt}:${password.trim()}`;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= BigInt(value.charCodeAt(index));
    hash = (hash * prime) & mask;
  }
  return hash.toString(16).padStart(16, "0") === expectedHash;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function randomToken(): string {
  return base64Url(crypto.getRandomValues(new Uint8Array(32)));
}
