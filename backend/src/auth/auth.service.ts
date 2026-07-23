import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../otp/otp.service';
import { JwtService } from './jwt.service';
import { Role, SubscriptionStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly saltRounds = 12;

  constructor(
    private prisma: PrismaService,
    private otpService: OtpService,
    private jwtService: JwtService,
  ) {}

  // ── Send OTP ─────────────────────────────────────────────────────────────
  async sendOtp(phone: string) {
    await this.otpService.generateOtp(phone);
    return { message: 'OTP sent successfully' };
  }

  // ── Password Login ───────────────────────────────────────────────────────
  async loginWithPassword(
    phone: string,
    password: string,
    organizationId?: string,
  ) {
    this.logger.log(
      `Login attempt: phone=${phone}, organizationId=${organizationId || 'not provided'}`,
    );

    const user = await this.prisma.user.findUnique({
      where: { phone },
      include: { userAssignments: true },
    });

    if (!user) {
      this.logger.warn(`Login failed: no user found for phone=${phone}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.passwordHash) {
      this.logger.warn(`Login failed: no password hash for user id=${user.id}`);
      throw new UnauthorizedException(
        'Password not set. Please use OTP login or activate your invitation.',
      );
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      this.logger.warn(`Login failed: invalid password for user id=${user.id}`);
      throw new UnauthorizedException('Invalid credentials');
    }

    // Find which assignment to use
    let assignment;
    if (organizationId) {
      assignment = user.userAssignments.find(
        (a) => a.organizationId === organizationId,
      );
      if (!assignment) {
        throw new BadRequestException(
          'You are not a member of this organization',
        );
      }
    } else if (user.userAssignments.length === 1) {
      assignment = user.userAssignments[0];
    } else {
      throw new BadRequestException(
        'Please specify which organization to log in to',
      );
    }

    this.logger.log(`Login successful for user id=${user.id}`);
    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
    );
    return {
      tokens,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      roles: user.userAssignments.map((a) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }

  // ── Verify OTP → issue tokens ─────────────────────────────────────────────
  async verifyOtpAndLogin(
    phone: string,
    code: string,
    organizationId?: string,
  ) {
    // Verify OTP first — throws BadRequestException on failure
    await this.otpService.verifyOtp(phone, code);

    let user = await this.prisma.user.findUnique({
      where: { phone },
      include: { userAssignments: true },
    });

    if (!user) {
      if (!organizationId) {
        throw new UnauthorizedException(
          'User not found. Please provide an organization ID or create a business account.',
        );
      }

      const organization = await this.prisma.organization.findUnique({
        where: { id: organizationId },
      });

      if (!organization) {
        throw new BadRequestException('Organization not found');
      }

      this.logger.log(
        `Auto-creating CASHIER for phone=${phone} org=${organizationId}`,
      );
      user = await this.prisma.user.create({
        data: {
          phone,
          userAssignments: {
            create: {
              organizationId,
              role: Role.CASHIER,
            },
          },
        },
        include: { userAssignments: true },
      });
    }

    // Find which assignment to use
    let assignment;
    if (organizationId) {
      assignment = user.userAssignments.find(
        (a) => a.organizationId === organizationId,
      );
      if (!assignment) {
        throw new BadRequestException(
          'You are not a member of this organization',
        );
      }
    } else if (user.userAssignments.length === 1) {
      assignment = user.userAssignments[0];
    } else {
      throw new BadRequestException(
        'Please specify which organization to log in to',
      );
    }

    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
    );
    return {
      tokens,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      roles: user.userAssignments.map((a) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }

  // ── Create business (requires verified OTP for owner's phone) ─────────────
  async createBusiness(
    name: string,
    fullName: string | undefined,
    phone: string,
    otpCode: string,
    password: string,
    email?: string,
    address?: string,
    type?: string,
    city?: string,
    country?: string,
  ) {
    await this.otpService.verifyOtp(phone, otpCode);

    let user = await this.prisma.user.findUnique({
      where: { phone },
      include: { userAssignments: true },
    });

    if (user?.userAssignments.some((a) => a.role === Role.OWNER)) {
      throw new BadRequestException(
        'This phone number is already registered with a business',
      );
    }

    const organization = await this.prisma.organization.create({
      data: {
        name,
        phone,
        email,
        address,
        type: type ?? 'restaurant',
        city,
        country,
      },
    });

    const startDate = new Date();
    const endDate = new Date(startDate);
    endDate.setDate(endDate.getDate() + 14);
    await this.prisma.subscription.create({
      data: {
        organizationId: organization.id,
        planName: 'free_trial',
        status: SubscriptionStatus.ACTIVE,
        startDate,
        endDate,
        maxUsers: 5,
        maxDevices: 10,
      },
    });

    const passwordHash = await bcrypt.hash(password, this.saltRounds);

    if (user) {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          fullName,
          passwordHash,
          email,
          userAssignments: {
            create: {
              organizationId: organization.id,
              role: Role.OWNER,
            },
          },
        },
        include: { userAssignments: true },
      });
    } else {
      user = await this.prisma.user.create({
        data: {
          phone,
          fullName,
          passwordHash,
          email,
          userAssignments: {
            create: {
              organizationId: organization.id,
              role: Role.OWNER,
            },
          },
        },
        include: { userAssignments: true },
      });
    }

    this.logger.log(
      `Business created: org=${organization.id} owner=${user.id}`,
    );

    const tokens = await this.jwtService.generateTokens(
      user.id,
      organization.id,
      Role.OWNER,
    );

    return {
      organization,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      tokens,
      roles: user.userAssignments.map((a) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }

  // ── Change Password (authenticated user) ───────────────────────────────────
  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
    });

    if (!user.passwordHash) {
      throw new BadRequestException(
        'No password set. Use reset password instead.',
      );
    }

    const isCurrentPasswordValid = await bcrypt.compare(
      currentPassword,
      user.passwordHash,
    );
    if (!isCurrentPasswordValid) {
      throw new UnauthorizedException('Current password is incorrect');
    }

    const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    return { message: 'Password changed successfully' };
  }

  // ── Reset Password (using OTP) ───────────────────────────────────────────
  async resetPassword(phone: string, otpCode: string, newPassword: string) {
    await this.otpService.verifyOtp(phone, otpCode);

    const user = await this.prisma.user.findUnique({
      where: { phone },
    });

    if (!user) {
      throw new BadRequestException('User not found');
    }

    const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: newPasswordHash },
    });

    return { message: 'Password reset successfully' };
  }

  // ── Get current user and organization ────────────────────────────────────
  async getMe(userId: string, organizationId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      include: { userAssignments: true },
    });
    const organization = await this.prisma.organization.findUniqueOrThrow({
      where: { id: organizationId },
    });
    return { user, organization };
  }

  // ── Add staff member ───────────────────────────────────────────────────────
  async addStaff(
    organizationId: string,
    fullName: string,
    phone: string,
    role: Role,
    branchId?: string,
    password?: string,
  ) {
    if (branchId) {
      const branch = await this.prisma.branch.findFirst({
        where: { id: branchId, organizationId },
      });
      if (!branch) {
        throw new BadRequestException('Branch not found in your organization');
      }
    }

    const user = await this.prisma.user.findUnique({
      where: { phone },
      include: { userAssignments: true },
    });

    if (user) {
      const existingAssignment = user.userAssignments.find(
        (a) => a.organizationId === organizationId,
      );

      if (existingAssignment) {
        throw new BadRequestException(
          'This user is already a member of your organization',
        );
      }

      await this.prisma.userBusinessAssignment.create({
        data: {
          userId: user.id,
          organizationId,
          role,
          branchId: branchId || null,
        },
      });

      this.logger.log(
        `Existing user added to org: id=${user.id} role=${role} org=${organizationId}`,
      );

      return {
        ...user,
        organizationId,
        branchId,
        role,
      };
    }

    // If password is provided, create user immediately
    if (password) {
      const passwordHash = await bcrypt.hash(password, this.saltRounds);

      const newUser = await this.prisma.user.create({
        data: {
          phone,
          fullName,
          passwordHash,
        },
      });

      await this.prisma.userBusinessAssignment.create({
        data: {
          userId: newUser.id,
          organizationId,
          role,
          branchId: branchId || null,
        },
      });

      this.logger.log(
        `New user created and added to org: id=${newUser.id} role=${role} org=${organizationId}`,
      );

      return {
        ...newUser,
        organizationId,
        branchId,
        role,
      };
    }

    // Otherwise, create invitation
    const invitation = await this.prisma.invitation.create({
      data: {
        phone,
        organizationId,
        role,
        branchId: branchId || null,
      },
    });

    const organization = await this.prisma.organization.findUnique({
      where: { id: organizationId }
    });

    this.logger.log(
      `Invitation created: id=${invitation.id} phone=${phone} role=${role}`,
    );

    // Send SMS notification for invitation
    await this.otpService.sendInvitationSms(phone, role, organization?.name);

    return invitation;
  }

  // ── Get Invitation ────────────────────────────────────────────────────────
  async getInvitation(phone: string) {
    const invitations = await this.prisma.invitation.findMany({
      where: { phone, status: 'PENDING' },
      include: { organization: true, branch: true },
    });

    if (invitations.length === 0) {
      throw new BadRequestException(
        'No pending invitations found for this phone number',
      );
    }

    return invitations;
  }

  // ── Activate Invitation ───────────────────────────────────────────────────
  async activateInvitation(
    phone: string,
    otpCode: string,
    fullName: string,
    password: string,
    organizationId: string,
  ) {
    await this.otpService.verifyOtp(phone, otpCode);

    const invitation = await this.prisma.invitation.findFirst({
      where: {
        phone,
        organizationId,
        status: 'PENDING',
      },
    });

    if (!invitation) {
      throw new BadRequestException('Invitation not found');
    }

    let user = await this.prisma.user.findUnique({
      where: { phone },
    });

    const passwordHash = await bcrypt.hash(password, this.saltRounds);

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          fullName,
          passwordHash,
        },
      });
    } else {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          fullName,
          passwordHash,
        },
      });
    }

    await this.prisma.userBusinessAssignment.create({
      data: {
        userId: user.id,
        organizationId,
        role: invitation.role,
        branchId: invitation.branchId,
      },
    });

    await this.prisma.invitation.update({
      where: { id: invitation.id },
      data: { status: 'ACTIVE' },
    });

    this.logger.log(`Invitation activated: user id=${user.id}`);

    const tokens = await this.jwtService.generateTokens(
      user.id,
      organizationId,
      invitation.role,
    );
    return {
      tokens,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      roles: [
        {
          businessId: organizationId,
          branchId: invitation.branchId,
          role: invitation.role,
        },
      ],
    };
  }

  // ── List staff for an organization ────────────────────────────────────────
  async getStaff(organizationId: string, branchId?: string) {
    return this.prisma.userBusinessAssignment.findMany({
      where: {
        organizationId,
        role: { not: 'OWNER' },
        ...(branchId ? { branchId } : {}),
      },
      orderBy: { createdAt: 'desc' },
      include: {
        user: true,
        branch: { select: { id: true, name: true } },
      },
    });
  }

  // ── Remove a staff member ─────────────────────────────────────────────────
  async removeStaff(staffAssignmentId: string, organizationId: string) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { id: staffAssignmentId, organizationId },
    });

    if (!assignment) {
      throw new BadRequestException(
        'Staff member not found in your organization',
      );
    }

    if (assignment.role === Role.OWNER) {
      throw new BadRequestException('Cannot remove the organization owner');
    }

    await this.prisma.userBusinessAssignment.delete({
      where: { id: staffAssignmentId },
    });

    return { message: 'Staff member removed successfully' };
  }
}
