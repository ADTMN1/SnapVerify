import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const organizationId = process.argv[2];
  const newAccountNumber = process.argv[3];
  const newSuffix = process.argv[4];

  if (!organizationId || !newAccountNumber) {
    console.log('Usage: npx ts-node scripts/update-payment-account.ts <organizationId> <newAccountNumber> [newSuffix]');
    console.log('Example: npx ts-node scripts/update-payment-account.ts d9faf008-09e1-47f3-ada0-c06dcd472cfb 0986006897 6897');
    process.exit(1);
  }

  console.log(`Updating payment account for organization: ${organizationId}`);
  console.log(`New account number: ${newAccountNumber}`);
  console.log(`New suffix: ${newSuffix || 'auto-generated from last digits'}`);

  // Calculate suffix from account number if not provided
  const suffix = newSuffix || newAccountNumber.slice(-8);

  // Update the payment account
  const updated = await prisma.paymentAccount.updateMany({
    where: { organizationId },
    data: {
      accountNumber: newAccountNumber,
      suffix: suffix,
    },
  });

  console.log(`Updated ${updated.count} payment account(s)`);

  // Show the updated account
  const accounts = await prisma.paymentAccount.findMany({
    where: { organizationId },
  });

  console.log('\nUpdated payment accounts:');
  console.log(JSON.stringify(accounts, null, 2));
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
