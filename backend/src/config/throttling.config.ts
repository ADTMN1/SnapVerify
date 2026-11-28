/**
 * Rate-limiting configuration (Stage 1 — verification endpoint security).
 *
 * All values are positive integers validated at startup; invalid values fail
 * fast with a FATAL error, matching the application's existing startup
 * validation style (see resolveAllowedOrigins in main.ts).
 *
 * Time-to-live is expressed in MILLISECONDS, as required by
 * @nestjs/throttler v6 (ttl is ms, not seconds).
 */

export interface ThrottlingConfig {
  /** Window size for every rate-limit bucket, in milliseconds. */
  ttlMs: number;
  /** Default requests-per-window for all routes (per organization, or per IP when unauthenticated). */
  defaultLimit: number;
  /** POST /payments/verify requests-per-window (per organization). */
  paymentVerifyLimit: number;
  /**
   * POST /payments/verify-image requests-per-window (per organization).
   * Intentionally stricter than the reference endpoint: each call uploads a
   * file and can trigger upstream OCR plus one upstream verification call per
   * registered payment account.
   */
  paymentVerifyImageLimit: number;
  /**
   * GET /qr/resolve/:publicId requests-per-window (per organization).
   * Bounds QR enumeration attempts from a scanned/forged code.
   */
  qrResolveLimit: number;
}

/**
 * Window used by the per-route @Throttle() decorators on public auth routes.
 * Kept here so auth limits share the single documented millisecond unit.
 */
export const AUTH_THROTTLE_TTL_MS = 60_000;

const DEFAULTS: ThrottlingConfig = {
  ttlMs: AUTH_THROTTLE_TTL_MS,
  defaultLimit: 100,
  paymentVerifyLimit: 60,
  paymentVerifyImageLimit: 30,
  qrResolveLimit: 60,
};

function parsePositiveInt(
  env: Record<string, string | undefined>,
  name: string,
  fallback: number,
): number {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(
      `FATAL: ${name} must be a positive integer (got "${raw}"). ` +
        `Remove the variable to use the safe default of ${fallback}.`,
    );
  }
  return value;
}

export function resolveThrottlingConfig(
  env: Record<string, string | undefined> = process.env,
): ThrottlingConfig {
  return {
    ttlMs: parsePositiveInt(env, 'THROTTLE_TTL_MS', DEFAULTS.ttlMs),
    defaultLimit: parsePositiveInt(
      env,
      'THROTTLE_LIMIT',
      DEFAULTS.defaultLimit,
    ),
    paymentVerifyLimit: parsePositiveInt(
      env,
      'PAYMENT_VERIFY_RATE_LIMIT',
      DEFAULTS.paymentVerifyLimit,
    ),
    paymentVerifyImageLimit: parsePositiveInt(
      env,
      'PAYMENT_VERIFY_IMAGE_RATE_LIMIT',
      DEFAULTS.paymentVerifyImageLimit,
    ),
    qrResolveLimit: parsePositiveInt(
      env,
      'QR_RESOLVE_RATE_LIMIT',
      DEFAULTS.qrResolveLimit,
    ),
  };
}
