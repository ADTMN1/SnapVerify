import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  /** Upper bound for the readiness probe so /health cannot hang. */
  private static readonly HEALTH_TIMEOUT_MS = 3000;

  constructor() {
    // Strip sslmode from the connection string — we pass ssl config directly
    // to avoid pg's broken sslmode=require behavior in newer versions
    const url = new URL(process.env.DATABASE_URL ?? '');
    for (const key of [
      'sslmode',
      'channel_binding',
      'uselibpqcompat',
      'connect_timeout',
    ]) {
      url.searchParams.delete(key);
    }
    const connStr = url.toString();
    const pool = new Pool({
      connectionString: connStr,
      ssl: resolveSslConfig(),
    });
    const adapter = new PrismaPg(pool);
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  /**
   * Lightweight readiness probe used by GET /health.
   *
   * Runs a single `SELECT 1` with a bounded timeout and collapses every
   * failure to `false` — the caller must never surface driver errors (they can
   * contain host/port details) to an unauthenticated health-check client.
   */
  async isHealthy(): Promise<boolean> {
    let timer: NodeJS.Timeout | undefined;
    try {
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error('health check timed out')),
          PrismaService.HEALTH_TIMEOUT_MS,
        );
      });
      await Promise.race([this.$queryRaw`SELECT 1`, timeout]);
      return true;
    } catch {
      this.logger.warn('Health check: database is not reachable');
      return false;
    } finally {
      if (timer) clearTimeout(timer);
    }
  }
}

/**
 * Resolve the TLS configuration for the PostgreSQL pool.
 *
 * Defaults preserve the previous behavior (`rejectUnauthorized: false`), which
 * is what managed providers with private/self-signed CAs need.
 *
 * Tightening knobs (no default changes, so existing deployments keep working):
 *   - DATABASE_SSL_REJECT_UNAUTHORIZED=true
 *       Verify the server certificate against Node's trust store. Enable this
 *       only once the provider's certificate chain validates; otherwise a
 *       valid managed connection would be rejected.
 *   - DATABASE_SSL_CA=<PEM contents>
 *       Trust an explicit CA (typical for providers shipping their own root).
 *   - DATABASE_SSL=disable
 *       No TLS at all — for a local PostgreSQL during development only.
 */
function resolveSslConfig():
  false | { rejectUnauthorized: boolean; ca?: string } {
  const mode = (process.env.DATABASE_SSL ?? '').trim().toLowerCase();
  if (mode === 'disable') return false;

  const rejectUnauthorized =
    (process.env.DATABASE_SSL_REJECT_UNAUTHORIZED ?? '')
      .trim()
      .toLowerCase() === 'true';
  const ca = process.env.DATABASE_SSL_CA?.trim();

  return rejectUnauthorized && ca
    ? { rejectUnauthorized, ca }
    : { rejectUnauthorized };
}
