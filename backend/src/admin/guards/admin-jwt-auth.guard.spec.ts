import { ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AdminJwtAuthGuard } from './admin-jwt-auth.guard';

const ACCESS_SECRET = 'a'.repeat(64);
const REFRESH_SECRET = 'b'.repeat(64);
const ADMIN_ACCESS_SECRET = 'c'.repeat(64);
const ADMIN_REFRESH_SECRET = 'd'.repeat(64);

function makeConfig(overrides: Record<string, string> = {}) {
  return new ConfigService({
    JWT_ACCESS_SECRET: ACCESS_SECRET,
    JWT_REFRESH_SECRET: REFRESH_SECRET,
    JWT_ADMIN_ACCESS_SECRET: ADMIN_ACCESS_SECRET,
    JWT_ADMIN_REFRESH_SECRET: ADMIN_REFRESH_SECRET,
    ...overrides,
  });
}

function makeContext(token: string, request: Record<string, unknown> = {}) {
  request.headers = { authorization: `Bearer ${token}` };
  return {
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function makeUser(overrides: Record<string, unknown> = {}) {
  return {
    status: 'active',
    isPlatformAdmin: true,
    userAssignments: [{ role: 'OWNER', status: 'active' }],
    ...overrides,
  };
}

describe('AdminJwtAuthGuard — session validation', () => {
  const jwt = new JwtService();
  let prisma: { user: { findUnique: jest.Mock } };

  beforeEach(() => {
    prisma = {
      user: { findUnique: jest.fn().mockResolvedValue(makeUser()) },
    };
  });

  function makeGuard(config = makeConfig()) {
    return new AdminJwtAuthGuard(jwt, config, prisma as never);
  }

  it('accepts a token signed with the dedicated admin access secret', async () => {
    const guard = makeGuard();
    const token = jwt.sign(
      { sub: 'admin-1', email: 'admin@example.com', role: 'SUPER_ADMIN' },
      { secret: ADMIN_ACCESS_SECRET, expiresIn: '15m' },
    );
    const request: Record<string, unknown> = {};

    await expect(guard.canActivate(makeContext(token, request))).resolves.toBe(
      true,
    );
    expect(request.admin).toEqual(
      expect.objectContaining({
        sub: 'admin-1',
        email: 'admin@example.com',
        role: 'SUPER_ADMIN',
      }),
    );
  });

  it('rejects a token signed with the application access secret', async () => {
    const token = jwt.sign(
      { sub: 'user-1', email: 'owner@example.com', role: 'OWNER' },
      { secret: ACCESS_SECRET, expiresIn: '15m' },
    );

    await expect(
      makeGuard().canActivate(makeContext(token)),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('rejects a demoted admin even if the token still says SUPER_ADMIN', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser({ isPlatformAdmin: false, userAssignments: [] }),
    );
    const token = jwt.sign(
      { sub: 'admin-1', email: 'admin@example.com', role: 'SUPER_ADMIN' },
      { secret: ADMIN_ACCESS_SECRET, expiresIn: '15m' },
    );

    await expect(
      makeGuard().canActivate(makeContext(token)),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('uses the current database role for an OWNER admin', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser({
        isPlatformAdmin: false,
        userAssignments: [{ role: 'OWNER', status: 'active' }],
      }),
    );
    const token = jwt.sign(
      { sub: 'admin-1', email: 'admin@example.com', role: 'SUPER_ADMIN' },
      { secret: ADMIN_ACCESS_SECRET, expiresIn: '15m' },
    );
    const request: Record<string, unknown> = {};

    await expect(
      makeGuard().canActivate(makeContext(token, request)),
    ).resolves.toBe(true);
    expect(request.admin).toEqual(
      expect.objectContaining({ role: 'BUSINESS_OWNER' }),
    );
  });

  it('rejects an inactive admin', async () => {
    prisma.user.findUnique.mockResolvedValueOnce(
      makeUser({ status: 'inactive' }),
    );
    const token = jwt.sign(
      { sub: 'admin-1', email: 'admin@example.com', role: 'SUPER_ADMIN' },
      { secret: ADMIN_ACCESS_SECRET, expiresIn: '15m' },
    );

    await expect(
      makeGuard().canActivate(makeContext(token)),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('fails closed when the dedicated admin secret is missing', () => {
    const config = makeConfig();
    jest.spyOn(config, 'getOrThrow').mockImplementation((key: string) => {
      if (key === 'JWT_ADMIN_ACCESS_SECRET') {
        throw new Error('missing');
      }
      return key === 'JWT_ADMIN_REFRESH_SECRET' ? ADMIN_REFRESH_SECRET : '';
    });

    expect(() => makeGuard(config)).toThrow();
  });

  it('fails closed when admin and application secrets are reused', () => {
    expect(() =>
      makeGuard(makeConfig({ JWT_ADMIN_ACCESS_SECRET: ACCESS_SECRET })),
    ).toThrow(/distinct/);
  });
});
