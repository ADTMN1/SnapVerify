import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ConflictException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService, OTP_PURPOSES } from '../otp/otp.service';
import { PasswordService } from './password.service';
import { EmailService } from '../email/email.service';
import { SmsService } from '../sms/sms.service';
import { JwtService } from './jwt.service';
import { Role, SubscriptionStatus } from '@prisma/client';
import { RegisterDto } from './dto/email-auth.dto';
import * as crypto from 'crypto';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private otpService: OtpService,
    private passwordService: PasswordService,
    private emailService: EmailService,
    private smsService: SmsService,
    private jwtService: JwtService,
  ) {}

  // ── Owner Registration (step 1: create account, send email OTP) ────────────
  async register(dto: RegisterDto) {
    const email = dto.email.trim().toLowerCase();

    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('Passwords do not match.');
    }

    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing && existing.emailVerified) {
      throw new ConflictException(
        'An account with this email already exists. Please login instead.',
      );
    }

    // Owner emails are unique across the platform
    const ownerAssignmentExists = existing
      ? await this.prisma.userBusinessAssignment.findFirst({
          where: { userId: existing.id, role: Role.OWNER },
        })
      : false;
    if (ownerAssignmentExists) {
      throw new BadRequestException(
        'This email is already registered as a business owner. Please login instead.',
      );
    }

    const passwordHash = await this.passwordService.hash(dto.password);

    let user = existing;
    let organization;
    if (user) {
      // Unverified registration being retried — refresh the details
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { fullName: dto.fullName, passwordHash, emailVerified: false },
      });
      const priorOrg = await this.prisma.userBusinessAssignment.findFirst({
        where: { userId: user.id, role: Role.OWNER },
      });
      if (priorOrg) {
        organization = await this.prisma.organization.update({
          where: { id: priorOrg.organizationId },
          data: {
            name: dto.name,
            email,
            type: dto.type ?? 'restaurant',
            city: dto.city,
            country: dto.country,
          },
        });
      }
    }

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email,
          fullName: dto.fullName,
          passwordHash,
        },
      });
    }

    if (!organization) {
      organization = await this.prisma.organization.create({
        data: {
          name: dto.name,
          // Phone is no longer part of registration; retained for legacy data.
          phone: '',
          email,
          type: dto.type ?? 'restaurant',
          city: dto.city,
          country: dto.country,
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

      await this.prisma.userBusinessAssignment.create({
        data: {
          userId: user.id,
          organizationId: organization.id,
          role: Role.OWNER,
        },
      });
    }

    await this.otpService.generateOtp(email, OTP_PURPOSES.REGISTER);

    this.logger.log(
      `Registration initiated: org=${organization.id} user=${user.id}`,
    );

    return {
      message:
        'Registration successful. A verification code has been sent to your email.',
      email,
    };
  }

  // ── Verify Email (step 2: consume OTP → login) ─────────────────────────────
  async verifyEmail(email: string, otpCode: string) {
    const normalized = email.trim().toLowerCase();
    await this.otpService.verifyOtp(
      normalized,
      otpCode,
      OTP_PURPOSES.REGISTER,
    );

    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
      include: {
        userAssignments: {
          where: { status: 'active' },
          include: { organization: true },
        },
      },
    });

    if (!user) {
      throw new BadRequestException('Account not found. Please register again.');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { emailVerified: true },
    });

    const assignment = user.userAssignments.find((a) => a.status === 'active');
    if (!assignment) {
      throw new BadRequestException(
        'No active business assignment found. Please contact support.',
      );
    }

    const tokens = await this.jwtService.generateTokens(
      user.id,
      assignment.organizationId,
      assignment.role,
      assignment.branchId ?? undefined,
    );
    return this.buildAuthResponse(user, assignment, tokens);
  }

  // ── Resend verification OTP ────────────────────────────────────────────────
  async resendVerificationOtp(email: string) {
    const normalized = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
    });

    if (!user || user.emailVerified) {
      // Do not leak whether the email is registered — but tell an
      // already-verified user to log in instead of waiting for an OTP.
      return {
        message: user
          ? 'Email is already verified. Please log in.'
          : 'If the account exists and is unverified, a new verification code has been sent.',
        alreadyVerified: !!user?.emailVerified,
      };
    }

    await this.otpService.generateOtp(normalized, OTP_PURPOSES.REGISTER);
    return { message: 'A new verification code has been sent to your email.' };
  }

  // ── Password Login (email, with legacy phone fallback) ─────────────────────
  async login(identifier: string, password: string, organizationId?: string) {
    const isEmail = EMAIL_RE.test(identifier);
    const user = await this.prisma.user.findFirst({
      where: isEmail
        ? { email: identifier.trim().toLowerCase() }
        : { phone: identifier },
      include: {
        userAssignments: {
          include: { organization: true },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException(
        'Invalid email or password. Please try again.',
      );
    }

    if (!user.passwordHash) {
      throw new UnauthorizedException(
        'No password set for this account. Please activate your invitation.',
      );
    }

    if (isEmail && !user.emailVerified) {
      await this.otpService
        .generateOtp(user.email!, OTP_PURPOSES.REGISTER)
        .catch(() => undefined);
      throw new UnauthorizedException(
        'Please verify your email first. A new verification code has been sent.',
      );
    }

    const { valid, needsRehash } = await this.passwordService.verify(
      user.passwordHash,
      password,
    );
    if (!valid) {
      throw new UnauthorizedException(
        'Invalid email or password. Please try again.',
      );
    }

    // Lazy migration: upgrade legacy bcrypt hashes to Argon2id on successful login
    if (needsRehash) {
      const argonHash = await this.passwordService.hash(password);
      await this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash: argonHash },
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
        user: this.sanitizeUser(user),
      };
    }

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
    );
    return this.buildAuthResponse(user, assignment, tokens);
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
      throw new UnauthorizedException('Account not found.');
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

    return this.buildAuthResponse(user, assignment, tokens);
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

    const { valid } = await this.passwordService.verify(
      user.passwordHash,
      currentPassword,
    );
    if (!valid) {
      throw new UnauthorizedException(
        'Current password is incorrect. Please try again.',
      );
    }

    const newPasswordHash = await this.passwordService.hash(newPassword);
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: newPasswordHash },
    });

    // Invalidate all existing sessions so stolen tokens cannot be reused
    await this.prisma.refreshToken.deleteMany({ where: { userId } });

    return { message: 'Password changed successfully' };
  }

  // ── Forgot Password (send email OTP) ───────────────────────────────────────
  async forgotPassword(email: string) {
    const normalized = email.trim().toLowerCase();
    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
    });

    if (user && user.passwordHash) {
      await this.otpService.generateOtp(
        normalized,
        OTP_PURPOSES.PASSWORD_RESET,
      );
    }

    // Same response regardless — prevents email enumeration
    return {
      message:
        'If an account exists for this email, a password reset code has been sent.',
    };
  }

  // ── Reset Password (email OTP verified) ────────────────────────────────────
  async resetPassword(email: string, otpCode: string, newPassword: string) {
    const normalized = email.trim().toLowerCase();
    await this.otpService.verifyOtp(
      normalized,
      otpCode,
      OTP_PURPOSES.PASSWORD_RESET,
    );

    const user = await this.prisma.user.findUnique({
      where: { email: normalized },
    });

    if (!user) {
      throw new BadRequestException(
        'Account not found. Please check your email address.',
      );
    }

    const newPasswordHash = await this.passwordService.hash(newPassword);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: newPasswordHash, emailVerified: true },
    });

    // Invalidate all existing sessions so stolen tokens cannot be reused
    await this.prisma.refreshToken.deleteMany({ where: { userId: user.id } });

    return { message: 'Password reset successfully' };
  }

  // ── Staff invitation (owner/manager creates invite; QR/deep link) ──────────
  async addStaff(
    organizationId: string,
    fullName: string,
    email: string | undefined,
    phone: string | undefined,
    role: Role,
    branchId?: string,
  ) {
    if (!email && !phone) {
      throw new BadRequestException(
        'Email (or legacy phone number) is required to invite staff.',
      );
    }

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

    // If a verified user with this email exists, add them to the org directly
    if (email) {
      const normalized = email.trim().toLowerCase();
      const user = await this.prisma.user.findUnique({
        where: { email: normalized },
        include: { userAssignments: true },
      });

      if (user && user.emailVerified) {
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
    }

    // Invitation-only flow: staff receives a QR/deep-link invitation and
    // completes registration (email + password + email OTP verification).
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

    const invitation = await this.prisma.invitation.create({
      data: {
        token,
        email: email?.trim().toLowerCase() ?? null,
        phone: phone ?? null,
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
      `Invitation created: id=${invitation.id} role=${role} expires=${expiresAt.toISOString()}`,
    );

    // Notify via email when available; legacy SMS invitations still work
    if (email) {
      await this.emailService.sendStaffInvitationEmail(
        email.trim().toLowerCase(),
        role,
        organization?.name,
        token,
      );
    } else if (phone) {
      // Legacy phone invitation — notify via SMS (non-OTP, kept for backwards compatibility)
      const formattedPhone = phone.replace(/^0/, '251');
      await this.smsService.sendInvitationSms(
        formattedPhone,
        role,
        organization?.name,
      );
    }

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

  // ── Check Invitation (PUBLIC — staff joining via QR deep link) ────────────
  // Validates the invitation token (from the QR deep link), with a legacy
  // phone-only fallback. Returns the matching valid invitation(s).
  async checkInvitation(token?: string, phone?: string) {
    const now = new Date();

    try {
      await this.prisma.invitation.deleteMany({
        where: {
          status: 'PENDING',
          expiresAt: { lt: now },
          ...(token ? { token } : {}),
        },
      });
    } catch (_) {
      /* best-effort cleanup */
    }

    const invitations = await this.prisma.invitation.findMany({
      where: {
        status: 'PENDING',
        expiresAt: { gt: now },
        ...(token ? { token } : { ...(phone ? { phone } : {}) }),
      },
      include: { organization: true, branch: true },
    });

    if (invitations.length === 0) {
      throw new BadRequestException(
        token
          ? 'Invalid invitation (wrong or already used/expired token)'
          : 'No pending invitations found',
      );
    }

    return invitations.map((inv) => ({
      id: inv.id,
      role: inv.role,
      email: inv.email,
      branchId: inv.branchId,
      branch: inv.branch,
      organizationId: inv.organizationId,
      organization: inv.organization,
      status: inv.status,
      expiresAt: inv.expiresAt.toISOString(),
    }));
  }

  // ── Send staff activation OTP (email verification for invited staff) ──────
  async sendStaffActivationOtp(email: string, token?: string) {
    const normalized = email.trim().toLowerCase();

    const invitation = await this.prisma.invitation.findFirst({
      where: {
        status: 'PENDING',
        expiresAt: { gt: new Date() },
        ...(token ? { token } : { email: normalized }),
      },
    });

    if (!invitation) {
      throw new BadRequestException(
        'No pending invitation found for this email. Please request a new invitation.',
      );
    }

    await this.otpService.generateOtp(
      normalized,
      OTP_PURPOSES.STAFF_ACTIVATION,
    );
    return {
      message: 'A verification code has been sent to your email.',
    };
  }

  // ── Activate Invitation (consume email OTP → create staff account) ────────
  async activateInvitation(dto: {
    token?: string;
    email: string;
    otpCode: string;
    fullName: string;
    password: string;
  }) {
    const email = dto.email.trim().toLowerCase();
    await this.otpService.verifyOtp(
      email,
      dto.otpCode,
      OTP_PURPOSES.STAFF_ACTIVATION,
    );

    const now = new Date();
    const invitation = await this.prisma.invitation.findFirst({
      where: {
        status: 'PENDING',
        expiresAt: { gt: now },
        ...(dto.token ? { token: dto.token } : { email }),
      },
      include: { organization: true },
    });

    if (!invitation) {
      throw new BadRequestException(
        'Invitation not found or expired. Please request a new invitation.',
      );
    }

    // Verify organization still exists
    const organization = await this.prisma.organization.findUnique({
      where: { id: invitation.organizationId },
    });
    if (!organization) {
      throw new BadRequestException(
        'Organization not found. Please check the details.',
      );
    }

    let user = await this.prisma.user.findUnique({
      where: { email },
    });

    const passwordHash = await this.passwordService.hash(dto.password);

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          email,
          fullName: dto.fullName,
          passwordHash,
          emailVerified: true,
        },
      });
    } else {
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: {
          fullName: dto.fullName,
          passwordHash,
          emailVerified: true,
        },
      });
    }

    // Owner assigned the branch + role on the invitation
    await this.prisma.userBusinessAssignment.create({
      data: {
        userId: user.id,
        organizationId: invitation.organizationId,
        role: invitation.role,
        branchId: invitation.branchId,
      },
    });

    await this.prisma.invitation.update({
      where: { id: invitation.id },
      data: { status: 'ACTIVE' },
    });

    this.logger.log(
      `Invitation activated: user id=${user.id} org=${invitation.organizationId} role=${invitation.role}`,
    );

    const tokens = await this.jwtService.generateTokens(
      user.id,
      invitation.organizationId,
      invitation.role,
    );
    return {
      tokens,
      user: this.sanitizeUser(user),
      roles: [
        {
          businessId: invitation.organizationId,
          branchId: invitation.branchId,
          role: invitation.role,
        },
      ],
    };
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
    return { user: this.sanitizeUser(user), organization };
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

    await this.prisma.user.update({
      where: { id: assignment.userId },
      data: { fullName },
    });

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

  // ── Helpers ────────────────────────────────────────────────────────────────

  private sanitizeUser(user: {
    id: string;
    fullName: string | null;
    phone: string | null;
    email: string | null;
    status: string;
    createdAt: Date;
    updatedAt: Date;
    emailVerified?: boolean;
  }) {
    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      email: user.email,
      emailVerified: user.emailVerified ?? undefined,
      status: user.status,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }

  private buildAuthResponse(user: any, assignment: any, tokens: any) {
    const org = assignment.organization;
    return {
      tokens,
      requiresBusinessSelection: false,
      user: this.sanitizeUser(user),
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
      roles: user.userAssignments.map((a: any) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }
}
