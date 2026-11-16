import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const email = process.argv[2]!;
  const user = await prisma.user.findUnique({
    where: { email },
    select: { emailVerified: true, status: true, createdAt: true },
  });
  const otps = await prisma.emailOtp.findMany({
    where: { email },
    orderBy: { createdAt: 'desc' },
    take: 5,
  });
  console.log({ user, otps });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
