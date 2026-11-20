import { Test, TestingModule } from '@nestjs/testing';
import { HttpException, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { computeAccountNumberHash } from './account-hash';
import {
  PaymentService,
  parseVerifiedAmount,
  validateVerifiedCurrency,
} from './payment.service';
import { CheckEtService } from './check-et/check-et.service';
import { CheckEtError } from './check-et/check-et-error';
import { ProviderErrorType } from './provider-error';
import {
  NormalizedVerification,
  CHECK_ET_SUPPORTED_PDF_MIMES,
} from './check-et/check-et.service';

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
};

const mockCheckEt = {
  verifyReference: jest.fn(),
  verifyReceiptUrl: jest.fn(),
  verifyReceiptText: jest.fn(),
  verifyReceiptFile: jest.fn(),
};

const baseConfig = (overrides: Record<string, unknown> = {}) => ({
  get: jest.fn((key: string, defaultValue?: unknown) => {
    const config: Record<string, unknown> = {
      NODE_ENV: 'development',
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

// A fully verified Check.et answer for the registered test account.
const validNormalized = (
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
  raw: { success: true, exists: true, duplicate: false, message: null },
  ...overrides,
});

const registeredAccount = {
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
};

const mockVerifiedPayment = () => ({
  id: 'p1',
  amount: 100,
  transactionId: 'FT123',
  senderName: null,
  receiverName: 'Test Business',
  riskScore: 0,
});

describe('PaymentService security (Check.et provider)', () => {
  let service: PaymentService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
  });

  it('fails closed when the provider is unreachable', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(
        ProviderErrorType.NETWORK_ERROR,
        null,
        'Network error: ECONNREFUSED',
      ),
    );

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toMatchObject({ response: { status: 'PROVIDER_UNAVAILABLE' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('fails closed with a distinct status when the Check.et quota is exhausted', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(
        ProviderErrorType.QUOTA_EXHAUSTED,
        402,
        'Monthly verification limit reached. Please upgrade your plan.',
      ),
    );

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toMatchObject({ response: { status: 'QUOTA_EXHAUSTED' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('fails closed with a distinct status when API credentials are invalid', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(ProviderErrorType.AUTH_ERROR, 401, 'Unauthenticated.'),
    );

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toMatchObject({ response: { status: 'PROVIDER_CONFIG_ERROR' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('rejects duplicate transactions without calling the provider', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue({
      id: 'existing',
      amount: 100,
      transactionId: 'FT123',
      senderName: 'A',
      receiverName: 'B',
      riskScore: 0,
    });

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe('DUPLICATE_TRANSACTION');
    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
  });

  it('treats a provider-reported duplicate as an app-level duplicate (fail closed)', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ duplicate: true }),
    );

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe('DUPLICATE_TRANSACTION');
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('passes bank code and reference — never the client amount — to the provider', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});

    await service.verifyByReference('FT123', 'org-1', 'user-1', 1000, 'CBE');

    expect(mockCheckEt.verifyReference).toHaveBeenCalledWith(
      PaymentProvider.CBE,
      'FT123',
      '1000516323381',
    );
  });
});

describe('verifyByReference validation rejection classification', () => {
  let service: PaymentService;

  const receivingAccountRejected = () =>
    new CheckEtError(
      ProviderErrorType.VALIDATION_ERROR,
      400,
      'This payment was not made to the receiving account you entered.',
    );

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      ...mockVerifiedPayment(),
      amount: args.data.amount,
      status: args.data.status,
      transactionId: args.data.transactionId,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('returns a clear rejection (not PROVIDER_UNAVAILABLE) when one account returns VALIDATION_ERROR', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(receivingAccountRejected());

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');

    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(result.message).toContain('not made to the receiving account');
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.FAILED }),
      }),
    );
  });

  it('returns a clear rejection when multiple accounts all return VALIDATION_ERROR', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      registeredAccount,
      { ...registeredAccount, id: 'account-2', accountNumber: '1000999999999' },
    ]);
    mockCheckEt.verifyReference.mockRejectedValue(receivingAccountRejected());

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');

    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(result.message).toContain('not made to the receiving account');
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.FAILED }),
      }),
    );
  });

  it('approves when one account returns VALIDATION_ERROR and another returns a confirmed matching transaction', async () => {
    const second = { ...registeredAccount, id: 'account-2', accountNumber: '1000999999999' };
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount, second]);
    mockCheckEt.verifyReference
      .mockRejectedValueOnce(receivingAccountRejected())
      .mockResolvedValueOnce(
        validNormalized({ receiverAccount: '1000999999999' }),
      );

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');

    expect(result.verified).toBe(true);
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.VERIFIED }),
      }),
    );
  });

  it('fails closed with PROVIDER_UNAVAILABLE when one account returns VALIDATION_ERROR and another returns an infrastructure error', async () => {
    const second = { ...registeredAccount, id: 'account-2', accountNumber: '1000999999999' };
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount, second]);
    mockCheckEt.verifyReference
      .mockRejectedValueOnce(receivingAccountRejected())
      .mockRejectedValueOnce(
        new CheckEtError(ProviderErrorType.NETWORK_ERROR, null, 'Network error: ETIMEDOUT'),
      );

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toMatchObject({ response: { status: 'PROVIDER_UNAVAILABLE' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('fails closed with PROVIDER_UNAVAILABLE when all accounts return infrastructure errors', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      registeredAccount,
      { ...registeredAccount, id: 'account-2', accountNumber: '1000999999999' },
    ]);
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(ProviderErrorType.SERVER_ERROR, 503, 'Upstream unavailable'),
    );

    await expect(
      service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE'),
    ).rejects.toMatchObject({ response: { status: 'PROVIDER_UNAVAILABLE' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('never produces VERIFIED after a validation rejection', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(receivingAccountRejected());

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');

    expect(result.verified).toBe(false);
    expect(result.status).not.toBe(PaymentStatus.VERIFIED);
    const created = mockPrisma.payment.create.mock.calls[0]?.[0];
    expect(created?.data?.status).toBe(PaymentStatus.FAILED);
  });

  it('keeps existing successful reference verification behavior unchanged', async () => {
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');

    expect(result.verified).toBe(true);
    expect(Number(result.amount)).toBe(100);
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.VERIFIED }),
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// Financial integrity (amount + currency validation)
// ---------------------------------------------------------------------------

describe('parseVerifiedAmount', () => {
  it.each([
    ['missing (undefined)', undefined],
    ['missing (null)', null],
    ['empty string', '   '],
    ['invalid numeric string', 'abc'],
    ['comma-formatted string', '1,000'],
    ['exponent notation', '1e3'],
    ['signed number string', '+100'],
    ['NaN', NaN],
    ['Infinity', Infinity],
    ['zero (number)', 0],
    ['zero (string)', '0'],
    ['negative amount', -50],
    ['negative amount (string)', '-50'],
    ['excessive decimal precision', '100.999'],
    ['excessive decimal precision (number)', 100.999],
  ])('rejects %s', (_label, value) => {
    const result = parseVerifiedAmount(value);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.reason).toBeTruthy();
  });

  it.each([
    ['valid number', 100],
    ['valid decimal number', 999.99],
    ['valid decimal string', '999.99'],
    ['valid integer string', '100'],
  ])('accepts %s', (_label, value) => {
    const result = parseVerifiedAmount(value);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.amount.toNumber()).toBeGreaterThan(0);
      expect(result.amount.decimalPlaces()).toBeLessThanOrEqual(2);
    }
  });
});

