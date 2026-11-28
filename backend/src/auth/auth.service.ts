import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
  ConflictException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService, OTP_PURPOSES } from '../otp/otp.service';
import { PasswordService } from './password.service';
import { EmailService } from '../email/email.service';
import { SmsService } from '../sms/sms.service';
import {
  JwtService,
  DEFAULT_REFRESH_TTL_MS,
  REMEMBERED_REFRESH_TTL_MS,
} from './jwt.service';
import { Role } from '@prisma/client';
import { RegisterDto } from './dto/email-auth.dto';
import {
  subscriptionDto,
  usagePeriodStart,
} from '../subscription/subscription-usage';
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
    await this.otpService.verifyOtp(normalized, otpCode, OTP_PURPOSES.REGISTER);

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
      throw new BadRequestException(
        'Account not found. Please register again.',
      );
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { emailVerified: true },
    });

    const activeAssignments = user.userAssignments.filter(
      (a) => a.status === 'active',
    );
    if (activeAssignments.length === 0) {
      throw new BadRequestException(
        'No active business assignment found. Please contact support.',
      );
    }

    if (activeAssignments.length > 1) {
      return this.buildBusinessSelectionResponse(user, activeAssignments);
    }

    const tokens = await this.jwtService.generateTokens(
      user.id,
      activeAssignments[0].organizationId,
      activeAssignments[0].role,
      activeAssignments[0].branchId ?? undefined,
    );
    return await this.buildAuthResponse(user, activeAssignments[0], tokens);
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
  async login(
    identifier: string,
    password: string,
    organizationId?: string,
    rememberMe = false,
  ) {
    const isEmail = EMAIL_RE.test(identifier);
    const normalized = identifier.trim().toLowerCase();
    // Resolution order: email → username → legacy phone. Username is only
    // tried when the identifier can't be an email or phone number, so owner
    // login behavior is unchanged.
    const isPhoneLike = /^\+?\d[\d\s-]{6,}$/.test(identifier.trim());
    const user = await this.prisma.user.findFirst({
      where: isEmail
        ? { email: normalized }
        : !isPhoneLike
          ? { username: normalized }
          : { phone: identifier.trim() },
      include: {
        userAssignments: {
          include: { organization: true },
        },
      },
    });

    if (!user) {
      this.logger.warn(
        `[Login] account lookup failed style=${isEmail ? 'email' : isPhoneLike ? 'phone' : 'username'}`,
      );
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
      const hashFamily = user.passwordHash.startsWith('$argon2')
        ? 'argon2id'
        : user.passwordHash.startsWith('$2')
          ? 'bcrypt'
          : 'unknown';
      this.logger.warn(
        `[Login] password verification failed userId=${user.id} hashFamily=${hashFamily}`,
      );
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

    if (user.status !== 'active') {
      throw new UnauthorizedException(
        'This account is not active. Please contact support.',
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
      return this.buildBusinessSelectionResponse(user, activeAssignments);
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
      undefined,
      undefined,
      rememberMe ? REMEMBERED_REFRESH_TTL_MS : DEFAULT_REFRESH_TTL_MS,
    );
    return await this.buildAuthResponse(user, assignment, tokens);
  }

  // ── Business switching (fresh single-use challenge) ─────────────────────
  async issueBusinessSelectionChallenge(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        userAssignments: {
          where: { status: 'active' },
          include: { organization: true },
        },
      },
    });

    if (!user) {
      throw new UnauthorizedException('Account not found.');
    }
    if (user.userAssignments.length < 2) {
      throw new BadRequestException(
        'Business switching requires more than one organization.',
      );
    }

    const selectionToken =
      await this.jwtService.generateBusinessSelectionChallenge(user.id);
    return {
      selectionToken,
      businesses: user.userAssignments.map((a) => ({
        organizationId: a.organizationId,
        organizationName: a.organization?.name,
        role: a.role,
        branchId: a.branchId,
      })),
    };
  }

  // ── Select Business (called when user has multiple orgs) ─────────────────
  async selectBusiness(
    selectionToken: string,
    organizationId: string,
    rememberMe = false,
  ) {
    const userId =
      await this.jwtService.consumeBusinessSelectionChallenge(selectionToken);

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
      undefined,
      undefined,
      rememberMe ? REMEMBERED_REFRESH_TTL_MS : DEFAULT_REFRESH_TTL_MS,
    );

    return await this.buildAuthResponse(user, assignment, tokens);
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

  // ── Staff invitation (QR flow: owner creates a staff profile and hands
  // over a single-use, 10-minute QR code) ────────────────────────────────────
  async addStaff(
    organizationId: string,
    fullName: string,
    username: string,
    role: Role,
    branchId?: string,
  ) {
    const normalizedUsername = username.trim().toLowerCase();
    if (!/^[a-z0-9._-]{3,30}$/.test(normalizedUsername)) {
      throw new BadRequestException(
        'Username must be 3-30 characters: letters, numbers, dots, dashes or underscores.',
      );
    }

    if (role === Role.OWNER) {
      throw new BadRequestException(
        'Cannot assign OWNER role through staff invitation. Please create a new business instead.',
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

    // Username must be free across users AND pending invitations of any org.
    const [existingUser, existingInvitation] = await Promise.all([
      this.prisma.user.findUnique({ where: { username: normalizedUsername } }),
      this.prisma.invitation.findFirst({
        where: { username: normalizedUsername, status: 'PENDING' },
      }),
    ]);
    if (existingUser || existingInvitation) {
      throw new ConflictException(
        'This username is already taken. Please choose another one.',
      );
    }

    // Single-use QR invitation, valid for 10 minutes.
    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    const invitation = await this.prisma.invitation.create({
      data: {
        token,
        fullName: fullName.trim(),
        username: normalizedUsername,
        organizationId,
        role,
        branchId: branchId || null,
        status: 'PENDING',
        expiresAt,
      },
    });

    this.logger.log(
      `QR invitation created: id=${invitation.id} role=${role} expires=${expiresAt.toISOString()}`,
    );

    return invitation;
  }

  // ── List invitations for the organization (owner/manager) ─────────────────
  async listInvitations(organizationId: string) {
    const now = new Date();
    // Expire stale PENDING rows lazily so the UI always reflects reality.
    await this.prisma.invitation.updateMany({
      where: {
        organizationId,
        status: 'PENDING',
        expiresAt: { lt: now },
      },
      data: { status: 'EXPIRED' },
    });

    return this.prisma.invitation.findMany({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
      include: { branch: { select: { id: true, name: true } } },
    });
  }

  // ── Revoke a pending invitation (owner/manager) ───────────────────────────
  async revokeInvitation(invitationId: string, organizationId: string) {
    const invitation = await this.prisma.invitation.findFirst({
      where: { id: invitationId, organizationId },
    });
    if (!invitation) {
      throw new NotFoundException('Invitation not found.');
    }
    if (invitation.status === 'ACTIVATED') {
      throw new BadRequestException('This invitation was already activated.');
    }
    if (invitation.status === 'REVOKED') {
      throw new BadRequestException('This invitation is already revoked.');
    }

    return this.prisma.invitation.update({
      where: { id: invitationId },
      data: { status: 'REVOKED', revokedAt: new Date() },
    });
  }

  // ── Regenerate a QR invitation (new token, fresh 10-minute expiry) ────────
  async regenerateInvitation(invitationId: string, organizationId: string) {
    const invitation = await this.prisma.invitation.findFirst({
      where: { id: invitationId, organizationId },
    });
    if (!invitation) {
      throw new NotFoundException('Invitation not found.');
    }
    if (invitation.status === 'ACTIVATED') {
      throw new BadRequestException(
        'This invitation was already activated and cannot be regenerated.',
      );
    }

    const token = crypto.randomBytes(32).toString('hex');
    return this.prisma.invitation.update({
      where: { id: invitationId },
      data: {
        token,
        status: 'PENDING',
        revokedAt: null,
        usedAt: null,
        expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      },
    });
  }

  async getInvitation(phone: string, organizationId: string) {
    const invitations = await this.prisma.invitation.findMany({
      where: {
        phone,
        organizationId,
        status: 'PENDING',
        expiresAt: { gt: new Date() },
      },
      select: {
        id: true,
        fullName: true,
        username: true,
        email: true,
        phone: true,
        organizationId: true,
        branchId: true,
        role: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        expiresAt: true,
        usedAt: true,
        revokedAt: true,
        organization: { select: { id: true, name: true } },
        branch: { select: { id: true, name: true } },
      },
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
  async checkInvitation(token: string) {
    const now = new Date();

    try {
      await this.prisma.invitation.deleteMany({
        where: {
          token,
          status: 'PENDING',
          expiresAt: { lt: now },
        },
      });
    } catch (_) {
      /* best-effort cleanup */
    }

    const invitations = await this.prisma.invitation.findMany({
      where: {
        token,
        status: 'PENDING',
        expiresAt: { gt: now },
      },
      include: { organization: true, branch: true },
    });

    if (invitations.length === 0) {
      throw new BadRequestException(
        'Invalid invitation (wrong or already used/expired token)',
      );
    }

    return invitations.map((inv) => ({
      id: inv.id,
      role: inv.role,
      fullName: inv.fullName,
      username: inv.username,
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

  // ── Activate Invitation (QR flow: validate token → staff sets password) ───
  async activateInvitation(dto: {
    token: string;
    password: string;
    confirmPassword: string;
  }) {
    if (dto.password !== dto.confirmPassword) {
      throw new BadRequestException('Passwords do not match.');
    }

    const now = new Date();

    // Single-use activation: the updateMany guard below fails if two devices
    // scan the same QR concurrently — only the first wins.
    const invitation = await this.prisma.invitation.findFirst({
      where: {
        token: dto.token,
        status: 'PENDING',
        expiresAt: { gt: now },
      },
      include: { organization: true, branch: true },
    });

    if (!invitation) {
      // Distinguish the common cases for a clear UX message.
      const anyMatch = await this.prisma.invitation.findFirst({
        where: { token: dto.token },
      });
      if (!anyMatch) {
        throw new BadRequestException(
          'Invalid invitation. Please scan the QR code again.',
        );
      }
      if (anyMatch.status === 'ACTIVATED') {
        throw new BadRequestException(
          'This invitation was already activated. Please log in instead.',
        );
      }
      if (anyMatch.status === 'REVOKED') {
        throw new BadRequestException(
          'This invitation was revoked. Please ask your manager for a new one.',
        );
      }
      throw new BadRequestException(
        'This invitation has expired. Please ask your manager to regenerate it.',
      );
    }

    const username = invitation.username?.trim().toLowerCase();
    if (!username) {
      throw new BadRequestException(
        'This invitation has no assigned username. Please ask your manager to regenerate it.',
      );
    }

    // Username must not collide with an existing account.
    const existingUser = await this.prisma.user.findUnique({
      where: { username },
    });
    if (existingUser) {
      throw new ConflictException(
        'This username is already taken. Please ask your manager for assistance.',
      );
    }

    const passwordHash = await this.passwordService.hash(dto.password);

    const user = await this.prisma.user.create({
      data: {
        username,
        fullName: invitation.fullName,
        email: invitation.email,
        phone: invitation.phone,
        passwordHash,
        emailVerified: true,
      },
    });

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
      data: { status: 'ACTIVATED', usedAt: now },
    });

    this.logger.log(
      `Invitation activated: user id=${user.id} org=${invitation.organizationId} role=${invitation.role}`,
    );

    // Staff logs in with username + password afterwards; do NOT issue
    // tokens here so credentials are only ever entered on the login screen.
    return {
      message: 'Account activated successfully. You can now log in.',
      username,
      organization: invitation.organization
        ? { id: invitation.organization.id, name: invitation.organization.name }
        : null,
      role: invitation.role,
      branch: invitation.branch
        ? { id: invitation.branch.id, name: invitation.branch.name }
        : null,
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
    return {
      user: this.sanitizeUser(user),
      organization,
      subscription: await this.latestSubscription(organizationId),
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
        user: {
          select: {
            id: true,
            fullName: true,
            username: true,
            phone: true,
            email: true,
            emailVerified: true,
            status: true,
            createdAt: true,
            updatedAt: true,
          },
        },
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
    callerRole: string,
    branchId?: string,
  ) {
    if (role === Role.OWNER && callerRole !== Role.OWNER) {
      throw new BadRequestException(
        'Only an owner can assign the OWNER role.',
      );
    }

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

    if (assignment.role !== role) {
      await this.jwtService.logoutAll(assignment.userId);
    }

    this.logger.log(
      `Staff updated: id=${staffAssignmentId} role=${role} branch=${branchId || 'none'}`,
    );

    return updatedAssignment;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  private async buildBusinessSelectionResponse(user: any, assignments: any[]) {
    const selectionToken =
      await this.jwtService.generateBusinessSelectionChallenge(user.id);

    return {
      requiresBusinessSelection: true,
      selectionToken,
      businesses: assignments.map((a) => ({
        organizationId: a.organizationId,
        organizationName: a.organization?.name,
        role: a.role,
        branchId: a.branchId,
      })),
      user: this.sanitizeUser(user),
    };
  }

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

  private async latestSubscription(organizationId: string) {
    const subscription = await this.prisma.subscription.findFirst({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
    });
    if (!subscription) return null;
    const usage = await this.prisma.subscriptionUsage.findUnique({
      where: {
        subscriptionId_periodStart: {
          subscriptionId: subscription.id,
          periodStart: usagePeriodStart(subscription),
        },
      },
    });
    return subscriptionDto(subscription, usage);
  }

  private async buildAuthResponse(user: any, assignment: any, tokens: any) {
    const org = assignment.organization;
    return {
      tokens,
      requiresBusinessSelection: false,
      user: this.sanitizeUser(user),
      subscription: await this.latestSubscription(org.id),
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
