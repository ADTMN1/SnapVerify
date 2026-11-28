import { BadRequestException, HttpException } from '@nestjs/common';
import { CheckoutStatus, PaymentProvider } from '@prisma/client';
import { validate } from 'class-validator';
import { SubscriptionService } from './subscription.service';
import { CreateSubscriptionCheckoutDto } from './dto/create-subscription-checkout.dto';
import { NormalizedVerification } from '../payment/check-et/check-et.service';

const checkout = {
  id: 'checkout-1',
  organizationId: 'org-1',
  userId: 'user-1',
  planName: 'one_month',
  amount: 1500,
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

const plan = {
  id: 'one_month',
  name: '1 Month',
  price: 1500,
  currency: 'ETB',
  durationDays: 30,
  verificationLimit: null,
  maxUsers: null,
  maxDevices: null,
  isActive: true,
  sortOrder: 1,
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
      amount: 1500,
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
    amount: 1500,
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

function build(attempts = 0, planOverride = plan) {
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
      create: jest.fn(),
      findFirst: jest
        .fn()
        .mockResolvedValueOnce(checkout)
        .mockResolvedValue(null),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    platformPaymentAccount: {
      findFirst: jest.fn().mockResolvedValue(account),
    },
    subscriptionPlan: {
      findUnique: jest.fn().mockResolvedValue(planOverride),
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
  jest.spyOn(service, 'getCurrent').mockResolvedValue({
    id: 'subscription-1',
    organizationId: 'org-1',
    planName: 'one_month',
    status: 'ACTIVE',
    startDate: new Date(),
    endDate: null,
    maxUsers: null,
    maxDevices: null,
    verificationLimit: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    verificationUsed: 0,
    verificationRemaining: null,
    usagePeriodStart: new Date().toISOString(),
    usagePeriodEnd: null,
  });

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

describe('CreateSubscriptionCheckoutDto dynamic plan ids', () => {
  it('accepts all legacy plan ids', async () => {
    for (const id of ['one_month', 'three_months', 'six_months', 'one_year']) {
      const dto = Object.assign(new CreateSubscriptionCheckoutDto(), { planId: id });
      expect(await validate(dto)).toEqual([]);
    }
  });

  it('accepts database-created plan ids', async () => {
    const dto = Object.assign(new CreateSubscriptionCheckoutDto(), {
      planId: 'promo_2026_plan',
    });
    expect(await validate(dto)).toEqual([]);
  });
});

describe('SubscriptionService dynamic plan checkout', () => {
  const existingPlans = [
    { id: 'one_month', price: 1500, currency: 'ETB' },
    { id: 'three_months', price: 3000, currency: 'ETB' },
    { id: 'six_months', price: 5000, currency: 'ETB' },
    { id: 'one_year', price: 10000, currency: 'ETB' },
  ];

  const dynamicPlan = {
    id: 'promo_2026_plan',
    name: 'Promo 2026',
    price: 777,
    currency: 'ETB',
    durationDays: 45,
    verificationLimit: 12,
    maxUsers: 3,
    maxDevices: 2,
    isActive: true,
  };

  function buildCheckoutService(planOverride = plan) {
    const prisma = {
      subscriptionPlan: {
        findUnique: jest.fn().mockResolvedValue(planOverride),
      },
      subscriptionCheckout: {
        create: jest.fn().mockResolvedValue({
          ...checkout,
          id: 'checkout-dynamic',
          planName: planOverride.id,
          amount: planOverride.price,
          currency: planOverride.currency,
        }),
      },
      platformPaymentAccount: {
        findFirst: jest.fn().mockResolvedValue(account),
      },
    };

    const service = new SubscriptionService(prisma as never, {} as never);
    return { service, prisma };
  }

  it.each(existingPlans)(
    'uses database terms for legacy plan $id',
    async (planFixture) => {
      const { service, prisma } = buildCheckoutService({
        ...plan,
        ...planFixture,
      });

      await service.createCheckout('user-1', 'org-1', planFixture.id);

      expect(prisma.subscriptionPlan.findUnique).toHaveBeenCalledWith({
        where: { id: planFixture.id },
      });
      expect(prisma.subscriptionCheckout.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          planName: planFixture.id,
          amount: planFixture.price,
          currency: planFixture.currency,
          provider: PaymentProvider.TELEBIRR,
        }),
      });
    },
  );

  it('checks out a database-created plan by its actual id', async () => {
    const { service, prisma } = buildCheckoutService(dynamicPlan);

    await service.createCheckout('user-1', 'org-1', dynamicPlan.id);

    expect(prisma.subscriptionPlan.findUnique).toHaveBeenCalledWith({
      where: { id: dynamicPlan.id },
    });
    expect(prisma.subscriptionCheckout.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        planName: dynamicPlan.id,
        amount: dynamicPlan.price,
        currency: dynamicPlan.currency,
        provider: PaymentProvider.TELEBIRR,
      }),
    });
  });

  it('rejects a nonexistent plan with a clear error', async () => {
    const { service, prisma } = buildCheckoutService();
    prisma.subscriptionPlan.findUnique.mockResolvedValue(null);

    await expect(
      service.createCheckout('user-1', 'org-1', 'missing_plan'),
    ).rejects.toThrow(/does not exist/);
    expect(prisma.subscriptionCheckout.create).not.toHaveBeenCalled();
  });

  it('rejects an inactive plan with a clear error', async () => {
    const { service, prisma } = buildCheckoutService({
      ...dynamicPlan,
      isActive: false,
    });

    await expect(
      service.createCheckout('user-1', 'org-1', dynamicPlan.id),
    ).rejects.toThrow(/is inactive/);
    expect(prisma.subscriptionCheckout.create).not.toHaveBeenCalled();
  });

  it('uses database duration and limits when the payment is verified', async () => {
    const { service, tx } = build(0, dynamicPlan);

    await service.verifyCheckout(
      'user-1',
      'org-1',
      checkout.id,
      checkout.reference,
    );

    expect(tx.subscription.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        planName: dynamicPlan.id,
        startDate: expect.any(Date),
        endDate: expect.any(Date),
        verificationLimit: dynamicPlan.verificationLimit,
        maxUsers: dynamicPlan.maxUsers,
        maxDevices: dynamicPlan.maxDevices,
      }),
    });
  });
});

