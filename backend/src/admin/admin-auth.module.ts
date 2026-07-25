import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AdminAuthService } from './services/admin-auth.service';
import { AdminJwtService } from './services/admin-jwt.service';
import { AdminAuthController } from './controllers/admin-auth.controller';
import { AdminJwtAuthGuard } from './guards/admin-jwt-auth.guard';
import { AdminRolesGuard } from './guards/admin-roles.guard';

@Module({
  imports: [
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_ADMIN_ACCESS_SECRET') || 
                config.getOrThrow<string>('JWT_ACCESS_SECRET'),
      }),
    }),
  ],
  providers: [
    AdminAuthService,
    AdminJwtService,
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
