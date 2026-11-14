import * as crypto from 'crypto';

/**
 * Stage 1 — account-number hashing (review finding).
 *
 * Plain SHA-256 of an account number is offline-brute-forceable: Ethiopian
 * bank account numbers are 8-13 digits (10^8 - 10^13 keyspace), so an
 * attacker who leaks the database can enumerate candidates and recover the
 * numbers. Matching therefore uses KEYED HMAC-SHA-256 instead, with a
 * dedicated server-side secret.
 *
 * Storage format: "hmac-v1:<hex>" — the algorithm version is embedded so
 * that future secret rotations or algorithm changes can be handled without
 * silently breaking matching.
 *
 * ENVIRONMENT REQUIREMENTS:
 *   - ACCOUNT_HASH_SECRET must be a long random string (>= 32 bytes).
 *     It is generated with: openssl rand -base64 48
 *   - Production startup FAILS FAST if it is missing or too short.
 *   - The secret exists ONLY on the server (env / secret manager). It is
 *     never sent to the Flutter app, never included in API responses and
 *     never logged.
 *
 * BACKUP / ROTATION REQUIREMENTS (documented for operations):
 *   - Back up the secret alongside database backups: without it, stored
 *     hashes are useless and full-number matching degrades to weaker
 *     heuristics (suffix/masked-tail/name).
 *   - Rotation: compute new hashes under the new secret with
 *     scripts/backfill-account-hashes.ts (run AFTER the new secret is in
 *     place; it overwrites accountNumberHash). Never delete legacy
 *     account data until the replacement hash is verified.
 */
export const ACCOUNT_HASH_PREFIX = 'hmac-v1:';

export function normalizeAccountNumber(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const out = value.replace(/[\s\-_]/g, '');
  return out.length ? out : null;
}

/**
 * Compute the versioned HMAC-SHA-256 hash of a normalized account number.
 * Throws if called without a usable secret — callers must fail closed.
 */
export function computeAccountNumberHash(
  accountNumber: string | null | undefined,
  secret: string,
): string | null {
  if (!secret || secret.length < 32) {
    throw new Error(
      'ACCOUNT_HASH_SECRET is missing or too short (require >= 32 chars). Refusing to compute account hashes with a weak key.',
    );
  }
  const normalized = normalizeAccountNumber(accountNumber);
  if (!normalized) return null;
  const digest = crypto
    .createHmac('sha256', secret)
    .update(normalized)
    .digest('hex');
  return `${ACCOUNT_HASH_PREFIX}${digest}`;
}

export function parseAccountHashVersion(
  stored: string | null | undefined,
): string | null {
  if (!stored) return null;
  if (stored.startsWith(ACCOUNT_HASH_PREFIX)) return 'hmac-v1';
  // Unknown/legacy format (e.g. plain sha256 from an earlier build).
  return null;
}
