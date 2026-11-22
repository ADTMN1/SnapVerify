import {
  ProviderError,
  ProviderErrorType,
  RETRYABLE_PROVIDER_ERRORS,
  classifyLeulEtResponse,
} from './provider-error';

describe('Leul.et provider error classification (Stage 1)', () => {
  it('treats 2xx as a non-error', () => {
    expect(classifyLeulEtResponse({ success: true }, 200)).toBeNull();
  });

  it('classifies upstream 5xx as SERVER_ERROR and retryable', () => {
    const e = classifyLeulEtResponse({ error: 'internal server error' }, 500);
    expect(e?.type).toBe(ProviderErrorType.SERVER_ERROR);
    expect(e?.isRetryable).toBe(true);
    expect(classifyLeulEtResponse({}, 502)?.type).toBe(
      ProviderErrorType.SERVER_ERROR,
    );
  });

  it('classifies 401/403 as AUTH_ERROR (configuration fault)', () => {
    expect(classifyLeulEtResponse({}, 401)?.type).toBe(
      ProviderErrorType.AUTH_ERROR,
    );
    expect(classifyLeulEtResponse({}, 403)?.type).toBe(
      ProviderErrorType.AUTH_ERROR,
    );
    expect(classifyLeulEtResponse({}, 401)?.isRetryable).toBe(true);
  });

  it('classifies 429 as RATE_LIMITED and 402 as QUOTA_EXHAUSTED', () => {
    expect(classifyLeulEtResponse({}, 429)?.type).toBe(
      ProviderErrorType.RATE_LIMITED,
    );
    expect(classifyLeulEtResponse({}, 402)?.type).toBe(
      ProviderErrorType.QUOTA_EXHAUSTED,
    );
  });

  it('classifies 404 as an authoritative TRANSACTION_NOT_FOUND (negative answer)', () => {
    const e = classifyLeulEtResponse({ error: 'Transaction not found' }, 404);
    expect(e?.type).toBe(ProviderErrorType.TRANSACTION_NOT_FOUND);
    expect(e?.isRetryable).toBe(false);
  });

  it('classifies 400/422 as VALIDATION_ERROR (negative answer)', () => {
    expect(classifyLeulEtResponse({}, 400)?.type).toBe(
      ProviderErrorType.VALIDATION_ERROR,
    );
    expect(classifyLeulEtResponse({}, 422)?.isRetryable).toBe(false);
  });

  it('detects Leul.et scraper infrastructure failures smuggled inside 4xx bodies', () => {
    // Observed Leul.et behavior: its headless-browser stack fails while the
    // HTTP layer answers 4xx. These are NOT negative answers.
    const e = classifyLeulEtResponse(
      { error: 'both direct and puppeteer failed' },
      400,
    );
    expect(e?.type).toBe(ProviderErrorType.SERVER_ERROR);
    expect(e?.isRetryable).toBe(true);
  });

  it('recognizes not-found phrasing on unknown 4xx statuses', () => {
    const e = classifyLeulEtResponse(
      { message: 'receipt not found for this reference' },
      409,
    );
    expect(e?.type).toBe(ProviderErrorType.TRANSACTION_NOT_FOUND);
    expect(e?.isRetryable).toBe(false);
  });

  it('treats unrecognized 4xx bodies as UNKNOWN (persisted, logged loudly)', () => {
    const e = classifyLeulEtResponse({ error: 'weird upstream state' }, 409);
    expect(e?.type).toBe(ProviderErrorType.UNKNOWN);
    expect(e?.isRetryable).toBe(false);
  });

  it('classifies network failures as NETWORK_ERROR and retryable', () => {
    const e = new ProviderError(
      ProviderErrorType.NETWORK_ERROR,
      null,
      'Network error: ECONNREFUSED',
    );
    expect(e.isRetryable).toBe(true);
  });

  it('marks every retryable class as one that must never persist a failed payment', () => {
    for (const type of [
      ProviderErrorType.NETWORK_ERROR,
      ProviderErrorType.SERVER_ERROR,
      ProviderErrorType.RATE_LIMITED,
      ProviderErrorType.QUOTA_EXHAUSTED,
      ProviderErrorType.AUTH_ERROR,
    ]) {
      expect(RETRYABLE_PROVIDER_ERRORS.has(type)).toBe(true);
    }
    for (const type of [
      ProviderErrorType.TRANSACTION_NOT_FOUND,
      ProviderErrorType.VALIDATION_ERROR,
      ProviderErrorType.UNKNOWN,
    ]) {
      expect(RETRYABLE_PROVIDER_ERRORS.has(type)).toBe(false);
    }
  });
});
