import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentService } from './payment.service';
import {
  CheckEtService,
  NormalizedVerification,
} from './check-et/check-et.service';
import { CheckEtError } from './check-et/check-et-error';
import { ProviderErrorType } from './provider-error';

const HMAC_SECRET = 'a'.repeat(48);

const mockPrisma = {
  payment: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  paymentAccount: {
    findMany: jest.fn(),
  },
  verificationLog: {
    create: jest.fn(),
  },
  subscription: {
    findFirst: jest.fn(),
  },
  subscriptionUsage: {
    upsert: jest.fn(),
    updateMany: jest.fn(),
    findUnique: jest.fn(),
  },
  $transaction: jest.fn(),
};

const txClient = {
  subscription: mockPrisma.subscription,
  subscriptionUsage: mockPrisma.subscriptionUsage,
  payment: mockPrisma.payment,
};

const mockCheckEt = {
  verifyReference: jest.fn(),
  verifyReceiptFile: jest.fn(),
};

let usageCount = 0;
let committedIncrements = 0;
let verificationLimit: number | null = 10;
let transactionQueue: Promise<void> = Promise.resolve();

async function build(): Promise<PaymentService> {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      PaymentService,
      { provide: PrismaService, useValue: mockPrisma },
      {
        provide: ConfigService,
        useValue: {
          get: jest.fn((key: string, defaultValue?: unknown) => {
            const config: Record<string, unknown> = {
              NODE_ENV: 'development',
              ACCOUNT_HASH_SECRET: HMAC_SECRET,
            };
            return key in config ? config[key] : defaultValue;
          }),
        },
      },
      { provide: CheckEtService, useValue: mockCheckEt },
    ],
  }).compile();
  return module.get<PaymentService>(PaymentService);
}

const account = () => ({
  id: 'account-1',
  organizationId: 'org-1',
  provider: PaymentProvider.CBE,
  accountNumber: '1000516323381',
  accountNumberHash: null,
  suffix: '3381',
  accountHolderName: 'Test Business',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  branchId: null,
});

const winner = (overrides: Record<string, unknown> = {}) => ({
  id: 'winner-1',
  status: PaymentStatus.VERIFIED,
  verificationProvider: 'check_et',
  rawData: { provider: PaymentProvider.CBE },
  amount: 100,
  transactionId: 'FT123',
  paymentDate: new Date('2026-01-01T10:00:00+03:00'),
  createdAt: new Date('2026-01-01T10:00:00+03:00'),
  updatedAt: new Date('2026-01-01T10:05:00+03:00'),
  senderName: 'Payer',
  receiverName: 'Test Business',
  riskScore: 0,
  ...overrides,
});

const validNormalized = (
  overrides: Partial<NormalizedVerification> = {},
): NormalizedVerification =>
  ({
    success: true,
    duplicate: false,
    message: null,
    provider: PaymentProvider.CBE,
    checkEtBank: 'cbe',
    transactionNumber: 'FT123',
    verificationId: 'FT123',
    amount: '100',
    currency: 'ETB',
    transactionDate: '2026-01-01T10:00:00+03:00',
    payer: 'Payer',
    payerAccount: '1000123456789',
    receiver: 'Test Business',
    receiverAccount: '1000516323381',
    verificationMethod: 'official',
    raw: { success: true, exists: true, duplicate: false, message: null },
    ...overrides,
  }) as NormalizedVerification;

