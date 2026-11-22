import { PaymentProvider } from '@prisma/client';
import { PaymentQrService } from './payment-qr.service';

describe('PaymentQrService', () => {
  let service: PaymentQrService;

  beforeEach(() => {
    service = new PaymentQrService();
  });

  it.each(Object.values(PaymentProvider))(
    'does not fabricate a bank payment QR for %s',
    (provider) => {
      const result = service.generate({
        provider,
        accountNumber: '1000516323381',
        accountHolderName: 'Test Business',
        suffix: '16323381',
      });

      expect(result.supported).toBe(false);
      expect(result.payload).toBeNull();
      expect(result.format).toBe('UNSUPPORTED');
      expect(result.reasonCode).toBe('REQUIRES_ACQUIRER_ONBOARDING');
      expect(result.reason).toEqual(expect.stringContaining(provider));
      expect(result.reason).toEqual(
        expect.stringContaining('must not fabricate'),
      );
      expect(result.evidence.length).toBeGreaterThan(0);
      // No verified bank payment payload is produced (qrUrl/payload must stay null).
      expect(result.payload).toBeNull();
      expect(JSON.stringify(result.payload)).not.toContain('/qr/v1/');
    },
  );
});
