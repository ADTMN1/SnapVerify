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
    include: { organization: true },
    orderBy: { createdAt: 'asc' }
  });

  console.log(`Found ${users.length} user(s):\n`);
  
  users.forEach((user, index) => {
    console.log(`${index + 1}. User ID: ${user.id}`);
    console.log(`   Full Name: ${user.fullName || '(not set)'}`);
    console.log(`   Role: ${user.role}`);
    console.log(`   Organization: ${user.organization?.name || '(unnamed)'} (${user.organizationId})`);
    console.log(`   Created: ${user.createdAt}`);
    console.log(`   Password Hash: ${user.passwordHash ? 'SET' : 'NOT SET'}`);
    console.log('');
  });

  // Keep the first (oldest) account and delete the rest
  const userToKeep = users[0];
  const usersToDelete = users.slice(1);

  console.log(`\n=== Keeping ===`);
  console.log(`User ID: ${userToKeep.id}`);
  console.log(`Organization: ${userToKeep.organization?.name || '(unnamed)'}`);
  console.log(`Full Name: ${userToKeep.fullName || '(not set)'}`);

  console.log(`\n=== Deleting ${usersToDelete.length} duplicate(s) ===`);
  
  for (const user of usersToDelete) {
    console.log(`\nDeleting user: ${user.id} (${user.organization?.name || '(unnamed)'})`);
    
    // Delete related records first (if any)
    // Note: Adjust this based on your actual schema relationships
    
    await prisma.user.delete({
      where: { id: user.id }
    });
    
    console.log(`✓ Deleted user ${user.id}`);
    
    // Optionally delete the organization if it has no other users
    const orgUsers = await prisma.user.findMany({
      where: { organizationId: user.organizationId }
    });
    
    if (orgUsers.length === 0 && user.organizationId) {
      console.log(`  → Organization ${user.organizationId} has no more users, deleting...`);
      await prisma.organization.delete({
        where: { id: user.organizationId }
      });
      console.log(`  ✓ Deleted organization ${user.organizationId}`);
    }
  }

  console.log(`\n=== Verification ===`);
  const remainingUsers = await prisma.user.findMany({
    where: { phone },
    include: { organization: true }
  });
  
  console.log(`Remaining users with phone ${phone}: ${remainingUsers.length}`);
  remainingUsers.forEach(user => {
    console.log(`- ${user.organization?.name || '(unnamed)'} (${user.id})`);
  });

  await prisma.$disconnect();
  console.log('\n✓ Cleanup complete!');
}

main()
  .catch((e) => {
    console.error('Error:', e);
    process.exit(1);
  });
