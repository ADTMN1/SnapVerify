import { resolveThrottlingConfig } from './throttling.config';

describe('resolveThrottlingConfig', () => {
  it('returns documented safe defaults when variables are unset', () => {
    const cfg = resolveThrottlingConfig({});
    expect(cfg).toEqual({
      ttlMs: 60_000,
      defaultLimit: 100,
      paymentVerifyLimit: 60,
      paymentVerifyImageLimit: 30,
    });
  });

  it('uses configured values when valid', () => {
    const cfg = resolveThrottlingConfig({
      THROTTLE_TTL_MS: '30000',
      THROTTLE_LIMIT: '50',
      PAYMENT_VERIFY_RATE_LIMIT: '20',
      PAYMENT_VERIFY_IMAGE_RATE_LIMIT: '10',
    });
    expect(cfg).toEqual({
      ttlMs: 30_000,
      defaultLimit: 50,
      paymentVerifyLimit: 20,
      paymentVerifyImageLimit: 10,
    });
  });

  it.each([
    ['non-numeric', { THROTTLE_LIMIT: 'abc' }],
    ['zero', { THROTTLE_LIMIT: '0' }],
    ['negative', { THROTTLE_LIMIT: '-5' }],
    ['non-integer', { THROTTLE_LIMIT: '1.5' }],
    ['invalid ttl', { THROTTLE_TTL_MS: 'abc' }],
    ['invalid verify limit', { PAYMENT_VERIFY_RATE_LIMIT: '0' }],
    ['invalid image limit', { PAYMENT_VERIFY_IMAGE_RATE_LIMIT: '-1' }],
  ])('fails fast on %s configuration', (_label, env) => {
    expect(() => resolveThrottlingConfig(env as any)).toThrow(/FATAL/);
  });
});
