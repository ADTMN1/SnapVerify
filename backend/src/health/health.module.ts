import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

/**
 * Readiness probe module. `PrismaService` comes from the global PrismaModule.
 */
@Module({
  controllers: [HealthController],
})
export class HealthModule {}
