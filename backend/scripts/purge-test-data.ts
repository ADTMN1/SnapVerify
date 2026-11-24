import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// Known test/demo accounts to purge before production.
const TEST_EMAILS = [
  'natnaelabebaw32@gmail.com',
  'resendtest77@gmail.com',
  'natnaelabebaw81@gmail.com',
];

async function main() {
  for (const email of TEST_EMAILS) {
    const user = await prisma.user.findUnique({
      where: { email },
      include: { userAssignments: true },
    });
    if (!user) continue;
    for (const a of user.userAssignments) {
      await prisma.device.deleteMany({ where: { userAssignmentId: a.id } });
    }
    await prisma.userBusinessAssignment.deleteMany({ where: { userId: user.id } });
    await prisma.emailOtp.deleteMany({ where: { email } });
    await prisma.refreshToken.deleteMany({ where: { userId: user.id } });
    await prisma.user.delete({ where: { id: user.id } });
    console.log(`deleted user ${email}`);
  }
  console.log('test data purge complete');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
