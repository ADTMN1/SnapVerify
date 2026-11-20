/**
 * Check.et provider error classification.
 *
 * Source: https://docs.check.et (API Overview + Error Handling guide).
 * Semantics per official documentation:
 *   401 — missing/invalid/revoked API key          → AUTH_ERROR
 *   402 — monthly verification quota exceeded      → QUOTA_EXHAUSTED (billing action required; never fixed by retrying)
 *   400 — unsupported bank / malformed input       → VALIDATION_ERROR (negative)
 *   404 — transaction not found ONLY when the body matches the documented
 *         VerifyResponse envelope (success:false, exists:false); a bare 404
 *         is an infrastructure failure
 *   422 — field-level validation error             → VALIDATION_ERROR (negative)
 *   429 — rate limited (respect Retry-After)       → RATE_LIMITED (retryable)
 *   5xx — provider server error                    → SERVER_ERROR (retryable with back-off)
 * Transport failures / timeouts                  → NETWORK_ERROR (retryable)
 *
 * The classification intentionally REUSES the ProviderErrorType enum from the
 * legacy Veritas integration so the fail-closed handling in PaymentService
 * stays uniform. The retryable set DIFFERS: for Check.et, 402 (quota) and
 * auth errors are billing/configuration issues, never transient, so they are
 * NOT retryable.
 */
import { ProviderError, ProviderErrorType } from '../provider-error';

const RETRYABLE_CHECK_ET_ERRORS: ReadonlySet<ProviderErrorType> = new Set([
  ProviderErrorType.NETWORK_ERROR,
  ProviderErrorType.SERVER_ERROR,
  ProviderErrorType.RATE_LIMITED,
]);

/**
 * Check.et distinguishes two 402 flavors by message:
 *  - "Monthly verification limit reached. Please upgrade your plan." (quota)
 *  - plan/permission gating on other endpoints.
 * Both are billing issues; neither is fixed by retrying.
 */
export function isCheckEtQuotaMessage(msg: string): boolean {
  const lower = msg.toLowerCase();
  return (
    lower.includes('quota') ||
    lower.includes('limit reached') ||
    lower.includes('upgrade your plan') ||
    lower.includes('payment required')
  );
}

export class CheckEtError extends ProviderError {
  constructor(
    type: ProviderErrorType,
    httpStatus: number | null,
    message: string,
  ) {
    super(type, httpStatus, message);
    this.name = 'CheckEtError';
  }

  /** Check.et-specific retryability (quota/auth are NOT retryable). */
  override get isRetryable(): boolean {
    return RETRYABLE_CHECK_ET_ERRORS.has(this.type);
  }
}

/** Shape of a Check.et error body: { message, errors? } */
export interface CheckEtErrorBody {
  message?: string | null;
  errors?: Record<string, string[]>;
}

/**
 * Flatten a Check.et error body into a single human-readable string.
 * Validation errors carry a per-field breakdown that is more actionable
 * than the generic "The given data was invalid." message.
 */
export function checkEtErrorBodyMessage(
  body: CheckEtErrorBody | null,
  httpStatus: number,
): string {
  const message = body?.message?.trim();
  if (body?.errors && Object.keys(body.errors).length > 0) {
    const fieldErrors = Object.entries(body.errors)
      .map(([field, errs]) => `${field}: ${errs.join('; ')}`)
      .join(' | ');
    return message && message !== 'The given data was invalid.'
      ? `${message} (${fieldErrors})`
      : fieldErrors;
  }
  return message || `HTTP ${httpStatus}`;
}

/**
 * Classify an HTTP-4xx/5xx response from Check.et. Returns null for
 * business-level VerifyResponse envelopes (the caller processes those as
 * verification results — including 404 "Transaction not found." bodies,
 * which are authoritative NEGATIVE answers per the docs).
 */
export function classifyCheckEtResponse(
  body: unknown,
  httpStatus: number,
): CheckEtError | null {
  // Non-error status: the caller processes the body as a verification result.
  if (httpStatus < 400) return null;

  // 404 always carries a VerifyResponse envelope (success:false,
  // exists:false) — an authoritative negative answer, not an error.
  if (
    httpStatus === 404 &&
    body !== null &&
    typeof body === 'object' &&
    'success' in (body as Record<string, unknown>)
  ) {
    return null;
  }

  // A 404 that does NOT carry the VerifyResponse envelope is NOT an
  // authoritative "transaction not found" answer — it most likely means a
  // missing/moved endpoint. Treat it as provider infrastructure failure
  // (retryable, fail closed) rather than a negative verification.
  if (httpStatus === 404) {
    return new CheckEtError(
      ProviderErrorType.SERVER_ERROR,
      httpStatus,
      `Unexpected bare 404 from check.et (no verification envelope)`,
    );
  }

  const message = checkEtErrorBodyMessage(
    body as CheckEtErrorBody | null,
    httpStatus,
  );

  switch (httpStatus) {
    case 401:
    case 403:
      return new CheckEtError(
        ProviderErrorType.AUTH_ERROR,
        httpStatus,
        message,
      );
    case 402:
      return new CheckEtError(
        ProviderErrorType.QUOTA_EXHAUSTED,
        httpStatus,
        message,
      );
    case 400:
    case 422:
      return new CheckEtError(
        ProviderErrorType.VALIDATION_ERROR,
        httpStatus,
        message,
      );
    case 429:
      return new CheckEtError(
        ProviderErrorType.RATE_LIMITED,
        httpStatus,
        message,
      );
    default:
      if (httpStatus >= 500) {
        return new CheckEtError(
          ProviderErrorType.SERVER_ERROR,
          httpStatus,
          message,
        );
      }
      return new CheckEtError(ProviderErrorType.UNKNOWN, httpStatus, message);
  }
}

/**
 * Classify transport failures (fetch threw or the request was aborted).
 * Timeouts (AbortError / abort) and connection failures (FetchError, ECONN*)
 * are BOTH temporary upstream failures — neither is ever a business answer —
 * but their messages are distinguishable for diagnostics.
 */
export function classifyCheckEtNetworkFailure(
  err: unknown,
  timeoutMs?: number,
  attempt?: number,
): CheckEtError {
  const e = err as { name?: string; type?: string } | null;
  const isTimeout = e?.name === 'AbortError' || e?.type === 'abort';
  const timeoutDetail =
    isTimeout && typeof timeoutMs === 'number' ? ` after ${timeoutMs}ms` : '';
  const attemptDetail =
    isTimeout && typeof attempt === 'number' ? ` (attempt ${attempt})` : '';
  const message = isTimeout
    ? `check.et request timed out${timeoutDetail}${attemptDetail}`
    : `Network error: ${err instanceof Error ? err.message : String(err)}`;
  return new CheckEtError(ProviderErrorType.NETWORK_ERROR, null, message);
}
