/**
 * Check.et verification provider service.
 *
 * Implements the official Check.et REST API (v1):
 *   Base URL: https://api.check.et/api/v1
 *   Endpoint: POST /verify (four mutually exclusive input methods)
 *   Auth:     Authorization: Bearer <CHECK_ET_API_KEY>
 *   Response: { success, exists, duplicate, message, data: { bank, receipt: {...} } }
 *
 * Documentation: https://docs.check.et/api-reference/verify.md
 * The credentials are server-side only and are never exposed to Flutter or
 * browser clients.
 */
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider } from '@prisma/client';
import * as FormData from 'form-data';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetch = require('node-fetch') as typeof import('node-fetch').default;
import {
  CheckEtError,
  classifyCheckEtNetworkFailure,
  classifyCheckEtResponse,
} from './check-et-error';
import { ProviderErrorType } from '../provider-error';
import { UpstreamVerificationUnavailableError } from '../payment-provider-errors';

// Official docs: most verifications complete in 1–3 seconds, but bank-backed
// lookups can stall. The timeout is configurable (CHECK_ET_TIMEOUT_MS) with a
// safe default of 45s and bounded to avoid hangs or excessively short budgets.
const CHECK_ET_TIMEOUT_DEFAULT_MS = 45_000;
const CHECK_ET_TIMEOUT_MIN_MS = 5_000;
const CHECK_ET_TIMEOUT_MAX_MS = 120_000;

// Retryable transport/upstream failures (network/timeout/5xx/429) get bounded
// exponential backoff with jitter: up to 3 attempts total.
const CHECK_ET_MAX_ATTEMPTS = 3;
const CHECK_ET_BACKOFF_BASE_MS = 1_000;
const CHECK_ET_BACKOFF_CAP_MS = 8_000;

export function resolveCheckEtTimeoutMs(raw: unknown): number {
  if (raw === undefined || raw === null || raw === '') {
    return CHECK_ET_TIMEOUT_DEFAULT_MS;
  }
  const n = typeof raw === 'number' ? raw : Number(String(raw));
  if (!Number.isFinite(n)) return CHECK_ET_TIMEOUT_DEFAULT_MS;
  return Math.min(
    CHECK_ET_TIMEOUT_MAX_MS,
    Math.max(CHECK_ET_TIMEOUT_MIN_MS, Math.trunc(n)),
  );
}

export function checkEtBackoffDelayMs(
  attempt: number,
  random: () => number = Math.random,
): number {
  // attempt is 1-based for the completed failed attempt; delay precedes the next try.
  const exp = Math.min(
    CHECK_ET_BACKOFF_CAP_MS,
    CHECK_ET_BACKOFF_BASE_MS * 2 ** Math.max(0, attempt - 1),
  );
  // Equal jitter in [exp/2, exp] to spread retries while staying bounded.
  return Math.max(0, Math.trunc(exp / 2 + random() * (exp / 2)));
}

/** Per official docs: PDF, JPG, JPEG, PNG, WEBP — max 10 MB. */
export const CHECK_ET_MAX_FILE_BYTES = 10 * 1024 * 1024;
export const CHECK_ET_SUPPORTED_IMAGE_MIMES = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
]);
export const CHECK_ET_SUPPORTED_PDF_MIMES = new Set(['application/pdf']);

/**
 * Validate that the file content matches the declared MIME type via its
 * magic bytes. MIME headers are client-supplied and untrustworthy; a
 * mismatch is rejected before anything is forwarded upstream.
 * Returns null when valid, or a safe rejection reason.
 */
export function _validateFileSignature(
  file: Buffer,
  contentType: string,
): string | null {
  const startsWith = (...bytes: number[]) =>
    bytes.every((b, i) => file[i] === b);

  if (CHECK_ET_SUPPORTED_PDF_MIMES.has(contentType)) {
    // %PDF
    if (!startsWith(0x25, 0x50, 0x44, 0x46)) {
      return 'File content does not match the declared type (PDF signature missing).';
    }
    return null;
  }

  if (CHECK_ET_SUPPORTED_IMAGE_MIMES.has(contentType)) {
    if (startsWith(0xff, 0xd8, 0xff)) return null; // JPEG
    if (startsWith(0x89, 0x50, 0x4e, 0x47)) return null; // PNG
    if (
      file.length >= 12 &&
      file.toString('ascii', 0, 4) === 'RIFF' &&
      file.toString('ascii', 8, 12) === 'WEBP'
    ) {
      return null; // WEBP
    }
    return 'File content does not match the declared image type.';
  }

  return `Unsupported receipt file type: ${contentType}.`;
}

