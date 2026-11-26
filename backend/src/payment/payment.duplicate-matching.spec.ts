import { Test, TestingModule } from '@nestjs/testing';
import { HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentService } from './payment.service';
import { CheckEtService } from './check-et/check-et.service';
import { CheckEtError } from './check-et/check-et-error';
import { ProviderErrorType } from './provider-error';
import { NormalizedVerification } from './check-et/check-et.service';
import * as crypto from 'crypto';

const HMAC_SECRET = 'a'.repeat(48);
const hmacHash = (s: string) =>
  `hmac-v1:${crypto.createHmac('sha256', HMAC_SECRET).update(s).digest('hex')}`;

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
    findUnique: jest.fn().mockResolvedValue(null),
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

const baseConfig = (overrides: Record<string, unknown> = {}) => ({
  get: jest.fn((key: string, defaultValue?: unknown) => {
    const config: Record<string, unknown> = {
      SKIP_PRIMARY_VERIFICATION: false,
      NODE_ENV: 'development',
      ACCOUNT_HASH_SECRET: HMAC_SECRET,
      ...overrides,
    };
    return key in config ? config[key] : defaultValue;
  }),
});

async function build(overrides: Record<string, unknown> = {}) {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      PaymentService,
      { provide: PrismaService, useValue: mockPrisma },
      { provide: ConfigService, useValue: baseConfig(overrides) },
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
  suffix: '3381',
  accountHolderName: 'Test Business',
  isActive: true,
  createdAt: new Date(),
  updatedAt: new Date(),
  branchId: null,
  ...overrides,
});

const verifiedWinner = (overrides: Record<string, unknown> = {}) => ({
  id: 'winner-1',
  status: PaymentStatus.VERIFIED,
  verificationProvider: 'check_et',
  rawData: { provider: PaymentProvider.CBE },
  amount: 100,
  transactionId: 'FT123',
  senderName: 'Payer',
  receiverName: 'Test Business',
  riskScore: 0,
  createdAt: new Date('2026-01-01T10:00:00+03:00'),
  updatedAt: new Date('2026-01-01T10:05:00+03:00'),
  ...overrides,
});

const validUpstreamRaw = (overrides: Record<string, unknown> = {}) => ({
  success: true,
  amount: '100',
  currency: 'ETB',
  receiver: 'Test Business',
  suffix: '3381',
  ...overrides,
});

/**
 * A Check.et-shaped verification answer for the registered test account
 * (receiverAccount = full receiving number of `account()`).
 */
const validNormalized = (overrides: Record<string, unknown> = {}) =>
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

describe('Stage 1 — database duplicate protection (unit)', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: args.data.riskScore,
    }));
  });

  it('persists a deterministic normalizedTransactionId on create', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    jest
      .spyOn(service as any, '_saveAndReturn')
      .mockResolvedValue({ verified: false });

    await service.verifyByReference(
      '  ft 1234-5678 ',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    // normalized reference stored alongside the original (raw reference is
    // preserved verbatim; no destructive rewriting of client data)
    const dupCheck = mockPrisma.payment.findFirst.mock.calls[0][0];
    expect(dupCheck.where.status).toBe(PaymentStatus.VERIFIED);
    expect(dupCheck.where.OR).toEqual(
      expect.arrayContaining([
        { normalizedTransactionId: 'ft 1234-5678' },
        { transactionId: '  ft 1234-5678 ' },
      ]),
    );
  });

  it('maps a P2002 duplicate winner stored with check_et vendor to PREVIOUSLY_VERIFIED', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null) // pre-check: no duplicate
      .mockResolvedValueOnce(verifiedWinner());
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );
    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(result).toHaveProperty('paymentId', 'winner-1');
  });

  it('scopes the concurrent-winner lookup to the requesting organization (isolation)', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(verifiedWinner());
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    await service.verifyByReference(
      'FT123',
      'org-2',
      'user-1',
      undefined,
      'CBE',
    );

    const winnerLookup = mockPrisma.payment.findFirst.mock.calls[1][0];
    expect(winnerLookup.where.organizationId).toBe('org-2');
  });

  it('fails closed (503-style HttpException) when the constraint fires but the winner is not visible', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toBeInstanceOf(HttpException);
  });

  it('does not swallow non-P2002 database errors as duplicates', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({ code: 'P2025' });

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toThrow(/Database error/);
  });

  it('does NOT treat an unrelated P2002 (different constraint) as a duplicate payment', async () => {
    // Review finding: any future unique violation (e.g. a global id or other
    // unique index) must follow the normal error path, never masquerade as
    // previously-verified recheck outcome.
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['id'] },
    });

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toThrow(/Database error/);
    // No duplicate outcome was returned and no winner lookup ran.
    expect(mockPrisma.payment.findFirst).toHaveBeenCalledTimes(1);
  });

  it('does NOT treat a P2002 on the normalized index name variant as unrelated (index-name form)', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(verifiedWinner());
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: {
        target: 'payments_organizationId_normalizedTransactionId_key',
      },
    });

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
  });

  it('treats a P2002 winner with NULL verificationProvider as previously verified', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(
        verifiedWinner({
          verificationProvider: null,
          senderName: null,
          receiverName: null,
        }),
      );
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockRejectedValue({
      code: 'P2002',
      meta: { target: ['organizationId', 'normalizedTransactionId'] },
    });

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(result).toHaveProperty('paymentId', 'winner-1');
    expect(mockPrisma.payment.create).toHaveBeenCalledTimes(1);
    expect(mockPrisma.payment.findFirst).toHaveBeenCalledTimes(2);
  });
});

