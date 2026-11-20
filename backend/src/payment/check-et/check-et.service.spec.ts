import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';
import {
  CheckEtService,
  checkEtBackoffDelayMs,
  resolveCheckEtTimeoutMs,
} from './check-et.service';
import { CheckEtError } from './check-et-error';
import { ProviderErrorType } from '../provider-error';

// The service does: require('node-fetch') as <default fn>. Jest intercepts
// the module registry, so the require call receives this jest.fn itself.
jest.mock('node-fetch');
const mockFetch = jest.requireMock('node-fetch');

const baseVerifyBody = {
  success: true,
  exists: true,
  duplicate: false,
  message: null,
  data: {
    bank: 'cbe',
    bank_name: 'Commercial Bank of Ethiopia',
    verification_id: 'FT26144SG2ST',
    transaction_number: 'FT26144SG2ST',
    verification_method: 'official',
    receipt: {
      status: 'completed',
      amount: 1350,
      currency: 'ETB',
      transaction_date: '2026-01-01T10:00:00+03:00',
      payer_name: 'Payer',
      payer_account: '1000123456789',
      receiver_name: 'Receiver',
      receiver_account: '1000876543218',
    },
  },
};

const jsonResponse = (body: unknown, status = 200) => ({
  status,
  text: () => Promise.resolve(JSON.stringify(body)),
});

async function build(
  baseUrl?: string,
  overrides: Record<string, unknown> = {},
) {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      CheckEtService,
      {
        provide: ConfigService,
        useValue: {
          get: (key: string, defaultValue?: unknown) => {
            if (key in overrides) return overrides[key];
            if (key === 'CHECK_ET_API_KEY')
              return 'chk_test_key_for_unit_tests';
            if (key === 'CHECK_ET_BASE_URL')
              return baseUrl ?? 'https://api.check.et';
            return defaultValue;
          },
        },
      },
    ],
  }).compile();
  return module.get<CheckEtService>(CheckEtService);
}

const advance = async (ms: number) => {
  await Promise.resolve();
  await jest.advanceTimersByTimeAsync(ms);
};

beforeEach(() => {
  mockFetch.mockReset();
});

describe('CheckEtService timeout/retry configuration', () => {
  it('uses a safe 45s default timeout', () => {
    expect(resolveCheckEtTimeoutMs(undefined)).toBe(45000);
    expect(resolveCheckEtTimeoutMs('')).toBe(45000);
  });

  it('clamps timeout to sensible bounds', () => {
    expect(resolveCheckEtTimeoutMs(100)).toBe(5000);
    expect(resolveCheckEtTimeoutMs(5000)).toBe(5000);
    expect(resolveCheckEtTimeoutMs(45000)).toBe(45000);
    expect(resolveCheckEtTimeoutMs(200000)).toBe(120000);
    expect(resolveCheckEtTimeoutMs('not-a-number')).toBe(45000);
  });

  it('computes bounded exponential backoff with jitter', () => {
    expect(checkEtBackoffDelayMs(1, () => 0)).toBe(500);
    expect(checkEtBackoffDelayMs(1, () => 1)).toBe(1000);
    expect(checkEtBackoffDelayMs(2, () => 0)).toBe(1000);
    expect(checkEtBackoffDelayMs(2, () => 1)).toBe(2000);
    expect(checkEtBackoffDelayMs(3, () => 0)).toBe(2000);
    expect(checkEtBackoffDelayMs(5, () => 1)).toBe(8000);
  });
});

describe('CheckEtService configuration', () => {
  it('warns clearly (without revealing any value) when the API key is missing', async () => {
    const warnSpy = jest.spyOn(Logger.prototype, 'warn');
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CheckEtService,
        {
          provide: ConfigService,
          useValue: {
            get: (key: string, defaultValue?: unknown) =>
              key === 'CHECK_ET_API_KEY' ? '' : defaultValue,
          },
        },
      ],
    }).compile();
    module.get<CheckEtService>(CheckEtService);
    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringContaining('CHECK_ET_API_KEY is empty'),
    );
    for (const call of warnSpy.mock.calls) {
      expect(String(call[0])).not.toContain('chk_');
    }
  });
});

