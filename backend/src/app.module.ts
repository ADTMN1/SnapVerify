import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { join } from 'path';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { OtpModule } from './otp/otp.module';
import { PaymentModule } from './payment/payment.module';
import { BranchModule } from './branch/branch.module';
import { AdminModule } from './admin/admin.module';
import { OrgThrottlerGuard } from './auth/guards/org-throttler.guard';
import { resolveThrottlingConfig } from './config/throttling.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        '.env',
        'backend/.env',
        join(__dirname, '..', '.env'),
      ],
    }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: () => {
        const cfg = resolveThrottlingConfig(process.env);
        return {
          throttlers: [
            // ttl is in MILLISECONDS (@nestjs/throttler v6).
            { name: 'default', ttl: cfg.ttlMs, limit: cfg.defaultLimit },
          ],
        };
      },
    }),
    PrismaModule,
    AuthModule,
    OtpModule,
    PaymentModule,
    BranchModule,
    AdminModule,
  ],
  providers: [
    // Global rate limiting. Registered BEFORE JwtAuthGuard (which is applied
    // per-controller), so unauthenticated requests are throttled by IP before
    // any handler or guard work; authenticated requests are tracked per
    // organization by OrgThrottlerGuard (see its documentation).
    { provide: APP_GUARD, useClass: OrgThrottlerGuard },
  ],
})
export class AppModule {}
