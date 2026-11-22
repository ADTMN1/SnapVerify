import 'dotenv/config';
import { Pool } from 'pg';

const identifier = process.argv[2];

async function main() {
  if (!identifier) {
    console.log('Usage: npm run inspect-user -- <email|username|phone>');
    return;
  }

  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const userResult = await pool.query(
      `SELECT id, email, username, phone, status, "emailVerified",
              CASE
                WHEN "passwordHash" LIKE '$argon2%' THEN 'argon2id'
                WHEN "passwordHash" LIKE '$2%' THEN 'bcrypt'
                WHEN "passwordHash" IS NULL THEN 'none'
                ELSE 'unknown'
              END AS "passwordAlgorithm",
              length("passwordHash") AS "passwordHashLength",
              "createdAt", "updatedAt"
       FROM users
       WHERE lower(trim(coalesce(email, ''))) = lower(trim($1))
          OR lower(trim(coalesce(username, ''))) = lower(trim($1))
          OR lower(trim(coalesce(phone, ''))) = lower(trim($1))
       LIMIT 5`,
      [identifier],
    );

    const users = userResult.rows as Array<{
      id: string;
      email: string | null;
    }>;

    if (users.length === 0) {
      console.log('No matching user found.');
      return;
    }

    for (const user of users) {
      const assignments = await pool.query(
        `SELECT "organizationId", role, status, "createdAt", "updatedAt"
         FROM user_business_assignments
         WHERE "userId" = $1
         ORDER BY "createdAt" DESC`,
        [user.id],
      );
      const activity = await pool.query(
        `SELECT action, "createdAt"
         FROM activity_logs
         WHERE "userId" = $1
           AND action ILIKE '%PASSWORD%'
         ORDER BY "createdAt" DESC
         LIMIT 10`,
        [user.id],
      );
      const otps = await pool.query(
        `SELECT purpose, attempts, "consumedAt", "createdAt", "expiresAt"
         FROM email_otps
         WHERE lower(email) = lower($1)
         ORDER BY "createdAt" DESC
         LIMIT 10`,
        [user.email ?? identifier],
      );

      console.log(
        JSON.stringify(
          {
            ...user,
            assignments: assignments.rows,
            passwordActivity: activity.rows,
            emailOtps: otps.rows,
          },
          null,
          2,
        ),
      );
    }
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
