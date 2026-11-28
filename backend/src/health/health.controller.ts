import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '../auth/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';

/** Body returned when the service and its database are reachable. */
export interface HealthResponse {
  status: 'ok';
  database: 'up';
  uptime: number;
}

/** Body returned when the database cannot be reached. */
export interface UnhealthyResponse {
  status: 'error';
  database: 'down';
}

/**
 * Readiness probe for the hosting platform (Render health check).
 *
 * Deliberately avoids leaking internals: no connection strings, driver
 * messages, error codes, row counts or versions are returned — only a coarse
 * status, and the process uptime for debugging restarts.
 *
 * Rate limiting is skipped so that platform health checks can never be
 * throttled into 429s (which the platform would read as "unhealthy").
 */
@Controller('health')
@Public()
@SkipThrottle()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async check(): Promise<HealthResponse> {
    const databaseUp = await this.prisma.isHealthy();
    if (!databaseUp) {
      const body: UnhealthyResponse = { status: 'error', database: 'down' };
      throw new ServiceUnavailableException(body);
    }

    return {
      status: 'ok',
      database: 'up',
      uptime: Math.floor(process.uptime()),
    };
  }
}
