import { config } from 'dotenv';
import { PrismaClient, Role } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';

// Load environment variables from .env file
config();

// Initialize PrismaClient with adapter, just like PrismaService does
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Migrating existing users to UserBusinessAssignment...');

  // First, get all users
  const users = await prisma.user.findMany();
  console.log('Current users (total:', users.length, '):');
  users.forEach(user => {
    console.log(`- ${user.id}: ${user.fullName} (${user.phone})`);
  });

  // Get all organizations
  const organizations = await prisma.organization.findMany();
  console.log('\nOrganizations found (total:', organizations.length, '):');
  organizations.forEach(org => {
    console.log(`- ${org.id}: ${org.name}`);
  });

  let firstOrg: any = null;
  if (organizations.length > 0) {
    firstOrg = organizations[0];
    console.log('\nUsing organization:', firstOrg.name, '(', firstOrg.id, ')');

    // First, create UserBusinessAssignment entries for all users
    for (const user of users) {
      // Check if user already has an assignment
      const existingAssignment = await prisma.userBusinessAssignment.findFirst({
        where: { userId: user.id },
      });

      if (!existingAssignment) {
        await prisma.userBusinessAssignment.create({
          data: {
            userId: user.id,
            organizationId: firstOrg.id,
            role: Role.OWNER,
            branchId: null,
            status: 'ACTIVE',
          },
        });
        console.log('Created assignment for user:', user.id, 'to org:', firstOrg.id, 'role:', Role.OWNER);
      } else {
        console.log('User already has assignment:', user.id);
      }
    }
  }

  // Now, migrate devices!
  console.log('\nMigrating devices...');
  const devices = await prisma.device.findMany();
  console.log('Current devices (total:', devices.length, '):');

  for (const device of devices) {
    // For each device, get the user's first assignment
    const userAssignment = await prisma.userBusinessAssignment.findFirst({
      where: { userId: (device as any).userId }, // We have to cast as any because userId is no longer in the model
    });

    if (userAssignment) {
      // Update the device to use userAssignmentId instead of userId
      await prisma.device.update({
        where: { id: device.id },
        data: {
          userAssignmentId: userAssignment.id,
        },
      });
      console.log('Updated device:', device.id, 'to use assignment:', userAssignment.id);
    } else {
      console.log('No assignment found for device:', device.id, '(user:', (device as any).userId, ')');
    }
  }

  console.log('\nMigration complete!');
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });