import {
  Controller,
  Post,
  Get,
  Delete,
  Put,
  UseGuards,
  Request,
  Body,
  HttpCode,
  HttpStatus,
  Param,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AUTH_THROTTLE_TTL_MS } from '../config/throttling.config';
import { AuthService } from './auth.service';
import { JwtService } from './jwt.service';
import { JwtAuthGuard, JwtPayload } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from './decorators/roles.decorator';
import { Public } from './decorators/public.decorator';
import { Role } from '@prisma/client';
import {
  RegisterDto,
  VerifyEmailDto,
  ResendVerificationDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  StaffActivationOtpDto,
  CheckInvitationDto,
  ActivateInvitationDto,
} from './dto/email-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { SelectBusinessDto } from './dto/select-business.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { AddStaffDto } from './dto/add-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';

@Controller('auth')
export class AuthController {
  constructor(
    private authService: AuthService,
    private jwtService: JwtService,
  ) {}

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: AUTH_THROTTLE_TTL_MS } })
  async login(@Body() dto: LoginDto, @Request() req: { ip: string }) {
    return this.authService.login(
      dto.identifier,
      dto.password,
      dto.organizationId,
      dto.rememberMe,
    );
  }

  // ── Owner registration (email verification) ────────────────────────────────

  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  @Throttle({ default: { limit: 3, ttl: AUTH_THROTTLE_TTL_MS } })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    return this.authService.verifyEmail(dto.email, dto.otpCode);
  }

  @Public()
  @Post('resend-verification')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: AUTH_THROTTLE_TTL_MS } })
  async resendVerification(@Body() dto: ResendVerificationDto) {
    return this.authService.resendVerificationOtp(dto.email);
  }

  // ── Password recovery (email OTP) ───────────────────────────────────────────

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: AUTH_THROTTLE_TTL_MS } })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.authService.forgotPassword(dto.email);
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(
      dto.email,
      dto.otpCode,
      dto.newPassword,
    );
  }

  // ── Staff activation (QR invitation + email OTP) ────────────────────────────

  @Public()
  @Post('check-invitation')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 6, ttl: AUTH_THROTTLE_TTL_MS } })
  async checkInvitationPublic(@Body() dto: CheckInvitationDto) {
    return this.authService.checkInvitation(dto.token);
  }

  @Public()
  @Post('staff-activation-otp')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: AUTH_THROTTLE_TTL_MS } })
  async staffActivationOtp(@Body() dto: StaffActivationOtpDto) {
    return this.authService.sendStaffActivationOtp(dto.email, dto.token);
  }

  @Public()
  @Post('activate-invitation')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async activateInvitation(@Body() dto: ActivateInvitationDto) {
    return this.authService.activateInvitation(dto);
  }

  // ── Session management ──────────────────────────────────────────────────────

  @Post('business-selection-challenge')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async issueBusinessSelectionChallenge(@Request() req: { user: JwtPayload }) {
    return this.authService.issueBusinessSelectionChallenge(req.user.sub);
  }

  @Public()
  @Post('select-business')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async selectBusiness(@Body() dto: SelectBusinessDto) {
    return this.authService.selectBusiness(
      dto.selectionToken,
      dto.organizationId,
      dto.rememberMe,
    );
  }

  @Public()
  @Post('refresh-token')
  @HttpCode(HttpStatus.OK)
  async refreshToken(
    @Body() dto: RefreshTokenDto,
    @Request() req: { ip: string },
  ) {
    return this.jwtService.refreshTokens(dto.refreshToken, undefined, req.ip);
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: AUTH_THROTTLE_TTL_MS } })
  async logout(@Body() dto: RefreshTokenDto) {
    await this.jwtService.logout(dto.refreshToken);
    return { message: 'Logged out successfully' };
  }

  @Post('logout-all')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logoutAll(@Request() req: { user: JwtPayload }) {
    await this.jwtService.logoutAll(req.user.sub);
    return { message: 'All sessions terminated successfully' };
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async changePassword(
    @Body() dto: ChangePasswordDto,
    @Request() req: { user: JwtPayload },
  ) {
    return this.authService.changePassword(
      req.user.sub,
      dto.currentPassword,
      dto.newPassword,
    );
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async getMe(@Request() req: { user: JwtPayload }) {
    return this.authService.getMe(req.user.sub, req.user.organizationId);
  }

  // ── Staff management ────────────────────────────────────────────────────────

  @Post('staff')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.CREATED)
  async addStaff(
    @Request() req: { user: JwtPayload },
    @Body() dto: AddStaffDto,
  ) {
    return this.authService.addStaff(
      req.user.organizationId,
      dto.fullName,
      dto.username,
      dto.role,
      dto.branchId,
    );
  }

  // ── QR invitation lifecycle (owner/manager) ────────────────────────────────

  @Get('invitations')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async listInvitations(@Request() req: { user: JwtPayload }) {
    return this.authService.listInvitations(req.user.organizationId);
  }

  @Post('invitations/:id/revoke')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async revokeInvitation(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    return this.authService.revokeInvitation(id, req.user.organizationId);
  }

  @Post('invitations/:id/regenerate')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async regenerateInvitation(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    return this.authService.regenerateInvitation(id, req.user.organizationId);
  }

  @Get('staff')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async getStaff(@Request() req: { user: JwtPayload; branchFilter?: string }) {
    return this.authService.getStaff(req.user.organizationId, req.branchFilter);
  }

  @Delete('staff/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER)
  @HttpCode(HttpStatus.OK)
  async removeStaff(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
  ) {
    return this.authService.removeStaff(id, req.user.organizationId);
  }

  @Put('staff/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async updateStaff(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
    @Body() dto: UpdateStaffDto,
  ) {
    return this.authService.updateStaff(
      id,
      req.user.organizationId,
      dto.fullName,
      dto.role,
      req.user.role,
      dto.branchId ?? undefined,
    );
  }

  // JWT-authenticated invitation lookup — for owners/staff to view invitations
  // for a given phone. Pre-login staff MUST use POST /check-invitation instead.
  @Get('invitations/:phone')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.OWNER, Role.MANAGER)
  @HttpCode(HttpStatus.OK)
  async getInvitations(
    @Param('phone') phone: string,
    @Request() req: { user: JwtPayload },
  ) {
    return this.authService.getInvitation(phone, req.user.organizationId);
  }
}
