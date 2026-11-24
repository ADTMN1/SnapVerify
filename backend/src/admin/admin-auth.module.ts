import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { OtpModule } from '../otp/otp.module';
import { AdminAuthService } from './services/admin-auth.service';
import { AdminJwtService } from './services/admin-jwt.service';
import { AdminAuthController } from './controllers/admin-auth.controller';
import { AdminJwtAuthGuard } from './guards/admin-jwt-auth.guard';
import { AdminRolesGuard } from './guards/admin-roles.guard';
import { PasswordService } from '../auth/password.service';
import { resolveAdminAuthSecrets } from '../config/admin-auth-secrets';

@Module({
  imports: [
    OtpModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: resolveAdminAuthSecrets(config).accessSecret,
      }),
    }),
  ],
  providers: [
    AdminAuthService,
    AdminJwtService,
    PasswordService,
    AdminJwtAuthGuard,
    AdminRolesGuard,
  ],
  controllers: [AdminAuthController],
  exports: [
    AdminAuthService,
    AdminJwtService,
    AdminJwtAuthGuard,
    AdminRolesGuard,
    JwtModule,
  ],
})
export class AdminAuthModule {}
