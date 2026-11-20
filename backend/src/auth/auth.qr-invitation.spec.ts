/**
 * QR staff invitation flow — unit tests.
 * Covers: addStaff profile creation, single-use activation, expiry,
 * revocation, regeneration, username login, and org isolation.
 */
import { Test } from '@nestjs/testing';
import { BadRequestException, ConflictException, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../otp/otp.service';
import { PasswordService } from './password.service';
import { EmailService } from '../email/email.service';
import { SmsService } from '../sms/sms.service';
import { JwtService } from './jwt.service';
import { Role } from '@prisma/client';

const NOW = new Date('2026-01-01T00:00:00Z');

function makeInvitation(overrides: Record<string, unknown> = {}) {
  return {
    id: 'inv-1',
    token: 'tok-abc',
    fullName: 'Test Staff',
    username: 'teststaff',
    email: null,
    phone: null,
    organizationId: 'org-1',
    branchId: null,
    role: Role.CASHIER,
    status: 'PENDING',
    expiresAt: new Date(NOW.getTime() + 10 * 60 * 1000),
    usedAt: null,
    revokedAt: null,
    organization: { id: 'org-1', name: 'Biz' },
    branch: null,
    ...overrides,
  };
}

describe('AuthService — QR staff invitations', () => {
  let service: AuthService;
  let prisma: {
    user: Record<string, jest.Mock>;
    invitation: Record<string, jest.Mock>;
    userBusinessAssignment: Record<string, jest.Mock>;
    branch: Record<string, jest.Mock>;
  };
  let passwordService: { hash: jest.Mock; verify: jest.Mock };
  let jwtService: { generateTokens: jest.Mock };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(null),
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'user-1', username: 'teststaff' }),
      },
      invitation: {
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn(),
        create: jest.fn().mockImplementation(({ data }) =>
          Promise.resolve(makeInvitation({ ...data })),
        ),
        update: jest.fn().mockImplementation(({ data, where }) =>
          Promise.resolve(makeInvitation({ id: where.id, ...data })),
        ),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn().mockResolvedValue([]),
      },
      userBusinessAssignment: {
        create: jest.fn().mockResolvedValue({}),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      branch: { findFirst: jest.fn().mockResolvedValue({ id: 'b1' }) },
    };
    passwordService = {
      hash: jest.fn().mockResolvedValue('hashed'),
      verify: jest.fn().mockResolvedValue({ valid: true, needsRehash: false }),
    };
    jwtService = { generateTokens: jest.fn().mockResolvedValue({}) };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: OtpService, useValue: {} },
        { provide: PasswordService, useValue: passwordService },
        { provide: EmailService, useValue: {} },
        { provide: SmsService, useValue: {} },
        { provide: JwtService, useValue: jwtService },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    jest.spyOn((service as any).logger, 'log').mockImplementation(() => undefined);
    jest.spyOn((service as any).logger, 'warn').mockImplementation(() => undefined);
  });

  describe('addStaff', () => {
    it('creates a PENDING invitation with 10-minute expiry and no notification', async () => {
      const inv = await service.addStaff('org-1', 'Test Staff', 'TestStaff', Role.CASHIER);
      expect(inv.status).toBe('PENDING');
      expect(inv.username).toBe('teststaff');
      expect(prisma.invitation.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            username: 'teststaff',
            status: 'PENDING',
          }),
        }),
      );
      const data = prisma.invitation.create.mock.calls[0][0].data;
      const ttl = data.expiresAt.getTime() - Date.now();
      expect(ttl).toBeGreaterThan(9 * 60 * 1000);
      expect(ttl).toBeLessThanOrEqual(10 * 60 * 1000);
    });

    it('rejects OWNER role', async () => {
      await expect(
        service.addStaff('org-1', 'X', 'xuser', Role.OWNER),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects taken username (existing user)', async () => {
      prisma.user.findUnique.mockResolvedValueOnce({ id: 'u2' });
      await expect(
        service.addStaff('org-1', 'X', 'taken', Role.CASHIER),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('rejects username held by a pending invitation of ANY org', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce({ id: 'inv-other' });
      await expect(
        service.addStaff('org-1', 'X', 'taken', Role.CASHIER),
      ).rejects.toBeInstanceOf(ConflictException);
    });

    it('rejects invalid branch (org isolation)', async () => {
      prisma.branch.findFirst.mockResolvedValueOnce(null);
      await expect(
        service.addStaff('org-1', 'X', 'user1', Role.CASHIER, 'other-org-branch'),
      ).rejects.toBeInstanceOf(BadRequestException);
    });
  });

  describe('activateInvitation', () => {
    it('activates: creates user with username + assignment, marks ACTIVATED, no tokens', async () => {
      prisma.invitation.findFirst
        .mockResolvedValueOnce(makeInvitation()) // active invitation lookup
        .mockResolvedValueOnce(null); // duplicate status probe
      prisma.user.findUnique.mockResolvedValueOnce(null);

      const result = await service.activateInvitation({
        token: 'tok-abc',
        password: 'Str0ngPass!',
      });

      expect(result.message).toMatch(/activated successfully/i);
      expect(result.username).toBe('teststaff');
      expect(prisma.user.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            username: 'teststaff',
            emailVerified: true,
          }),
        }),
      );
      expect(prisma.userBusinessAssignment.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            organizationId: 'org-1',
            role: Role.CASHIER,
          }),
        }),
      );
      expect(prisma.invitation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'ACTIVATED' }),
        }),
      );
    });

    it('rejects expired invitations', async () => {
      prisma.invitation.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(makeInvitation({ status: 'EXPIRED' }));
      await expect(
        service.activateInvitation({ token: 'tok-abc', password: 'Str0ngPass!' }),
      ).rejects.toThrow(/expired/i);
    });

    it('rejects already-activated invitations', async () => {
      prisma.invitation.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(makeInvitation({ status: 'ACTIVATED' }));
      await expect(
        service.activateInvitation({ token: 'tok-abc', password: 'Str0ngPass!' }),
      ).rejects.toThrow(/already activated/i);
    });

    it('rejects revoked invitations', async () => {
      prisma.invitation.findFirst
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(makeInvitation({ status: 'REVOKED' }));
      await expect(
        service.activateInvitation({ token: 'tok-abc', password: 'Str0ngPass!' }),
      ).rejects.toThrow(/revoked/i);
    });

    it('rejects unknown tokens', async () => {
      prisma.invitation.findFirst.mockResolvedValue(null);
      await expect(
        service.activateInvitation({ token: 'nope', password: 'Str0ngPass!' }),
      ).rejects.toThrow(/Invalid invitation/i);
    });

    it('rejects usernames that already exist as users', async () => {
      prisma.invitation.findFirst
        .mockResolvedValueOnce(makeInvitation())
        .mockResolvedValueOnce(null);
      prisma.user.findUnique.mockResolvedValueOnce({ id: 'u9' });
      await expect(
        service.activateInvitation({ token: 'tok-abc', password: 'Str0ngPass!' }),
      ).rejects.toBeInstanceOf(ConflictException);
    });
  });

  describe('lifecycle management', () => {
    it('revokes a pending invitation scoped to the org', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce(
        makeInvitation({ organizationId: 'org-1' }),
      );
      await service.revokeInvitation('inv-1', 'org-1');
      expect(prisma.invitation.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ status: 'REVOKED' }),
        }),
      );
    });

    it('refuses to revoke invitations of another organization', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce(null);
      await expect(
        service.revokeInvitation('inv-1', 'org-OTHER'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('refuses to revoke an activated invitation', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce(
        makeInvitation({ status: 'ACTIVATED' }),
      );
      await expect(
        service.revokeInvitation('inv-1', 'org-1'),
      ).rejects.toThrow(/already activated/i);
    });

    it('regenerates: new token + fresh expiry, only when not activated', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce(
        makeInvitation({ status: 'EXPIRED' }),
      );
      await service.regenerateInvitation('inv-1', 'org-1');
      const data = prisma.invitation.update.mock.calls[0][0].data;
      expect(data.token).toBeTruthy();
      expect(data.status).toBe('PENDING');
      const ttl = data.expiresAt.getTime() - Date.now();
      expect(ttl).toBeGreaterThan(9 * 60 * 1000);
      expect(ttl).toBeLessThanOrEqual(10 * 60 * 1000);
    });

    it('refuses to regenerate an activated invitation', async () => {
      prisma.invitation.findFirst.mockResolvedValueOnce(
        makeInvitation({ status: 'ACTIVATED' }),
      );
      await expect(
        service.regenerateInvitation('inv-1', 'org-1'),
      ).rejects.toThrow(/already activated/i);
    });
  });

  describe('username login', () => {
    it('resolves staff by username when identifier is not email/phone', async () => {
      prisma.user.findFirst.mockResolvedValueOnce({
        id: 'u1',
        username: 'teststaff',
        passwordHash: 'h',
        emailVerified: true,
        userAssignments: [
          {
            organizationId: 'org-1',
            role: Role.CASHIER,
            branchId: null,
            status: 'active',
            organization: { id: 'org-1' },
          },
        ],
      });
      const result = await service.login('teststaff', 'pw');
      expect(prisma.user.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { username: 'teststaff' },
        }),
      );
      expect(result).toBeTruthy();
    });

    it('rejects unverified username users with 401 (no OTP for username path)', async () => {
      prisma.user.findFirst.mockResolvedValueOnce({
        id: 'u1',
        username: 'teststaff',
        passwordHash: 'h',
        email: null,
        emailVerified: false,
        userAssignments: [],
      });
      await expect(service.login('teststaff', 'pw')).rejects.toBeInstanceOf(
        UnauthorizedException,
      );
    });
  });
});
