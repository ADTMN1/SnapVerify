import {
  collectProductionConfigErrors,
  validateEnvironment,
} from './env.validation';

const VALID_PROD: Record<string, string> = {
  NODE_ENV: 'production',
  DATABASE_URL: 'postgresql://user:pass@host:5432/db',
  JWT_ACCESS_SECRET: 'a'.repeat(64),
  JWT_REFRESH_SECRET: 'b'.repeat(64),
  JWT_ADMIN_ACCESS_SECRET: 'd'.repeat(64),
  JWT_ADMIN_REFRESH_SECRET: 'e'.repeat(64),
  ACCOUNT_HASH_SECRET: 'c'.repeat(64),
  ALLOWED_ORIGINS: 'https://app.example.com',
  BREVO_API_KEY: 'xkeysib-test',
  EMAIL_FROM: 'SnapVerify <no-reply@example.com>',
  APP_URL: 'https://api.example.com',
  QR_PUBLIC_BASE_URL: 'https://api.example.com',
  CHECK_ET_BASE_URL: 'https://api.check.et',
  CHECK_ET_API_KEY: 'test-key',
};

describe('validateEnvironment', () => {
  it('is a no-op outside production', () => {
    expect(() =>
      validateEnvironment({ NODE_ENV: 'development' }),
    ).not.toThrow();
    expect(() => validateEnvironment({ NODE_ENV: 'test' })).not.toThrow();
    expect(() => validateEnvironment({})).not.toThrow();
  });

  it('enforces the same rules in staging', () => {
    const staging = { ...VALID_PROD, NODE_ENV: 'staging' };
    delete (staging as Record<string, string>).DATABASE_URL;
    expect(() => validateEnvironment(staging)).toThrow(/DATABASE_URL is required/);
  });

  it('accepts a complete production environment', () => {
    const result = validateEnvironment({ ...VALID_PROD });
    expect(result.CHECK_ET_TIMEOUT_MS).toBe('45000');
    expect(collectProductionConfigErrors(result)).toEqual([]);
  });

  it('fails fast when a boot variable is missing', () => {
    const env: Record<string, string> = { ...VALID_PROD };
    delete env.DATABASE_URL;
    expect(() => validateEnvironment(env)).toThrow(/DATABASE_URL is required/);
  });

  it('rejects weak signing secrets', () => {
    const env = { ...VALID_PROD, JWT_ACCESS_SECRET: 'short' };
    expect(() => validateEnvironment(env)).toThrow(/JWT_ACCESS_SECRET/);
  });

  it('fails fast when admin JWT secrets are missing', () => {
    const noAccess = { ...VALID_PROD };
    delete noAccess.JWT_ADMIN_ACCESS_SECRET;
    expect(() => validateEnvironment(noAccess)).toThrow(
      /JWT_ADMIN_ACCESS_SECRET is required/,
    );

    const noRefresh = { ...VALID_PROD };
    delete noRefresh.JWT_ADMIN_REFRESH_SECRET;
    expect(() => validateEnvironment(noRefresh)).toThrow(
      /JWT_ADMIN_REFRESH_SECRET is required/,
    );
  });

  it('rejects admin and application JWT secret reuse', () => {
    const env = {
      ...VALID_PROD,
      JWT_ADMIN_ACCESS_SECRET: VALID_PROD.JWT_ACCESS_SECRET,
    };
    expect(() => validateEnvironment(env)).toThrow(/must all be distinct/);
  });

  it('rejects identical admin JWT secrets', () => {
    const env = {
      ...VALID_PROD,
      JWT_ADMIN_REFRESH_SECRET: VALID_PROD.JWT_ADMIN_ACCESS_SECRET,
    };
    expect(() => validateEnvironment(env)).toThrow(/must all be distinct/);
  });

  it('refuses to boot without any email transport', () => {
    const env: Record<string, string> = { ...VALID_PROD };
    delete env.BREVO_API_KEY;
    expect(() => validateEnvironment(env)).toThrow(
      /Email delivery is not configured/,
    );
  });

  it('accepts SMTP as the email transport', () => {
    const env: Record<string, string> = {
      ...VALID_PROD,
      SMTP_HOST: 'smtp.example.com',
    };
    delete env.BREVO_API_KEY;
    expect(() => validateEnvironment(env)).not.toThrow();
  });

  it('rejects non-HTTPS public URLs', () => {
    const env = { ...VALID_PROD, QR_PUBLIC_BASE_URL: 'http://api.example.com' };
    expect(() => validateEnvironment(env)).toThrow(
      /QR_PUBLIC_BASE_URL must be a valid https/,
    );
  });

  it('rejects a malformed URL', () => {
    const env = { ...VALID_PROD, APP_URL: 'not-a-url' };
    expect(() => validateEnvironment(env)).toThrow(
      /APP_URL must be a valid https/,
    );
  });

  it('rejects an out-of-range Check.et timeout', () => {
    const env = { ...VALID_PROD, CHECK_ET_TIMEOUT_MS: '10' };
    expect(() => validateEnvironment(env)).toThrow(/CHECK_ET_TIMEOUT_MS/);
  });
});
