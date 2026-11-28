import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentService } from './payment.service';
import { CheckEtService } from './check-et/check-et.service';
import { NormalizedVerification } from './check-et/check-et.service';

/**
 * Regression coverage for the payment verification workflow improvements:
 *   1. redundant Check.et probes are collapsed,
 *   2. receiving-account selection stays accurate (and branch-scoped),
 *   3. unstable OCR fallback references can never be recorded as approvals,
 *   4. an already verified payment is never persisted a second time,
 *   5. shared recheck logic behaves identically for reference and image paths.
 */

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
    findFirst: jest.fn().mockResolvedValue({
      id: 'sub-1',
      verificationLimit: null,
    }),
  },
  subscriptionUsage: {
    upsert: jest.fn().mockResolvedValue({ id: 'usage-1', count: 0 }),
    updateMany: jest.fn().mockResolvedValue({ count: 1 }),
  },
  $transaction: jest.fn(),
};
mockPrisma.$transaction.mockImplementation(
  (callback: (client: typeof mockPrisma) => unknown) =>
    Promise.resolve(callback(mockPrisma)),
);

const mockCheckEt = {
  verifyReference: jest.fn(),
  verifyReceiptUrl: jest.fn(),
  verifyReceiptText: jest.fn(),
  verifyReceiptFile: jest.fn(),
};

const config = {
  get: jest.fn((key: string, defaultValue?: unknown) => {
    const values: Record<string, unknown> = {
      NODE_ENV: 'development',
      ACCOUNT_HASH_SECRET: 'a'.repeat(48),
    };
    return key in values ? values[key] : defaultValue;
  }),
};

async function build(): Promise<PaymentService> {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      PaymentService,
      { provide: PrismaService, useValue: mockPrisma },
      { provide: ConfigService, useValue: config },
      { provide: CheckEtService, useValue: mockCheckEt },
    ],
  }).compile();
  return module.get<PaymentService>(PaymentService);
}

const account = (overrides: Record<string, unknown> = {}) => ({
  id: 'account-1',
  organizationId: 'org-1',
  provider: PaymentProvider.CBE,
  accountNumber: '1000516323381',
  accountNumberHash: null,
  suffix: '3381',
  accountHolderName: 'Test Business',
  isActive: true,
  branchId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  ...overrides,
});

const verification = (
  overrides: Partial<NormalizedVerification> = {},
): NormalizedVerification => ({
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
  raw: { success: true, exists: true, duplicate: false },
  ...overrides,
});

const existingVerified = (overrides: Record<string, unknown> = {}) => ({
  id: 'winner-1',
  status: PaymentStatus.VERIFIED,
  verificationProvider: 'check_et',
  rawData: { provider: PaymentProvider.CBE },
  amount: 100,
  transactionId: 'FT123',
  senderName: 'Payer',
  receiverName: 'Test Business',
  riskScore: 0,
  paymentDate: new Date('2026-01-01T10:00:00+03:00'),
  createdAt: new Date('2026-01-01T10:00:00+03:00'),
  updatedAt: new Date('2026-01-01T10:05:00+03:00'),
  ...overrides,
});

beforeEach(() => {
  jest.clearAllMocks();
  mockPrisma.payment.findFirst.mockResolvedValue(null);
  mockPrisma.verificationLog.create.mockResolvedValue({});
  mockPrisma.payment.create.mockImplementation(async (args: any) => ({
    id: 'p1',
    amount: args.data.amount,
    transactionId: args.data.transactionId,
    senderName: null,
    receiverName: 'Test Business',
    riskScore: args.data.riskScore,
  }));
});

