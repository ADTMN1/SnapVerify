import "dotenv/config";
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { PasswordService } from '../src/auth/password.service';

/**
 * Provision (or reset) a platform admin account for the Admin Panel.
 *
 * The admin login (POST /api/admin/auth/login) only accepts users that are
 * either a platform admin (isPlatformAdmin = true) or an OWNER of an
 * organization. This script creates/updates such a platform admin so the
 * Admin Panel can be controlled.
 *
 * The password is hashed with the same Argon2id PasswordService the backend
 * verifies against. The password is never printed.
 *
 * Usage:
 *   npx tsx scripts/create-platform-admin.ts
 *   ADMIN_EMAIL="admin@gmail.com" ADMIN_PASSWORD="Admin123$" npx tsx scripts/create-platform-admin.ts
 *
 * Optional environment variables:
 *   ADMIN_EMAIL     Email to provision (default: admin@gmail.com)
 *   ADMIN_PASSWORD  Password to set (default: Admin123$)
 *   ADMIN_FULL_NAME Display name (default: Platform Admin)
 */

async function main() {
  const email = (process.env.ADMIN_EMAIL?.trim() || "admin@gmail.com").toLowerCase();
  const password = process.env.ADMIN_PASSWORD || "Admin123$";
  const fullName = process.env.ADMIN_FULL_NAME?.trim() || "Platform Admin";

  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });
  const passwordService = new PasswordService();

  try {
    const passwordHash = await passwordService.hash(password);

    const user = await prisma.user.upsert({
      where: { email },
      update: {
        fullName,
        passwordHash,
        status: "active",
        emailVerified: true,
        isPlatformAdmin: true,
      },
      create: {
        email,
        fullName,
        passwordHash,
        status: "active",
        emailVerified: true,
        isPlatformAdmin: true,
      },
    });

    console.log(`Platform admin ready: ${user.email} (id=${user.id})`);
    console.log(`isPlatformAdmin=${user.isPlatformAdmin} status=${user.status}`);
    console.log("Login at POST /api/admin/auth/login with the configured credentials.");
  } finally {
    await prisma.$disconnect();
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});