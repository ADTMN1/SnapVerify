import { Reflector } from '@nestjs/core';
import { AuthController } from './auth.controller';

const THROTTLER_TTL = 'THROTTLER:TTLdefault';
const THROTTLER_LIMIT = 'THROTTLER:LIMITdefault';

describe('AuthController throttling metadata', () => {
  const reflector = new Reflector();

  it.each([
    ['login', 5],
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
