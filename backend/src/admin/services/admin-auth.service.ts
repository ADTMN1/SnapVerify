import {
  Injectable,
  UnauthorizedException,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminJwtService } from './admin-jwt.service';
import { PasswordService } from '../../auth/password.service';
import { OtpService, OTP_PURPOSES } from '../../otp/otp.service';

@Injectable()
export class AdminAuthService {
  private readonly logger = new Logger(AdminAuthService.name);

  constructor(
    private prisma: PrismaService,
    private adminJwtService: AdminJwtService,
    private passwordService: PasswordService,
    private otpService: OtpService,
  ) {}

  /**
   * Admin login via email and password.
   * Only users with OWNER role can log in as admin for now.
   */
  async loginWithPassword(
    email: string,
    password: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    this.logger.log(`Admin login attempt: email=${email}`);

    const user = await this.prisma.user.findFirst({
      where: { email: email.toLowerCase() },
      include: { userAssignments: true },
    });

    if (!user) {
      this.logger.warn(`Admin login failed: no user found for email=${email}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.passwordHash) {
      this.logger.warn(
        `Admin login failed: no password set for user id=${user.id}`,
      );
      throw new UnauthorizedException('Password not set for this account');
    }

    // Shared verifier handles Argon2id (current) and legacy bcrypt hashes.
    const { valid: isPasswordValid } = await this.passwordService.verify(
      user.passwordHash,
      password,
    );
    if (!isPasswordValid) {
      this.logger.warn(
        `Admin login failed: invalid password for user id=${user.id}`,
      );
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status !== 'active') {
      this.logger.warn(
        `Admin login failed: user account inactive for user id=${user.id}`,
      );
      throw new UnauthorizedException('Your account is inactive');
    }

    // Determine admin role: platform super admins get unrestricted access,
    // otherwise the user must own at least one organization.
    const isPlatformAdmin = user.isPlatformAdmin === true;
    const hasAdminRole = user.userAssignments.some(
      (assignment) => assignment.role === 'OWNER',
    );

    if (!isPlatformAdmin && !hasAdminRole) {
      this.logger.warn(
        `Admin login failed: user lacks admin access for user id=${user.id}`,
      );
      throw new UnauthorizedException(
        'You do not have permission to access the admin panel',
      );
    }

    const role = isPlatformAdmin ? 'SUPER_ADMIN' : 'BUSINESS_OWNER';
    this.logger.log(
      `Admin login successful for user id=${user.id} (role=${role})`,
    );

    // Log this admin activity (platform admins without an org assignment
    // have no organization to attribute the log to, so it is skipped).
    const primaryOrgId = user.userAssignments[0]?.organizationId;
    if (primaryOrgId) {
      await this.prisma.activityLog.create({
        data: {
          organizationId: primaryOrgId,
          userId: user.id,
          action: 'ADMIN_LOGIN',
          metadata: { email, role },
          ipAddress,
        },
      });
    }

    const tokens = await this.adminJwtService.generateTokens(
      user.id,
      user.email || email,
      role,
      ipAddress,
      userAgent,
    );

    return {
      tokens,
      admin: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        status: user.status,
        isPlatformAdmin,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      organizations: user.userAssignments.map((a) => ({
        organizationId: a.organizationId,
        role: a.role,
      })),
    };
  }

  /**
   * Get current admin details.
   */
  async getCurrentAdmin(adminId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: adminId },
      include: { userAssignments: true },
    });

    if (!user || user.status !== 'active') {
      throw new UnauthorizedException('Admin not found or inactive');
    }

    return {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      phone: user.phone,
      status: user.status,
      isPlatformAdmin: user.isPlatformAdmin === true,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      organizations: user.userAssignments.map((a) => ({
        organizationId: a.organizationId,
        role: a.role,
      })),
    };
  }

  /**
   * Change admin password.
   */
  async changePassword(
    adminId: string,
    currentPassword: string,
    newPassword: string,
    ipAddress?: string,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: adminId } });

    if (!user || !user.passwordHash) {
      throw new BadRequestException('Admin not found');
    }

    const { valid: isCurrentValid } = await this.passwordService.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!isCurrentValid) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const newPasswordHash = await this.passwordService.hash(newPassword);

    await this.prisma.user.update({
      where: { id: adminId },
      data: { passwordHash: newPasswordHash },
    });

    // Log this action
    await this.prisma.activityLog.create({
      data: {
        organizationId:
          (
            await this.prisma.userBusinessAssignment.findFirst({
              where: { userId: adminId },
            })
          )?.organizationId || 'unknown',
        userId: adminId,
        action: 'ADMIN_CHANGE_PASSWORD',
        ipAddress,
      },
    });

    this.logger.log(`Admin changed password: id=${adminId}`);

    return { message: 'Password changed successfully' };
  }

  /**
   * Admin logout - revoke refresh token.
   */
  async logout(refreshToken: string, adminId: string, ipAddress?: string) {
    await this.adminJwtService.revokeToken(refreshToken);

    // Log this action
    const org = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: adminId },
    });

    if (org) {
      await this.prisma.activityLog.create({
        data: {
          organizationId: org.organizationId,
          userId: adminId,
          action: 'ADMIN_LOGOUT',
          ipAddress,
        },
      });
    }

    this.logger.log(`Admin logged out: id=${adminId}`);
    return { message: 'Logged out successfully' };
  }

  /**
   * Refresh admin tokens.
   */
  async refreshTokens(
    refreshToken: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    return this.adminJwtService.refreshTokens(
      refreshToken,
      ipAddress,
      userAgent,
    );
  }

  /**
   * Logout all sessions (revoke all tokens).
   */
  async logoutAll(adminId: string, ipAddress?: string) {
    await this.adminJwtService.revokeAllTokens(adminId);

    const org = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: adminId },
    });

    if (org) {
      await this.prisma.activityLog.create({
        data: {
          organizationId: org.organizationId,
          userId: adminId,
          action: 'ADMIN_LOGOUT_ALL',
          ipAddress,
        },
      });
    }

    this.logger.log(`Admin logged out from all sessions: id=${adminId}`);
    return { message: 'Logged out from all sessions' };
  }

  /**
   * Admin forgot password - send OTP to email.
   * Prevents email enumeration by always returning success message.
   */
  async forgotPassword(email: string) {
    const normalized = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
      include: { userAssignments: true },
    });

    // Only send OTP if user exists AND has admin access (OWNER role or platform admin)
    if (user) {
      const hasAdminRole = user.userAssignments.some(
        (assignment) => assignment.role === 'OWNER',
      );
      const isPlatformAdmin = user.isPlatformAdmin === true;

      if (hasAdminRole || isPlatformAdmin) {
        await this.otpService.generateOtp(
          normalized,
          OTP_PURPOSES.PASSWORD_RESET,
        );
      }
    }

    // Same response regardless — prevents email enumeration
    return {
      message:
        'If an admin account exists for this email, a password reset code has been sent.',
    };
  }

  /**
   * Admin reset password - verify OTP and update password.
   */
  async resetPassword(email: string, otpCode: string, newPassword: string) {
    const normalized = email.trim().toLowerCase();

    // Verify OTP
    await this.otpService.verifyOtp(
      normalized,
      otpCode,
      OTP_PURPOSES.PASSWORD_RESET,
    );

    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
      include: { userAssignments: true },
    });

    if (!user) {
      throw new BadRequestException(
        'Account not found. Please check your email address.',
      );
    }

    // Verify user has admin access
    const hasAdminRole = user.userAssignments.some(
      (assignment) => assignment.role === 'OWNER',
    );
    const isPlatformAdmin = user.isPlatformAdmin === true;

    if (!hasAdminRole && !isPlatformAdmin) {
      throw new UnauthorizedException(
        'You do not have permission to access the admin panel',
      );
    }

    if (user.status !== 'active') {
      throw new UnauthorizedException('Your account is inactive');
    }

    const newPasswordHash = await this.passwordService.hash(newPassword);

    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: newPasswordHash },
    });

    // Invalidate all existing admin refresh tokens for this user
    await this.adminJwtService.revokeAllTokens(user.id);

    // Log this action
    const primaryOrgId = user.userAssignments[0]?.organizationId;
    if (primaryOrgId) {
      await this.prisma.activityLog.create({
        data: {
          organizationId: primaryOrgId,
          userId: user.id,
          action: 'ADMIN_RESET_PASSWORD',
          ipAddress: undefined,
        },
      });
    }

    this.logger.log(`Admin reset password: id=${user.id}`);

    return { message: 'Password reset successfully' };
  }
}
