import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { OtpModule } from './otp/otp.module';
import { PaymentModule } from './payment/payment.module';
import { BranchModule } from './branch/branch.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60, limit: 10 }]),
    PrismaModule,
    AuthModule,
    OtpModule,
    PaymentModule,
    BranchModule,
    AdminModule,
  ],
})
export class AppModule {}
