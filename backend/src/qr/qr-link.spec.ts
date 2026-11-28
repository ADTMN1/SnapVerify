import {
  QR_PATH_PREFIX,
  QR_VERSION,
  buildQrUrl,
  normalizeQrBaseUrl,
  parseQrPayload,
  resolveQrBaseUrl,
} from './qr-link';

const PUBLIC_ID = 'a1b2c3d4e5f60718293a4b5c';

describe('buildQrUrl', () => {
  it('builds a versioned https deep link and trims trailing slashes', () => {
    expect(buildQrUrl('https://qr.example.com/', PUBLIC_ID)).toBe(
      `https://qr.example.com${QR_PATH_PREFIX}${PUBLIC_ID}`,
    );
  });

  it('uses the v1 path prefix', () => {
    expect(QR_PATH_PREFIX).toBe('/qr/v1/');
    expect(QR_VERSION).toBe('v1');
  });
});

describe('parseQrPayload', () => {
  it('parses a valid v1 link', () => {
    expect(
      parseQrPayload(`https://api.example.com/qr/v1/${PUBLIC_ID}`),
    ).toEqual({
      version: 'v1',
      publicId: PUBLIC_ID,
    });
  });

  it('accepts http links (development) and normalises upper-case ids', () => {
    expect(
      parseQrPayload(
        `http://192.168.100.93:3000/qr/v1/${PUBLIC_ID.toUpperCase()}`,
      ),
    ).toEqual({ version: 'v1', publicId: PUBLIC_ID });
  });

  it('accepts a trailing slash but no extra path segments', () => {
    expect(
      parseQrPayload(`https://api.example.com/qr/v1/${PUBLIC_ID}/`),
    ).toEqual({ version: 'v1', publicId: PUBLIC_ID });

    expect(
      parseQrPayload(`https://api.example.com/qr/v1/${PUBLIC_ID}/extra`),
    ).toBeNull();
  });

  it.each([
    ['plain text', 'hello world'],
    ['empty', '   '],
    ['non-http scheme', `ftp://api.example.com/qr/v1/${PUBLIC_ID}`],
    ['javascript scheme', `javascript:alert(1)//qr/v1/${PUBLIC_ID}`],
    ['unknown version', `https://api.example.com/qr/v2/${PUBLIC_ID}`],
    ['wrong scope', `https://api.example.com/pay/v1/${PUBLIC_ID}`],
    ['query string', `https://api.example.com/qr/v1/${PUBLIC_ID}?a=1`],
    ['fragment', `https://api.example.com/qr/v1/${PUBLIC_ID}#x`],
    ['short id', 'https://api.example.com/qr/v1/abc'],
    ['non-hex id', 'https://api.example.com/qr/v1/zzzzzzzzzzzzzzzzzzzzzzzz'],
    [
      'embedded credentials',
      `https://user:pass@api.example.com/qr/v1/${PUBLIC_ID}`,
    ],
    ['missing id', 'https://api.example.com/qr/v1/'],
  ])('rejects %s', (_label, payload) => {
    expect(parseQrPayload(payload)).toBeNull();
  });

  it('rejects non-string input', () => {
    expect(parseQrPayload(undefined)).toBeNull();
    expect(parseQrPayload(42)).toBeNull();
  });
});

describe('normalizeQrBaseUrl', () => {
  it('accepts https and strips trailing slashes', () => {
    expect(normalizeQrBaseUrl('https://api.example.com///', 'production')).toBe(
      'https://api.example.com',
    );
  });

  it('rejects http in production', () => {
    expect(
      normalizeQrBaseUrl('http://api.example.com', 'production'),
    ).toBeNull();
  });

  it('allows http in development', () => {
    expect(normalizeQrBaseUrl('http://192.168.1.10:3000', 'development')).toBe(
      'http://192.168.1.10:3000',
    );
  });

  it('rejects malformed URLs, credentials and non-http schemes', () => {
    expect(normalizeQrBaseUrl('not-a-url')).toBeNull();
    expect(normalizeQrBaseUrl('ftp://api.example.com')).toBeNull();
    expect(normalizeQrBaseUrl('https://user:pass@api.example.com')).toBeNull();
    expect(normalizeQrBaseUrl('')).toBeNull();
    expect(normalizeQrBaseUrl(null)).toBeNull();
  });
});

describe('resolveQrBaseUrl', () => {
  const config = (value?: string) => ({
    get: jest.fn((key: string) =>
      key === 'QR_PUBLIC_BASE_URL' ? value : undefined,
    ),
  });

  it('prefers the configured public base URL', () => {
    expect(
      resolveQrBaseUrl(config('https://qr.mybusiness.com') as any, {
        protocol: 'http',
        headers: { host: 'internal:3000' },
      }),
    ).toBe('https://qr.mybusiness.com');
  });

  it('falls back to the request origin when nothing is configured', () => {
    expect(
      resolveQrBaseUrl(config(undefined) as any, {
        protocol: 'https',
        headers: { host: 'api.mybusiness.com' },
      }),
    ).toBe('https://api.mybusiness.com');
  });

  it('honours a single X-Forwarded-Proto hop', () => {
    expect(
      resolveQrBaseUrl(config(undefined) as any, {
        protocol: 'http',
        headers: {
          host: 'api.mybusiness.com',
          'x-forwarded-proto': 'https, http',
        },
      }),
    ).toBe('https://api.mybusiness.com');
  });

  it('returns null when no usable origin exists', () => {
    expect(resolveQrBaseUrl(config(undefined) as any)).toBeNull();
    expect(
      resolveQrBaseUrl(config(undefined) as any, {
        protocol: 'https',
        headers: {},
      }),
    ).toBeNull();
  });
});
