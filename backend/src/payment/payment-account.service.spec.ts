import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentAccountService } from './payment-account.service';
import { CreatePaymentAccountDto } from './dto/create-payment-account.dto';
import { UpdatePaymentAccountDto } from './dto/update-payment-account.dto';
import * as crypto from 'crypto';

const HMAC_SECRET = 'a'.repeat(48);
const hmac = (s: string) =>
  `hmac-v1:${crypto.createHmac('sha256', HMAC_SECRET).update(s).digest('hex')}`;

type AccountRecord = {
  id: string;
  publicId: string | null;
  organizationId: string;
  provider: PaymentProvider;
  accountNumber: string;
  accountNumberHash: string | null;
  suffix: string | null;
  accountHolderName: string | null;
  isActive: boolean;
  branchId: string | null;
};

type CreateArgs = {
  data: {
    publicId: string;
    accountNumber?: string | null;
    accountNumberHash?: string | null;
    suffix?: string | null;
    [key: string]: unknown;
  };
};

type UpdateArgs = {
  where: { id: string };
  data: {
    publicId?: string;
    accountNumberHash?: string | null;
    suffix?: string | null;
    [key: string]: unknown;
  };
};

const paymentAccountMock = {
  findFirst: jest.fn<Promise<AccountRecord | null>, [unknown]>(),
  findMany: jest.fn<Promise<AccountRecord[]>, [unknown]>(),
  create: jest.fn<Promise<AccountRecord>, [CreateArgs]>(),
  update: jest.fn<Promise<AccountRecord>, [UpdateArgs]>(),
  updateMany: jest.fn<Promise<{ count: number }>, [unknown]>(),
  deleteMany: jest.fn<Promise<{ count: number }>, [unknown]>(),
};

const mockPrisma = { paymentAccount: paymentAccountMock };

const createDto = (
  dto: CreatePaymentAccountDto & { suffix?: string },
): CreatePaymentAccountDto => dto;

const updateDto = (
  dto: UpdatePaymentAccountDto & { suffix?: string },
): UpdatePaymentAccountDto => dto;

async function build() {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      PaymentAccountService,
      { provide: PrismaService, useValue: mockPrisma },
      {
        provide: ConfigService,
        useValue: {
          get: jest.fn((key: string) =>
            key === 'ACCOUNT_HASH_SECRET' ? HMAC_SECRET : undefined,
          ),
        },
      },
    ],
  }).compile();
  return module.get<PaymentAccountService>(PaymentAccountService);
}

