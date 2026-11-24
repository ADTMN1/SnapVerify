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

describe('AdminJwtAuthGuard — secret separation', () => {
  const jwt = new JwtService();

  it('accepts a token signed with the dedicated admin access secret', () => {
    const guard = new AdminJwtAuthGuard(jwt, makeConfig());
    const token = jwt.sign(
      { sub: 'admin-1', email: 'admin@example.com', role: 'SUPER_ADMIN' },
      { secret: ADMIN_ACCESS_SECRET, expiresIn: '15m' },
    );
    const request: Record<string, unknown> = {};

    expect(() => guard.canActivate(makeContext(token, request))).not.toThrow();
    expect(request.admin).toEqual(
      expect.objectContaining({
        sub: 'admin-1',
        email: 'admin@example.com',
        role: 'SUPER_ADMIN',
      }),
    );
  });

  it('rejects a token signed with the application access secret', () => {
    const guard = new AdminJwtAuthGuard(jwt, makeConfig());
    const token = jwt.sign(
      { sub: 'user-1', email: 'owner@example.com', role: 'OWNER' },
      { secret: ACCESS_SECRET, expiresIn: '15m' },
    );

    expect(() => guard.canActivate(makeContext(token))).toThrow(
      UnauthorizedException,
    );
  });

  it('fails closed when the dedicated admin secret is missing', () => {
    const config = makeConfig();
    jest.spyOn(config, 'getOrThrow').mockImplementation((key: string) => {
      if (key === 'JWT_ADMIN_ACCESS_SECRET') {
        throw new Error('missing');
      }
      return key === 'JWT_ADMIN_REFRESH_SECRET' ? ADMIN_REFRESH_SECRET : '';
    });

    expect(() => new AdminJwtAuthGuard(jwt, config)).toThrow();
  });

  it('fails closed when admin and application secrets are reused', () => {
    expect(
      () =>
        new AdminJwtAuthGuard(
          jwt,
          makeConfig({ JWT_ADMIN_ACCESS_SECRET: ACCESS_SECRET }),
        ),
    ).toThrow(/distinct/);
  });
});
