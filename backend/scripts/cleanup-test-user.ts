import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);const prisma = new PrismaClient({ adapter });

async function main() {
  const email = 'resendtest77@gmail.com';
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) {
    console.log('user not found — nothing to clean');
    return;
  }
  await prisma.userBusinessAssignment.deleteMany({ where: { userId: user.id } });
  await prisma.emailOtp.deleteMany({ where: { email } });
  await prisma.user.delete({ where: { id: user.id } });
  if (user.organizationId) {
    await prisma.organization.deleteMany({ where: { id: user.organizationId } });
  }
  console.log('deleted test user + org');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
