/**
 * Deterministic transaction-reference normalization (Stage 1 — duplicate
 * protection).
 *
 * SAFEST normalization (final review):
 *
 * Leul.et has NEVER officially documented that:
 *   - uppercase and lowercase references are identical, or
 *   - internal whitespace is insignificant.
 * Neither assumption has evidence, so NEITHER is applied. Any normalization
 * beyond trimming could merge two DISTINCT transactions onto the database
 * unique constraint, which would block a legitimate payment.
 *
 * Final rules — all provably safe:
 *   1. Trim leading and trailing whitespace ONLY.
 *   2. Preserve internal whitespace.
 *   3. Preserve letter case.
 *   4. The original transaction reference is stored unchanged in
 *      `transactionId`; the trimmed value is only the duplicate-detection
 *      key (`normalizedTransactionId`).
 *
 * Every other variant ("ft123" vs "FT123", "FT 123" vs "FT123", "AB-C" vs
 * "A-BC") is deliberately treated as DISTINCT until the provider confirms
 * otherwise. A provider-confirmed relaxation can be added later together
 * with a re-run of scripts/check-normalized-duplicates.ts.
 *
 * Empty results map to null so the unique constraint (which ignores NULLs
 * in PostgreSQL) never blocks unrelated rows.
 */
export function normalizeTransactionId(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const normalized = raw.trim();
  return normalized.length > 0 ? normalized : null;
}
