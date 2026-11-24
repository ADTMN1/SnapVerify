import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import * as crypto from 'crypto';
import { AdminJwtService } from './admin-jwt.service';

const ACCESS_SECRET = 'a'.repeat(64);
const REFRESH_SECRET = 'b'.repeat(64);
const ADMIN_ACCESS_SECRET = 'c'.repeat(64);
const ADMIN_REFRESH_SECRET = 'd'.repeat(64);

function hmacAdminRefreshToken(token: string) {
  return crypto
    .createHmac('sha256', ADMIN_REFRESH_SECRET)
    .update(token)
    .digest('hex');
}

function makeConfig() {
  return new ConfigService({
    JWT_ACCESS_SECRET: ACCESS_SECRET,
    JWT_REFRESH_SECRET: REFRESH_SECRET,
    JWT_ADMIN_ACCESS_SECRET: ADMIN_ACCESS_SECRET,
    JWT_ADMIN_REFRESH_SECRET: ADMIN_REFRESH_SECRET,
  });
}

describe('AdminJwtService — dedicated secrets', () => {
  let service: AdminJwtService;
  let jwt: { sign: jest.Mock; verify: jest.Mock };
  let prisma: { refreshToken: Record<string, jest.Mock> };

  beforeEach(() => {
    jwt = {
      sign: jest.fn().mockReturnValue('admin-access-token'),
      verify: jest.fn().mockReturnValue({ sub: 'admin-1' }),
    };
    prisma = {
      refreshToken: {
        findMany: jest.fn().mockResolvedValue([]),
        create: jest.fn().mockResolvedValue({}),
        findUnique: jest.fn().mockResolvedValue(null),
        delete: jest.fn().mockResolvedValue({}),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    service = new AdminJwtService(
      jwt as unknown as NestJwtService,
      makeConfig(),
      prisma as never,
    );
  });

  it('signs access tokens with the admin access secret', async () => {
    await service.generateTokens('admin-1', 'admin@example.com', 'SUPER_ADMIN');

    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({
        sub: 'admin-1',
        email: 'admin@example.com',
        role: 'SUPER_ADMIN',
      }),
      expect.objectContaining({ secret: ADMIN_ACCESS_SECRET }),
    );
  });

  it('hashes admin refresh tokens with the dedicated admin refresh secret', async () => {
    const result = await service.generateTokens(
      'admin-1',
      'admin@example.com',
      'SUPER_ADMIN',
    );
    const data = prisma.refreshToken.create.mock.calls[0][0].data;

    expect(data.token).toBe(hmacAdminRefreshToken(result.refreshToken));
    expect(data.token).not.toBe(result.refreshToken);
    expect(data.organizationId).toBe('admin');
  });

  it('accepts an admin refresh token hashed with the admin refresh secret', async () => {
    const refreshToken = 'admin-refresh-token';
    prisma.refreshToken.findUnique.mockResolvedValueOnce({
      id: 'rt-1',
      token: hmacAdminRefreshToken(refreshToken),
      organizationId: 'admin',
      role: 'SUPER_ADMIN',
      expiresAt: new Date(Date.now() + 60_000),
      user: {
        id: 'admin-1',
        email: 'admin@example.com',
        status: 'active',
      },
    });

    const result = await service.refreshTokens(refreshToken);

    expect(result.accessToken).toBe('admin-access-token');
    expect(prisma.refreshToken.delete).toHaveBeenCalledWith({
      where: { id: 'rt-1' },
    });
  });

  it('rejects application refresh tokens', async () => {
    prisma.refreshToken.findUnique.mockResolvedValueOnce({
      id: 'rt-2',
      token: 'app-token-hash',
      organizationId: 'org-1',
      role: 'OWNER',
      expiresAt: new Date(Date.now() + 60_000),
      user: { id: 'user-1', email: 'owner@example.com', status: 'active' },
    });

    await expect(
      service.refreshTokens('app-refresh-token'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('verifies access tokens with the admin access secret', () => {
    service.verifyAccessToken('admin-access-token');
    expect(jwt.verify).toHaveBeenCalledWith('admin-access-token', {
      secret: ADMIN_ACCESS_SECRET,
    });
  });
});