describe('Check.et probe planning (no redundant upstream requests)', () => {
  it('probes a shared-request provider once regardless of account count', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      account({
        id: 'tb-1',
        provider: PaymentProvider.TELEBIRR,
        accountNumber: '0911223344',
        suffix: null,
        accountHolderName: null,
      }),
      account({
        id: 'tb-2',
        provider: PaymentProvider.TELEBIRR,
        accountNumber: '0911223355',
        suffix: null,
        accountHolderName: null,
      }),
      account({
        id: 'tb-3',
        provider: PaymentProvider.TELEBIRR,
        accountNumber: '0911223366',
        suffix: null,
        accountHolderName: null,
      }),
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      verification({
        success: false,
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        message: 'Transaction not found.',
      }),
    );

    await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'TELEBIRR',
    );

    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(1);
  });

  it('probes each genuinely distinct CBE account number once', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      account({ id: 'cbe-1', accountNumber: '1000516323381' }),
      account({ id: 'cbe-2', accountNumber: '1000999999999', suffix: '9999' }),
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      verification({ success: false, message: 'Transaction not found.' }),
    );

    await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(2);
  });

  it('collapses accounts that map to an identical CBE request', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      account({ id: 'branch-row', branchId: 'branch-a' }),
      account({ id: 'org-row', branchId: null }),
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(verification());

    await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(1);
  });
});

describe('payment-account selection accuracy', () => {
  it('does not attribute an account-specific CBE success to a different account by name alone', async () => {
    const service = await build();
    const other = account({
      id: 'cbe-other',
      accountNumber: '1000999999999',
      suffix: '9999',
      accountHolderName: 'Other Business',
    });
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account(), other]);
    mockCheckEt.verifyReference
      .mockResolvedValueOnce(
        verification({ success: false, message: 'Transaction not found.' }),
      )
      .mockResolvedValueOnce(
        verification({
          receiverAccount: '25****17',
          receiver: 'Test Business',
        }),
      );

    const result = await service.verifyByReference(
      'DJV9JIVHMR',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(false);
    expect(result.message).toMatch(/different account/i);
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.FAILED }),
      }),
    );
  });

  it('prefers the branch-scoped account and never probes another branch', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      account({
        id: 'org-wide',
        branchId: null,
        accountNumber: '1000000000001',
      }),
      account({
        id: 'branch-a',
        branchId: 'branch-a',
        accountNumber: '1000000000002',
        suffix: '0002',
      }),
      account({
        id: 'branch-b',
        branchId: 'branch-b',
        accountNumber: '1000000000003',
        suffix: '0003',
      }),
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      verification({ receiverAccount: '1000000000002' }),
    );

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
      undefined,
      'branch-a',
    );

    expect(result.verified).toBe(true);
    // branch-a probe runs first and matches its own account.
    expect(mockCheckEt.verifyReference.mock.calls[0][2]).toBe('1000000000002');
    // branch-b is outside the caller's scope and is never sent upstream.
    for (const call of mockCheckEt.verifyReference.mock.calls) {
      expect(call[2]).not.toBe('1000000000003');
    }
    const log = mockPrisma.verificationLog.create.mock.calls[0][0];
    expect(log.data.matchedPaymentAccountId).toBe('branch-a');
    expect(log.data.matchedBranchId).toBe('branch-a');
  });
});

describe('OCR receipt references', () => {
  it('fails closed instead of recording an approval under a timestamp label', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      verification({
        transactionNumber: null,
        verificationId: null,
      }),
    );

    const result = await service.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE receipt',
    );

    expect(result.verified).toBe(false);
    const create = mockPrisma.payment.create.mock.calls[0][0];
    expect(create.data.status).toBe(PaymentStatus.FAILED);
    expect(create.data.normalizedTransactionId).toBeNull();
    expect(create.data.transactionId).toMatch(/^OCR-\d+$/);
  });

  it('does not persist a second payment for a receipt with a known provider reference', async () => {
    const service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.findFirst.mockResolvedValue(existingVerified());
    mockCheckEt.verifyReceiptFile.mockResolvedValue(verification());

    const result = await service.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE receipt',
    );

    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(result.paymentId).toBe('winner-1');
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('rejects a direct approval attempt that carries only a synthetic reference', async () => {
    const service = await build();
    const result = await (service as any)._saveAndReturn(
      {
        success: true,
        amount: '100',
        currency: 'ETB',
        transactionDate: '2026-01-01T10:00:00+03:00',
      },
      'org-1',
      'user-1',
      { method: 'IMAGE_OCR', transactionId: 'OCR-1730000000000' },
      null,
    );

    expect(result.verified).toBe(false);
    const create = mockPrisma.payment.create.mock.calls[0][0];
    expect(create.data.status).toBe(PaymentStatus.FAILED);
    expect(create.data.normalizedTransactionId).toBeNull();
  });
});