describe('PaymentAccountService — Stage 1 data minimization', () => {
  let service: PaymentAccountService;

  beforeEach(async () => {
    jest.clearAllMocks();
    service = await build();
  });

  it('refuses to construct without a usable ACCOUNT_HASH_SECRET (fail closed)', async () => {
    const builder = Test.createTestingModule({
      providers: [
        PaymentAccountService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: ConfigService, useValue: { get: jest.fn(() => undefined) } },
      ],
    });
    await expect(builder.compile()).rejects.toThrow(/ACCOUNT_HASH_SECRET/);
  });

  const baseAccount: AccountRecord = {
    id: 'acc-1',
    publicId: '0123456789abcdef01234567',
    organizationId: 'org-1',
    provider: PaymentProvider.CBE,
    accountNumber: '1000516323381',
    accountNumberHash: hmac('1000516323381'),
    suffix: '16323381',
    accountHolderName: 'Test Business',
    isActive: true,
    branchId: null,
  };

  it('stores a keyed HMAC accountNumberHash on create (not plain SHA-256)', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockResolvedValue(baseAccount);

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    const args = paymentAccountMock.create.mock.calls[0][0];
    expect(args.data.accountNumberHash).toBe(hmac('1000516323381'));
    const plain = crypto
      .createHash('sha256')
      .update('1000516323381')
      .digest('hex');
    expect(args.data.accountNumberHash).not.toContain(plain);
    expect(args.data.accountNumber).toBe('1000516323381');
  });

  it('never returns a full account number from the API (create response masked)', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockResolvedValue(baseAccount);

    const result = await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    expect(result.accountNumber).toBe('****3381');
    expect(JSON.stringify(result)).not.toContain('1000516323381');
  });

  it('masks account numbers in findAll and findByOrganizationAndBranch', async () => {
    paymentAccountMock.findMany.mockResolvedValue([baseAccount]);

    const all = await service.findAll('org-1');
    const byBranch = await service.findByOrganizationAndBranch('org-1');

    expect(all[0].accountNumber).toBe('****3381');
    expect(byBranch[0].accountNumber).toBe('****3381');
  });

  it('assigns a stable, opaque public QR id when creating an account', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockImplementation(({ data }) =>
      Promise.resolve({ ...baseAccount, publicId: data.publicId }),
    );

    const result = await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    const args = paymentAccountMock.create.mock.calls[0][0];
    expect(args.data.publicId).toMatch(/^[0-9a-f]{24}$/);
    expect(result.publicId).toBe(args.data.publicId);
    // The QR identifier must not be derived from the account number.
    expect(args.data.publicId).not.toContain('1000516323381');
  });

  it('retries with a fresh public id when the generated one collides', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create
      .mockRejectedValueOnce({ code: 'P2002', meta: { target: ['publicId'] } })
      .mockImplementationOnce(({ data }) =>
        Promise.resolve({ ...baseAccount, publicId: data.publicId }),
      );

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    expect(paymentAccountMock.create).toHaveBeenCalledTimes(2);
    const first = paymentAccountMock.create.mock.calls[0][0].data;
    const second = paymentAccountMock.create.mock.calls[1][0].data;
    expect(second.publicId).toMatch(/^[0-9a-f]{24}$/);
    expect(second.publicId).not.toBe(first.publicId);
  });

  it('never rewrites the public id of an existing account', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(baseAccount);
    paymentAccountMock.update.mockResolvedValue(baseAccount);

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data.publicId).toBeUndefined();
  });

  it('backfills a public id for a legacy account that has none', async () => {
    paymentAccountMock.findFirst.mockResolvedValue({
      ...baseAccount,
      publicId: null,
    });
    paymentAccountMock.update.mockResolvedValue(baseAccount);

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '16323381',
        accountHolderName: 'Test Business',
        branchId: undefined,
      }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data.publicId).toMatch(/^[0-9a-f]{24}$/);
  });

  it('derives the CBE suffix from a formatted account number on create and ignores a client suffix', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockResolvedValue(baseAccount);

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.CBE,
        accountNumber: '1000 5163-23381',
        suffix: '99999999',
      }),
    );

    const args = paymentAccountMock.create.mock.calls[0][0];
    expect(args.data.suffix).toBe('16323381');
  });

  it('derives the ABYSSINIA suffix from the last five digits on create', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockResolvedValue({
      ...baseAccount,
      provider: PaymentProvider.ABYSSINIA,
    });

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.ABYSSINIA,
        accountNumber: '1000290172',
        suffix: '99999',
      }),
    );

    const args = paymentAccountMock.create.mock.calls[0][0];
    expect(args.data.suffix).toBe('90172');
  });

  it('does not fabricate a suffix for providers without a verified rule', async () => {
    paymentAccountMock.findFirst.mockResolvedValue(null);
    paymentAccountMock.create.mockResolvedValue({
      ...baseAccount,
      provider: PaymentProvider.TELEBIRR,
    });

    await service.create(
      'org-1',
      createDto({
        provider: PaymentProvider.TELEBIRR,
        accountNumber: '0912345678',
        suffix: 'brigade',
      }),
    );

    const args = paymentAccountMock.create.mock.calls[0][0];
    expect(args.data.suffix).toBeNull();
  });

  const invalidCreateCases: Array<[PaymentProvider, string | undefined]> = [
    [PaymentProvider.CBE, '1234'],
    [PaymentProvider.ABYSSINIA, '123'],
    [PaymentProvider.CBE, undefined],
  ];

  it.each(invalidCreateCases)(
    'rejects an account number with too few digits for %s',
    async (provider, accountNumber) => {
      await expect(
        service.create('org-1', createDto({ provider, accountNumber })),
      ).rejects.toThrow(/at least \d+ digits/);
      expect(paymentAccountMock.create).not.toHaveBeenCalled();
    },
  );

  it('keeps the hash in sync and recomputes the suffix when the account number is updated', async () => {
    paymentAccountMock.findMany.mockResolvedValue([baseAccount]);
    paymentAccountMock.update.mockResolvedValue(baseAccount);
    paymentAccountMock.findFirst.mockResolvedValue(baseAccount);

    await service.update(
      'org-1',
      PaymentProvider.CBE,
      undefined,
      updateDto({ accountNumber: '1000999999' }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data.accountNumberHash).toBe(hmac('1000999999'));
    expect(args.data.suffix).toBe('00999999');
    expect(paymentAccountMock.updateMany).not.toHaveBeenCalled();
  });

  it('recomputes the suffix when the provider changes to a provider with a rule', async () => {
    paymentAccountMock.findMany.mockResolvedValue([
      { ...baseAccount, provider: PaymentProvider.TELEBIRR, suffix: null },
    ]);
    paymentAccountMock.update.mockResolvedValue(baseAccount);
    paymentAccountMock.findFirst.mockResolvedValue(baseAccount);

    await service.update(
      'org-1',
      PaymentProvider.TELEBIRR,
      undefined,
      updateDto({
        provider: PaymentProvider.CBE,
        accountNumber: '0912345678',
      }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data.suffix).toBe('12345678');
  });

  it('clears the suffix when the provider changes to one without a rule', async () => {
    paymentAccountMock.findMany.mockResolvedValue([baseAccount]);
    paymentAccountMock.update.mockResolvedValue(baseAccount);
    paymentAccountMock.findFirst.mockResolvedValue(baseAccount);

    await service.update(
      'org-1',
      PaymentProvider.CBE,
      undefined,
      updateDto({ provider: PaymentProvider.TELEBIRR }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data.suffix).toBeNull();
  });

  it('masks account numbers on update responses and leaves suffixes untouched on unrelated edits', async () => {
    paymentAccountMock.findMany.mockResolvedValue([baseAccount]);
    paymentAccountMock.update.mockResolvedValue(baseAccount);
    paymentAccountMock.findFirst.mockResolvedValue(baseAccount);

    const result = await service.update(
      'org-1',
      PaymentProvider.CBE,
      undefined,
      updateDto({ accountHolderName: 'Renamed Business' }),
    );

    const args = paymentAccountMock.update.mock.calls[0][0];
    expect(args.data).not.toHaveProperty('suffix');
    expect(result.accountNumber).toBe('****3381');
  });
});
