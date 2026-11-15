/**
 * Stage 1 (data minimization): full receiving-account numbers are never
 * returned from the API. Responses carry a masked rendering that preserves
 * the tail digits needed for configuration.
 *
 * Shared by every service that returns payment-account data (accounts and
 * QR) so there is a single masking implementation.
 */
export function maskAccountNumberForResponse(
  accountNumber: string | null,
): string | null {
  if (!accountNumber) return null;
  const digits = accountNumber.replace(/\s/g, '');
  if (digits.length <= 4) return '****';
  return `****${digits.slice(-4)}`;
}

export function maskAccount<
  T extends { accountNumber?: string | null },
>(account: T): T {
  return {
    ...account,
    accountNumber: maskAccountNumberForResponse(account.accountNumber ?? null),
  };
}
