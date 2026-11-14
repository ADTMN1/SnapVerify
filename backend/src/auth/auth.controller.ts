import {
  Controller,
  Post,
  Get,
  Delete,
  Put,
  UseGuards,
  Request,
  Body,
  Ip,
  HttpCode,
  HttpStatus,
  Param,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { JwtService } from './jwt.service';
import { JwtAuthGuard, JwtPayload } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { BranchGuard } from './guards/branch.guard';
import { Roles } from './decorators/roles.decorator';
import { Public } from './decorators/public.decorator';
import { Role } from '@prisma/client';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { CreateBusinessDto } from './dto/create-business.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto, ResetPasswordDto } from './dto/change-password.dto';
import { AddStaffDto } from './dto/add-staff.dto';
import { UpdateStaffDto } from './dto/update-staff.dto';

@Controller('auth')
export class AuthController {
  constructor(
    private authService: AuthService,
    private jwtService: JwtService,
  ) {}

  @Public()
  @Post('send-otp')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: 60 } })
  async sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto.phone, dto.purpose);
  }

  @Public()
  @Post('check-otp')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60 } })
  async checkOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.checkOtp(dto.phone, dto.code);
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60 } })
  async login(@Body() dto: LoginDto) {
    return this.authService.loginWithPassword(
      dto.phone,
      dto.password,
      dto.organizationId,
    );
  }

  @Public()
  @Post('verify-otp')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60 } })
  async verifyOtp(@Body() dto: VerifyOtpDto, @Ip() ipAddress: string) {
    return this.authService.verifyOtpAndLogin(
      dto.phone,
      dto.code,
      dto.organizationId,
      ipAddress,
    );
  }

  @Public()
  @Post('create-business')
  @HttpCode(HttpStatus.CREATED)
  async createBusiness(@Body() dto: CreateBusinessDto) {
    return this.authService.createBusiness(
      dto.name,
      dto.fullName,
      dto.phone,
      dto.otpCode,
      dto.password,
      dto.email,
      dto.address,
      dto.type,
      dto.city,
      dto.country,
    );
  }

  @Public()
  @Post('select-business')
  @HttpCode(HttpStatus.OK)
  async selectBusiness(
    @Body() body: { userId: string; organizationId: string },
  ) {
    return this.authService.selectBusiness(body.userId, body.organizationId);
  }

  @Public()
  @Post('refresh-token')
  @HttpCode(HttpStatus.OK)
  async refreshToken(@Body() dto: RefreshTokenDto, @Ip() ipAddress: string) {
    return this.jwtService.refreshTokens(
      dto.refreshToken,
      undefined,
      ipAddress,
    );
  }

  @Public()
  @Post('logout')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60 } })
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

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 3, ttl: 60 } })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.authService.resetPassword(
      dto.phone,
      dto.otpCode,
      dto.newPassword,
    );
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async getMe(@Request() req: { user: JwtPayload }) {
    return this.authService.getMe(req.user.sub, req.user.organizationId);
  }

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
      dto.phone,
      dto.role,
      dto.branchId,
      dto.password,
    );
  }

  @Get('staff')
  @UseGuards(JwtAuthGuard, RolesGuard, BranchGuard)
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
      dto.branchId ?? undefined,
    );
  }

  // JWT-authenticated invitation lookup — for owners/staff to view invitations
  // for a given phone. Pre-login staff MUST use POST /check-invitation instead.
  @Get('invitations/:phone')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async getInvitations(@Param('phone') phone: string) {
    return this.authService.getInvitation(phone);
  }

  // PUBLIC invitation check — for pre-login activation flow.
  // Takes { phone, token? } and returns valid invitations list
  // (compatible with invitation picker on step 1 of activation).
  // Throttled aggressively to block phone-enumeration scans.
  @Public()
  @Post('check-invitation')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 6, ttl: 60 } })
  async checkInvitationPublic(@Body() body: { phone: string; token?: string }) {
    return this.authService.checkInvitation(body.phone, body.token);
  }

  @Public()
  @Post('activate-invitation')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60 } })
  async activateInvitation(
    @Body()
    body: {
      phone: string;
      otpCode: string;
      fullName: string;
      password: string;
      organizationId: string;
      token?: string;
    },
  ) {
    return this.authService.activateInvitation(
      body.phone,
      body.otpCode,
      body.fullName,
      body.password,
      body.organizationId,
      body.token,
    );
  }
}
