import { ConfigService } from '@nestjs/config';

/**
 * QR deep-link format
 * -------------------
 *   https://<public-host>/qr/v1/<publicId>
 *
 * The QR payload carries ONLY the opaque public identifier — never an account
 * number, holder name, amount or provider. The link is versioned in the path
 * ("v1") so a future payload change can be introduced without invalidating
 * printed codes; scanners reject payloads whose version they do not know.
 *
 * The public host is resolved from configuration instead of being hardcoded:
 *   1. QR_PUBLIC_BASE_URL (explicit, recommended for production/printed codes)
 *   2. the origin of the incoming request (the API host actually serving the
 *      client), honouring a single X-Forwarded-Proto hop when present
 * A literal placeholder domain is never used.
 */

export const QR_VERSION = 'v1';
export const QR_PATH_PREFIX = `/qr/${QR_VERSION}/`;

/** Minimal request shape needed to derive the public origin. */
export interface QrOriginRequest {
  protocol?: string;
  headers?: Record<string, unknown>;
  get?: (name: string) => string | undefined;
}

export interface ParsedQrPayload {
  version: string;
  publicId: string;
}

function stripTrailingSlashes(url: string): string {
  return url.replace(/\/+$/, '');
}

/**
 * Validate a base URL used to build QR links.
 *
 * Production requires HTTPS (a printed QR must never resolve over plain HTTP).
 * Development may use HTTP for LAN/emulator testing.
 */
export function normalizeQrBaseUrl(
  raw: string | null | undefined,
  nodeEnv: string = process.env.NODE_ENV ?? 'development',
): string | null {
  if (!raw) return null;
  const trimmed = stripTrailingSlashes(raw.trim());
  if (!trimmed) return null;

  let uri: URL;
  try {
    uri = new URL(trimmed);
  } catch {
    return null;
  }

  if (uri.protocol !== 'https:' && uri.protocol !== 'http:') return null;
  if (!uri.hostname) return null;
  if (uri.username || uri.password) return null; // no embedded credentials
  if (uri.search || uri.hash) return null;
  if (nodeEnv === 'production' && uri.protocol !== 'https:') return null;

  return `${uri.protocol}//${uri.host}`;
}

function requestOrigin(req?: QrOriginRequest): string | null {
  if (!req) return null;

  const forwardedProto = headerValue(req.headers ?? {}, 'x-forwarded-proto');
  const proto = forwardedProto
    ? forwardedProto.split(',')[0].trim()
    : (req.protocol ?? 'https');

  const forwardedHost = headerValue(req.headers ?? {}, 'x-forwarded-host');
  const host =
    (forwardedHost ? forwardedHost.split(',')[0].trim() : null) ??
    headerValue(req.headers ?? {}, 'host') ??
    (typeof req.get === 'function' ? req.get('host') : undefined);

  if (!host) return null;
  return `${proto}://${host}`;
}

function headerValue(
  headers: Record<string, unknown>,
  name: string,
): string | null {
  const raw = headers[name];
  if (typeof raw === 'string' && raw.length > 0) return raw;
  if (Array.isArray(raw) && typeof raw[0] === 'string') return raw[0];
  return null;
}

/**
 * Resolve the public base URL used in QR links.
 *
 * Returns null only when neither configuration nor the request supplies a
 * usable origin; callers then omit the URL rather than emit a fake one.
 */
export function resolveQrBaseUrl(
  config: Pick<ConfigService, 'get'>,
  req?: QrOriginRequest,
): string | null {
  const configured = normalizeQrBaseUrl(
    config.get<string>('QR_PUBLIC_BASE_URL'),
  );
  if (configured) return configured;

  return normalizeQrBaseUrl(requestOrigin(req));
}

/** Build the versioned deep link for a public identifier. */
export function buildQrUrl(baseUrl: string, publicId: string): string {
  const base = stripTrailingSlashes(baseUrl);
  return `${base}${QR_PATH_PREFIX}${publicId}`;
}

/**
 * Parse and validate a scanned QR payload.
 *
 * Strict by design: only an http(s) URL whose path is exactly
 * /qr/<known-version>/<valid public id> is accepted. Anything else (arbitrary
 * links, plain text, other versions, extra path segments, query strings,
 * embedded credentials) is rejected, so the scanner never forwards untrusted
 * input to the resolver.
 */
export function parseQrPayload(raw: unknown): ParsedQrPayload | null {
  if (typeof raw !== 'string') return null;
  const text = raw.trim();
  if (!text || text.length > 2048) return null;

  let uri: URL;
  try {
    uri = new URL(text);
  } catch {
    return null;
  }

  if (uri.protocol !== 'https:' && uri.protocol !== 'http:') return null;
  if (uri.username || uri.password) return null;
  if (uri.search || uri.hash) return null;

  const segments = uri.pathname.split('/').filter((s) => s.length > 0);
  if (segments.length !== 3) return null;

  const [scope, version, rawId] = segments;
  if (scope !== 'qr') return null;
  if (version !== QR_VERSION) return null;

  const publicId = rawId.toLowerCase();
  if (!/^[0-9a-f]{24}$/.test(publicId)) return null;

  return { version, publicId };
}
