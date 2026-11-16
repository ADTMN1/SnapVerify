import "dotenv/config";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { Pool } from "pg";

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log("🧹 Starting full database reset...");

  // Order matters because of foreign keys!
  // Children first, then parents.

  // 1. Tokens & session data
  await prisma.refreshToken.deleteMany({});
  console.log("✅ Deleted all RefreshTokens");

  // 2. Logs and Payments (depend on Organization + User)
  await prisma.activityLog.deleteMany({});
  console.log("✅ Deleted all ActivityLogs");
  await prisma.verificationLog.deleteMany({});
  console.log("✅ Deleted all VerificationLogs");
  await prisma.payment.deleteMany({});
  console.log("✅ Deleted all Payments");
  await prisma.paymentAccount.deleteMany({});
  console.log("✅ Deleted all PaymentAccounts");

  // 4. Invitations (depend on Organization)
  await prisma.invitation.deleteMany({});
  console.log("✅ Deleted all Invitations");

  // 5. UserBusinessAssignments (join table, depends on User + Org + Branch)
  await prisma.userBusinessAssignment.deleteMany({});
  console.log("✅ Deleted all UserBusinessAssignments");

  // 6. Branches (depend on Organization)
  await prisma.branch.deleteMany({});
  console.log("✅ Deleted all Branches");

  // 7. Subscriptions (depend on Organization)
  await prisma.subscription.deleteMany({});
  console.log("✅ Deleted all Subscriptions");

  // 8. Organizations
  await prisma.organization.deleteMany({});
  console.log("✅ Deleted all Organizations");

  // 9. Users LAST (after everything referencing them is gone)
  await prisma.user.deleteMany({});
  console.log("✅ Deleted all Users");

  console.log("\n🎉 Full database reset complete! You can start fresh!");
}

main()
  .catch((e) => {
    console.error("❌ Reset failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
