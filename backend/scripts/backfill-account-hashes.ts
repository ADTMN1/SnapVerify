/**
 * Stage 1 — account-number hash backfill (keyed HMAC-SHA-256).
 *
 * The accountNumberHash column is backfilled by THIS script, not by the SQL
 * migration, because the hash is keyed HMAC-SHA-256 under
 * ACCOUNT_HASH_SECRET — a server secret that must never appear in a
 * migration file or database history.
 *
 * Usage (after the Stage 1 migration has been deployed):
 *   ACCOUNT_HASH_SECRET=<secret> npx ts-node scripts/backfill-account-hashes.ts
 *
 * Behavior:
 *   - Idempotent: re-running recomputes all hashes (use after rotating the
 *     secret — set the NEW secret and run again).
 *   - Overwrites accountNumberHash for every account; never deletes or
 *     modifies accountNumber, suffix, or any other column.
 *   - Prints per-row progress without printing account numbers or secrets.
 */
import { PrismaClient } from '@prisma/client';
import { computeAccountNumberHash } from '../src/payment/account-hash';

async function main() {
  const secret = process.env.ACCOUNT_HASH_SECRET ?? '';
  if (!secret || secret.length < 32) {
    console.error(
      'FATAL: ACCOUNT_HASH_SECRET missing or too short (>= 32 chars). Aborting without changes.',
    );
    process.exit(1);
  }

  const prisma = new PrismaClient();
  try {
    const accounts = await prisma.paymentAccount.findMany({
      select: { id: true, accountNumber: true },
    });
    console.log(`Backfilling HMAC hashes for ${accounts.length} account(s)...`);

    let updated = 0;
    let skipped = 0;
    for (const account of accounts) {
      if (!account.accountNumber) {
        skipped++;
        continue;
      }
      const hash = computeAccountNumberHash(account.accountNumber, secret);
      if (!hash) {
        skipped++;
        continue;
      }
      await prisma.paymentAccount.update({
        where: { id: account.id },
        data: { accountNumberHash: hash },
      });
      updated++;
    }
    console.log(`Done. updated=${updated} skipped=${skipped}`);
  } finally {
    await prisma.$disconnect();
  }
}

void main();
