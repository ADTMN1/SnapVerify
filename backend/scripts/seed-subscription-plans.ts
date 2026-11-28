import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

/**
 * Seed the subscription plans table with the default SnapVerify plans.
 * Idempotent: existing rows (including admin-edited prices/names) are only
 * created when missing, never overwritten.
 *
 * Usage:
 *   npx tsx scripts/seed-subscription-plans.ts
 */

const PLANS = [
  { id: 'free', name: 'Free', price: 0, durationDays: null, durationMonths: null, isLifetime: true, verificationLimit: 20, maxUsers: 5, maxDevices: 10, sortOrder: 0 },
  { id: 'one_month', name: '1 Month', price: 1500, durationDays: null, durationMonths: 1, isLifetime: false, verificationLimit: null, maxUsers: null, maxDevices: null, sortOrder: 1 },
  { id: 'three_months', name: '3 Months', price: 3000, durationDays: null, durationMonths: 3, isLifetime: false, verificationLimit: null, maxUsers: null, maxDevices: null, sortOrder: 2 },
  { id: 'six_months', name: '6 Months', price: 5000, durationDays: null, durationMonths: 6, isLifetime: false, verificationLimit: null, maxUsers: null, maxDevices: null, sortOrder: 3 },
  { id: 'one_year', name: '1 Year', price: 10000, durationDays: null, durationMonths: 12, isLifetime: false, verificationLimit: null, maxUsers: null, maxDevices: null, sortOrder: 4 },
] as const;

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  try {
    for (const plan of PLANS) {
      await prisma.subscriptionPlan.upsert({
        where: { id: plan.id },
        update: {},
        create: { ...plan, currency: 'ETB', isActive: true },
      });
      console.log(`Seeded plan: ${plan.id} (${plan.name})`);
    }
    console.log("Subscription plans seeded.");
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});