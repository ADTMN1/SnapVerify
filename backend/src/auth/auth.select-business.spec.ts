import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { Role } from '@prisma/client';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../otp/otp.service';
import { PasswordService } from './password.service';
import { EmailService } from '../email/email.service';
import { SmsService } from '../sms/sms.service';
import { JwtService } from './jwt.service';

function makeUser(assignments: any[] = []) {
  return {
    id: 'user-1',
    email: 'owner@example.com',
    fullName: 'Owner',
    phone: null,
    username: null,
    passwordHash: 'hashed',
    emailVerified: true,
    status: 'active',
    createdAt: new Date(),
    updatedAt: new Date(),
    userAssignments: assignments,
  };
}

function makeAssignment(organizationId: string, role: Role = Role.OWNER) {
  return {
    id: `assignment-${organizationId}`,
    userId: 'user-1',
    organizationId,
    role,
    branchId: null,
    status: 'active',
    organization: {
      id: organizationId,
      name: organizationId,
      type: 'restaurant',
      phone: '',
      email: null,
      address: null,
      city: null,
      country: null,
    },
  };
}

describe('AuthService — secure business selection', () => {
  let service: AuthService;
  let prisma: Record<string, Record<string, jest.Mock>>;
  let jwtService: Record<string, jest.Mock>;

  beforeEach(async () => {
    prisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        findUnique: jest.fn().mockResolvedValue(null),
      },
      subscription: { findFirst: jest.fn().mockResolvedValue(null) },
      subscriptionUsage: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    jwtService = {
      generateTokens: jest.fn().mockResolvedValue({ accessToken: 'a' }),
      generateBusinessSelectionChallenge: jest
        .fn()
        .mockResolvedValue('selection-token'),
      consumeBusinessSelectionChallenge: jest.fn().mockResolvedValue('user-1'),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: OtpService, useValue: {} },
        {
          provide: PasswordService,
          useValue: {
            verify: jest
              .fn()
              .mockResolvedValue({ valid: true, needsRehash: false }),
          },
        },
        { provide: EmailService, useValue: {} },
        { provide: SmsService, useValue: {} },
        { provide: JwtService, useValue: jwtService },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('issues a selection challenge for multi-business login', async () => {
    prisma.user.findFirst.mockResolvedValueOnce(
      makeUser([
        makeAssignment('org-1'),
        makeAssignment('org-2', Role.MANAGER),
      ]),
    );

    const result = await service.login('owner@example.com', 'pw');

    expect(result.requiresBusinessSelection).toBe(true);
    if (!('selectionToken' in result)) {
      throw new Error('Expected a business-selection response');
    }
    expect(result.selectionToken).toBe('selection-token');
    expect(result.businesses).toHaveLength(2);
    expect(
      (result.user as Record<string, unknown>).passwordHash,
    ).toBeUndefined();
    expect(jwtService.generateBusinessSelectionChallenge).toHaveBeenCalledWith(
      'user-1',
    );
    expect(jwtService.generateTokens).not.toHaveBeenCalled();
  });

  it('issues tokens directly for a single-business login', async () => {
    prisma.user.findFirst.mockResolvedValueOnce(
      makeUser([makeAssignment('org-1')]),
    );

    const result = await service.login('owner@example.com', 'pw');

    expect(result.requiresBusinessSelection).toBe(false);
    expect(result).toHaveProperty('tokens');
    expect(result).not.toHaveProperty('selectionToken');
    expect(
      jwtService.generateBusinessSelectionChallenge,
    ).not.toHaveBeenCalled();
    expect(jwtService.generateTokens).toHaveBeenCalled();
  });

  it('issues a fresh challenge for in-app business switching', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser([
        makeAssignment('org-1'),
        makeAssignment('org-2', Role.MANAGER),
      ]),
    );

    const result = await service.issueBusinessSelectionChallenge('user-1');

    expect(result.selectionToken).toBe('selection-token');
    expect(result.businesses).toHaveLength(2);
    expect(jwtService.generateBusinessSelectionChallenge).toHaveBeenCalledWith(
      'user-1',
    );
  });

  it('refuses to issue a switching challenge for a single-org user', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser([makeAssignment('org-1')]),
    );

    await expect(
      service.issueBusinessSelectionChallenge('user-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(
      jwtService.generateBusinessSelectionChallenge,
    ).not.toHaveBeenCalled();
  });

  it('issues tokens only after the challenge is consumed', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser([makeAssignment('org-1')]),
    );

    await service.selectBusiness('selection-token', 'org-1');

    expect(jwtService.consumeBusinessSelectionChallenge).toHaveBeenCalledWith(
      'selection-token',
    );
    expect(jwtService.generateTokens).toHaveBeenCalledWith(
      'user-1',
      'org-1',
      Role.OWNER,
      undefined,
      undefined,
      undefined,
      expect.any(Number),
    );
  });

  it('returns tokens, organization and roles after a successful selection', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser([
        makeAssignment('org-1'),
        makeAssignment('org-2', Role.MANAGER),
      ]),
    );

    const result = await service.selectBusiness(
      'selection-token',
      'org-2',
      true,
    );

    expect(result.requiresBusinessSelection).toBe(false);
    expect(result.tokens).toEqual({ accessToken: 'a' });
    expect(result.organization).toEqual(
      expect.objectContaining({ id: 'org-2' }),
    );
    expect(result.roles).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ businessId: 'org-2', role: Role.MANAGER }),
      ]),
    );
    expect(jwtService.generateTokens).toHaveBeenCalledWith(
      'user-1',
      'org-2',
      Role.MANAGER,
      undefined,
      undefined,
      undefined,
      expect.any(Number),
    );
  });

  it('rejects business selection without a challenge', async () => {
    jwtService.consumeBusinessSelectionChallenge.mockRejectedValueOnce(
      new UnauthorizedException(),
    );

    await expect(service.selectBusiness('', 'org-1')).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(jwtService.generateTokens).not.toHaveBeenCalled();
  });

  it('rejects selection of an organization not assigned to the challenge user', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser([makeAssignment('org-1')]),
    );

    await expect(
      service.selectBusiness('selection-token', 'org-2'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(jwtService.generateTokens).not.toHaveBeenCalled();
  });
});
