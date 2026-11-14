/**
 * Shared provider-abstraction error for failures that are NOT provider
 * answers — configuration errors inside SnapVerify's own integration layer
 * (unmapped banks, empty inputs). Treated the same as transport failures:
 * fail closed, never persist a payment verdict.
 */
export class UpstreamVerificationUnavailableError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UpstreamVerificationUnavailableError';
  }
}
