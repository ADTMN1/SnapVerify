import {
  CheckEtError,
  classifyCheckEtResponse,
  classifyCheckEtNetworkFailure,
  checkEtErrorBodyMessage,
  isCheckEtQuotaMessage,
} from './check-et-error';
import { ProviderErrorType } from '../provider-error';

describe('Check.et error classification (official API semantics)', () => {
  it('classifies 401/403 as AUTH_ERROR', () => {
    expect(
      classifyCheckEtResponse({ message: 'Unauthenticated.' }, 401)?.type,
    ).toBe(ProviderErrorType.AUTH_ERROR);
    expect(classifyCheckEtResponse({ message: 'Forbidden' }, 403)?.type).toBe(
      ProviderErrorType.AUTH_ERROR,
    );
  });

  it('classifies 402 as QUOTA_EXHAUSTED (billing, never transient)', () => {
    const e = classifyCheckEtResponse(
      {
        message:
          'Monthly verification limit reached. Please upgrade your plan.',
      },
      402,
    );
    expect(e?.type).toBe(ProviderErrorType.QUOTA_EXHAUSTED);
    expect(e?.isRetryable).toBe(false);
  });

  it('classifies 400/422 as VALIDATION_ERROR (negative, non-retryable)', () => {
    expect(
      classifyCheckEtResponse({ message: 'Unsupported bank: xyz' }, 400)?.type,
    ).toBe(ProviderErrorType.VALIDATION_ERROR);
    expect(
      classifyCheckEtResponse(
        {
          message: 'The given data was invalid.',
          errors: { bank: ['The bank field is required.'] },
        },
        422,
      )?.type,
    ).toBe(ProviderErrorType.VALIDATION_ERROR);
  });

  it('classifies 429 as RATE_LIMITED (retryable) and 5xx as SERVER_ERROR (retryable)', () => {
    const rate = classifyCheckEtResponse({ message: 'Too many requests' }, 429);
    expect(rate?.type).toBe(ProviderErrorType.RATE_LIMITED);
    expect(rate?.isRetryable).toBe(true);

    const server = classifyCheckEtResponse({ message: 'boom' }, 500);
    expect(server?.type).toBe(ProviderErrorType.SERVER_ERROR);
    expect(server?.isRetryable).toBe(true);
  });

  it('treats a 404 VerifyResponse envelope (success:false) as a business answer, not an error', () => {
    expect(
      classifyCheckEtResponse(
        {
          success: false,
          exists: false,
          duplicate: false,
          message: 'Transaction not found.',
        },
        404,
      ),
    ).toBeNull();
  });

  it('treats a BARE 404 (no envelope) as provider infrastructure failure, not a negative answer', () => {
    // A missing/moved endpoint must NEVER be interpreted as "transaction
    // does not exist" — it is retryable and fails closed.
    const e = classifyCheckEtResponse({ message: 'Not found' }, 404);
    expect(e?.type).toBe(ProviderErrorType.SERVER_ERROR);
    expect(e?.isRetryable).toBe(true);
  });

  it('classifies transport failures as NETWORK_ERROR (retryable)', () => {
    const net = classifyCheckEtNetworkFailure(new Error('ECONNRESET'));
    expect(net.type).toBe(ProviderErrorType.NETWORK_ERROR);
    expect(net.isRetryable).toBe(true);
  });

  it('includes timeout detail for aborted requests without changing classification', () => {
    const abortErr: any = new Error('aborted');
    abortErr.name = 'AbortError';
    const net = classifyCheckEtNetworkFailure(abortErr, 45000, 2);
    expect(net.type).toBe(ProviderErrorType.NETWORK_ERROR);
    expect(net.isRetryable).toBe(true);
    expect(net.message).toContain('timed out after 45000ms');
    expect(net.message).toContain('(attempt 2)');
  });

  it('returns null for non-error statuses', () => {
    expect(classifyCheckEtResponse({ success: true }, 200)).toBeNull();
  });

  it('flattens field-level validation errors into actionable text', () => {
    expect(
      checkEtErrorBodyMessage(
        {
          message: 'The given data was invalid.',
          errors: { bank: ['The bank field is required.'] },
        },
        422,
      ),
    ).toBe('bank: The bank field is required.');
  });

  it('detects quota/plan messages for accurate 402 handling', () => {
    expect(
      isCheckEtQuotaMessage(
        'Monthly verification limit reached. Please upgrade your plan.',
      ),
    ).toBe(true);
    expect(isCheckEtQuotaMessage('Some other error')).toBe(false);
  });

  it('keeps auth/quota out of the Check.et retryable set', () => {
    const auth = new CheckEtError(
      ProviderErrorType.AUTH_ERROR,
      401,
      'Unauthenticated.',
    );
    const quota = new CheckEtError(
      ProviderErrorType.QUOTA_EXHAUSTED,
      402,
      'Monthly verification limit reached.',
    );
    expect(auth.isRetryable).toBe(false);
    expect(quota.isRetryable).toBe(false);
  });
});