describe('validateVerifiedCurrency', () => {
  it('accepts ETB (case-insensitive, trimmed)', () => {
    expect(validateVerifiedCurrency('ETB').ok).toBe(true);
    expect(validateVerifiedCurrency(' etb ').ok).toBe(true);
  });

  it.each([
    ['USD', 'USD'],
    ['invalid currency', 'NOT_A_CURRENCY'],
    ['missing (null)', null],
    ['missing (undefined)', undefined],
    ['empty string', ''],
  ])('rejects %s', (_label, value) => {
    const result = validateVerifiedCurrency(value);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.reason).toContain('ETB');
  });
});

describe('PaymentService financial integrity gate (Check.et)', () => {
  let service: PaymentService;

  async function buildWithAccount(overrides: Record<string, unknown> = {}) {
    const svc = await build(overrides);
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    return svc;
  }

  beforeEach(() => {
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      ...mockVerifiedPayment(),
      amount: args.data.amount,
      status: args.data.status,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('approves a transaction with a valid bank-verified amount and ETB currency', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    const result = await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(true);
    expect(Number(result.amount)).toBe(100);
  });

  it.each([
    ['missing amount', { amount: undefined }],
    ['null amount', { amount: null }],
    ['empty string amount', { amount: '' }],
    ['invalid numeric string', { amount: 'abc' }],
    ['NaN amount', { amount: NaN }],
    ['Infinity amount', { amount: Infinity }],
    ['zero amount', { amount: 0 }],
    ['negative amount', { amount: -100 }],
    ['excessive precision', { amount: '99.999' }],
  ])('rejects approval when the bank reports %s', async (_label, overrides) => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized(overrides as Partial<NormalizedVerification>),
    );

    const result = await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(mockPrisma.payment.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PaymentStatus.FAILED }),
      }),
    );
  });

  it.each([
    ['USD currency', { currency: 'USD' }],
    ['missing currency', { currency: undefined }],
    ['null currency', { currency: null }],
    ['invalid currency', { currency: 'GOLD' }],
  ])('rejects approval when the bank reports %s', async (_label, overrides) => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized(overrides as Partial<NormalizedVerification>),
    );

    const result = await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
  });

  it('rejects approval when the receiving account does not match a registered account', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        receiverAccount: '9999999999999',
        receiver: 'Someone Else',
      }),
    );

    const result = await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(mockPrisma.payment.create).toHaveBeenCalled();
  });

  it('does not approve a success:false provider answer', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        success: false,
        message: 'Transaction not found.',
        amount: null,
        currency: null,
        receiverAccount: null,
      }),
    );

    const result = await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
  });
});

