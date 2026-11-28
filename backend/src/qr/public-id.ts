import { randomBytes } from 'crypto';

/**
 * Public QR identifiers for payment accounts.
 *
 * Format: 24 lowercase hex characters (12 random bytes / 96 bits).
 *
 * Properties:
 *   - Opaque: generated independently of the account number, provider, branch
 *     or organization, so a scanned code cannot be reversed into banking data.
 *   - Stable: written exactly once, when the account is created, and never
 *     regenerated (see the QR migration and PaymentAccount.publicId).
 *   - Unique: enforced by a database unique index; callers retry on collisions.
 *
 * 96 bits keeps the value short enough for a scannable URL while making
 * accidental collisions infeasible (birthday bound ~ 7.9e14 identifiers).
 */
export const PUBLIC_ID_REGEX = /^[0-9a-f]{24}$/;

export const PUBLIC_ID_BYTES = 12;

export function generatePublicId(): string {
  return randomBytes(PUBLIC_ID_BYTES).toString('hex');
}

export function isValidPublicId(value: unknown): value is string {
  return typeof value === 'string' && PUBLIC_ID_REGEX.test(value);
}

/** True for a Prisma unique-constraint violation (P2002). */
export function isUniqueConstraintViolation(
  error: unknown,
  field?: string,
): boolean {
  if (!error || typeof error !== 'object') return false;
  const err = error as { code?: string; meta?: { target?: unknown } };
  if (err.code !== 'P2002') return false;
  if (!field) return true;
  const target = err.meta?.target;
  if (Array.isArray(target)) return target.includes(field);
  if (typeof target === 'string') return target.includes(field);
  // Prisma does not always populate `target`; treat it as the field we tried.
  return true;
}
