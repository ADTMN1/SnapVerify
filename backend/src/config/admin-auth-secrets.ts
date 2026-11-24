import { ConfigService } from '@nestjs/config';

type SecretReader = Pick<ConfigService, 'get' | 'getOrThrow'>;

const MIN_SECRET_LENGTH = 32;

function requireSecret(config: SecretReader, key: string): string {
  const value = config.getOrThrow<string>(key);
  if (!value || value.trim().length < MIN_SECRET_LENGTH) {
    throw new Error(
      `FATAL: ${key} is required and must be at least ${MIN_SECRET_LENGTH} characters.`,
    );
  }
  return value.trim();
}

export function resolveAdminAuthSecrets(config: SecretReader) {
  const accessSecret = requireSecret(config, 'JWT_ADMIN_ACCESS_SECRET');
  const refreshSecret = requireSecret(config, 'JWT_ADMIN_REFRESH_SECRET');

  const appSecrets = [
    config.get<string>('JWT_ACCESS_SECRET')?.trim(),
    config.get<string>('JWT_REFRESH_SECRET')?.trim(),
  ].filter((value): value is string => Boolean(value));

  if (accessSecret === refreshSecret) {
    throw new Error('FATAL: admin JWT secrets must be distinct.');
  }

  if (appSecrets.includes(accessSecret) || appSecrets.includes(refreshSecret)) {
    throw new Error(
      'FATAL: admin JWT secrets must be distinct from application JWT secrets.',
    );
  }

  return { accessSecret, refreshSecret };
}
