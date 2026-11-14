import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';

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
 *   - In production the allow-list must be explicitly configured.
 *   - Non-production may run without an allow-list (CORS disabled) to avoid
 *     blocking local tooling, but any configured list is still validated.
 */
export function resolveAllowedOrigins(
  raw: string | undefined = process.env.ALLOWED_ORIGINS,
  nodeEnv: string = process.env.NODE_ENV ?? 'development',
): string[] | false {
  const isProduction = nodeEnv === 'production';

  if (!raw || raw.trim().length === 0) {
    if (isProduction) {
      throw new Error(
        'FATAL: ALLOWED_ORIGINS is not configured. CORS must be explicitly restricted in production. Set a comma-separated list of trusted origins.',
      );
    }
    return false;
  }

  const origins = raw
    .split(',')
    .map((o) => o.trim())
    .filter((o) => o.length > 0);

  if (origins.length === 0) {
    if (isProduction) {
      throw new Error(
        'FATAL: ALLOWED_ORIGINS resolved to an empty list. CORS must be explicitly restricted in production.',
      );
    }
    return false;
  }

  const invalid = origins.filter((o) => o === '*' || !/^https?:\/\//i.test(o));
  if (invalid.length > 0) {
    throw new Error(
      'FATAL: ALLOWED_ORIGINS contains invalid entries. Use an explicit comma-separated list of http(s) origins only; wildcard origins are not permitted.',
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
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(helmet());

  app.enableCors(resolveCorsConfig());

  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}

if (require.main === module) {
  void bootstrap();
}
