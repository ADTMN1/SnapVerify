import { PaymentController } from './payment.controller';
import { resolveThrottlingConfig } from '../config/throttling.config';

const LIMIT_KEY = 'THROTTLER:LIMITdefault';
const TTL_KEY = 'THROTTLER:TTLdefault';

describe('Payment endpoint rate-limit configuration (Stage 1)', () => {
  const cfg = resolveThrottlingConfig();

  it('applies the stricter reference-verification limit to POST /payments/verify', () => {
    const limit = Reflect.getMetadata(
      LIMIT_KEY,
      PaymentController.prototype.verifyByReference,
    );
    const ttl = Reflect.getMetadata(
      TTL_KEY,
      PaymentController.prototype.verifyByReference,
    );
    expect(limit).toBe(cfg.paymentVerifyLimit);
    expect(ttl).toBe(cfg.ttlMs);
  });

  it('applies the stricter image-verification limit to POST /payments/verify-image', () => {
    const limit = Reflect.getMetadata(
      LIMIT_KEY,
      PaymentController.prototype.verifyByImage,
    );
    const ttl = Reflect.getMetadata(
      TTL_KEY,
      PaymentController.prototype.verifyByImage,
    );
    expect(limit).toBe(cfg.paymentVerifyImageLimit);
    expect(ttl).toBe(cfg.ttlMs);
  });

  it('keeps payment limits stricter than the application default', () => {
    expect(cfg.paymentVerifyLimit).toBeLessThan(cfg.defaultLimit);
    expect(cfg.paymentVerifyImageLimit).toBeLessThan(cfg.defaultLimit);
    expect(cfg.paymentVerifyImageLimit).toBeLessThanOrEqual(
      cfg.paymentVerifyLimit,
    );
  });
});