describe('PaymentService quota atomicity', () => {
  let service: PaymentService;

  beforeEach(async () => {
    usageCount = 0;
    committedIncrements = 0;
    verificationLimit = 10;
    transactionQueue = Promise.resolve();
    jest.clearAllMocks();

    mockPrisma.subscription.findFirst.mockImplementation(async () => ({
      id: 'sub-1',
      verificationLimit,
      startDate: new Date('2026-01-01T00:00:00.000Z'),
    }));
    mockPrisma.subscriptionUsage.upsert.mockImplementation(async () => ({
      id: 'usage-1',
      count: usageCount,
    }));
    mockPrisma.subscriptionUsage.updateMany.mockImplementation(async () => {
      if (verificationLimit !== null && usageCount >= verificationLimit) {
        return { count: 0 };
      }
      usageCount += 1;
      return { count: 1 };
    });
    mockPrisma.$transaction.mockImplementation(
      (callback: (client: any) => Promise<unknown>) => {
        const run = transactionQueue.then(async () => {
          const snapshot = usageCount;
          try {
            const result = await callback(txClient);
            committedIncrements += usageCount - snapshot;
            return result;
          } catch (error) {
            usageCount = snapshot;
            throw error;
          }
        });
        transactionQueue = run.then(
          () => undefined,
          () => undefined,
        );
        return run;
      },
    );

    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: `payment-${args.data.transactionId}`,
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: args.data.senderName,
      receiverName: args.data.receiverName,
      riskScore: args.data.riskScore,
      paymentDate: args.data.paymentDate,
      createdAt: new Date(),
      updatedAt: new Date(),
    }));
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    service = await build();
  });

  const verify = (reference = 'FT123') =>
    service.verifyByReference(reference, 'org-1', 'user-1', undefined, 'CBE');

  it('consumes exactly one quota unit for a successful new verified payment', async () => {
    const result = await verify('FT-SUCCESS');

    expect(result.verified).toBe(true);
    expect(result.status).toBe(PaymentStatus.VERIFIED);
    expect(mockPrisma.$transaction).toHaveBeenCalledTimes(1);
    expect(mockPrisma.subscriptionUsage.updateMany).toHaveBeenCalledTimes(1);
    expect(mockPrisma.payment.create).toHaveBeenCalledTimes(1);
    expect(usageCount).toBe(1);
    expect(committedIncrements).toBe(1);
  });

  it('rolls back the quota increment when payment creation fails', async () => {
    mockPrisma.payment.create.mockRejectedValue(new Error('db unavailable'));

    await expect(verify('FT-FAIL')).rejects.toThrow(
      'Unable to save the payment right now. Please try again.',
    );
    expect(mockPrisma.subscriptionUsage.updateMany).toHaveBeenCalledTimes(1);
    expect(usageCount).toBe(0);
    expect(committedIncrements).toBe(0);
  });

  it('does not consume quota for a P2002 duplicate-recovery request', async () => {
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(winner());
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    const result = await verify('FT123');

    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(result).toHaveProperty('paymentId', 'winner-1');
    expect(mockPrisma.subscriptionUsage.updateMany).toHaveBeenCalledTimes(1);
    expect(usageCount).toBe(0);
    expect(committedIncrements).toBe(0);
    expect(mockPrisma.payment.create).toHaveBeenCalledTimes(1);
  });

  it('does not consume quota when a P2002 winner cannot be found', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    await expect(verify('FT123')).rejects.toMatchObject({
      response: expect.objectContaining({ status: 'RECHECK_FAILED' }),
    });
    expect(mockPrisma.subscriptionUsage.updateMany).toHaveBeenCalledTimes(1);
    expect(usageCount).toBe(0);
    expect(committedIncrements).toBe(0);
  });

  it('enforces the quota limit under concurrent distinct requests', async () => {
    verificationLimit = 2;

    const results = await Promise.allSettled([
      verify('FT-LIMIT-1'),
      verify('FT-LIMIT-2'),
      verify('FT-LIMIT-3'),
    ]);
    const fulfilled = results.filter(
      (result) => result.status === 'fulfilled',
    ) as PromiseFulfilledResult<any>[];
    const rejected = results.filter(
      (result) => result.status === 'rejected',
    ) as PromiseRejectedResult[];

    expect(fulfilled).toHaveLength(2);
    expect(rejected).toHaveLength(1);
    expect(rejected[0].reason).toBeInstanceOf(ForbiddenException);
    expect(usageCount).toBe(2);
    expect(committedIncrements).toBe(2);
    expect(mockPrisma.payment.create).toHaveBeenCalledTimes(2);
  });

  it('does not consume quota for a cached PREVIOUSLY_VERIFIED recheck', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(winner());

    const result = await verify('FT123');

    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.subscriptionUsage.updateMany).not.toHaveBeenCalled();
    expect(usageCount).toBe(0);
  });

  it('does not consume quota for a cached IDENTITY_MISMATCH recheck', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(winner());

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      250,
      'CBE',
    );

    expect(result.status).toBe('IDENTITY_MISMATCH');
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.subscriptionUsage.updateMany).not.toHaveBeenCalled();
    expect(usageCount).toBe(0);
  });

  it('does not consume quota when the provider times out', async () => {
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(
        ProviderErrorType.NETWORK_ERROR,
        null,
        'Network error: timeout',
      ),
    );

    await expect(verify('FT123')).rejects.toMatchObject({
      response: { status: 'PROVIDER_UNAVAILABLE' },
    });
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.subscriptionUsage.updateMany).not.toHaveBeenCalled();
    expect(usageCount).toBe(0);
  });

  it('does not consume quota when the provider reports an upstream failure', async () => {
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(
        ProviderErrorType.SERVER_ERROR,
        503,
        'Upstream unavailable',
      ),
    );

    await expect(verify('FT123')).rejects.toMatchObject({
      response: { status: 'PROVIDER_UNAVAILABLE' },
    });
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.subscriptionUsage.updateMany).not.toHaveBeenCalled();
    expect(usageCount).toBe(0);
  });

  it('does not consume quota for a failed verification persisted as FAILED', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ success: false, transactionNumber: 'FT-FAILED' }),
    );

    const result = await verify('FT-FAILED');

    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    expect(mockPrisma.subscriptionUsage.updateMany).not.toHaveBeenCalled();
    expect(usageCount).toBe(0);
    expect(mockPrisma.payment.create).toHaveBeenCalledTimes(1);
  });
});