describe('CheckEtService HTTP layer (mocked transport — no real API calls)', () => {
  it('sends JSON verification requests with Bearer auth to the documented endpoint', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));

    await svc.verifyReference(
      PaymentProvider.CBE,
      'FT26144SG2ST',
      '1000876543218',
    );

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [url, init] = mockFetch.mock.calls[0];
    expect(url).toBe('https://api.check.et/api/v1/verify');
    expect(init.method).toBe('POST');
    expect(init.headers['Content-Type']).toBe('application/json');
    expect(init.headers.Authorization).toMatch(
      /^Bearer chk_test_key_for_unit_tests$/,
    );
    expect(JSON.parse(init.body)).toEqual({
      bank: 'cbe',
      transaction_number: 'FT26144SG2ST',
      account_number: '1000876543218',
    });
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('sends multipart requests with Bearer auth (file + OCR text fields)', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));
    const jpeg = Buffer.concat([
      Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
      Buffer.alloc(16, 0x11),
    ]);

    await svc.verifyReceiptFile({
      file: jpeg,
      filename: 'capture.jpg',
      contentType: 'image/jpeg',
      receiptText: 'CBE FT26144SG2ST',
    });

    const [url, init] = mockFetch.mock.calls[0];
    expect(url).toBe('https://api.check.et/api/v1/verify');
    expect(init.headers.Authorization).toMatch(
      /^Bearer chk_test_key_for_unit_tests$/,
    );
    // form-data generates the multipart boundary header itself
    expect(String(init.headers['content-type'])).toMatch(
      /^multipart\/form-data; boundary=/,
    );
    expect(init.body.getBuffer().toString('latin1')).toContain(
      'name="receipt_file"',
    );
    expect(init.body.getBuffer().toString('latin1')).toContain(
      'name="receipt_text"',
    );
    expect(init.signal).toBeInstanceOf(AbortSignal);
  });

  it('retries retryable timeout/network failures up to 3 attempts with bounded backoff, then fails closed', async () => {
    jest.useFakeTimers();
    const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);
    try {
      const svc = await build(undefined, { CHECK_ET_TIMEOUT_MS: 5000 });
      mockFetch.mockImplementation(
        (_url: string, init: any) =>
          new Promise((_resolve, reject) => {
            init.signal.addEventListener('abort', () => {
              const err: any = new Error('The operation was aborted');
              err.name = 'AbortError';
              reject(err);
            });
          }),
      );

      const pending = svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
      const assertion = expect(pending).rejects.toMatchObject({
        type: ProviderErrorType.NETWORK_ERROR,
        isRetryable: true,
        message: expect.stringContaining(
          'check.et request timed out after 5000ms',
        ),
      });

      // attempt 1 timeout + 500ms backoff + attempt 2 timeout + 1000ms backoff + attempt 3 timeout
      await advance(5000);
      expect(mockFetch).toHaveBeenCalledTimes(1);
      await advance(500);
      await advance(5000);
      expect(mockFetch).toHaveBeenCalledTimes(2);
      await advance(1000);
      await advance(5000);
      await assertion;
      expect(mockFetch).toHaveBeenCalledTimes(3);
      expect(jest.getTimerCount()).toBe(0);
    } finally {
      randomSpy.mockRestore();
      jest.useRealTimers();
    }
  });

  it('retries retryable 5xx responses with backoff and returns on a later success', async () => {
    jest.useFakeTimers();
    const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);
    try {
      const svc = await build(undefined, { CHECK_ET_TIMEOUT_MS: 5000 });
      mockFetch
        .mockResolvedValueOnce(jsonResponse({ message: 'boom' }, 503))
        .mockResolvedValueOnce(jsonResponse({ message: 'boom' }, 503))
        .mockResolvedValueOnce(jsonResponse(baseVerifyBody, 200));

      const pending = svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
      await advance(0);
      expect(mockFetch).toHaveBeenCalledTimes(1);
      await advance(500);
      expect(mockFetch).toHaveBeenCalledTimes(2);
      await advance(1000);
      const result = await pending;
      expect(result.success).toBe(true);
      expect(mockFetch).toHaveBeenCalledTimes(3);
    } finally {
      randomSpy.mockRestore();
      jest.useRealTimers();
    }
  });

  it('retries retryable 429 responses with backoff', async () => {
    jest.useFakeTimers();
    const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);
    try {
      const svc = await build(undefined, { CHECK_ET_TIMEOUT_MS: 5000 });
      mockFetch
        .mockResolvedValueOnce(jsonResponse({ message: 'Too many requests' }, 429))
        .mockResolvedValueOnce(jsonResponse(baseVerifyBody, 200));

      const pending = svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
      await advance(0);
      await advance(500);
      const result = await pending;
      expect(result.success).toBe(true);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    } finally {
      randomSpy.mockRestore();
      jest.useRealTimers();
    }
  });

  it('classifies connection failures as NETWORK_ERROR (not timeouts, not negative answers)', async () => {
    const svc = await build();
    mockFetch.mockImplementation(() => {
      const err: any = new Error('connect ECONNREFUSED 127.0.0.1:443');
      err.name = 'FetchError';
      err.type = 'system';
      return Promise.reject(err);
    });

    await expect(
      svc.verifyReference(PaymentProvider.CBE, 'FT123', null),
    ).rejects.toMatchObject({
      type: ProviderErrorType.NETWORK_ERROR,
      message: expect.stringContaining('ECONNREFUSED'),
    });
  });

  it('treats HTTP 409 as an authoritative branch duplicate answer (duplicate: true, not an error)', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue({
      status: 409,
      text: async () =>
        JSON.stringify({ success: false, message: 'This payment was already verified.' }),
    });

    const result = await svc.verifyReference(PaymentProvider.TELEBIRR, 'DJV9JIVHMR', null);

    expect(result.success).toBe(false);
    expect(result.duplicate).toBe(true);
    expect(result.message).toMatch(/already verified/i);
    // Exactly ONE upstream attempt — 409 must never be retried.
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('clears the timeout timer after a successful request', async () => {
    jest.useFakeTimers();
    try {
      const svc = await build();
      mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));

      await svc.verifyReference(PaymentProvider.CBE, 'FT123', null);

      expect(jest.getTimerCount()).toBe(0);
    } finally {
      jest.useRealTimers();
    }
  });

  it('fails closed on invalid JSON responses without logging the body', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue({
      status: 200,
      text: async () =>
        '<html>504 Gateway Time-out… payer Hayat Ahmed FT26144SG2ST</html>',
    });
    const warnSpy = jest.spyOn((svc as any).logger, 'warn');

    await expect(
      svc.verifyReference(PaymentProvider.CBE, 'FT123', null),
    ).rejects.toMatchObject({
      type: ProviderErrorType.SERVER_ERROR,
      httpStatus: 200,
    });

    expect(warnSpy).toHaveBeenCalledWith(
      expect.stringMatching(
        /non-JSON response from check\.et \(HTTP 200, \d+ bytes\)/,
      ),
    );
    // The raw body (PII) must never reach the logs.
    for (const call of warnSpy.mock.calls) {
      expect(String(call[0])).not.toContain('Hayat');
      expect(String(call[0])).not.toContain('FT26144SG2ST');
    }
  });

  it('propagates provider error statuses as typed CheckEtErrors with correct retry behavior', async () => {
    jest.useFakeTimers();
    const randomSpy = jest.spyOn(Math, 'random').mockReturnValue(0);
    try {
      const svc = await build(undefined, { CHECK_ET_TIMEOUT_MS: 5000 });
      const cases: [number, unknown, ProviderErrorType, boolean, number][] = [
        [401, { message: 'Unauthenticated.' }, ProviderErrorType.AUTH_ERROR, false, 1],
        [
          402,
          { message: 'Monthly verification limit reached. Please upgrade your plan.' },
          ProviderErrorType.QUOTA_EXHAUSTED,
          false,
          1,
        ],
        [429, { message: 'Too many requests' }, ProviderErrorType.RATE_LIMITED, true, 3],
        [500, { message: 'boom' }, ProviderErrorType.SERVER_ERROR, true, 3],
        [422, { message: 'The given data was invalid.' }, ProviderErrorType.VALIDATION_ERROR, false, 1],
      ];
      for (const [status, body, type, retryable, expectedCalls] of cases) {
        mockFetch.mockReset();
        mockFetch.mockImplementation(async () => jsonResponse(body, status));
        const pending = svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
        const assertion = expect(pending).rejects.toMatchObject({
          type,
          isRetryable: retryable,
          httpStatus: status,
        });
        // Drain bounded backoff windows for retryable cases (3 attempts).
        await advance(0);
        await advance(500);
        await advance(1000);
        await assertion;
        expect(mockFetch).toHaveBeenCalledTimes(expectedCalls);
      }
    } finally {
      randomSpy.mockRestore();
      jest.useRealTimers();
    }
  });

  it('does not retry authoritative negative (404 envelope) responses', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(
      jsonResponse(
        {
          success: false,
          exists: false,
          duplicate: false,
          message: 'Transaction not found.',
          data: { bank: 'cbe', receipt: {} },
        },
        404,
      ),
    );

    const result = await svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
    expect(result.success).toBe(false);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  it('normalizes the provider response into the internal shape', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));

    const result = await svc.verifyReference(
      PaymentProvider.CBE,
      'FT26144SG2ST',
      null,
    );
    expect(result.success).toBe(true);
    expect(result.provider).toBe(PaymentProvider.CBE);
    expect(result.checkEtBank).toBe('cbe');
    expect(result.amount).toBe(1350);
    expect(result.currency).toBe('ETB');
    expect(result.receiverAccount).toBe('1000876543218');
    expect(result.transactionNumber).toBe('FT26144SG2ST');
    expect(result.raw).toEqual(baseVerifyBody);
  });
});

