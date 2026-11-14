import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';
import { CheckEtService } from './check-et.service';
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

async function build(baseUrl?: string) {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      CheckEtService,
      {
        provide: ConfigService,
        useValue: {
          get: (key: string, defaultValue?: unknown) => {
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

beforeEach(() => {
  mockFetch.mockReset();
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

  it('actually cancels the request on timeout via the AbortController signal', async () => {
    jest.useFakeTimers();
    try {
      const svc = await build();
      // Simulate node-fetch honoring the signal: reject on abort.
      mockFetch.mockImplementation(
        (_url: string, init: any) =>
          new Promise((_resolve, reject) => {
            init.signal.addEventListener('abort', () => {
              const err: any = new Error('The operation was aborted');
              err.name = 'AbortError';
              reject(err);
            });
            // never resolves otherwise
          }),
      );

      const pending = svc.verifyReference(PaymentProvider.CBE, 'FT123', null);
      const assertion = expect(pending).rejects.toMatchObject({
        type: ProviderErrorType.NETWORK_ERROR,
        message: 'check.et request timed out',
      });

      await jest.advanceTimersByTimeAsync(30_000);
      await assertion;
      // No hanging work remains: all pending timers consumed.
      expect(jest.getTimerCount()).toBe(0);
    } finally {
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

  it('propagates provider error statuses as typed CheckEtErrors', async () => {
    const svc = await build();
    const cases: [number, unknown, ProviderErrorType, boolean][] = [
      [
        401,
        { message: 'Unauthenticated.' },
        ProviderErrorType.AUTH_ERROR,
        false,
      ],
      [
        402,
        {
          message:
            'Monthly verification limit reached. Please upgrade your plan.',
        },
        ProviderErrorType.QUOTA_EXHAUSTED,
        false,
      ],
      [
        429,
        { message: 'Too many requests' },
        ProviderErrorType.RATE_LIMITED,
        true,
      ],
      [500, { message: 'boom' }, ProviderErrorType.SERVER_ERROR, true],
      [
        422,
        { message: 'The given data was invalid.' },
        ProviderErrorType.VALIDATION_ERROR,
        false,
      ],
    ];
    for (const [status, body, type, retryable] of cases) {
      mockFetch.mockResolvedValue(jsonResponse(body, status));
      await expect(
        svc.verifyReference(PaymentProvider.CBE, 'FT123', null),
      ).rejects.toMatchObject({
        type,
        isRetryable: retryable,
        httpStatus: status,
      });
    }
  });

  it('returns a 404 envelope as an authoritative negative verification', async () => {
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

    const result = await svc.verifyReference(
      PaymentProvider.CBE,
      'FT123',
      null,
    );
    expect(result.success).toBe(false);
    expect(result.message).toBe('Transaction not found.');
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
