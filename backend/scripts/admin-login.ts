import "dotenv/config";
import { writeFileSync, chmodSync } from "node:fs";

/**
 * Admin login helper.
 *
 * Authenticates against the admin API (the same endpoint the Admin Panel uses)
 * and stores the returned tokens so they can be reused for admin API calls.
 *
 * Credentials default to the values below and can be overridden via the
 * environment. They are never printed. The session file is written with 0600
 * permissions.
 *
 * Usage:
 *   npx tsx scripts/admin-login.ts
 *   ADMIN_EMAIL="other@example.com" ADMIN_PASSWORD="other" npx tsx scripts/admin-login.ts
 *
 * Optional environment variables:
 *   API_BASE_URL        Backend base URL (default: http://localhost:3000)
 *   ADMIN_SESSION_FILE  Where to save tokens (default: /tmp/snapverify-admin-session.json)
 *   PRINT_TOKEN         Set to "true" to also print the access token to stdout
 */

const API_BASE_URL = (process.env.API_BASE_URL ?? "http://localhost:3000").replace(
  /\/+$/,
  "",
);
const SESSION_FILE =
  process.env.ADMIN_SESSION_FILE ?? "/tmp/snapverify-admin-session.json";
const PRINT_TOKEN = (process.env.PRINT_TOKEN ?? "").toLowerCase() === "true";
const REQUEST_TIMEOUT_MS = 20_000;

interface AdminLoginResponse {
  tokens?: { accessToken?: string; refreshToken?: string };
  admin?: { id?: string; fullName?: string; email?: string; role?: string };
  message?: string;
}

async function main() {
  const email = process.env.ADMIN_EMAIL?.trim() || "admin@gmail.com";
  const password = process.env.ADMIN_PASSWORD || "Admin123$";

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}/api/admin/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      signal: controller.signal,
    });
  } catch (err) {
    const reason = err instanceof Error ? err.message : String(err);
    console.error(`Could not reach ${API_BASE_URL}: ${reason}`);
    process.exit(1);
  } finally {
    clearTimeout(timer);
  }

  const body = (await res.json().catch(() => ({}))) as AdminLoginResponse;

  if (!res.ok) {
    console.error(
      `Admin login failed (HTTP ${res.status}): ${body.message ?? "invalid credentials"}`,
    );
    process.exit(1);
  }

  const accessToken = body.tokens?.accessToken;
  const refreshToken = body.tokens?.refreshToken;
  if (!accessToken) {
    console.error("Admin login succeeded but no access token was returned.");
    process.exit(1);
  }

  writeFileSync(
    SESSION_FILE,
    JSON.stringify(
      { accessToken, refreshToken: refreshToken ?? null, admin: body.admin ?? null },
      null,
      2,
    ),
  );
  chmodSync(SESSION_FILE, 0o600);

  console.log(`Admin login successful: ${body.admin?.email ?? email}`);
  if (body.admin?.role) console.log(`Role: ${body.admin.role}`);
  console.log(`Session saved to ${SESSION_FILE} (permissions 600).`);
  if (PRINT_TOKEN) console.log(accessToken);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});