describe('CheckEtService request construction', () => {
  it('does not double-append /api/v1 when the base URL already includes it', async () => {
    const svc = await build('https://api.check.et/api/v1');
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));
    await svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
    expect(mockFetch.mock.calls[0][0]).toBe(
      'https://api.check.et/api/v1/verify',
    );
  });

  it('maps all SnapVerify banks and forwards account_number only where required', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));

    await svc.verifyReference(PaymentProvider.CBE, 'FT1', '1000876543218');
    expect(JSON.parse(mockFetch.mock.calls[0][1].body).account_number).toBe(
      '1000876543218',
    );
    expect(JSON.parse(mockFetch.mock.calls[0][1].body).bank).toBe('cbe');

    await svc.verifyReference(
      PaymentProvider.TELEBIRR,
      'DEL1',
      '1000876543218',
    );
    let body = JSON.parse(mockFetch.mock.calls[1][1].body);
    expect(body.bank).toBe('telebirr');
    expect(body.account_number).toBeUndefined(); // not required by the API

    await svc.verifyReference(PaymentProvider.ABYSSINIA, 'BOA1', '1000290172');
    body = JSON.parse(mockFetch.mock.calls[2][1].body);
    expect(body.bank).toBe('boa');
    expect(body.account_number).toBe('1000290172'); // required by the API

    await svc.verifyReference(PaymentProvider.CBEBIRR, 'CGU1', '1000516323381');
    body = JSON.parse(mockFetch.mock.calls[3][1].body);
    expect(body.bank).toBe('cbebirr');
    expect(body.account_number).toBeUndefined(); // payer phone not stored — never forwarded

    await svc.verifyReference(PaymentProvider.DASHEN, 'DASH1', null);
    expect(JSON.parse(mockFetch.mock.calls[4][1].body).bank).toBe('dashen');

    await svc.verifyReference(PaymentProvider.M_PESA, 'MP1', null);
    expect(JSON.parse(mockFetch.mock.calls[5][1].body).bank).toBe('mpesa');
  });
});