describe('PaymentService image verification (Check.et receipt_file + receipt_text)', () => {
  let service: PaymentService;

  async function buildWithAccount() {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([registeredAccount]);
    return svc;
  }

  beforeEach(() => {
    jest.clearAllMocks();
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      ...mockVerifiedPayment(),
      amount: args.data.amount,
      status: args.data.status,
    }));
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('requires OCR text for image receipts (provider contract)', async () => {
    const svc = await buildWithAccount();
    await expect(
      svc.verifyByImage(
        Buffer.from('fake-image'),
        'image/jpeg',
        'org-1',
        'user-1',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(mockCheckEt.verifyReceiptFile).not.toHaveBeenCalled();
  });

  it('allows PDF receipts without OCR text', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(validNormalized());
    await svc.verifyByImage(
      Buffer.from('fake-pdf'),
      'application/pdf',
      'org-1',
      'user-1',
    );
    expect(mockCheckEt.verifyReceiptFile).toHaveBeenCalledWith(
      expect.objectContaining({
        receiptText: undefined,
        bankHint: 'cbe',
        accountNumber: '1000516323381',
      }),
    );
  });

  it('CBE receipt image passes bankHint cbe and correct receiving account number', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(validNormalized());
    await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123',
    );
    expect(mockCheckEt.verifyReceiptFile).toHaveBeenCalledWith(
      expect.objectContaining({
        bankHint: 'cbe',
        accountNumber: '1000516323381',
      }),
    );
  });

  it('BOA receipt image passes bankHint boa and correct receiving account number', async () => {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      {
        ...registeredAccount,
        id: 'account-boa',
        provider: PaymentProvider.ABYSSINIA,
        accountNumber: '1234567890',
        suffix: '67890',
      },
    ]);
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.ABYSSINIA,
        checkEtBank: 'boa',
        receiverAccount: '1234567890',
      }),
    );

    await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'BOA receipt',
    );
    expect(mockCheckEt.verifyReceiptFile).toHaveBeenCalledWith(
      expect.objectContaining({
        bankHint: 'boa',
        accountNumber: '1234567890',
      }),
    );
  });

  it('other banks preserve existing behavior (no bank hint/account number)', async () => {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      {
        ...registeredAccount,
        id: 'account-tele',
        provider: PaymentProvider.TELEBIRR,
        accountNumber: '0911223344',
      },
    ]);
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '0911223344',
      }),
    );

    await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'Telebirr receipt',
    );
    const call = mockCheckEt.verifyReceiptFile.mock.calls[0][0];
    expect(call.bankHint).toBeUndefined();
    expect(call.accountNumber).toBeUndefined();
  });

  it('fails safely when multiple CBE/BOA receiving accounts make destination ambiguous', async () => {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      registeredAccount,
      {
        ...registeredAccount,
        id: 'account-cbe-2',
        accountNumber: '1000999999999',
        suffix: '9999',
      },
    ]);

    await expect(
      svc.verifyByImage(
        Buffer.from('fake-image'),
        'image/jpeg',
        'org-1',
        'user-1',
        'CBE FT123',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(mockCheckEt.verifyReceiptFile).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('preserves branch isolation when resolving the receiving account', async () => {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      { ...registeredAccount, id: 'branch-a', branchId: 'branch-a', accountNumber: '1000111111111' },
      { ...registeredAccount, id: 'branch-b', branchId: 'branch-b', accountNumber: '1000222222222' },
    ]);
    mockCheckEt.verifyReceiptFile.mockResolvedValue(validNormalized({ receiverAccount: '1000222222222' }));

    await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123',
      'branch-b',
    );
    expect(mockPrisma.paymentAccount.findMany).toHaveBeenCalledWith({
      where: { organizationId: 'org-1', isActive: true },
    });
    expect(mockCheckEt.verifyReceiptFile).toHaveBeenCalledWith(
      expect.objectContaining({
        bankHint: 'cbe',
        accountNumber: '1000222222222',
      }),
    );
  });

  it('preserves organization isolation by loading accounts only for the request organization', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(validNormalized());

    await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123',
    );
    expect(mockPrisma.paymentAccount.findMany).toHaveBeenCalledWith({
      where: { organizationId: 'org-1', isActive: true },
    });
  });

  it('fails safely when required CBE/BOA account number is missing', async () => {
    const svc = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      { ...registeredAccount, accountNumber: null },
    ]);

    await expect(
      svc.verifyByImage(
        Buffer.from('fake-image'),
        'image/jpeg',
        'org-1',
        'user-1',
        'CBE FT123',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(mockCheckEt.verifyReceiptFile).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('provider retryable errors cannot result in VERIFIED payments (fail closed, PROVIDER_UNAVAILABLE)', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockRejectedValue(
      new CheckEtError(ProviderErrorType.NETWORK_ERROR, 503, 'timeout'),
    );

    await expect(
      svc.verifyByImage(
        Buffer.from('fake-image'),
        'image/jpeg',
        'org-1',
        'user-1',
        'CBE FT123',
      ),
    ).rejects.toMatchObject({ response: { status: 'PROVIDER_UNAVAILABLE' } });
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('stores the bank-verified amount; OCR text never triggers approval', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      validNormalized({ transactionNumber: 'FT123' }),
    );

    const result = await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123 Amount: ETB 9999',
    );

    expect(result.verified).toBe(true);
    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
    const stored = mockPrisma.payment.create.mock.calls[0][0];
    expect(Number(stored.data.amount)).toBe(100);
  });

  it('fails the image verification when the bank amount is missing', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      validNormalized({ amount: undefined }),
    );

    const result = await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123',
    );
    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
  });

  it('rejects approval when the verified payment went to a different account', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReceiptFile.mockResolvedValue(
      validNormalized({ receiverAccount: '9999999999999', receiver: 'Someone Else' }),
    );

    const result = await svc.verifyByImage(
      Buffer.from('fake-image'),
      'image/jpeg',
      'org-1',
      'user-1',
      'CBE FT123',
    );
    expect(result.verified).toBe(false);
    expect(result.message).toMatch(/different account/i);
  });

  it('records the check_et provider identity on new payment rows', async () => {
    const svc = await buildWithAccount();
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());

    await svc.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    const args = mockPrisma.payment.create.mock.calls[0][0];
    expect(args.data.verificationProvider).toBe('check_et');
  });

  it('documents the supported receipt MIME types per Check.et contract', () => {
    expect(CHECK_ET_SUPPORTED_PDF_MIMES.has('application/pdf')).toBe(true);
    expect(CHECK_ET_SUPPORTED_PDF_MIMES.has('image/jpeg')).toBe(false);
  });
});