/** Official bank codes from https://docs.check.et (List Banks). */
export type CheckEtBank =
  | 'cbe'
  | 'telebirr'
  | 'dashen'
  | 'awash'
  | 'boa'
  | 'zemen'
  | 'cbebirr'
  | 'mpesa'
  | 'sinqee'
  | 'amhara';

/**
 * Map SnapVerify's internal PaymentProvider enum (bank the merchant registered)
 * to the Check.et bank code.
 *
 * Per docs, CBE and BOA REQUIRE account_number (the receiving account);
 * CBE Birr needs the PAYER's phone, which SnapVerify never stores —
 * accountNumber is deliberately NOT forwarded for cbebirr.
 */
export const SNAP_TO_CHECK_ET_BANK: Record<PaymentProvider, CheckEtBank> = {
  CBE: 'cbe',
  TELEBIRR: 'telebirr',
  DASHEN: 'dashen',
  ABYSSINIA: 'boa',
  CBEBIRR: 'cbebirr',
  M_PESA: 'mpesa',
};

const CHECK_ET_TO_SNAP_BANK: Record<CheckEtBank, PaymentProvider | null> = {
  cbe: PaymentProvider.CBE,
  telebirr: PaymentProvider.TELEBIRR,
  dashen: PaymentProvider.DASHEN,
  awash: null, // not yet in SnapVerify's PaymentProvider enum
  boa: PaymentProvider.ABYSSINIA,
  zemen: null,
  cbebirr: PaymentProvider.CBEBIRR,
  mpesa: PaymentProvider.M_PESA,
  sinqee: null,
  amhara: null,
};

/** Banks whose verify calls REQUIRE the receiving account_number. */
const BANKS_REQUIRING_ACCOUNT_NUMBER: ReadonlySet<CheckEtBank> = new Set([
  'cbe',
  'boa',
]);

/** Raw (unmodified) Check.et VerifyResponse body. */
export interface CheckEtRawResponse {
  success: boolean;
  exists: boolean;
  duplicate: boolean;
  message?: string | null;
  data?: {
    bank?: string;
    bank_name?: string;
    verification_id?: string | null;
    transaction_number?: string | null;
    verification_method?: string;
    receipt?: {
      status?: string;
      amount?: number | string;
      currency?: string;
      transaction_date?: string;
      payer_name?: string;
      payer_account?: string;
      receiver_name?: string;
      receiver_account?: string;
      description?: string | null;
    } | null;
  } | null;
  existing_verification_id?: number;
  verified_at?: string;
}

/**
 * Normalized verification result consumed by PaymentService. Field names are
 * aligned with the raw-shape conventions already used by the receiving-account
 * matcher (_isPaymentToAccount) and the persistence layer (_saveAndReturn) so
 * downstream logic needs no Veritas-era knowledge.
 */
export interface NormalizedVerification {
  success: boolean;
  /** Check.et's own per-branch duplicate flag. */
  duplicate: boolean;
  /** Business-level failure message from the provider, if any. */
  message: string | null;
  /** SnapVerify PaymentProvider enum key (e.g. CBE, ABYSSINIA) or null. */
  provider: PaymentProvider | null;
  /** Raw Check.et bank code, always present on data-bearing responses. */
  checkEtBank: CheckEtBank | null;
  /** Bank-reported transaction reference (data.transaction_number). */
  transactionNumber: string | null;
  verificationId: string | null;
  /** Bank-verified amount (data.receipt.amount). Null unless reported. */
  amount: string | number | null;
  /** Bank-verified currency (data.receipt.currency). Null unless reported. */
  currency: string | null;
  transactionDate: string | null;
  payer: string | null;
  payerAccount: string | null;
  receiver: string | null;
  receiverAccount: string | null;
  verificationMethod: string | null;
  /** Complete, unmodified provider response for audit (rawData persistence). */
  raw: CheckEtRawResponse;
}

