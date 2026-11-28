import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../otp/otp.service';
import { PasswordService } from './password.service';
import { EmailService } from '../email/email.service';
import { SmsService } from '../sms/sms.service';
import { JwtService } from './jwt.service';
import { ROLES_KEY } from './decorators/roles.decorator';

describe('AuthService — authorization hardening', () => {
  let service: AuthService;
  let prisma: Record<string, Record<string, jest.Mock>>;

  beforeEach(async () => {
    prisma = {
      invitation: {
        findMany: jest.fn().mockResolvedValue([]),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      userBusinessAssignment: {
        findMany: jest.fn().mockResolvedValue([]),
      },
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: OtpService, useValue: {} },
        { provide: PasswordService, useValue: {} },
        { provide: EmailService, useValue: {} },
        { provide: SmsService, useValue: {} },
        { provide: JwtService, useValue: {} },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('restricts invitation lookup and staff listing to owners and managers', () => {
    expect(
      Reflect.getMetadata(ROLES_KEY, AuthController.prototype.getInvitations),
    ).toEqual([Role.OWNER, Role.MANAGER]);
    expect(
      Reflect.getMetadata(ROLES_KEY, AuthController.prototype.getStaff),
    ).toEqual([Role.OWNER, Role.MANAGER]);
  });

  it('scopes invitation lookup to the authenticated organization', async () => {
    prisma.invitation.findMany.mockResolvedValueOnce([
      {
        id: 'inv-1',
        fullName: 'Staff',
        role: Role.CASHIER,
        status: 'PENDING',
      },
    ]);

    const result = await service.getInvitation('+251900000000', 'org-1');
    const query = prisma.invitation.findMany.mock.calls[0][0];

    expect(query.where.organizationId).toBe('org-1');
    expect(query.where.status).toBe('PENDING');
    expect(query.where.expiresAt).toHaveProperty('gt');
    expect(query.select.token).toBeUndefined();
    expect(JSON.stringify(result)).not.toContain('token');
  });

  it('does not delete expired invitations during lookup', async () => {
    prisma.invitation.findMany.mockResolvedValueOnce([]);

    await expect(
      service.getInvitation('+251900000000', 'org-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.invitation.deleteMany).not.toHaveBeenCalled();
  });

  it('returns only safe staff fields', async () => {
    prisma.userBusinessAssignment.findMany.mockResolvedValueOnce([
      {
        id: 'assignment-1',
        userId: 'user-1',
        role: Role.CASHIER,
        user: { id: 'user-1', username: 'cashier' },
      },
    ]);

    const result = await service.getStaff('org-1');
    const query = prisma.userBusinessAssignment.findMany.mock.calls[0][0];

    expect(query.where.organizationId).toBe('org-1');
    expect(query.include.user.select).not.toHaveProperty('passwordHash');
    expect(JSON.stringify(query.include.user.select)).not.toContain(
      'refreshToken',
    );
    expect(query.include.user.select.username).toBe(true);
    expect(JSON.stringify(result)).not.toContain('passwordHash');
  });
});
