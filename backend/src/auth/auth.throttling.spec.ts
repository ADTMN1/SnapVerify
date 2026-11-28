import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import {
  getOptionsToken,
  getStorageToken,
  ThrottlerException,
  ThrottlerStorageService,
} from '@nestjs/throttler';
import { AuthController } from './auth.controller';
import { OrgThrottlerGuard } from './guards/org-throttler.guard';

const THROTTLER_TTL = 'THROTTLER:TTLdefault';
const THROTTLER_LIMIT = 'THROTTLER:LIMITdefault';

describe('AuthController throttling metadata', () => {
  const reflector = new Reflector();

  it.each([
    ['login', 10],
    ['register', 3],
    ['verifyEmail', 5],
    ['resendVerification', 3],
    ['forgotPassword', 3],
    ['resetPassword', 5],
    ['checkInvitationPublic', 6],
    ['staffActivationOtp', 3],
    ['activateInvitation', 5],
    ['selectBusiness', 5],
    ['logout', 5],
  ])('uses a 60-second window for %s (limit %i)', (method, limit) => {
    const handler = (AuthController.prototype as Record<string, unknown>)[
      method
    ];
    expect(typeof handler).toBe('function');
    expect(reflector.get<number>(THROTTLER_TTL, handler as never)).toBe(60_000);
    expect(reflector.get<number>(THROTTLER_LIMIT, handler as never)).toBe(
      limit,
    );
  });

  it('does not throttle the refresh route with a shorter per-route window', () => {
    const handler = (AuthController.prototype as Record<string, unknown>)[
      'refreshToken'
    ];
    expect(
      reflector.get<number>(THROTTLER_TTL, handler as never),
    ).toBeUndefined();
  });
});

describe('AuthController login throttling behavior', () => {
  const reflector = new Reflector();
  const login = (AuthController.prototype as Record<string, unknown>)[
    'login'
  ] as (...args: unknown[]) => unknown;

  function makeContext(): ExecutionContext {
    return {
      getHandler: () => login,
      getClass: () => AuthController,
      switchToHttp: () => ({
        getRequest: () => ({ ip: '192.0.2.44', headers: {} }),
        getResponse: () => ({ header: jest.fn() }),
      }),
    } as unknown as ExecutionContext;
  }

  it('allows 10 login attempts per 60 seconds and throttles the 11th', async () => {
    const limit = reflector.get<number>(THROTTLER_LIMIT, login as never);
    const ttl = reflector.get<number>(THROTTLER_TTL, login as never);
    expect(limit).toBe(10);
    expect(ttl).toBe(60_000);

    const moduleRef = await Test.createTestingModule({
      providers: [
        OrgThrottlerGuard,
        {
          provide: getOptionsToken(),
          useValue: {
            throttlers: [{ name: 'default', ttl, limit }],
          },
        },
        { provide: getStorageToken(), useClass: ThrottlerStorageService },
        Reflector,
        {
          provide: JwtService,
          useValue: new JwtService({
            secret: 'test-secret-that-is-long-enough',
          }),
        },
      ],
    }).compile();

    const guard = moduleRef.get<OrgThrottlerGuard>(OrgThrottlerGuard);
    await guard.onModuleInit();
    const context = makeContext();

    for (let attempt = 1; attempt <= 10; attempt++) {
      await expect(guard.canActivate(context)).resolves.toBe(true);
    }

    await expect(guard.canActivate(context)).rejects.toBeInstanceOf(
      ThrottlerException,
    );
    await expect(guard.canActivate(context)).rejects.toMatchObject({
      status: 429,
    });
  });
});
