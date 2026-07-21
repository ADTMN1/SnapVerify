import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const phone = '0986006897';

  console.log(`Looking for users with phone: ${phone}`);
  const users = await prisma.user.findMany({
    where: { phone },
    include: { organization: true }
  });

  console.log(`Found ${users.length} user(s):`);
  for (const user of users) {
    console.log('-----------------------');
    console.log('User ID:', user.id);
    console.log('Phone:', user.phone);
    console.log('Full Name:', user.fullName);
    console.log('Role:', user.role);
    console.log('Organization ID:', user.organizationId);
    console.log('Password Hash:', user.passwordHash ? 'SET' : 'NOT SET');
    console.log('Organization:', user.organization?.name);
  }

  await prisma.$disconnect();
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
