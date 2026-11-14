import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentAccountService } from './payment-account.service';
import * as crypto from 'crypto';

const HMAC_SECRET = 'a'.repeat(48);
const hmac = (s: string) =>
  `hmac-v1:${crypto.createHmac('sha256', HMAC_SECRET).update(s).digest('hex')}`;

const mockPrisma = {
  paymentAccount: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
    deleteMany: jest.fn(),
  },
};

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

  const baseAccount = {
    id: 'acc-1',
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
    mockPrisma.paymentAccount.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.create.mockResolvedValue(baseAccount);

    await service.create('org-1', {
      provider: PaymentProvider.CBE,
      accountNumber: '1000516323381',
      suffix: '16323381',
      accountHolderName: 'Test Business',
      branchId: undefined,
    } as any);

    const args = mockPrisma.paymentAccount.create.mock.calls[0][0];
    expect(args.data.accountNumberHash).toBe(hmac('1000516323381'));
    const plain = crypto.createHash('sha256').update('1000516323381').digest('hex');
    expect(args.data.accountNumberHash).not.toContain(plain);
    expect(args.data.accountNumber).toBe('1000516323381');
  });

  it('never returns a full account number from the API (create response masked)', async () => {
    mockPrisma.paymentAccount.findFirst.mockResolvedValue(null);
    mockPrisma.paymentAccount.create.mockResolvedValue(baseAccount);

    const result = await service.create('org-1', {
      provider: PaymentProvider.CBE,
      accountNumber: '1000516323381',
      suffix: '16323381',
      accountHolderName: 'Test Business',
      branchId: undefined,
    } as any);

    expect(result.accountNumber).toBe('****3381');
    expect(JSON.stringify(result)).not.toContain('1000516323381');
  });

  it('masks account numbers in findAll and findByOrganizationAndBranch', async () => {
    mockPrisma.paymentAccount.findMany.mockResolvedValue([baseAccount]);

    const all = await service.findAll('org-1');
    const byBranch = await service.findByOrganizationAndBranch('org-1');

    expect(all[0].accountNumber).toBe('****3381');
    expect(byBranch[0].accountNumber).toBe('****3381');
  });

  it('keeps the hash in sync when the account number is updated', async () => {
    mockPrisma.paymentAccount.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.paymentAccount.findFirst.mockResolvedValue({
      ...baseAccount,
      accountNumber: '1000999999',
      accountNumberHash: hmac('1000999999'),
    });

    await service.update('org-1', PaymentProvider.CBE, undefined, {
      accountNumber: '1000999999',
    } as any);

    const args = mockPrisma.paymentAccount.updateMany.mock.calls[0][0];
    expect(args.data.accountNumberHash).toBe(hmac('1000999999'));
  });

  it('masks account numbers on update responses', async () => {
    mockPrisma.paymentAccount.updateMany.mockResolvedValue({ count: 1 });
    mockPrisma.paymentAccount.findFirst.mockResolvedValue(baseAccount);

    const result = await service.update(
      'org-1',
      PaymentProvider.CBE,
      undefined,
      { suffix: '16323381' } as any,
    );

    expect(result.accountNumber).toBe('****3381');
  });
});
