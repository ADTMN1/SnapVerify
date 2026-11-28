import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { lookup } from 'dns/promises';
import { isIP } from 'net';

interface CorsConfig {
  origin: string[] | false;
  credentials: boolean;
  methods: string[];
  allowedHeaders: string[];
}

/**
 * Parse and validate the CORS trusted-origin allow-list at startup.
 *
 * Security rules:
 *   - A wildcard ("*") origin is NEVER permitted.
 *   - In deployed environments the allow-list must be explicitly configured.
 *   - Local development may run without an allow-list (CORS disabled) to avoid
 *     blocking local tooling, but any configured list is still validated.
 */
export function resolveAllowedOrigins(
  raw: string | undefined = process.env.ALLOWED_ORIGINS,
  nodeEnv: string = process.env.NODE_ENV ?? 'development',
): string[] | false {
  const isStrict = nodeEnv === 'production' || nodeEnv === 'staging';

  if (!raw || raw.trim().length === 0) {
    if (isStrict) {
      throw new Error(
        'FATAL: ALLOWED_ORIGINS is not configured. CORS must be explicitly restricted in deployed environments. Set a comma-separated list of trusted origins.',
      );
    }
    return false;
  }

  const origins = raw
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);

  if (origins.length === 0) {
    if (isStrict) {
      throw new Error(
        'FATAL: ALLOWED_ORIGINS resolved to an empty list. CORS must be explicitly restricted in deployed environments.',
      );
    }
    return false;
  }

  const originPattern = isStrict ? /^https:\/\//i : /^https?:\/\//i;
  const invalid = origins.filter((o) => o === '*' || !originPattern.test(o));
  if (invalid.length > 0) {
    throw new Error(
      isStrict
        ? 'FATAL: ALLOWED_ORIGINS contains invalid entries. Deployed environments require explicit HTTPS origins; wildcard origins are not permitted.'
        : 'FATAL: ALLOWED_ORIGINS contains invalid entries. Use an explicit comma-separated list of http(s) origins only; wildcard origins are not permitted.',
    );
  }

  return origins;
}

export function resolveCorsConfig(
  env: NodeJS.ProcessEnv = process.env,
): CorsConfig {
  const allowedOrigins = resolveAllowedOrigins(
    env.ALLOWED_ORIGINS,
    env.NODE_ENV,
  );

  // This application authenticates via the Authorization: Bearer <token> header.
  // Cookies/credentialed cross-origin requests are not used, so credentials stay
  // disabled unless explicitly required with a valid explicit allow-list.
  const allowCredentials =
    env.ALLOW_CREDENTIALS === 'true' && Array.isArray(allowedOrigins);

  return {
    origin: allowedOrigins,
    credentials: allowCredentials,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
}

async function pinDatabaseIpv4() {
  const raw = process.env.DATABASE_URL;
  if (!raw) return;
  const url = new URL(raw);
  if (isIP(url.hostname)) {
    process.env.DATABASE_HOST_V4 = url.hostname;
    return;
  }
  try {
    const result = await lookup(url.hostname, { family: 4 });
    process.env.DATABASE_HOST_V4 = result.address;
  } catch {
    process.env.DATABASE_HOST_V4 = url.hostname;
  }
}

export function configureTrustProxy(app: NestExpressApplication) {
  app.set('trust proxy', 1);
}

async function bootstrap() {
  await pinDatabaseIpv4();
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  configureTrustProxy(app);
  app.use(helmet());

  app.enableCors(resolveCorsConfig());

  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}

if (require.main === module) {
  void bootstrap();
}
