import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { validate } from 'class-validator';
import { AdminDataController } from '../admin/controllers/admin-data.controller';
import { ADMIN_ROLES_KEY } from '../admin/decorators/admin-roles.decorator';
import { AdminAuthService } from '../admin/services/admin-auth.service';
import { PlatformAdminService } from '../admin/services/platform-admin.service';
import { AuthService } from './auth.service';
import { CheckInvitationDto } from './dto/email-auth.dto';
import { JwtService } from './jwt.service';

describe('security regression fixes', () => {
  const future = new Date(Date.now() + 60_000);

  function buildAuthService(prisma: any, jwt: any = {}) {
    return new AuthService(
      prisma,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      jwt as any,
    );
  }

  it('requires a token on public invitation checks', async () => {
    const errors = await validate(Object.assign(new CheckInvitationDto(), {}));
    expect(errors.map((error) => error.property)).toContain('token');
  });

  it('scopes invitation lookups and cleanup to the supplied token', async () => {
    const prisma = {
      invitation: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'invite-1',
            role: Role.CASHIER,
            fullName: 'Test Staff',
            username: 'test.staff',
            email: null,
            branchId: null,
            branch: null,
            organizationId: 'org-1',
            organization: { id: 'org-1', name: 'Test Org' },
            status: 'PENDING',
            expiresAt: future,
          },
        ]),
      },
    };
    const service = buildAuthService(prisma);

    const result = await service.checkInvitation('token-1');

    expect(prisma.invitation.deleteMany).toHaveBeenCalledWith({
      where: { token: 'token-1', status: 'PENDING', expiresAt: { lt: expect.any(Date) } },
    });
    expect(prisma.invitation.findMany).toHaveBeenCalledWith({
      where: { token: 'token-1', status: 'PENDING', expiresAt: { gt: expect.any(Date) } },
      include: { organization: true, branch: true },
    });
    expect(result[0].organizationId).toBe('org-1');
  });

  it('rejects mismatched activation passwords', async () => {
    const service = buildAuthService({});
    await expect(
      service.activateInvitation({
        token: 'token-1',
        password: 'password1',
        confirmPassword: 'password2',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects login for a suspended user', async () => {
    const prisma = {
      user: { findFirst: jest.fn().mockResolvedValue({
        id: 'user-1',
        status: 'suspended',
        passwordHash: '$2b$10$hash',
        userAssignments: [{ status: 'active', organizationId: 'org-1' }],
      }) },
    };
    const passwordService = { verify: jest.fn().mockResolvedValue({ valid: true, needsRehash: false }) };
    const service = new AuthService(prisma as any, {} as any, passwordService as any, {} as any, {} as any, {} as any);

    await expect(service.login('cashier', 'password1')).rejects.toThrow(
      UnauthorizedException,
    );
  });

  it('prevents managers from assigning the OWNER role', async () => {
    const prisma = {
      userBusinessAssignment: {
        findFirst: jest.fn().mockResolvedValue({
          id: 'assignment-1',
          userId: 'user-1',
          organizationId: 'org-1',
          role: Role.CASHIER,
        }),
        update: jest.fn(),
      },
      user: { update: jest.fn() },
    };
    const jwt = { logoutAll: jest.fn() };
    const service = buildAuthService(prisma, jwt);

    await expect(
      service.updateStaff(
        'assignment-1',
        'org-1',
        'Renamed Staff',
        Role.OWNER,
        Role.MANAGER,
      ),
    ).rejects.toThrow(/Only an owner can assign the OWNER role/);
    expect(prisma.userBusinessAssignment.update).not.toHaveBeenCalled();
  });

  it('uses the current assignment role when refreshing tokens', async () => {
    const prisma = {
      refreshToken: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'refresh-1',
          userId: 'user-1',
          organizationId: 'org-1',
          role: Role.MANAGER,
          expiresAt: future,
          user: {
            status: 'active',
            userAssignments: [
              {
                organizationId: 'org-1',
                role: Role.CASHIER,
                status: 'active',
                branchId: null,
              },
            ],
          },
        }),
        delete: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    const config = { getOrThrow: jest.fn().mockReturnValue('x'.repeat(64)) };
    const jwt = new JwtService({} as any, config as any, prisma as any);
    jest.spyOn(jwt, 'generateTokens').mockResolvedValue({
      accessToken: 'access',
      refreshToken: 'refresh',
    });

    await jwt.refreshTokens('raw-refresh-token');

    expect(jwt.generateTokens).toHaveBeenCalledWith(
      'user-1',
      'org-1',
      Role.CASHIER,
      undefined,
      undefined,
      undefined,
      expect.any(Number),
    );
  });

  it('protects the platform subscription account with SUPER_ADMIN', () => {
    expect(
      Reflect.getMetadata(
        ADMIN_ROLES_KEY,
        AdminDataController.prototype.getSubscriptionAccount,
      ),
    ).toEqual(['SUPER_ADMIN']);
    expect(
      Reflect.getMetadata(
        ADMIN_ROLES_KEY,
        AdminDataController.prototype.updateSubscriptionAccount,
      ),
    ).toEqual(['SUPER_ADMIN']);
  });

  it('revokes admin sessions after a password change', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'admin-1',
          passwordHash: '$2b$10$hash',
        }),
        update: jest.fn(),
      },
      userBusinessAssignment: { findFirst: jest.fn().mockResolvedValue(null) },
      activityLog: { create: jest.fn() },
    };
    const adminJwt = { revokeAllTokens: jest.fn() };
    const passwordService = {
      verify: jest.fn().mockResolvedValue({ valid: true }),
      hash: jest.fn().mockResolvedValue('new-hash'),
    };
    const service = new AdminAuthService(
      prisma as any,
      adminJwt as any,
      passwordService as any,
      {} as any,
    );

    await service.changePassword('admin-1', 'old', 'new');

    expect(adminJwt.revokeAllTokens).toHaveBeenCalledWith('admin-1');
  });

  it('revokes refresh tokens when a platform user is suspended', async () => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue({ id: 'user-1' }),
        update: jest.fn().mockResolvedValue({ id: 'user-1', status: 'suspended' }),
      },
      refreshToken: { deleteMany: jest.fn() },
    };
    const service = new PlatformAdminService(prisma as any);

    await service.updateUser('user-1', { status: 'suspended' });

    expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'user-1' },
    });
  });
});
