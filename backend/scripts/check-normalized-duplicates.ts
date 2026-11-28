/**
 * Stage 1 preflight — READ-ONLY duplicate inspection.
 *
 * Run BEFORE `prisma migrate deploy` of the Stage 1 migration:
 *   npx ts-node scripts/check-normalized-duplicates.ts
 *
 * Lists payment references that would collide under the new unique constraint
 * on (organizationId, normalizedTransactionId). It never modifies data.
 * If any rows are printed, the migration will abort on index creation — do
 * not deploy until the duplicates are resolved by a business decision.
 *
 * REVIEW FIX: the normalization here mirrors
 * src/payment/reference-normalizer.ts exactly (uppercase + whitespace-only
 * stripping; separators are preserved).
 */
import { PrismaClient } from '@prisma/client';
import { normalizeTransactionId } from '../src/payment/reference-normalizer';

async function main() {
  const prisma = new PrismaClient();
  try {
    const payments = await prisma.payment.findMany({
      select: {
        id: true,
        organizationId: true,
        transactionId: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    const seen = new Map<string, string[]>();
    for (const p of payments) {
      const key = normalizeTransactionId(p.transactionId);
      if (!key) continue;
      const composite = `${p.organizationId}::${key}`;
      const arr = seen.get(composite) ?? [];
      arr.push(p.id);
      seen.set(composite, arr);
    }

    const dupes = [...seen.entries()].filter(([, ids]) => ids.length > 1);
    if (dupes.length === 0) {
      console.log('OK: no duplicate normalized references found. Migration is safe.');
      return;
    }
    console.error(`DUPLICATES FOUND: ${dupes.length} colliding reference group(s).`);
    for (const [composite, ids] of dupes) {
      const [orgId, ref] = composite.split('::');
      console.error(`- organization=${orgId} normalizedReference=${ref} paymentIds=${ids.join(',')}`);
    }
    console.error('STOP: resolve these duplicates manually before migrating.');
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
