import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { QrController } from './qr.controller';
import { QrService } from './qr.service';
import { PaymentQrService } from './payment-qr/payment-qr.service';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [QrController],
  providers: [QrService, PaymentQrService],
  exports: [QrService],
})
export class QrModule {}
