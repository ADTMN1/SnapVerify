import { BadRequestException, HttpException } from '@nestjs/common';
import { CheckoutStatus, PaymentProvider } from '@prisma/client';
import { SubscriptionService } from './subscription.service';
import { NormalizedVerification } from '../payment/check-et/check-et.service';

const checkout = {
  id: 'checkout-1',
  organizationId: 'org-1',
  userId: 'user-1',
  planName: 'one_month',
  amount: 580,
  currency: 'ETB',
  provider: PaymentProvider.TELEBIRR,
  reference: 'SV-SUB-TEST-REF',
  vendorReference: null,
  status: CheckoutStatus.PENDING,
  expiresAt: new Date(Date.now() + 30 * 60_000),
  createdAt: new Date(),
  paidAt: null,
};

const account = {
  accountNumber: '0912345678',
  accountName: 'abebaw',
};

const raw = {
  success: true,
  exists: true,
  duplicate: false,
  message: null,
  data: {
    bank: 'telebirr',
    verification_id: 'TB123456',
    transaction_number: 'TB123456',
    receipt: {
      status: 'completed',
      amount: 580,
      currency: 'ETB',
      payer_name: 'Payer',
      receiver_name: 'abebaw',
      receiver_account: '+251912345678',
    },
  },
};

function verification(
  overrides: Partial<NormalizedVerification> = {},
): NormalizedVerification {
  return {
    success: true,
    duplicate: false,
    message: null,
    provider: PaymentProvider.TELEBIRR,
    checkEtBank: 'telebirr',
    transactionNumber: 'TB123456',
    verificationId: 'TB123456',
    amount: 580,
    currency: 'ETB',
    transactionDate: '2026-11-22T10:00:00+03:00',
    payer: 'Payer',
    payerAccount: '1000123456789',
    receiver: 'abebaw',
    receiverAccount: '+251912345678',
    verificationMethod: 'official',
    raw,
    ...overrides,
  } as NormalizedVerification;
}

function build(attempts = 0) {
  const tx = {
    paymentReceiptUsage: { create: jest.fn().mockResolvedValue({}) },
    subscription: {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      create: jest.fn().mockResolvedValue({}),
    },
    organization: { update: jest.fn().mockResolvedValue({}) },
    subscriptionCheckout: { update: jest.fn().mockResolvedValue({}) },
    activityLog: { create: jest.fn().mockResolvedValue({}) },
  };

  const prisma = {
    subscriptionCheckout: {
      findFirst: jest
        .fn()
        .mockResolvedValueOnce(checkout)
        .mockResolvedValue(null),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    platformPaymentAccount: {
      findFirst: jest.fn().mockResolvedValue(account),
    },
    activityLog: {
      count: jest.fn().mockResolvedValue(attempts),
      create: jest.fn().mockResolvedValue({}),
    },
    paymentReceiptUsage: { create: jest.fn().mockResolvedValue({}) },
    subscription: {
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      create: jest.fn().mockResolvedValue({}),
    },
    organization: { update: jest.fn().mockResolvedValue({}) },
    $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
      Promise.resolve(callback(tx)),
    ),
  };

  const checkEt = {
    verifyReference: jest.fn().mockResolvedValue(verification()),
  };

  const service = new SubscriptionService(
    prisma as never,
    checkEt as unknown as never,
  );
  jest.spyOn(service, 'getCurrent').mockResolvedValue({ id: 'subscription-1' });

  return { service, prisma, checkEt, tx };
}

describe('SubscriptionService payment verification hardening', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects a receipt for a different checkout reference', async () => {
    const { service, checkEt } = build();

    await expect(
      service.verifyCheckout('user-1', 'org-1', checkout.id, 'WRONG-REF'),
    ).rejects.toThrow(BadRequestException);
    expect(checkEt.verifyReference).not.toHaveBeenCalled();
  });

  it('rejects a normalized success whose raw response is not strictly successful', async () => {
    const { service, checkEt, prisma } = build();
    checkEt.verifyReference.mockResolvedValue(
      verification({ raw: { ...raw, exists: false } }),
    );

    await expect(
      service.verifyCheckout(
        'user-1',
        'org-1',
        checkout.id,
        checkout.reference,
      ),
    ).rejects.toThrow(/not confirmed as successful/);
    expect(checkEt.verifyReference).toHaveBeenCalled();
    expect(prisma.subscriptionCheckout.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: CheckoutStatus.FAILED },
      }),
    );
  });

  it('rejects a masked receiver account with a mismatched name', async () => {
    const { service, checkEt } = build();
    checkEt.verifyReference.mockResolvedValue(
      verification({
        receiverAccount: '****5678',
        receiver: 'someone-else',
      }),
    );

    await expect(
      service.verifyCheckout(
        'user-1',
        'org-1',
        checkout.id,
        checkout.reference,
      ),
    ).rejects.toThrow(/not sent to the SnapVerify subscription account/);
  });

  it('accepts a full matching receiver account and records global receipt usage', async () => {
    const { service, tx } = build();

    const result = await service.verifyCheckout(
      'user-1',
      'org-1',
      checkout.id,
      checkout.reference,
    );

    expect(result.status).toBe('PAID');
    expect(tx.paymentReceiptUsage.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          normalizedReference: 'TB123456',
          checkoutId: checkout.id,
        }),
      }),
    );
    expect(tx.activityLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: 'SUBSCRIPTION_PAYMENT_VERIFIED',
        }),
      }),
    );
  });

  it('rate limits repeated verification attempts', async () => {
    const { service, checkEt } = build(10);

    await expect(
      service.verifyCheckout(
        'user-1',
        'org-1',
        checkout.id,
        checkout.reference,
      ),
    ).rejects.toThrow(HttpException);
    expect(checkEt.verifyReference).not.toHaveBeenCalled();
  });
});