describe('receiver matching with canonicalized Ethiopian phone numbers', () => {
  const HASH_SECRET = 'a'.repeat(48);
  let service: PaymentService;

  const telebirrAccount = {
    ...registeredAccount,
    id: 'account-tb',
    provider: PaymentProvider.TELEBIRR,
    accountNumber: '0986006897',
    suffix: null,
    accountHolderName: null,
    // Stored hash uses the LOCAL 09… format (existing registered data).
    accountNumberHash: computeAccountNumberHash('0986006897', HASH_SECRET),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build({ ACCOUNT_HASH_SECRET: HASH_SECRET });
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('approves a Telebirr payment whose receiver_account is in international 251… format', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '251986006897',
      }),
    );

    const result = await service.verifyByReference('TB251115.1234.A123456', 'org-1', 'user-1', undefined, 'TELEBIRR');

    expect(result.verified).toBe(true);
    expect(result.status).toBe(PaymentStatus.VERIFIED);
  });

  it('approves a Telebirr payment whose receiver_account is in E.164 +251… format', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '+251986006897',
      }),
    );

    const result = await service.verifyByReference('TB251115.1234.A123456', 'org-1', 'user-1', undefined, 'TELEBIRR');
    expect(result.verified).toBe(true);
  });

  it('still rejects a Telebirr payment to a genuinely different account', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '251911111111',
      }),
    );

    const result = await service.verifyByReference('TB251115.1234.A123456', 'org-1', 'user-1', undefined, 'TELEBIRR');
    expect(result.verified).toBe(false);
    expect(result.message).toMatch(/different account/i);
  });

  it('does NOT forward account_number to Check.et for Telebirr (docs contract)', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(validNormalized());
    await service.verifyByReference('TB123', 'org-1', 'user-1', undefined, 'TELEBIRR');
    expect(mockCheckEt.verifyReference).toHaveBeenCalledWith(
      PaymentProvider.TELEBIRR,
      'TB123',
      '0986006897',
    );
  });

  it('approves a Telebirr payment when Check.et returns a MASKED receiver_account matching the registered phone', async () => {
    // Runtime-confirmed behavior: Check.et masks wallet receiver accounts
    // (e.g. "25****97" for 251986006897).
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '25****97',
      }),
    );

    const result = await service.verifyByReference('DJV9JIVHMR', 'org-1', 'user-1', undefined, 'TELEBIRR');
    expect(result.verified).toBe(true);
  });

  it('rejects a Telebirr payment whose masked receiver_account is a different wallet', async () => {
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '25****17',
      }),
    );

    const result = await service.verifyByReference('DJV9JIVHMR', 'org-1', 'user-1', undefined, 'TELEBIRR');
    expect(result.verified).toBe(false);
    expect(result.message).toMatch(/different account/i);
  });
});