describe('Stage 1 — receiving-account matching', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: 0,
    }));
  });

  const setup = async (accounts: any[]) => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue(accounts);
  };

  const matched = (svc: PaymentService, raw: any, acct: any) =>
    (svc as any)._isPaymentToAccount(raw, acct) as boolean;

  it('approves on exact suffix equality', () => {
    expect(matched(service, validUpstreamRaw(), account())).toBe(true);
  });

  it('hard-rejects on suffix mismatch even when the receiver name matches', () => {
    expect(
      matched(service, validUpstreamRaw({ suffix: '9999' }), account()),
    ).toBe(false);
  });

  it('hard-rejects when the upstream provider disagrees with the registered account', () => {
    expect(
      matched(
        service,
        validUpstreamRaw({ provider: PaymentProvider.TELEBIRR }),
        account(),
      ),
    ).toBe(false);
  });

  it('matches full receiving-account numbers via the stored hash', () => {
    const normalized = '1000516323381';
    const acct = account({
      accountNumberHash: hmacHash(normalized),
      accountNumber: null,
      suffix: null,
    });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, accountNumber: normalized }),
        acct,
      ),
    ).toBe(true);
  });

  it('rejects when full receiving-account numbers differ (hash compare)', () => {
    const acct = account({
      accountNumberHash: hmacHash('1000516323381'),
      accountNumber: null,
      suffix: null,
    });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, accountNumber: '1000516329999' }),
        acct,
      ),
    ).toBe(false);
  });

  it('treats a legacy plain SHA-256 hash as unusable and falls back to plaintext compare', () => {
    const legacyHash = crypto
      .createHash('sha256')
      .update('1000516323381')
      .digest('hex');
    const acct = account({
      accountNumberHash: legacyHash,
      accountNumber: '1000516323381',
      suffix: null,
    });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, accountNumber: '1000516323381' }),
        acct,
      ),
    ).toBe(true);
    // And a genuinely different number is still rejected.
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, accountNumber: '1000516329999' }),
        acct,
      ),
    ).toBe(false);
  });

  it('still supports the legacy plaintext full-number comparison until backfill runs', () => {
    const acct = account({ accountNumberHash: null, suffix: null });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, accountNumber: '1000 5163-23381' }),
        acct,
      ),
    ).toBe(true);
  });

  it('accepts a masked upstream number whose tail equals the registered suffix', () => {
    const acct = account({ accountNumber: '1000516323381' });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '****3381',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(true);
  });

  it('rejects a masked upstream number with a non-matching tail', () => {
    const acct = account({ accountNumber: '1000516323381' });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '****9999',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(false);
  });

  it('rejects approval when only two masked tail digits match an unrelated account', () => {
    // Registered suffix '3381'; provider returns masked tail '81' (two ending
    // digits). Two digits are partial evidence an unrelated account could
    // share, so it must not approve.
    const acct = account({ suffix: '3381', accountNumber: null });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '****81',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(false);
  });

  it('still approves when the masked tail equals the full registered suffix', () => {
    const acct = account({ accountNumber: '1000516323381' });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '****3381',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(true);
  });

  it('approves a wallet via a four-digit non-exact partial masked tail', () => {
    const acct = account({ suffix: null, accountNumber: '0986006897' });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '25****6897',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(true);
  });

  it('rejects a wallet when only two masked tail digits match', () => {
    const acct = account({ suffix: null, accountNumber: '0986006897' });
    expect(
      matched(
        service,
        validUpstreamRaw({
          suffix: null,
          accountNumber: '25****97',
          receiver: 'Someone Else',
        }),
        acct,
      ),
    ).toBe(false);
  });

  it('accepts EXACT receiver-name equality when no number evidence exists', () => {
    const acct = account({ suffix: null, accountNumber: null });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, receiver: 'Test Business' }),
        acct,
      ),
    ).toBe(true);
  });

  it('REJECTS receiver-name substring matches (removed vector)', () => {
    const acct = account({ suffix: null, accountNumber: null });
    expect(
      matched(
        service,
        validUpstreamRaw({ suffix: null, receiver: 'Test Business PLC' }),
        acct,
      ),
    ).toBe(false);
  });

  it('rejects an unsuccessful upstream result regardless of evidence', () => {
    expect(matched(service, { success: false }, account())).toBe(false);
  });

  it('never sends a client-supplied suffix upstream; registered data only', async () => {
    await setup([account()]);
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    // Client claims suffix "9999" (not registered) — must be ignored.
    await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
      '9999',
    );

    // The provider receives (bank, reference, registered accountNumber)
    // only — no suffix, no client-derived account data.
    for (const call of mockCheckEt.verifyReference.mock.calls) {
      expect(JSON.stringify(call)).not.toContain('9999');
    }
  });
});

