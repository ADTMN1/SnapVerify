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
import * as crypto from 'crypto';

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
  async sendOtp(phone: string, purpose?: string) {
    // For business owner registration, check if phone already has active OWNER assignment
    if (purpose === 'business_registration') {
      const user = await this.prisma.user.findUnique({
        where: { phone },
        include: { userAssignments: true },
      });

      if (
        user &&
        user.userAssignments.some(
          (a) => a.role === Role.OWNER && a.status === 'active',
        )
      ) {
        throw new BadRequestException(
          'This phone number is already registered as a business owner. Please login or create a branch from your dashboard.',
        );
      }
    }

    await this.otpService.generateOtp(phone);
    return { message: 'OTP sent successfully' };
  }

  // ── Check OTP (verify without consuming — for multi-step flows like registration) ─
  async checkOtp(phone: string, code: string) {
    await this.otpService.verifyOtp(phone, code, false);
    return { ok: true, message: 'OTP valid' };
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
      include: {
        userAssignments: {
          include: { organization: true },
        },
      },
    });

    if (!user) {
      this.logger.warn(`Login failed: no user found for phone=${phone}`);
      throw new UnauthorizedException(
        'Invalid phone number or password. Please try again.',
      );
    }

    if (!user.passwordHash) {
      this.logger.warn(`Login failed: no password hash for user id=${user.id}`);
      throw new UnauthorizedException(
        'No password set for this account. Please use OTP login or activate your invitation.',
      );
    }

    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      this.logger.warn(`Login failed: invalid password for user id=${user.id}`);
      throw new UnauthorizedException(
        'Invalid phone number or password. Please try again.',
      );
    }

    const activeAssignments = user.userAssignments.filter(
      (a) => a.status === 'active',
    );

    if (activeAssignments.length === 0) {
      throw new UnauthorizedException(
        'Your account is not active. Please contact support.',
      );
    }

    // Multi-business: if user has multiple orgs and none specified, return selection
    if (activeAssignments.length > 1 && !organizationId) {
      const businesses = activeAssignments.map((a) => ({
        organizationId: a.organizationId,
        organizationName: a.organization.name,
        role: a.role,
        branchId: a.branchId,
      }));
      return {
        requiresBusinessSelection: true,
        businesses,
        user: {
          id: user.id,
          fullName: user.fullName,
          phone: user.phone,
          email: user.email,
          status: user.status,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        },
      };
    }

    // Find which assignment to use
    let assignment;
    if (organizationId) {
      assignment = activeAssignments.find(
        (a) => a.organizationId === organizationId,
      );
      if (!assignment) {
        throw new BadRequestException(
          'You are not a member of this organization.',
        );
      }
    } else if (activeAssignments.length === 1) {
      assignment = activeAssignments[0];
    } else {
      throw new BadRequestException(
        'Please select which organization to log in to.',
      );
    }

    this.logger.log(`Login successful for user id=${user.id}`);
    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
      assignment.branchId ?? undefined,
    );
    const org = assignment.organization;
    return {
      tokens,
      requiresBusinessSelection: false,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      organization: {
        id: org.id,
        name: org.name,
        type: org.type,
        phone: org.phone,
        email: org.email,
        address: org.address,
        city: org.city,
        country: org.country,
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
    ipAddress?: string,
  ) {
    // Verify OTP first — throws BadRequestException on failure
    await this.otpService.verifyOtp(phone, code);

    let user = await this.prisma.user.findUnique({
      where: { phone },
      include: {
        userAssignments: {
          include: { organization: true },
        },
      },
    });

    if (!user) {
      if (!organizationId) {
        throw new UnauthorizedException(
          'Account not found. Please check your phone number or create a business account.',
        );
      }

      // SECURITY FIX: Only allow auto-create if there's a PENDING invitation for this phone+org
      const invitation = await this.prisma.invitation.findFirst({
        where: {
          phone,
          organizationId,
          status: 'PENDING',
        },
      });

      if (!invitation) {
        throw new BadRequestException(
          'No pending invitation found. Please request an invitation from the business owner.',
        );
      }

      const organization = await this.prisma.organization.findUnique({
        where: { id: organizationId },
      });

      if (!organization) {
        throw new BadRequestException(
          'Organization not found. Please check the details and try again.',
        );
      }

      this.logger.log(
        `Auto-creating staff from invitation for phone=${phone} org=${organizationId} role=${invitation.role}`,
      );
      user = await this.prisma.user.create({
        data: {
          phone,
          userAssignments: {
            create: {
              organizationId,
              role: invitation.role,
              branchId: invitation.branchId,
            },
          },
        },
        include: {
          userAssignments: {
            include: { organization: true },
          },
        },
      });

      // Mark invitation as active (used)
      await this.prisma.invitation.update({
        where: { id: invitation.id },
        data: { status: 'ACTIVE' },
      });
    }

    const activeAssignments = user.userAssignments.filter(
      (a) => a.status === 'active',
    );

    if (activeAssignments.length === 0) {
      throw new UnauthorizedException(
        'Your account is not active. Please contact support.',
      );
    }

    // Multi-business: if user has multiple orgs and none specified, return selection
    if (activeAssignments.length > 1 && !organizationId) {
      const businesses = activeAssignments.map((a) => ({
        organizationId: a.organizationId,
        organizationName: a.organization.name,
        role: a.role,
        branchId: a.branchId,
      }));
      return {
        requiresBusinessSelection: true,
        businesses,
        user: {
          id: user.id,
          fullName: user.fullName,
          phone: user.phone,
          email: user.email,
          status: user.status,
          createdAt: user.createdAt,
          updatedAt: user.updatedAt,
        },
      };
    }

    // Find which assignment to use
    let assignment;
    if (organizationId) {
      assignment = activeAssignments.find(
        (a) => a.organizationId === organizationId,
      );
      if (!assignment) {
        throw new BadRequestException(
          'You are not a member of this organization.',
        );
      }
    } else if (activeAssignments.length === 1) {
      assignment = activeAssignments[0];
    } else {
      throw new BadRequestException(
        'Please select which organization to log in to.',
      );
    }

    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
      assignment.branchId ?? undefined,
      undefined,
      ipAddress,
    );
    const org = assignment.organization;
    return {
      tokens,
      requiresBusinessSelection: false,
      user: {
        id: user.id,
        fullName: user.fullName,
        phone: user.phone,
        email: user.email,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      organization: {
        id: org.id,
        name: org.name,
        type: org.type,
        phone: org.phone,
        email: org.email,
        address: org.address,
        city: org.city,
        country: org.country,
      },
      roles: user.userAssignments.map((a) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }

  // ── Select Business (called when user has multiple orgs) ─────────────────
  async selectBusiness(userId: string, organizationId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        userAssignments: {
          include: { organization: true },
          where: { status: 'active' },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException(
        'Account not found. Please check your phone number.',
      );
    }

    const assignment = user.userAssignments.find(
      (a) => a.organizationId === organizationId,
    );

    if (!assignment) {
      throw new BadRequestException(
        'You are not a member of this organization',
      );
    }

    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
      assignment.branchId ?? undefined,
    );

    const org = assignment.organization;

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
      organization: {
        id: org.id,
        name: org.name,
        type: org.type,
        phone: org.phone,
        email: org.email,
        address: org.address,
        city: org.city,
        country: org.country,
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

    if (user) {
      if (user.userAssignments.some((a) => a.role === Role.OWNER)) {
        throw new BadRequestException(
          'You already own a business. Please create a branch instead.',
        );
      }
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
        'No password set. Please reset your password instead.',
      );
    }

    const isCurrentPasswordValid = await bcrypt.compare(
      currentPassword,
      user.passwordHash,
    );
    if (!isCurrentPasswordValid) {
      throw new UnauthorizedException(
        'Current password is incorrect. Please try again.',
      );
    }

    const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    // Invalidate all existing sessions so stolen tokens cannot be reused
    await this.prisma.refreshToken.deleteMany({ where: { userId } });

    return { message: 'Password changed successfully' };
  }

  // ── Reset Password (using OTP) ───────────────────────────────────────────
  async resetPassword(phone: string, otpCode: string, newPassword: string) {
    await this.otpService.verifyOtp(phone, otpCode);

    const user = await this.prisma.user.findUnique({
      where: { phone },
    });

    if (!user) {
      throw new BadRequestException(
        'Account not found. Please check your phone number.',
      );
    }

    const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: newPasswordHash },
    });

    // Invalidate all existing sessions so stolen tokens cannot be reused
    await this.prisma.refreshToken.deleteMany({ where: { userId: user.id } });

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
        throw new BadRequestException(
          'Branch not found. Please check the branch details.',
        );
      }
    }

    if (role === Role.OWNER) {
      throw new BadRequestException(
        'Cannot assign OWNER role through staff invitation. Please create a new business instead.',
      );
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
          'This user is already a member of your organization.',
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

    // Invitation-only flow: never create User / passwordHash at invite time.
    // Password field accepted for backwards compatibility but is intentionally ignored.
    // Staff member receives SMS invitation and sets their own password via
    // Activate Invitation (OTP verified) flow.
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    const invitation = await this.prisma.invitation.create({
      data: {
        token,
        phone,
        organizationId,
        role,
        branchId: branchId || null,
        expiresAt,
      },
    });

    const organization = await this.prisma.organization.findUnique({
      where: { id: organizationId },
    });

    this.logger.log(
      `Invitation created: id=${invitation.id} phone=${phone} role=${role} expires=${expiresAt.toISOString()}`,
    );

    // Send SMS notification for invitation
    await this.otpService.sendInvitationSms(phone, role, organization?.name);

    return invitation;
  }

  // ── Get Invitation (Authenticated only — JWT guarded) ────────────────────
  async getInvitation(phone: string) {
    const now = new Date();
    // Clean up expired invitations first
    await this.prisma.invitation.deleteMany({
      where: {
        phone,
        status: 'PENDING',
        expiresAt: { lt: now },
      },
    });

    const invitations = await this.prisma.invitation.findMany({
      where: {
        phone,
        status: 'PENDING',
        expiresAt: { gt: now },
      },
      include: { organization: true, branch: true },
    });

    if (invitations.length === 0) {
      throw new BadRequestException(
        'No pending invitations found for this phone number.',
      );
    }

    return invitations;
  }

  // ── Check Invitation (PUBLIC — used before login) ────────────────────────
  // Validates { phone + token } pair (strongly recommended), or falls back to
  // phone-only existence check with the same expiration logic.
  //
  // Returns the list of matching valid invitations (same format as getInvitation)
  // so step 1 of the activation flow can render an invitation picker.
  //
  // SECURITY:
  //   • Requires invitation to be status=PENDING and expiresAt>now
  //   • If `token` supplied → phone AND token BOTH must match (prevents
  //     phone-enumeration brute-forcing)
  //   • Organization must still exist in DB (FK checked implicitly by prisma
  //     include + explicit guard below for soft-deleted orgs if applicable)
  async checkInvitation(phone: string, token?: string) {
    const now = new Date();

    // Passive cleanup — don't throw if this fails, just best-effort.
    try {
      await this.prisma.invitation.deleteMany({
        where: { phone, status: 'PENDING', expiresAt: { lt: now } },
      });
    } catch (_) {
      /* ignore */
    }

    const invitations = await this.prisma.invitation.findMany({
      where: {
        phone,
        status: 'PENDING',
        expiresAt: { gt: now },
        ...(token ? { token } : {}),
      },
      include: { organization: true, branch: true },
    });

    if (invitations.length === 0) {
      throw new BadRequestException(
        token
          ? 'Invalid invitation (wrong phone/token, or already used/expired)'
          : 'No pending invitations found for this phone number',
      );
    }

    return invitations.map((inv) => ({
      id: inv.id,
      role: inv.role,
      branchId: inv.branchId,
      branch: inv.branch,
      organizationId: inv.organizationId,
      organization: inv.organization,
      status: inv.status,
      expiresAt: inv.expiresAt.toISOString(),
    }));
  }

  // ── Activate Invitation ───────────────────────────────────────────────────
  async activateInvitation(
    phone: string,
    otpCode: string,
    fullName: string,
    password: string,
    organizationId: string,
    invitationToken?: string,
  ) {
    await this.otpService.verifyOtp(phone, otpCode);

    // Verify organization still exists (FK would eventually enforce this but
    // give a cleaner error to the user + close off an org-guessing vector via
    // invitation.activate timing differences — negligible in practice, but explicit).
    const organization = await this.prisma.organization.findUnique({
      where: { id: organizationId },
    });
    if (!organization) {
      throw new BadRequestException(
        'Organization not found. Please check the details.',
      );
    }

    const now = new Date();
    const invitation = await this.prisma.invitation.findFirst({
      where: {
        phone,
        organizationId,
        status: 'PENDING',
        expiresAt: { gt: now },
        ...(invitationToken ? { token: invitationToken } : {}),
      },
    });

    if (!invitation) {
      throw new BadRequestException(
        'Invitation not found or expired. Please request a new invitation.',
      );
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
        'Staff member not found in your organization.',
      );
    }

    if (assignment.role === Role.OWNER) {
      throw new BadRequestException('Cannot remove the organization owner.');
    }

    await this.prisma.userBusinessAssignment.delete({
      where: { id: staffAssignmentId },
    });

    return { message: 'Staff member removed successfully' };
  }

  // ── Update a staff member ──────────────────────────────────────────────────
  async updateStaff(
    staffAssignmentId: string,
    organizationId: string,
    fullName: string,
    role: Role,
    branchId?: string,
  ) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { id: staffAssignmentId, organizationId },
      include: { user: true },
    });

    if (!assignment) {
      throw new BadRequestException(
        'Staff member not found in your organization.',
      );
    }

    if (assignment.role === Role.OWNER) {
      throw new BadRequestException('Cannot update the organization owner.');
    }

    // Validate branch if provided
    if (branchId) {
      const branch = await this.prisma.branch.findFirst({
        where: { id: branchId, organizationId },
      });
      if (!branch) {
        throw new BadRequestException(
          'Branch not found. Please check the branch details.',
        );
      }
    }

    // Update user full name
    await this.prisma.user.update({
      where: { id: assignment.userId },
      data: { fullName },
    });

    // Update assignment (role and branch)
    const updatedAssignment = await this.prisma.userBusinessAssignment.update({
      where: { id: staffAssignmentId },
      data: {
        role,
        branchId: branchId || null,
      },
      include: {
        user: true,
        branch: { select: { id: true, name: true } },
      },
    });

    this.logger.log(
      `Staff updated: id=${staffAssignmentId} role=${role} branch=${branchId || 'none'}`,
    );

    return updatedAssignment;
  }
}