describe('verifyByReference failure-message selection across multiple banks', () => {
  const HASH_SECRET = 'a'.repeat(48);
  let service: PaymentService;

  const telebirrAccount = {
    ...registeredAccount,
    id: 'account-tb',
    provider: PaymentProvider.TELEBIRR,
    accountNumber: '0986006897',
    suffix: null,
    accountHolderName: null,
    accountNumberHash: computeAccountNumberHash('0986006897', HASH_SECRET),
  };
  const cbeAccount = { ...registeredAccount };

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build({ ACCOUNT_HASH_SECRET: HASH_SECRET });
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('probes only the detected provider account and surfaces a confirmed different-account verdict', async () => {
    const secondCbe = {
      ...registeredAccount,
      id: 'account-cbe-2',
      accountNumber: '1000999999999',
      suffix: '9999',
      accountHolderName: 'Other Business',
    };
    // Both CBE and Telebirr accounts exist; only the detected CBE accounts
    // may be probed — never the Telebirr account.
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      cbeAccount,
      telebirrAccount,
      secondCbe,
    ]);
    mockCheckEt.verifyReference
      .mockResolvedValueOnce(
        validNormalized({
          success: false,

          provider: PaymentProvider.CBE,
          checkEtBank: 'cbe',
          message: 'Transaction not found.',

        }),
      )
      .mockResolvedValueOnce(
        validNormalized({
          provider: PaymentProvider.CBE,
          checkEtBank: 'cbe',
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
    // No Telebirr probe ever happens.
    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(2);
    for (const call of mockCheckEt.verifyReference.mock.calls) {
      expect(call[0]).toBe(PaymentProvider.CBE);
    }
  });

  it('preserves the transaction-not-found result for the detected provider', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      cbeAccount,
      telebirrAccount,
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        success: false,

        provider: PaymentProvider.CBE,
        checkEtBank: 'cbe',
        message: 'Transaction not found.',

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
    expect(result.message).toMatch(/transaction not found/i);
    expect(result.message).not.toMatch(/No CBE payment/);
    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(1);
    expect(mockCheckEt.verifyReference.mock.calls[0][0]).toBe(
      PaymentProvider.CBE,
    );
  });
});

