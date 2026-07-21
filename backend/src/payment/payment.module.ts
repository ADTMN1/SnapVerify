import { Module } from '@nestjs/common';
import { PaymentController } from './payment.controller';
import { PaymentService } from './payment.service';
import { PaymentAccountController } from './payment-account.controller';
import { PaymentAccountService } from './payment-account.service';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule, // provides JwtAuthGuard, RolesGuard, JwtModule
  ],
  controllers: [PaymentController, PaymentAccountController],
  providers: [PaymentService, PaymentAccountService],
})
export class PaymentModule {}
