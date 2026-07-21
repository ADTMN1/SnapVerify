import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtService } from './jwt.service';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { OtpModule } from '../otp/otp.module';

@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        // Throws at startup if the variable is missing — no silent fallback
        secret: config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      }),
    }),
    OtpModule,
  ],
  providers: [AuthService, JwtService, JwtAuthGuard, RolesGuard],
  controllers: [AuthController],
  exports: [AuthService, JwtService, JwtAuthGuard, RolesGuard, JwtModule],
})
export class AuthModule {}