describe('CBE and BOA verification compatibility after canonicalization', () => {
  const HASH_SECRET = 'a'.repeat(48);

  beforeEach(() => jest.clearAllMocks());

  it('still approves a CBE payment matched via the registered account number', async () => {
    const service = await build({ ACCOUNT_HASH_SECRET: HASH_SECRET });
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      { ...registeredAccount, suffix: null, accountHolderName: null },
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({ receiverAccount: '1000516323381', receiver: null }),
    );
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});

    const result = await service.verifyByReference('FT123', 'org-1', 'user-1', undefined, 'CBE');
    expect(result.verified).toBe(true);
  });

  it('still approves a BOA (Abyssinia) payment matched by account number', async () => {
    const service = await build({ ACCOUNT_HASH_SECRET: HASH_SECRET });
    const boaAccount = {
      ...registeredAccount,
      id: 'account-boa',
      provider: PaymentProvider.ABYSSINIA,
      accountNumber: '1000290172',
      suffix: '0172',
      accountHolderName: null,
      accountNumberHash: computeAccountNumberHash('1000290172', HASH_SECRET),
    };
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.findMany.mockResolvedValue([boaAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.ABYSSINIA,
        checkEtBank: 'boa',
        receiverAccount: '1000290172',
        receiver: null,
      }),
    );
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});

    const result = await service.verifyByReference('BOA123456789', 'org-1', 'user-1', undefined, 'ABYSSINIA');
    expect(result.verified).toBe(true);
  });
});

