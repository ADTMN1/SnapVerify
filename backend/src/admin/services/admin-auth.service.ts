import {
  Injectable,
  UnauthorizedException,
  Logger,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminJwtService } from './admin-jwt.service';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AdminAuthService {
  private readonly logger = new Logger(AdminAuthService.name);
  private readonly saltRounds = 12;

  constructor(
    private prisma: PrismaService,
    private adminJwtService: AdminJwtService,
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
      this.logger.warn(`Admin login failed: no password set for user id=${user.id}`);
      throw new UnauthorizedException('Password not set for this account');
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      this.logger.warn(`Admin login failed: invalid password for user id=${user.id}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status !== 'active') {
      this.logger.warn(
        `Admin login failed: user account inactive for user id=${user.id}`,
      );
      throw new UnauthorizedException('Your account is inactive');
    }

    // Check if user has OWNER role (admin access)
    const hasAdminRole = user.userAssignments.some(
      (assignment) => assignment.role === 'OWNER',
    );

    if (!hasAdminRole) {
      this.logger.warn(
        `Admin login failed: user lacks OWNER role for user id=${user.id}`,
      );
      throw new UnauthorizedException(
        'Only business owners can access the admin panel',
      );
    }

    this.logger.log(`Admin login successful for user id=${user.id}`);

    // Log this admin activity
    await this.prisma.activityLog.create({
      data: {
        organizationId: user.userAssignments[0].organizationId, // Use first org
        userId: user.id,
        action: 'ADMIN_LOGIN',
        metadata: { email },
        ipAddress,
      },
    });

    const tokens = await this.adminJwtService.generateTokens(
      user.id,
      user.email || email,
      'BUSINESS_OWNER',
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

    const isCurrentValid = await bcrypt.compare(
      currentPassword,
      user.passwordHash,
    );
    if (!isCurrentValid) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);

    await this.prisma.user.update({
      where: { id: adminId },
      data: { passwordHash: newPasswordHash },
    });

    // Log this action
    await this.prisma.activityLog.create({
      data: {
        organizationId: (
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
    return this.adminJwtService.refreshTokens(refreshToken, ipAddress, userAgent);
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
}