describe('Stage 1 — response data minimization', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
  });

  it('masks full receiving-account numbers in the client response', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: 0,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ receiverAccount: '1000516323381' }),
    );

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(JSON.stringify(result.raw)).not.toContain('1000516323381');
  });

  it('never writes the full receiving-account number into the verification log', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: 0,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    const logArgs = mockPrisma.verificationLog.create.mock.calls[0][0];
    expect(logArgs.data.matchedAccountNumber).not.toBe('1000516323381');
    expect(String(logArgs.data.matchedAccountNumber)).toContain('****');
  });
});

describe('Stage 1 — provider failures never persist as rejected payments', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.findFirst.mockResolvedValue(null);
  });

  it.each([
    [
      'network failure',
      new CheckEtError(
        ProviderErrorType.NETWORK_ERROR,
        null,
        'connect ECONNREFUSED',
      ),
    ],
    [
      'rate limiting (429)',
      new CheckEtError(
        ProviderErrorType.RATE_LIMITED,
        429,
        'Too many requests',
      ),
    ],
  ])(
    'returns PROVIDER_UNAVAILABLE on %s (fail-closed)',
    async (_label, err) => {
      mockCheckEt.verifyReference.mockRejectedValue(err);
      // Retryable provider failures must prevent persistence.
      await expect(
        service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
      ).rejects.toMatchObject({ response: { status: 'PROVIDER_UNAVAILABLE' } });
      expect(mockPrisma.payment.create).not.toHaveBeenCalled();
    },
  );

  it('persists a FAILED payment for an authoritative TRANSACTION_NOT_FOUND answer', async () => {
    // 404 VerifyResponse envelopes are business-level negative answers and
    // flow to _saveAndReturn as failed verifications.
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: args.data.riskScore,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        success: false,
        message: 'Transaction not found.',
        amount: null,
        currency: null,
        receiverAccount: null,
      }),
    );

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(mockPrisma.payment.create).toHaveBeenCalled();
  });
});

describe('Stage 1 — duplicate transaction identity reconciliation', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      amount: args.data.amount,
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: args.data.riskScore,
    }));
  });

  it('treats the same provider transaction verified under a different submitted reference format as a duplicate', async () => {
    const existing = verifiedWinner({ transactionId: 'FT123' });
    mockPrisma.payment.findFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(existing);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ transactionNumber: 'FT123' }),
    );

    const result = await service.verifyByReference(
      'ft-123',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(result).toHaveProperty('paymentId', existing.id);
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('stores the provider-confirmed transaction reference as the identity', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ transactionNumber: 'CANONICAL-123' }),
    );

    const result = await service.verifyByReference(
      'SUBMITTED-456',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(true);
    const stored = mockPrisma.payment.create.mock.calls[0][0];
    expect(stored.data.transactionId).toBe('CANONICAL-123');
    expect(stored.data.normalizedTransactionId).toBe('CANONICAL-123');
  });

  it('still recognizes a previously verified payment for the same provider when the provider is supplied', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(
      verifiedWinner({ transactionId: 'FT123' }),
    );

    const result = await service.verifyByReference(
      'FT123',
      'org-1',
      'user-1',
      100,
      'CBE',
    );

    expect(result.verified).toBe(true);
    expect(result.status).toBe('PREVIOUSLY_VERIFIED');
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('does not recognize a reference as previously verified when the provider is omitted and the stored payment is from another provider', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(
      verifiedWinner({ transactionId: 'FT123' }),
    );
    mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', 100, undefined),
    ).rejects.toMatchObject({
      response: { status: 'PAYMENT_PROVIDER_UNDETECTED' },
    });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('stores the submitted reference when the provider confirms success but returns no transaction reference', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ transactionNumber: null, verificationId: null }),
    );

    const result = await service.verifyByReference(
      'SUBMITTED-1',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(true);
    const stored = mockPrisma.payment.create.mock.calls[0][0];
    expect(stored.data.transactionId).toBe('SUBMITTED-1');
    expect(stored.data.normalizedTransactionId).toBe('SUBMITTED-1');
  });

  it('rejects a payment when the provider returns an empty transaction reference', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      id: 'p1',
      transactionId: args.data.transactionId,
      senderName: null,
      receiverName: null,
      riskScore: args.data.riskScore,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ transactionNumber: '', verificationId: null }),
    );

    const result = await service.verifyByReference(
      'SUBMITTED-2',
      'org-1',
      'user-1',
      undefined,
      'CBE',
    );

    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    const stored = mockPrisma.payment.create.mock.calls[0][0];
    expect(stored.data.normalizedTransactionId).toBeNull();
  });
});