describe('payment-provider detection and account matching (strict, no fallback)', () => {
  let service: PaymentService;

  const telebirrAccount = {
    ...registeredAccount,
    id: 'account-tb',
    provider: PaymentProvider.TELEBIRR,
    accountNumber: '0986006897',
    suffix: null,
    accountHolderName: null,
  };
  const cbeBirrAccount = {
    ...registeredAccount,
    id: 'account-cbe-birr',
    provider: PaymentProvider.CBEBIRR,
    accountNumber: null,
    suffix: null,
    accountHolderName: null,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
    mockPrisma.payment.findFirst.mockResolvedValue(null);
    mockPrisma.payment.create.mockResolvedValue(mockVerifiedPayment());
    mockPrisma.verificationLog.create.mockResolvedValue({});
  });

  it('verifies a Telebirr receipt with a registered Telebirr account (regression)', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        receiverAccount: '25****97',
      }),
    );

    const result = await service.verifyByReference(
      'DJV9JIVHMR',
      'org-1',
      'user-1',
      undefined,
      'TELEBIRR',
    );

    expect(result.verified).toBe(true);
    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(1);
    expect(mockCheckEt.verifyReference.mock.calls[0][0]).toBe(
      PaymentProvider.TELEBIRR,
    );
  });

  it('returns PAYMENT_ACCOUNT_NOT_CONFIGURED for a CBE Birr receipt when only Telebirr is registered (no fallback)', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);

    await expect(
      service.verifyByReference(
        'FT123456789',
        'org-1',
        'user-1',
        undefined,
        'CBEBIRR',
      ),
    ).rejects.toMatchObject({
      response: { status: 'PAYMENT_ACCOUNT_NOT_CONFIGURED' },
    });

    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('uses only the detected provider when both CBE Birr and Telebirr are registered', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([
      cbeBirrAccount,
      telebirrAccount,
    ]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.CBEBIRR,
        checkEtBank: 'cbebirr',
        receiverAccount: null,
      }),
    );

    const result = await service.verifyByReference(
      'FT123456789',
      'org-1',
      'user-1',
      undefined,
      'CBEBIRR',
    );

    // No receiver evidence -> not approved (fail closed), but the correct
    // provider was used and Telebirr was never probed.
    expect(result.verified).toBe(false);
    expect(mockCheckEt.verifyReference).toHaveBeenCalledTimes(1);
    expect(mockCheckEt.verifyReference.mock.calls[0][0]).toBe(
      PaymentProvider.CBEBIRR,
    );
    for (const call of mockCheckEt.verifyReference.mock.calls) {
      expect(call[0]).not.toBe(PaymentProvider.TELEBIRR);
    }
  });

  it('returns PAYMENT_PROVIDER_UNDETECTED when no provider is supplied', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);

    await expect(
      service.verifyByReference('DJV9JIVHMR', 'org-1', 'user-1'),
    ).rejects.toMatchObject({
      response: { status: 'PAYMENT_PROVIDER_UNDETECTED' },
    });

    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('returns UNSUPPORTED_PAYMENT_PROVIDER for an unknown provider', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);

    await expect(
      service.verifyByReference(
        'DJV9JIVHMR',
        'org-1',
        'user-1',
        undefined,
        'WECHAT',
      ),
    ).rejects.toMatchObject({
      response: { status: 'UNSUPPORTED_PAYMENT_PROVIDER' },
    });

    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
  });

  it('returns PAYMENT_ACCOUNT_NOT_CONFIGURED when the matching account is inactive', async () => {
    // The query only returns active accounts; an inactive-only org yields [].
    mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

    await expect(
      service.verifyByReference(
        'FT123456789',
        'org-1',
        'user-1',
        undefined,
        'CBEBIRR',
      ),
    ).rejects.toMatchObject({
      response: { status: 'PAYMENT_ACCOUNT_NOT_CONFIGURED' },
    });

    expect(mockPrisma.paymentAccount.findMany).toHaveBeenCalledWith({
      where: { organizationId: 'org-1', isActive: true },
    });
    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('fails closed with PROVIDER_UNAVAILABLE when the provider times out', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([cbeBirrAccount]);
    mockCheckEt.verifyReference.mockRejectedValue(
      new CheckEtError(
        ProviderErrorType.NETWORK_ERROR,
        null,
        'check.et request timed out',
      ),
    );

    await expect(
      service.verifyByReference(
        'FT123456789',
        'org-1',
        'user-1',
        undefined,
        'CBEBIRR',
      ),
    ).rejects.toMatchObject({
      response: { status: 'PROVIDER_UNAVAILABLE' },
    });

    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('preserves an authoritative transaction-not-found result', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([telebirrAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        success: false,

        provider: PaymentProvider.TELEBIRR,
        checkEtBank: 'telebirr',
        message: 'Transaction not found.',
        amount: null,
        currency: null,
        receiverAccount: null,
      }),
    );
    mockPrisma.payment.create.mockImplementation(async (args: any) => ({
      ...mockVerifiedPayment(),
      amount: args.data.amount,
      status: args.data.status,
    }));

    const result = await service.verifyByReference(
      'DJV9JIVHMR',
      'org-1',
      'user-1',
      undefined,
      'TELEBIRR',
    );

    expect(result.verified).toBe(false);
    expect(result.status).toBe(PaymentStatus.FAILED);
    expect(result.message).toMatch(/transaction not found/i);
  });

  it('enforces cross-organization account isolation', async () => {
    // No org-2 account exists; the query is org-scoped and must fail closed.
    mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

    await expect(
      service.verifyByReference(
        'FT123456789',
        'org-2',
        'user-1',
        undefined,
        'CBEBIRR',
      ),
    ).rejects.toMatchObject({
      response: { status: 'PAYMENT_ACCOUNT_NOT_CONFIGURED' },
    });

    expect(mockPrisma.paymentAccount.findMany).toHaveBeenCalledWith({
      where: { organizationId: 'org-2', isActive: true },
    });
    expect(mockCheckEt.verifyReference).not.toHaveBeenCalled();
    expect(mockPrisma.payment.create).not.toHaveBeenCalled();
  });

  it('normalizes provider separators (M-Pesa) before matching', async () => {
    const mpesaAccount = {
      ...registeredAccount,
      id: 'account-mpesa',
      provider: PaymentProvider.M_PESA,
      accountNumber: '0911223344',
      suffix: null,
      accountHolderName: null,
    };
    mockPrisma.paymentAccount.findMany.mockResolvedValue([mpesaAccount]);
    mockCheckEt.verifyReference.mockResolvedValue(
      validNormalized({
        provider: PaymentProvider.M_PESA,
        checkEtBank: 'mpesa',
        receiverAccount: '0911223344',
      }),
    );

    const result = await service.verifyByReference(
      'MP123456789',
      'org-1',
      'user-1',
      undefined,
      'M-Pesa',
    );

    expect(result.verified).toBe(true);
    expect(mockCheckEt.verifyReference.mock.calls[0][0]).toBe(
      PaymentProvider.M_PESA,
    );
  });
});
