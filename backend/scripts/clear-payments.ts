import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const organizationId = process.argv[2];

  if (!organizationId) {
    console.log('Usage: npx ts-node scripts/clear-payments.ts <organizationId>');
    console.log('Example: npx ts-node scripts/clear-payments.ts d9faf008-09e1-47f3-ada0-c06dcd472cfb');
    process.exit(1);
  }

  console.log(`Clearing payment records for organization: ${organizationId}`);
  console.log('This will delete all payments and verification logs for this organization.');
  
  // Confirm deletion
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  const answer = await new Promise<string>((resolve) => {
    rl.question('Are you sure you want to continue? (yes/no): ', resolve);
  });

  if (answer.toLowerCase() !== 'yes') {
    console.log('Operation cancelled.');
    rl.close();
    process.exit(0);
  }

  rl.close();

  // Delete verification logs first (due to foreign key constraints)
  const deletedLogs = await prisma.verificationLog.deleteMany({
    where: {
      payment: {
        organizationId
      }
    }
  });
  console.log(`Deleted ${deletedLogs.count} verification logs`);

  // Delete payments
  const deletedPayments = await prisma.payment.deleteMany({
    where: { organizationId }
  });
  console.log(`Deleted ${deletedPayments.count} payment records`);

  console.log('✅ Payment records cleared successfully');
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
