/**
 * [LEGACY — RETIRED] Veritas (verify.leul.et) provider error classification.
 *
 * SnapVerify's active verification provider is now Check.et
 * (see ./check-et/). This module is retained because:
 *   1. It defines ProviderErrorType / ProviderError, reused verbatim by the
 *      Check.et classification so the fail-closed handling in PaymentService
 *      stays uniform.
 *   2. classifyLeulEtResponse is kept for historical reference / rollback
 *      only. NOTHING in the active verification path calls it anymore.
 *
 * Historical payment rows (verificationProvider IS NULL) were produced by
 * this integration and are never rewritten.
 *
 * IMPORTANT: this classification is written for the Leul.et / verify.leul.et
 * integration's OBSERVED semantics. It must never be reused verbatim for
 * another provider (e.g. Check.et) without re-deriving it from that
 * provider's own documentation.
 *
 * Severity classes:
 *   - RETRYABLE (infrastructure): the verification service itself could not
 *     produce an answer. These must NEVER persist a FAILED payment — the
 *     caller fails closed with PROVIDER_UNAVAILABLE so the user retries.
 *   - CONFIG: SnapVerify's own credentials/configuration are wrong. Same
 *     fail-closed treatment as RETRYABLE plus an operational alert.
 *   - NEGATIVE: the provider authoritatively answered "this transaction is
 *     not verifiable". Safe to persist as a failed verification.
 */
export enum ProviderErrorType {
  /** Upstream authoritatively reports the reference does not exist. */
  TRANSACTION_NOT_FOUND = 'TRANSACTION_NOT_FOUND',
  /** Request rejected as malformed by the upstream API. */
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  /** Missing/invalid API key or forbidden. */
  AUTH_ERROR = 'AUTH_ERROR',
  /** Upstream quota exhausted (billing/plan). */
  QUOTA_EXHAUSTED = 'QUOTA_EXHAUSTED',
  /** Upstream rate limiting. */
  RATE_LIMITED = 'RATE_LIMITED',
  /** Upstream internal/server-side failure (incl. its scraping infra). */
  SERVER_ERROR = 'SERVER_ERROR',
  /** Network failure, DNS, or timeout reaching the upstream API. */
  NETWORK_ERROR = 'NETWORK_ERROR',
  /** Anything unclassifiable. Treated as NEGATIVE but logged loudly. */
  UNKNOWN = 'UNKNOWN',
}

export const RETRYABLE_PROVIDER_ERRORS: ReadonlySet<ProviderErrorType> =
  new Set([
    ProviderErrorType.NETWORK_ERROR,
    ProviderErrorType.SERVER_ERROR,
    ProviderErrorType.RATE_LIMITED,
    ProviderErrorType.QUOTA_EXHAUSTED,
    ProviderErrorType.AUTH_ERROR,
  ]);

export class ProviderError extends Error {
  constructor(
    public readonly type: ProviderErrorType,
    public readonly httpStatus: number | null,
    message: string,
  ) {
    super(message);
    this.name = 'ProviderError';
  }

  get isRetryable(): boolean {
    return RETRYABLE_PROVIDER_ERRORS.has(this.type);
  }
}

/**
 * Keywords observed in Leul.et error bodies that indicate its own scraping
 * infrastructure failed (headless browser, network, caching). A 4xx response
 * carrying one of these is an infrastructure failure, NOT a negative answer.
 */
const LEUL_INFRASTRUCTURE_KEYWORDS = [
  'puppeteer',
  'could not find chrome',
  'chromium',
  'econnrefused',
  'enotfound',
  'eai_again',
  'etimedout',
  'network error',
  'both direct and puppeteer failed',
  'cache path',
  'internal server error',
  'service unavailable',
  'bad gateway',
];

/**
 * Keywords in Leul.et bodies that indicate an authoritative "transaction not
 * found" answer for the submitted reference.
 */
const LEUL_NOT_FOUND_KEYWORDS = [
  'not found',
  'no transaction',
  'transaction not',
  'receipt not',
  'does not exist',
  'invalid reference',
];

type LeulEtBody = Record<string, unknown>;

function leulMessageOf(json: LeulEtBody | null, httpStatus: number): string {
  const raw =
    (json?.error as string | undefined) ??
    (json?.message as string | undefined) ??
    (json?.reason as string | undefined) ??
    `HTTP ${httpStatus}`;
  return String(raw);
}

/**
 * Classify a Leul.et HTTP response body. Returns null when the response is
 * NOT an error (i.e. it should be processed as a verification result).
 */
export function classifyLeulEtResponse(
  json: LeulEtBody | null,
  httpStatus: number,
): ProviderError | null {
  if (httpStatus < 400) return null;

  const msg = leulMessageOf(json, httpStatus);
  const lower = msg.toLowerCase();

  if (httpStatus >= 500) {
    return new ProviderError(ProviderErrorType.SERVER_ERROR, httpStatus, msg);
  }

  if (LEUL_INFRASTRUCTURE_KEYWORDS.some((k) => lower.includes(k))) {
    // Scraper infrastructure failure smuggled inside a 4xx body
    return new ProviderError(ProviderErrorType.SERVER_ERROR, httpStatus, msg);
  }

  switch (httpStatus) {
    case 401:
    case 403:
      return new ProviderError(ProviderErrorType.AUTH_ERROR, httpStatus, msg);
    case 429:
      return new ProviderError(ProviderErrorType.RATE_LIMITED, httpStatus, msg);
    case 402:
      return new ProviderError(
        ProviderErrorType.QUOTA_EXHAUSTED,
        httpStatus,
        msg,
      );
    case 404:
      return new ProviderError(
        ProviderErrorType.TRANSACTION_NOT_FOUND,
        httpStatus,
        msg,
      );
    case 400:
    case 422:
      return new ProviderError(
        ProviderErrorType.VALIDATION_ERROR,
        httpStatus,
        msg,
      );
    default:
      // Unrecognized 4xx body without a known not-found signal.
      if (LEUL_NOT_FOUND_KEYWORDS.some((k) => lower.includes(k))) {
        return new ProviderError(
          ProviderErrorType.TRANSACTION_NOT_FOUND,
          httpStatus,
          msg,
        );
      }
      return new ProviderError(ProviderErrorType.UNKNOWN, httpStatus, msg);
  }
}

/** Classify network/transport failures (fetch threw or timed out). */
export function classifyLeulEtNetworkFailure(err: unknown): ProviderError {
  const message =
    err instanceof Error ? err.message : `network failure (${typeof err})`;
  return new ProviderError(
    ProviderErrorType.NETWORK_ERROR,
    null,
    `Network error: ${message}`,
  );
}