describe('SubscriptionService duration-based expiration', () => {
  const activation = new Date('2026-01-31T10:00:00.000Z');
  const basePlan = {
    id: 'duration_plan',
    name: 'Duration Plan',
    price: 1500,
    currency: 'ETB',
    durationDays: null as number | null,
    durationMonths: null as number | null,
    isLifetime: false,
    verificationLimit: null,
    maxUsers: null,
    maxDevices: null,
    isActive: true,
  };

  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(activation);
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('expires a five-month subscription five calendar months after activation', async () => {
    const fiveMonthPlan = {
      ...basePlan,
      id: 'five_months',
      durationMonths: 5,
    };
    const { service, tx } = build(0, fiveMonthPlan);

    await service.verifyCheckout(
      'user-1',
      'org-1',
      checkout.id,
      checkout.reference,
    );

    expect(tx.subscription.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        planName: 'five_months',
        startDate: activation,
        endDate: new Date('2026-06-30T10:00:00.000Z'),
      }),
    });
  });

  it.each([
    ['1 Month', 30],
    ['3 Months', 90],
    ['6 Months', 180],
    ['1 Year', 360],
  ])('expires the %s legacy plan from its database durationDays', async (_label, days) => {
    const legacyPlan = {
      ...basePlan,
      id: 'legacy_duration_plan',
      durationDays: days,
    };
    const { service, tx } = build(0, legacyPlan);

    await service.verifyCheckout(
      'user-1',
      'org-1',
      checkout.id,
      checkout.reference,
    );

    expect(tx.subscription.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        planName: 'legacy_duration_plan',
        startDate: activation,
        endDate: new Date(activation.getTime() + days * 86_400_000),
      }),
    });
  });

  it('keeps an explicitly configured lifetime subscription without expiry', async () => {
    const lifetimePlan = {
      ...basePlan,
      id: 'lifetime_plan',
      isLifetime: true,
    };
    const { service, tx } = build(0, lifetimePlan);

    await service.verifyCheckout(
      'user-1',
      'org-1',
      checkout.id,
      checkout.reference,
    );

    expect(tx.subscription.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        planName: 'lifetime_plan',
        startDate: activation,
        endDate: null,
      }),
    });
  });
});
