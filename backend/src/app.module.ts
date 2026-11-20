import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { join } from 'path';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { SmsModule } from './sms/sms.module';
import { EmailModule } from './email/email.module';
import { OtpModule } from './otp/otp.module';
import { PaymentModule } from './payment/payment.module';
import { ReportsModule } from './reports/reports.module';
import { NotificationsModule } from './notifications/notifications.module';
import { BranchModule } from './branch/branch.module';
import { QrModule } from './qr/qr.module';
import { HealthModule } from './health/health.module';
import { AdminModule } from './admin/admin.module';
import { validateEnvironment } from './config/env.validation';
import { OrgThrottlerGuard } from './auth/guards/org-throttler.guard';
import { resolveThrottlingConfig } from './config/throttling.config';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env', 'backend/.env', join(__dirname, '..', '.env')],
      // Fails the boot (not a request) when a production deployment is
      // missing required variables. No-op outside NODE_ENV=production.
      validate: validateEnvironment,
    }),
    // NOTE: the default ThrottlerStorage is in-memory, so limits are enforced
    // per process. Keep this service at a single instance unless a shared
    // store is added — see OrgThrottlerGuard for details.
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
    SmsModule,
    EmailModule,
    OtpModule,
    PaymentModule,
    ReportsModule,
    NotificationsModule,
    BranchModule,
    QrModule,
    HealthModule,
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
