import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  HttpCode,
  Logger,
  Req,
  HttpStatus,
} from '@nestjs/common';
import { Public } from '../../auth/decorators/public.decorator';
import type { Request } from 'express';
import type { AdminAuthContext } from '../interfaces/admin-jwt-payload.interface';
import { AdminAuthService } from '../services/admin-auth.service';
import { AdminJwtAuthGuard } from '../guards/admin-jwt-auth.guard';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import {
  AdminLoginDto,
  AdminChangePasswordDto,
  AdminRefreshTokenDto,
  AdminLogoutDto,
  AdminForgotPasswordDto,
  AdminResetPasswordDto,
} from '../dto/admin-login.dto';

@Controller('api/admin/auth')
export class AdminAuthController {
  private readonly logger = new Logger(AdminAuthController.name);

  constructor(private adminAuthService: AdminAuthService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: AdminLoginDto, @Req() req: Request) {
    const ipAddress = req.ip || req.socket.remoteAddress;
    const userAgent = req.get('user-agent');

    return this.adminAuthService.loginWithPassword(
      dto.email,
      dto.password,
      ipAddress,
      userAgent,
    );
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  async forgotPassword(@Body() dto: AdminForgotPasswordDto) {
    return this.adminAuthService.forgotPassword(dto.email);
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  async resetPassword(@Body() dto: AdminResetPasswordDto) {
    return this.adminAuthService.resetPassword(
      dto.email,
      dto.otpCode,
      dto.newPassword,
    );
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: AdminRefreshTokenDto, @Req() req: Request) {
    const ipAddress = req.ip || req.socket.remoteAddress;
    const userAgent = req.get('user-agent');

    return this.adminAuthService.refreshTokens(
      dto.refreshToken,
      ipAddress,
      userAgent,
    );
  }

  @Get('me')
  @UseGuards(AdminJwtAuthGuard)
  async getCurrentAdmin(@CurrentAdmin() admin: any) {
    return this.adminAuthService.getCurrentAdmin(admin.sub);
  }

  @Post('logout')
  @UseGuards(AdminJwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logout(
    @Body() dto: AdminLogoutDto,
    @CurrentAdmin() admin: any,
    @Req() req: Request,
  ) {
    const ipAddress = req.ip || req.socket.remoteAddress;
    return this.adminAuthService.logout(dto.refreshToken, admin.sub, ipAddress);
  }

  @Post('logout-all')
  @UseGuards(AdminJwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logoutAll(@CurrentAdmin() admin: any, @Req() req: Request) {
    const ipAddress = req.ip || req.socket.remoteAddress;
    return this.adminAuthService.logoutAll(admin.sub, ipAddress);
  }

  @Post('change-password')
  @UseGuards(AdminJwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async changePassword(
    @Body() dto: AdminChangePasswordDto,
    @CurrentAdmin() admin: any,
    @Req() req: Request,
  ) {
    const ipAddress = req.ip || req.socket.remoteAddress;
    return this.adminAuthService.changePassword(
      admin.sub,
      dto.currentPassword,
      dto.newPassword,
      ipAddress,
    );
  }
}