@Injectable()
export class CheckEtService {
  private readonly logger = new Logger(CheckEtService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(config: ConfigService) {
    this.apiKey = config.get<string>('CHECK_ET_API_KEY', '');
    this.baseUrl = (
      config.get<string>('CHECK_ET_BASE_URL', 'https://api.check.et') ?? ''
    ).replace(/\/+$/, '');
    this.timeoutMs = resolveCheckEtTimeoutMs(
      config.get<string | number>('CHECK_ET_TIMEOUT_MS'),
    );
    if (!this.apiKey) {
      this.logger.warn(
        'CHECK_ET_API_KEY is empty — payment verification calls will fail until the key is configured.',
      );
    }
    this.logger.log(
      `=== CheckEtService ready === apiBase: ${this._apiBase()} timeoutMs=${this.timeoutMs} maxAttempts=${CHECK_ET_MAX_ATTEMPTS}`,
    );
  }

  /**
   * The documented server root is https://api.check.et/api/v1. Accept both
   * `https://api.check.et` and `.../api/v1` as configured base URLs and
   * always verify against the correct versioned path.
   */
  private _apiBase(): string {
    return /\/api\/v\d+$/.test(this.baseUrl)
      ? this.baseUrl
      : `${this.baseUrl}/api/v1`;
  }

  /**
   * Verify by bank + transaction number (the direct method).
   * @param bank SnapVerify bank enum; mapped to the Check.et bank code.
   * @param transactionNumber receipt reference (FT... / DEL... etc.)
   * @param accountNumber receiving account — forwarded ONLY for banks that
   *   the Check.et API requires it for (CBE, BOA).
   */
  async verifyReference(
    bank: PaymentProvider,
    transactionNumber: string,
    accountNumber?: string | null,
  ): Promise<NormalizedVerification> {
    const checkBank = SNAP_TO_CHECK_ET_BANK[bank];
    if (!checkBank) {
      throw new UpstreamVerificationUnavailableError(
        `Bank ${bank} is not mapped to a Check.et bank code`,
      );
    }

    const body: Record<string, unknown> = {
      bank: checkBank,
      transaction_number: transactionNumber,
    };
    if (accountNumber && BANKS_REQUIRING_ACCOUNT_NUMBER.has(checkBank)) {
      body.account_number = accountNumber;
    }

    // Sanitized diagnostics: bank code + reference style/length only.
    this.logger.log(
      `[CheckEt] verifyReference bank=${checkBank} refStyle=${(transactionNumber ?? '').slice(0, 2)} refLen=${(transactionNumber ?? '').length} accountNumberSent=${!!body.account_number}`,
    );

    return this._postJson('/verify', body);
  }

  /** Verify by receipt share-URL (bank + reference auto-extracted). */
  async verifyReceiptUrl(receiptUrl: string): Promise<NormalizedVerification> {
    return this._postJson('/verify', { receipt_url: receiptUrl });
  }

  /** Verify by OCR'd or pasted receipt text. */
  async verifyReceiptText(
    receiptText: string,
    bankHint?: CheckEtBank,
  ): Promise<NormalizedVerification> {
    if (!receiptText || receiptText.trim().length === 0) {
      throw new UpstreamVerificationUnavailableError(
        'receipt_text must not be empty',
      );
    }
    const body: Record<string, unknown> = {
      receipt_text: receiptText.slice(0, 50_000),
    };
    if (bankHint) body.bank = bankHint;
    return this._postJson('/verify', body);
  }

  /**
   * Verify by receipt file (PDF) or image + OCR text.
   *
   * Per official docs:
   *  - PDF: parsed server-side; receipt_text NOT needed.
   *  - Images (JPG/PNG/WEBP): receipt_text with OCR'd content REQUIRED.
   * Max 10 MB.
   */
  async verifyReceiptFile(params: {
    file: Buffer;
    filename: string;
    contentType: string;
    /** Required for image files; ignored for PDFs. */
    receiptText?: string;
    bankHint?: CheckEtBank;
    accountNumber?: string;
  }): Promise<NormalizedVerification> {
    const isPdf = CHECK_ET_SUPPORTED_PDF_MIMES.has(params.contentType);
    const isImage = CHECK_ET_SUPPORTED_IMAGE_MIMES.has(params.contentType);
    if (!isPdf && !isImage) {
      throw new UpstreamVerificationUnavailableError(
        `Unsupported receipt file type: ${params.contentType}. Check.et accepts PDF, JPG, PNG, or WEBP.`,
      );
    }
    if (
      !isPdf &&
      (!params.receiptText || params.receiptText.trim().length === 0)
    ) {
      throw new UpstreamVerificationUnavailableError(
        'receipt_text is required for image receipts (PDF only exempt).',
      );
    }
    if (!params.file || params.file.length === 0) {
      throw new UpstreamVerificationUnavailableError('Receipt file is empty.');
    }
    // Defense in depth: enforce the documented 10 MB limit at the provider
    // boundary too, independent of the HTTP-layer Multer limit.
    if (params.file.length > CHECK_ET_MAX_FILE_BYTES) {
      throw new UpstreamVerificationUnavailableError(
        `Receipt file exceeds the ${CHECK_ET_MAX_FILE_BYTES / (1024 * 1024)} MB limit.`,
      );
    }
    // MIME types are client-supplied and untrustworthy: validate the actual
    // file signature before forwarding anything upstream.
    const signatureError = _validateFileSignature(
      params.file,
      params.contentType,
    );
    if (signatureError) {
      throw new UpstreamVerificationUnavailableError(signatureError);
    }

    const form = new ((FormData as any).default ?? FormData)();
    form.append('receipt_file', params.file, {
      filename: params.filename,
      contentType: params.contentType,
    });
    if (!isPdf && params.receiptText) {
      form.append('receipt_text', params.receiptText.slice(0, 50_000));
    }
    if (params.bankHint) form.append('bank', params.bankHint);
    if (params.accountNumber)
      form.append('account_number', params.accountNumber);

    return this._postForm('/verify', form);
  }

  /**
   * POST a JSON body to the Check.et verify endpoint and normalize the
   * response. Retryable/provider-infrastructure failures throw CheckEtError;
   * authoritative business answers (including success:false envelopes) are
   * returned as NormalizedVerification.
   */
  private async _postJson(
    path: string,
    body: Record<string, unknown>,
  ): Promise<NormalizedVerification> {
    return this._request((signal) =>
      fetch(`${this._apiBase()}${path}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify(body),
        signal,
      }),
    );
  }

  private async _postForm(
    path: string,
    form: FormData,
  ): Promise<NormalizedVerification> {
    return this._request((signal) =>
      fetch(`${this._apiBase()}${path}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          ...form.getHeaders(),
        },
        body: form,
        signal,
      }),
    );
  }

  /**
   * Execute a provider request under a hard, configurable deadline.
   *
   * The AbortController is created HERE per attempt, its signal is passed to
   * fetch, and the timer is always cleared in a finally block — so a timeout
   * genuinely cancels the underlying socket and no request can hang past the
   * deadline. Aborts are classified as NETWORK_ERROR (temporary upstream
   * failure) — they must NEVER be interpreted as a negative verification
   * answer.
   *
   * Retryable infrastructure failures (network/timeout, 5xx, 429) are retried
   * with bounded exponential backoff + jitter, up to CHECK_ET_MAX_ATTEMPTS.
   * Authoritative business answers and non-retryable errors (auth/quota/
   * validation) are never retried.
   *
   * Only the HTTP status and safe classifications are logged; response bodies,
   * request bodies, authorization headers, receipt text, and raw provider
   * data are never logged (payer names/accounts/references are PII).
   */
  private async _request(
    doFetch: (signal: AbortSignal) => Promise<any>,
  ): Promise<NormalizedVerification> {
    let lastError: CheckEtError | null = null;
    for (let attempt = 1; attempt <= CHECK_ET_MAX_ATTEMPTS; attempt++) {
      try {
        return await this._requestOnce(doFetch, attempt);
      } catch (e) {
        if (!(e instanceof CheckEtError) || !e.isRetryable) throw e;
        lastError = e;
        if (attempt < CHECK_ET_MAX_ATTEMPTS) {
          const delayMs = checkEtBackoffDelayMs(attempt);
          this.logger.warn(
            `[CheckEt] retryable failure attempt ${attempt}/${CHECK_ET_MAX_ATTEMPTS} (${e.type}, HTTP ${e.httpStatus}) — backing off ${delayMs}ms`,
          );
          await new Promise((r) => setTimeout(r, delayMs));
        }
      }
    }
    throw lastError!;
  }

  private async _requestOnce(
    doFetch: (signal: AbortSignal) => Promise<any>,
    attempt: number,
  ): Promise<NormalizedVerification> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    let rawText: string;
    let httpStatus: number;
    let res: any;

    try {
      res = await doFetch(controller.signal);
      httpStatus = res.status;
      rawText = await res.text();
    } catch (err: unknown) {
      const net = classifyCheckEtNetworkFailure(err, this.timeoutMs, attempt);
      this.logger.warn(
        `[CheckEt] transport failure attempt ${attempt}/${CHECK_ET_MAX_ATTEMPTS} (${net.type}): ${net.message}`,
      );
      throw net;
    } finally {
      clearTimeout(timer);
    }

    let json: unknown;
    try {
      json = JSON.parse(rawText);
    } catch {
      // Non-JSON response: infrastructure failure, never a business answer.
      // The body itself is NOT logged — it may contain customer PII.
      this.logger.warn(
        `[CheckEt] non-JSON response from check.et (HTTP ${httpStatus}, ${rawText.length} bytes)`,
      );
      throw new CheckEtError(
        ProviderErrorType.SERVER_ERROR,
        httpStatus,
        `Non-JSON response from check.et (HTTP ${httpStatus})`,
      );
    }

    const raw = json as CheckEtRawResponse;

    if (httpStatus === 409) {
      // Branch-scoped duplicate: the transaction was already verified through
      // this Check.et account. Authoritative business answer, NOT an error —
      // never retried, never fails closed.
      this.logger.log(
        `[CheckEt] duplicate (HTTP 409): ${raw?.message ?? 'already verified'}`,
      );
      return this._normalize(
        {
          ...raw,
          success: false,
          duplicate: true,
          message: raw?.message ?? 'This payment was already verified.',
        } as CheckEtRawResponse,
        httpStatus,
      );
    }

    if (httpStatus >= 400) {
      const classified = classifyCheckEtResponse(json, httpStatus);
      if (classified) {
        // Retryable/infra/config failures propagate as typed errors so the
        // caller fails closed — these must NEVER persist a payment verdict.
        throw classified;
      }
      // 404 with a VerifyResponse envelope: authoritative negative answer.
      return this._normalize(raw, httpStatus);
    }

    return this._normalize(raw, httpStatus);
  }

  /** Normalize a Check.et VerifyResponse into the internal shape. */
  private _normalize(
    raw: CheckEtRawResponse,
    httpStatus: number,
  ): NormalizedVerification {
    const receipt = raw?.data?.receipt ?? {};
    const bankCode = raw?.data?.bank as CheckEtBank | undefined;
    const normalizedAmount =
      receipt?.amount === undefined || receipt?.amount === null
        ? null
        : receipt.amount;
    const transactionNumber =
      raw?.data?.transaction_number ?? raw?.data?.verification_id ?? null;

    if (raw?.success !== true) {
      this.logger.log(
        `[CheckEt] business-level negative answer (HTTP ${httpStatus}): ${raw?.message ?? 'no message'}`,
      );
    }

    return {
      success: raw?.success === true,
      duplicate: raw?.duplicate === true,
      message: raw?.message ?? null,
      provider: (bankCode && CHECK_ET_TO_SNAP_BANK[bankCode]) || null,
      checkEtBank: bankCode ?? null,
      transactionNumber,
      verificationId: raw?.data?.verification_id ?? null,
      amount: normalizedAmount,
      currency: receipt?.currency ?? null,
      transactionDate: receipt?.transaction_date ?? null,
      payer: receipt?.payer_name ?? null,
      payerAccount: receipt?.payer_account ?? null,
      receiver: receipt?.receiver_name ?? null,
      receiverAccount: receipt?.receiver_account ?? null,
      verificationMethod: raw?.data?.verification_method ?? null,
      raw,
    };
  }
}
