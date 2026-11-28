/**
 * Production environment validation.
 *
 * Runs once inside `ConfigModule.forRoot({ validate })`, i.e. BEFORE the
 * application starts listening. A misconfigured production deploy therefore
 * fails on boot instead of silently degrading (e.g. registration appearing to
 * succeed while no OTP email is ever delivered).
 *
 * Development and test environments are intentionally left permissive so the
 * existing granular validators (CORS in main.ts, JWT/JwtService,
 * ACCOUNT_HASH_SECRET, throttling) keep their current behavior.
 */

/** Variables the service cannot boot in production without. */
export const REQUIRED_PRODUCTION_VARS = [
  'DATABASE_URL',
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'JWT_ADMIN_ACCESS_SECRET',
  'JWT_ADMIN_REFRESH_SECRET',
  'ALLOWED_ORIGINS',
  'ACCOUNT_HASH_SECRET',
] as const;

/** Secrets that must be long enough to resist brute force. */
const SIGNING_SECRET_VARS = [
  'JWT_ACCESS_SECRET',
  'JWT_REFRESH_SECRET',
  'JWT_ADMIN_ACCESS_SECRET',
  'JWT_ADMIN_REFRESH_SECRET',
  'ACCOUNT_HASH_SECRET',
] as const;

const MIN_SECRET_LENGTH = 32;

/** URLs that must be valid HTTPS in production. */
const REQUIRED_HTTPS_URLS = [
  'APP_URL',
  'QR_PUBLIC_BASE_URL',
  'CHECK_ET_BASE_URL',
] as const;

const CHECK_ET_TIMEOUT_DEFAULT_MS = 45_000;
const CHECK_ET_TIMEOUT_MIN_MS = 5_000;
const CHECK_ET_TIMEOUT_MAX_MS = 120_000;

function value(config: Record<string, unknown>, key: string): string {
  const raw = config[key];
  return typeof raw === 'string' ? raw.trim() : '';
}

function isHttpsUrl(raw: string): boolean {
  try {
    const url = new URL(raw);
    return url.protocol === 'https:' && url.hostname.length > 0;
  } catch {
    return false;
  }
}

/**
 * Returns the list of production configuration problems (empty when healthy).
 * Exported separately so it can be unit-tested without throwing.
 */
export function collectProductionConfigErrors(
  config: Record<string, unknown>,
): string[] {
  const errors: string[] = [];

  for (const key of REQUIRED_PRODUCTION_VARS) {
    if (!value(config, key)) errors.push(`${key} is required`);
  }

  for (const key of SIGNING_SECRET_VARS) {
    const secret = value(config, key);
    if (secret && secret.length < MIN_SECRET_LENGTH) {
      errors.push(`${key} must be at least ${MIN_SECRET_LENGTH} characters`);
    }
  }

  const configuredSigningSecrets = SIGNING_SECRET_VARS.map((key) =>
    value(config, key),
  ).filter((secret) => secret.length > 0);
  if (
    new Set(configuredSigningSecrets).size !== configuredSigningSecrets.length
  ) {
    errors.push('JWT and account signing secrets must all be distinct');
  }

  // Email transport — without one, EmailService only logs messages to the
  // console, so OTP delivery, password reset and staff invitations would look
  // successful while nothing is ever sent.
  const hasBrevo = value(config, 'BREVO_API_KEY').length > 0;
  const hasSmtpHost = value(config, 'SMTP_HOST').length > 0;
  if (!hasBrevo && !hasSmtpHost) {
    errors.push(
      'Email delivery is not configured: set BREVO_API_KEY or SMTP_HOST ' +
        '(SMTP_USER/SMTP_PASS are required only for authenticated relays)',
    );
  }
  if (!value(config, 'EMAIL_FROM')) {
    errors.push(
      'EMAIL_FROM is required so verification and invitation emails have a sender',
    );
  }

  for (const key of REQUIRED_HTTPS_URLS) {
    const raw = value(config, key);
    if (!raw) {
      errors.push(`${key} is required`);
    } else if (!isHttpsUrl(raw)) {
      errors.push(
        `${key} must be a valid https:// URL (got a non-HTTPS value)`,
      );
    }
  }

  if (!value(config, 'CHECK_ET_API_KEY')) {
    errors.push('CHECK_ET_API_KEY is required for payment verification');
  }

  const timeoutRaw = value(config, 'CHECK_ET_TIMEOUT_MS');
  if (timeoutRaw) {
    const timeout = Number(timeoutRaw);
    if (
      !Number.isInteger(timeout) ||
      timeout < CHECK_ET_TIMEOUT_MIN_MS ||
      timeout > CHECK_ET_TIMEOUT_MAX_MS
    ) {
      errors.push(
        `CHECK_ET_TIMEOUT_MS must be an integer between ${CHECK_ET_TIMEOUT_MIN_MS} and ${CHECK_ET_TIMEOUT_MAX_MS}`,
      );
    }
  }

  return errors;
}

/**
 * `ConfigModule.forRoot({ validate })` entry point.
 *
 * Enforces strict rules for deployed environments (`production` and `staging`);
 * local development and test environments are returned untouched.
 */
export function validateEnvironment(
  config: Record<string, unknown>,
): Record<string, unknown> {
  const nodeEnv = value(config, 'NODE_ENV') || 'development';
  if (nodeEnv !== 'production' && nodeEnv !== 'staging') return config;

  const errors = collectProductionConfigErrors(config);
  if (errors.length > 0) {
    throw new Error(
      'FATAL: invalid production environment. Fix the following before deploying:\n' +
        errors.map((error) => `  - ${error}`).join('\n'),
    );
  }

  return {
    ...config,
    // Safe default for an optional tuning knob (the verification client also
    // falls back to this value); validated above when explicitly provided.
    CHECK_ET_TIMEOUT_MS:
      value(config, 'CHECK_ET_TIMEOUT_MS') ||
      String(CHECK_ET_TIMEOUT_DEFAULT_MS),
  };
}