describe('CheckEtService file upload security', () => {
  const okJpeg = Buffer.concat([
    Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
    Buffer.alloc(8),
  ]);
  const okPdf = Buffer.concat([Buffer.from('%PDF-1.4'), Buffer.alloc(8)]);

  it('rejects files larger than 10 MB before forwarding', async () => {
    const svc = await build();
    const big = Buffer.concat([okJpeg, Buffer.alloc(11 * 1024 * 1024)]);
    await expect(
      svc.verifyReceiptFile({
        file: big,
        filename: 'capture.jpg',
        contentType: 'image/jpeg',
        receiptText: 'text',
      }),
    ).rejects.toMatchObject({ message: expect.stringContaining('MB limit') });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('rejects empty files', async () => {
    const svc = await build();
    await expect(
      svc.verifyReceiptFile({
        file: Buffer.alloc(0),
        filename: 'capture.jpg',
        contentType: 'image/jpeg',
        receiptText: 'text',
      }),
    ).rejects.toMatchObject({ message: expect.stringContaining('empty') });
  });

  it('rejects image uploads without OCR text', async () => {
    const svc = await build();
    await expect(
      svc.verifyReceiptFile({
        file: okJpeg,
        filename: 'capture.jpg',
        contentType: 'image/jpeg',
      }),
    ).rejects.toMatchObject({
      message: expect.stringContaining('receipt_text'),
    });
    expect(mockFetch).not.toHaveBeenCalled();
  });

  it('accepts PDF uploads without OCR text', async () => {
    const svc = await build();
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));
    await svc.verifyReceiptFile({
      file: okPdf,
      filename: 'receipt.pdf',
      contentType: 'application/pdf',
    });
    expect(mockFetch).toHaveBeenCalledTimes(1);
    expect(
      mockFetch.mock.calls[0][1].body.getBuffer().toString('latin1'),
    ).not.toContain('name="receipt_text"');
  });

  it('rejects unsupported MIME types', async () => {
    const svc = await build();
    await expect(
      svc.verifyReceiptFile({
        file: okJpeg,
        filename: 'a.gif',
        contentType: 'image/gif',
        receiptText: 'text',
      }),
    ).rejects.toMatchObject({
      message: expect.stringContaining('Unsupported receipt file type'),
    });
  });

  it('rejects files whose content does not match the declared MIME type (magic bytes)', async () => {
    const svc = await build();
    // Declared JPEG but actually a GIF
    const gif = Buffer.concat([Buffer.from('GIF89a'), Buffer.alloc(8)]);
    await expect(
      svc.verifyReceiptFile({
        file: gif,
        filename: 'fake.jpg',
        contentType: 'image/jpeg',
        receiptText: 'text',
      }),
    ).rejects.toMatchObject({
      message: expect.stringContaining('does not match the declared'),
    });
    expect(mockFetch).not.toHaveBeenCalled();

    // Declared PDF but not %PDF
    await expect(
      svc.verifyReceiptFile({
        file: okJpeg,
        filename: 'fake.pdf',
        contentType: 'application/pdf',
      }),
    ).rejects.toMatchObject({
      message: expect.stringContaining('PDF signature'),
    });

    // WEBP with a valid RIFF/WEBP header is accepted
    const webp = Buffer.concat([
      Buffer.from('RIFF'),
      Buffer.alloc(4),
      Buffer.from('WEBP'),
      Buffer.alloc(4),
    ]);
    mockFetch.mockResolvedValue(jsonResponse(baseVerifyBody));
    await svc.verifyReceiptFile({
      file: webp,
      filename: 'r.webp',
      contentType: 'image/webp',
      receiptText: 'text',
    });
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });
});

