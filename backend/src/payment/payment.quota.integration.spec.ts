import { ConfigService } from '@nestjs/config';
import {
  PaymentProvider,
  PaymentStatus,
  PrismaClient,
  SubscriptionStatus,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { PrismaPg } from '@prisma/adapter-pg';
import { computeAccountNumberHash } from './account-hash';
import {
  CheckEtService,
  NormalizedVerification,
} from './check-et/check-et.service';
import { PaymentService } from './payment.service';

const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
const describeIfDb = TEST_DATABASE_URL ? describe : describe.skip;
const HMAC_SECRET = 'a'.repeat(48);

describeIfDb('PaymentService quota atomicity (integration)', () => {
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
  const orgId = `org-quota-${suffix}`;
  const userId = `user-quota-${suffix}`;
  const subscriptionId = `sub-quota-${suffix}`;
  const accountNumber = '1000516323381';
  const reference = `FT-${suffix}`;

  let prisma: PrismaClient;
  let service: PaymentService;
  let startDate: Date;

  beforeAll(async () => {
    prisma = new PrismaClient({
      adapter: new PrismaPg(TEST_DATABASE_URL!),
    });

    await prisma.organization.create({
      data: {
        id: orgId,
        name: 'Quota Test Organization',
        type: 'BUSINESS',
        phone: '+251900000001',
      },
    });
    await prisma.user.create({
      data: {
        id: userId,
        fullName: 'Quota Tester',
        username: `quota-${suffix}`,
      },
    });
    await prisma.paymentAccount.create({
      data: {
        id: `account-quota-${suffix}`,
        publicId: `quota-${suffix}`,
        organizationId: orgId,
        provider: PaymentProvider.CBE,
        accountNumber,
        accountNumberHash: computeAccountNumberHash(accountNumber, HMAC_SECRET),
        suffix: accountNumber.slice(-4),
        accountHolderName: 'Test Business',
        isActive: true,
      },
    });
    const subscription = await prisma.subscription.create({
      data: {
        id: subscriptionId,
        organizationId: orgId,
        planName: 'free',
        status: SubscriptionStatus.ACTIVE,
        startDate: new Date(),
        verificationLimit: 10,
      },
    });
    startDate = subscription.startDate;

    const verification: NormalizedVerification = {
      success: true,
      duplicate: false,
      message: null,
      provider: PaymentProvider.CBE,
      checkEtBank: 'cbe',
      transactionNumber: reference,
      verificationId: reference,
      amount: '100',
      currency: 'ETB',
      transactionDate: new Date('2026-01-01T10:00:00+03:00').toISOString(),
      payer: 'Payer',
      payerAccount: '1000123456789',
      receiver: 'Test Business',
      receiverAccount: accountNumber,
      verificationMethod: 'official',
      raw: { success: true, exists: true, duplicate: false, message: null },
    };

    service = new PaymentService(
      {
        get: jest.fn((key: string, defaultValue?: unknown) => {
          const config: Record<string, unknown> = {
            NODE_ENV: 'development',
            ACCOUNT_HASH_SECRET: HMAC_SECRET,
          };
          return key in config ? config[key] : defaultValue;
        }),
      } as unknown as ConfigService,
      prisma as never,
      {
        verifyReference: jest.fn().mockResolvedValue(verification),
      } as unknown as CheckEtService,
    );
  });

  afterAll(async () => {
    await prisma.organization.deleteMany({ where: { id: orgId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it('leaves exactly one payment and one quota unit after concurrent duplicate requests', async () => {
    const results = await Promise.allSettled([
      service.verifyByReference(
        reference,
        orgId,
        userId,
        undefined,
        'CBE',
      ),
      service.verifyByReference(
        reference,
        orgId,
        userId,
        undefined,
        'CBE',
      ),
    ]);

    expect(results.every((result) => result.status === 'fulfilled')).toBe(true);
    const statuses = results.map((result) =>
      result.status === 'fulfilled' ? result.value.status : 'rejected',
    );
    expect(statuses).toContain(PaymentStatus.VERIFIED);
    expect(statuses).toContain('PREVIOUSLY_VERIFIED');

    const payments = await prisma.payment.findMany({
      where: { organizationId: orgId, transactionId: reference },
    });
    expect(payments).toHaveLength(1);
    expect(payments[0].status).toBe(PaymentStatus.VERIFIED);

    const usage = await prisma.subscriptionUsage.findUnique({
      where: {
        subscriptionId_periodStart: {
          subscriptionId: subscriptionId,
          periodStart: startDate,
        },
      },
    });
    expect(usage?.count).toBe(1);
  });
});
