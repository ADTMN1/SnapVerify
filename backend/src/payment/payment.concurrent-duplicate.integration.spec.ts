/**
 * Stage 1 — CONCURRENT duplicate protection (database-level).
 *
 * These tests exercise a REAL PostgreSQL database: two identical verification
 * writes racing for the same (organizationId, normalizedTransactionId) must
 * produce exactly one persisted payment and one Prisma P2002 rejection.
 *
 * They are SKIPPED unless TEST_DATABASE_URL points at a disposable test
 * database (never the production one):
 *   TEST_DATABASE_URL="postgresql://.../snapverify_test" npx jest -- \
 *     payment.concurrent-duplicate.integration.spec.ts
 */
import { PrismaClient, PaymentStatus } from '@prisma/client';

const TEST_DATABASE_URL = process.env.TEST_DATABASE_URL;
const describeIfDb = TEST_DATABASE_URL ? describe : describe.skip;

describeIfDb('concurrent duplicate protection (integration)', () => {
  let prisma: PrismaClient;
  const orgId = 'org-concurrent-test';
  const ref = `FT-${Date.now()}-CONCURRENT`;

  beforeAll(() => {
    prisma = new PrismaClient({ datasources: { db: { url: TEST_DATABASE_URL } } } as never);
  });

  afterAll(async () => {
    await prisma.payment.deleteMany({ where: { organizationId: orgId } });
    await prisma.$disconnect();
  });

  it('persists exactly one payment when two identical requests race', async () => {
    const create = () =>
      prisma.payment.create({
        data: {
          organizationId: orgId,
          amount: 100,
          currency: 'ETB',
          paymentMethod: 'REFERENCE',
          transactionId: ref,
          normalizedTransactionId: ref.trim(),
          status: PaymentStatus.VERIFIED,
          riskScore: 0,
        },
      });

    const results = await Promise.allSettled([create(), create()]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);
    expect((rejected[0] as PromiseRejectedResult).reason?.code).toBe('P2002');

    const count = await prisma.payment.count({
      where: { organizationId: orgId, transactionId: ref },
    });
    expect(count).toBe(1);
  });

  it('allows the SAME reference across DIFFERENT organizations (isolation)', async () => {
    const otherOrg = 'org-concurrent-test-2';
    const normalized = ref.trim();

    const a = await prisma.payment.create({
      data: {
        organizationId: orgId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: ref,
        normalizedTransactionId: normalized,
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
      },
    });
    const b = await prisma.payment.create({
      data: {
        organizationId: otherOrg,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: ref,
        normalizedTransactionId: normalized,
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
      },
    });

    expect(a.id).not.toBe(b.id);
    await prisma.payment.deleteMany({ where: { organizationId: otherOrg } });
  });

  it('ignores NULL normalized references (empty references never collide)', async () => {
    const a = await prisma.payment.create({
      data: {
        organizationId: orgId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'IMAGE_OCR',
        transactionId: `OCR-${Date.now()}-A`,
        normalizedTransactionId: null,
        status: PaymentStatus.FAILED,
        riskScore: 80,
      },
    });
    const b = await prisma.payment.create({
      data: {
        organizationId: orgId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'IMAGE_OCR',
        transactionId: `OCR-${Date.now()}-B`,
        normalizedTransactionId: null,
        status: PaymentStatus.FAILED,
        riskScore: 80,
      },
    });
    expect(a.id).not.toBe(b.id);
  });
});