describe('CheckEtService logging hygiene', () => {
  it('never logs raw responses, request bodies, or API keys', async () => {
    const svc = await build();
    const logSpy = jest.spyOn((svc as any).logger, 'log');
    const warnSpy = jest.spyOn((svc as any).logger, 'warn');

    // Business-negative answer (message is the only logged part)
    mockFetch.mockResolvedValue(
      jsonResponse(
        {
          ...baseVerifyBody,
          success: false,
          message: 'Transaction not found.',
          data: {
            ...baseVerifyBody.data,
            receipt: { ...baseVerifyBody.data.receipt },
          },
        },
        200,
      ),
    );
    await svc.verifyReference(PaymentProvider.CBE, 'FT123', '1000876543218');

    // Transport failure
    mockFetch.mockRejectedValue(
      Object.assign(new Error('connect ECONNREFUSED'), { name: 'FetchError' }),
    );
    await expect(
      svc.verifyReference(PaymentProvider.CBE, 'FT123', null),
    ).rejects.toBeInstanceOf(CheckEtError);

    const allLogs = [...logSpy.mock.calls, ...warnSpy.mock.calls].map((c) =>
      String(c[0]),
    );
    for (const line of allLogs) {
      expect(line).not.toContain('chk_test_key_for_unit_tests');
      expect(line).not.toContain('Bearer');
      expect(line).not.toContain('1000876543218');
      expect(line).not.toContain('1000123456789');
      expect(line).not.toContain('Payer');
      expect(line).not.toContain('Receiver');
      expect(line).not.toContain('FT123');
      expect(line).not.toContain('success');
    }
  });
});
