import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const phone = '0986006897';

  console.log(`\n=== Current users with phone: ${phone} ===`);
  const users = await prisma.user.findMany({
    where: { phone },
    include: { userAssignments: { include: { organization: true } } },
    orderBy: { createdAt: 'asc' }
  });

  console.log(`Found ${users.length} user(s):\n`);
  
  users.forEach((user, index) => {
    console.log(`${index + 1}. User ID: ${user.id}`);
    console.log(`   Full Name: ${user.fullName || '(not set)'}`);
    console.log(`   Roles: ${user.userAssignments.map((a) => a.role).join(', ') || '(none)'}`);
    console.log(
      `   Organizations: ${user.userAssignments
        .map((a) => `${a.organization.name || '(unnamed)'} (${a.organizationId})`)
        .join(', ') || '(none)'}`,
    );
    console.log(`   Created: ${user.createdAt}`);
    console.log(`   Password Hash: ${user.passwordHash ? 'SET' : 'NOT SET'}`);
    console.log('');
  });

  // Keep the first (oldest) account and delete the rest
  const userToKeep = users[0];
  const usersToDelete = users.slice(1);

  console.log(`\n=== Keeping ===`);
  console.log(`User ID: ${userToKeep.id}`);
  console.log(
    `Organizations: ${userToKeep.userAssignments
      .map((a) => `${a.organization.name || '(unnamed)'} (${a.organizationId})`)
      .join(', ') || '(none)'}`,
  );
  console.log(`Full Name: ${userToKeep.fullName || '(not set)'}`);

  console.log(`\n=== Deleting ${usersToDelete.length} duplicate(s) ===`);
  
  for (const user of usersToDelete) {
    console.log(
      `\nDeleting user: ${user.id} (${user.userAssignments
        .map((a) => a.organization.name || '(unnamed)')
        .join(', ') || '(no organization)'})`,
    );

    await prisma.user.delete({
      where: { id: user.id }
    });

    console.log(`✓ Deleted user ${user.id}`);

    for (const assignment of user.userAssignments) {
      const orgId = assignment.organizationId;
      const orgUsers = await prisma.userBusinessAssignment.findMany({
        where: { organizationId: orgId },
        select: { userId: true },
      });

      if (orgUsers.length === 0) {
        console.log(`  → Organization ${orgId} has no more users, deleting...`);
        await prisma.organization.delete({
          where: { id: orgId }
        });
        console.log(`  ✓ Deleted organization ${orgId}`);
      }
    }
  }

  console.log(`\n=== Verification ===`);
  const remainingUsers = await prisma.user.findMany({
    where: { phone },
    include: { userAssignments: { include: { organization: true } } }
  });
  
  console.log(`Remaining users with phone ${phone}: ${remainingUsers.length}`);
  remainingUsers.forEach(user => {
    const orgs = user.userAssignments
      .map((a) => a.organization.name || '(unnamed)')
      .join(', ') || '(no organization)';
    console.log(`- ${orgs} (${user.id})`);
  });

  await prisma.$disconnect();
  console.log('\n✓ Cleanup complete!');
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  });
