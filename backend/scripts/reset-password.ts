import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';

const saltRounds = 12;

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const phone = '0986006897';
  const newPassword = 'One123';

  console.log(`Looking for users with phone: ${phone}`);

  const users = await prisma.user.findMany({
    where: { phone }
  });

  if (users.length === 0) {
    console.error('Users not found!');
    await prisma.$disconnect();
    process.exit(1);
  }

  console.log(`Found ${users.length} users! Hashing new password...`);
  const passwordHash = await bcrypt.hash(newPassword, saltRounds);

  console.log('Updating passwords for all users...');
  for (const user of users) {
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash }
    });
    console.log(`Updated password for user: ${user.id} (${user.fullName || 'No name'})`);
  }

  console.log('Passwords changed successfully!');
  console.log('Phone:', phone);
  console.log('New password:', newPassword);

  await prisma.$disconnect();
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
