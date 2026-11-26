import {
  Injectable,
  InternalServerErrorException,
  Logger,
  HttpException,
  HttpStatus,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import {
  Prisma,
  PaymentStatus,
  PaymentProvider,
  PaymentAccount,
} from '@prisma/client';
import { normalizeTransactionId } from './reference-normalizer';
import {
  computeAccountNumberHash,
  normalizeAccountNumber,
  parseAccountHashVersion,
} from './account-hash';
import { ProviderError, ProviderErrorType } from './provider-error';
import { UpstreamVerificationUnavailableError } from './payment-provider-errors';
import { usagePeriodStart } from '../subscription/subscription-usage';
import {
  CheckEtService,
  NormalizedVerification,
  CHECK_ET_SUPPORTED_PDF_MIMES,
  SNAP_TO_CHECK_ET_BANK,
  checkEtForwardsAccountNumber,
} from './check-et/check-et.service';

/**
 * Stage 1 review fix: identify the UNIQUE constraint that represents the
 * payment-reference duplicate protection. Prisma P2002 errors carry the
 * violated constraint in meta.target as either the index name
 * ("payments_organizationId_normalizedTransactionId_key") or the field list
 * (["organizationId","normalizedTransactionId"]).
 */
const PAYMENT_REFERENCE_INDEX_NAME =
  'payments_organizationId_normalizedTransactionId_key';
const PAYMENT_REFERENCE_FIELDS = ['organizationId', 'normalizedTransactionId'];

/**
 * Display-only label for an OCR receipt the provider returned without a
 * transaction reference. It contains a per-attempt timestamp and is therefore
 * NEVER a transaction identity: rows carrying it are FAILED, and approval with
 * such a reference is rejected as a defense-in-depth measure.
 */
const SYNTHETIC_REFERENCE_PATTERN = /^OCR-\d+$/;

const RECHECK_ACTION = 'RECHECKED';
const RECHECK_MISMATCH_ACTION = 'RECHECK_MISMATCH';
const RECHECK_FAILED_ACTION = 'RECHECK_FAILED';
const PROVIDER_DUPLICATE_ACTION = 'PROVIDER_DUPLICATE';

function isPaymentReferenceDuplicateError(err: any): boolean {
  const target = err?.meta?.target;
  if (!target) return false;
  if (Array.isArray(target)) {
    return (
      PAYMENT_REFERENCE_FIELDS.every((f) => target.includes(f)) &&
      target.length === PAYMENT_REFERENCE_FIELDS.length
    );
  }
  if (typeof target === 'string') {
    return target === PAYMENT_REFERENCE_INDEX_NAME;
  }
  return false;
}

/**
 * Stage 1 (provider error handling): extract an operational detail string
 * from any upstream failure for logging and the fail-closed 503 response.
 */
function upstreamErrorDetail(err: unknown): string {
  if (err instanceof ProviderError) {
    return `${err.type}: ${err.message}`;
  }
  if (err instanceof UpstreamVerificationUnavailableError) {
    return err.message;
  }
  return err instanceof Error ? err.message : String(err);
}

/**
 * Financial integrity constants (Stage 1).
 *
 * ETB is quoted with at most 2 decimal places; amounts with finer precision
 * are rejected rather than implicitly rounded, because rounding must never
 * turn an incorrect amount into a valid payment.
 */
const SUPPORTED_CURRENCY = 'ETB';
const MAX_DECIMAL_PLACES = 2;

/** Strict plain-decimal string, e.g. "100", "999.99". Rejects "1,000", "1e3", "+5", "-5". */
const DECIMAL_STRING_PATTERN = /^\d+(\.\d+)?$/;

type FinancialValidation =
  { ok: true; amount: Prisma.Decimal } | { ok: false; reason: string };

/**
 * Strictly parse and validate an upstream transaction amount.
 *
 * The parsed value is used for financial decisions; malformed input must
 * never be normalized into zero. Returns a Prisma.Decimal (exact decimal)
 * on success, or a rejection reason on failure.
 */
export function parseVerifiedAmount(value: unknown): FinancialValidation {
  if (value === undefined || value === null) {
    return { ok: false, reason: 'Transaction amount is missing' };
  }

  let candidate: unknown = value;
  if (typeof candidate === 'string') {
    const trimmed = candidate.trim();
    if (trimmed.length === 0) {
      return { ok: false, reason: 'Transaction amount is missing' };
    }
    if (!DECIMAL_STRING_PATTERN.test(trimmed)) {
      return { ok: false, reason: 'Transaction amount is not a valid number' };
    }
    candidate = trimmed;
  }

  if (typeof candidate !== 'number' && typeof candidate !== 'string') {
    return { ok: false, reason: 'Transaction amount is not a valid number' };
  }

  let amount: Prisma.Decimal;
  try {
    amount = new Prisma.Decimal(candidate);
  } catch {
    return { ok: false, reason: 'Transaction amount is not a valid number' };
  }

  if (!amount.isFinite()) {
    return { ok: false, reason: 'Transaction amount is not a finite number' };
  }

  if ((amount.decimalPlaces() ?? 0) > MAX_DECIMAL_PLACES) {
    return {
      ok: false,
      reason: `Transaction amount has more than ${MAX_DECIMAL_PLACES} decimal places`,
    };
  }

  if (!amount.greaterThan(0)) {
    return {
      ok: false,
      reason: 'Transaction amount must be greater than zero',
    };
  }

  return { ok: true, amount };
}

/**
 * Validate that the upstream transaction is denominated in ETB.
 *
 * SECURITY NOTE (upstream contract dependency): if the upstream response
 * omits the currency field we CANNOT confirm the transaction is in ETB and
 * we fail closed. Approving on the assumption that the provider "probably"
 * settles in ETB would let a foreign-currency transaction through. When the
 * upstream contract is formally confirmed to always return ETB transactions
 * without a currency field, this can be relaxed deliberately — with a test.
 */
export function validateVerifiedCurrency(
  rawCurrency: unknown,
): FinancialValidation {
  if (rawCurrency === undefined || rawCurrency === null) {
    return {
      ok: false,
      reason: `Transaction currency could not be confirmed as ${SUPPORTED_CURRENCY}`,
    };
  }
  const normalized = String(rawCurrency).trim().toUpperCase();
  if (normalized !== SUPPORTED_CURRENCY) {
    return {
      ok: false,
      reason: `Transaction currency ${normalized} is not supported (expected ${SUPPORTED_CURRENCY})`,
    };
  }
  return { ok: true, amount: new Prisma.Decimal(0) };
}

@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);
  /** Identity of the ACTIVE verification vendor, recorded on new rows. */
  private readonly verificationProvider = 'check_et';
  private readonly isProduction: boolean;
  private readonly accountHashSecret: string;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
    private checkEt: CheckEtService,
  ) {
    const nodeEnv = this.config.get<string>(
      'NODE_ENV',
      process.env.NODE_ENV ?? 'development',
    );
    this.isProduction = nodeEnv === 'production';

    // Stage 1 review fix: dedicated server-side secret for HMAC account
    // hashing. Required in production; missing secrets fail fast so that
    // full-number matching cannot silently degrade.
    const hashSecret = this.config.get<string>('ACCOUNT_HASH_SECRET', '');
    if (this.isProduction && (!hashSecret || hashSecret.length < 32)) {
      throw new Error(
        'FATAL: ACCOUNT_HASH_SECRET is missing or too short (>= 32 chars required). Generate one with: openssl rand -base64 48',
      );
    }
    if (!hashSecret || hashSecret.length < 32) {
      this.logger.warn(
        'ACCOUNT_HASH_SECRET missing or short — hashed full-number matching is DISABLED (dev only); legacy plaintext fallback applies.',
      );
    }
    this.accountHashSecret = hashSecret;

    this.logger.log(`=== PaymentService ready ===`);
    this.logger.log(`  verificationProvider: ${this.verificationProvider}`);
  }

  // Helper to get provider from raw response or reference type
  private _detectProvider(raw: any): PaymentProvider | null {
    const providerField = raw?.provider ?? raw?.paymentProvider;
    if (providerField) {
      const normalized = String(providerField).toUpperCase().replace('-', '_');
      if (Object.values(PaymentProvider).includes(normalized as any)) {
        return normalized as PaymentProvider;
      }
    }
    return null;
  }

  /**
   * Normalize an account number for comparison: strip whitespace, dashes and
   * underscores. Comparisons are structural only — they never widen the
   * match (e.g. no substring logic on full numbers).
   */
  private _normalizeAccountNumber(value: unknown): string | null {
    return normalizeAccountNumber(value);
  }

  /**
   * Stage 1 review fix: keyed HMAC-SHA-256 (versioned) instead of plain
   * SHA-256, so leaked database rows cannot be brute-forced offline into
   * account numbers. Legacy hashes without the hmac-v1 version marker are
   * ignored by matching until the backfill script rewrites them.
   */
  private _hashAccountNumber(normalized: string): string | null {
    try {
      return computeAccountNumberHash(normalized, this.accountHashSecret);
    } catch (e) {
      // Fail closed: without a usable secret, hash comparison must not
      // silently degrade — matching falls back to the explicit legacy path,
      // which is logged.
      this.logger.error(`[_hashAccountNumber] ${(e as Error).message}`);
      return null;
    }
  }

  /**
   * Stage 1 (receiving-account matching).
   *
   * Receiving-account data used here comes EXCLUSIVELY from the organization's
   * registered PaymentAccount rows and the upstream verification response.
   * No client-supplied account data participates in a match decision.
   *
   * Evidence tiers, strongest first:
   *   1. Full receiving-account number equality (hash compare when the
   *      accountNumberHash backfill exists; plaintext compare only as legacy
   *      fallback until backfill runs — logged).
   *   2. Exact suffix equality between the registered suffix and the
   *      upstream suffix field. A definitive mismatch is a hard "no".
   *   3. Masked upstream number (****1234): tail-digits must equal the
   *      registered suffix, or the registered suffix must end with them.
   *      This is a HEURISTIC and is logged as such — masked data alone can
   *      never be more than partial evidence.
   *   4. Receiver name EXACT equality (case/whitespace-insensitive). The
   *      previous substring check was removed: names are not unique enough
   *      for partial matching and shared words caused false approvals.
   *
   * If neither tier 1 nor tier 2 evidence exists in the stored account data,
   * the match can only be heuristic; callers must treat heuristic-only
   * matches cautiously (this is reported in the Stage 1 review notes).
   */
  private _isPaymentToAccount(raw: any, account: PaymentAccount): boolean {
    this.logger.log(
      `[_isPaymentToAccount] Checking account: provider=${account.provider}, suffix=${this._maskSensitive(account.suffix)}, accountNumber=${this._maskSensitive(account.accountNumber)}, accountHolderName=${account.accountHolderName}`,
    );

    if (!raw?.success) {
      this.logger.log(`[_isPaymentToAccount] Payment not successful`);
      return false;
    }

    // Upstream provider evidence must agree with the registered account.
    const detectedProvider = this._detectProvider(raw);
    if (detectedProvider && detectedProvider !== account.provider) {
      this.logger.warn(
        `[_isPaymentToAccount] Provider mismatch: upstream=${detectedProvider} registered=${account.provider}`,
      );
      return false;
    }

    const receiverName = raw?.receiver ?? raw?.receiverName;
    const accountNumber =
      raw?.accountNumber ?? raw?.receiverAccountNumber ?? raw?.receiverAccount;
    const suffixFromApi = raw?.suffix;

    // Tier 1: full receiving-account number comparison (HMAC, versioned).
    const normalizedApiAccount = this._normalizeAccountNumber(accountNumber);
    if (
      normalizedApiAccount &&
      !normalizedApiAccount.includes('*') &&
      (account.accountNumberHash || account.accountNumber)
    ) {
      const apiHash = this._hashAccountNumber(normalizedApiAccount);
      if (account.accountNumberHash) {
        if (
          // Only versioned hmac-v1 hashes participate; legacy/unrecognized
          // formats fall through to the legacy path until backfilled.
          parseAccountHashVersion(account.accountNumberHash) === 'hmac-v1' &&
          apiHash !== null &&
          apiHash === account.accountNumberHash
        ) {
          return true;
        }
        if (parseAccountHashVersion(account.accountNumberHash) === 'hmac-v1') {
          // Full numbers both present (current hash version) and different
          // => different accounts. Definitive reject.
          this.logger.warn(
            `[_isPaymentToAccount] Full account number mismatch (HMAC compare)`,
          );
          return false;
        }
        this.logger.warn(
          `[_isPaymentToAccount] Stored hash is not hmac-v1 (legacy/plain format) — using legacy plaintext compare until backfill runs`,
        );
      }
      // Legacy path: hash missing or legacy format. Compare plaintext once,
      // log the deprecation — this path disappears after the backfill.
      const normalizedRegistered = this._normalizeAccountNumber(
        account.accountNumber,
      );
      if (
        normalizedRegistered &&
        normalizedApiAccount === normalizedRegistered
      ) {
        return true;
      }
      if (normalizedRegistered) {
        this.logger.warn(
          `[_isPaymentToAccount] Full account number mismatch (legacy plaintext compare — run hash backfill)`,
        );
        return false;
      }
    }

    // Tier 2: exact suffix comparison.
    if (account.suffix && suffixFromApi) {
      if (account.suffix === suffixFromApi) return true;
      this.logger.warn(`[_isPaymentToAccount] Suffix mismatch`);
      return false;
    }

    // Tier 3: masked upstream number (****1234) vs registered suffix.
    if (account.suffix && accountNumber && typeof accountNumber === 'string') {
      const maskedSuffixMatch = accountNumber.match(/\*+(\d+)$/);
      if (maskedSuffixMatch) {
        const extractedSuffix = maskedSuffixMatch[1];
        if (account.suffix === extractedSuffix) return true;
        if (
          extractedSuffix.length >= 4 &&
          account.suffix.endsWith(extractedSuffix)
        ) {
          // Heuristic only: partial digits of a masked number. Logged so that
          // reliance on this tier is auditable.
          this.logger.warn(
            `[_isPaymentToAccount] Matched via masked-number tail heuristic (partial evidence)`,
          );
          return true;
        }
      }
    }

    // Tier 3b (Telebirr/mobile wallets): Check.et returns receiver_account
    // MASKED for wallet providers (e.g. "25****97" for a 251986006897
    // receiver), so full-number HMAC matching is impossible. Compare the
    // masked tail against the last digits of the REGISTERED phone number
    // (canonicalized), same partial-evidence strength as Tier 3.
    if (
      !account.suffix &&
      accountNumber &&
      typeof accountNumber === 'string' &&
      account.accountNumber
    ) {
      const maskedTailMatch = accountNumber.match(/\*+(\d+)$/);
      if (maskedTailMatch) {
        const registered = this._normalizeAccountNumber(account.accountNumber);
        // The provider masks the INTERNATIONAL phone form (2519…): try both
        // the stored canonical form and its 251-prefixed international form.
        const international = registered?.match(/^0([97]\d{8})$/)
          ? `251${registered.slice(1)}`
          : registered;
        const candidates = [registered, international].filter(
          (v): v is string => !!v,
        );
        const extractedSuffix = maskedTailMatch[1];
        if (
          extractedSuffix.length >= 4 &&
          candidates.some((c) => c.endsWith(extractedSuffix))
        ) {
          this.logger.warn(
            `[_isPaymentToAccount] Matched via provider-masked wallet tail (partial evidence, no stored suffix)`,
          );
          return true;
        }
        this.logger.warn(
          `[_isPaymentToAccount] Masked wallet tail mismatch (no stored suffix)`,
        );
        return false;
      }
    }

    // Tier 4: receiver name — EXACT equality only (substring removed in
    // Stage 1; name substrings were a false-approval vector).
    if (account.accountHolderName && receiverName) {
      const canonical = (s: unknown) =>
        String(s).toLowerCase().trim().replace(/\s+/g, ' ');
      if (
        canonical(receiverName).length > 0 &&
        canonical(receiverName) === canonical(account.accountHolderName)
      ) {
        this.logger.warn(
          `[_isPaymentToAccount] Matched via exact receiver-name equality (no number evidence available)`,
        );
        return true;
      }
    }

    return false;
  }

  private _maskSensitive(value: string | null | undefined): string {
    if (!value) return 'null';
    if (value.length <= 4) return '****';
    return value.substring(0, 2) + '****' + value.substring(value.length - 2);
  }

  /**
   * Most-specific destination first: branch-scoped accounts before
   * organization-wide ones. Ordering only — the candidate set is unchanged.
   */
  private _orderAccountsBySpecificity(
    accounts: PaymentAccount[],
  ): PaymentAccount[] {
    return [...accounts].sort(
      (a, b) => (a.branchId ? 0 : 1) - (b.branchId ? 0 : 1),
    );
  }

  /**
   * Plan the upstream probes for a reference verification.
   *
   * Check.et receives the receiving account number only for banks that
   * require it (CBE, BOA). For every other provider the request is
   * (bank, reference), so a second account of the same provider would send
   * the exact same request and consume quota without adding any evidence.
   * Accounts that map to an identical upstream request are therefore probed
   * once, while every genuinely distinct request is still executed.
   */
  private _planAccountProbes(
    accounts: PaymentAccount[],
  ): PaymentAccount[] {
    const seen = new Set<string>();
    const probes: PaymentAccount[] = [];
    for (const account of this._orderAccountsBySpecificity(accounts)) {
      const accountNumber = checkEtForwardsAccountNumber(account.provider)
        ? (this._normalizeAccountNumber(account.accountNumber) ?? '')
        : '';
      const key = `${account.provider}|${accountNumber}`;
      if (seen.has(key)) continue;
      seen.add(key);
      probes.push(account);
    }
    return probes;
  }

  /**
   * Mask any account-number-like field on a (shallow-copied) raw object.
   * Shared by the client-facing and persistence sanitizers.
   */
  private _maskAccountFields(
    clone: Record<string, unknown>,
  ): Record<string, unknown> {
    for (const key of Object.keys(clone)) {
      if (
        /account(number)?$|accountnumber$/i.test(key) ||
        /receiveraccount|payeraccount/i.test(key)
      ) {
        const value = clone[key];
        if (typeof value === 'string' && value.length > 4) {
          clone[key] = this._maskSensitive(value);
        }
      }
    }
    return clone;
  }

  private _parsePaymentDate(value: unknown): Date | null {
    if (typeof value !== 'string' || value.trim().length === 0) return null;
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  private _normalizeIdentityText(value: unknown): string | null {
    if (typeof value !== 'string') return null;
    const normalized = value.trim().replace(/\s+/g, ' ').toLocaleLowerCase();
    return normalized.length > 0 ? normalized : null;
  }

  private _normalizeProviderName(value: unknown): string | null {
    const normalized = this._normalizeIdentityText(value);
    return normalized ? normalized.replace(/[\s-]+/g, '_') : null;
  }

  private _bankProviderMatches(
    existingProvider: unknown,
    candidateProvider: unknown,
  ): boolean | null {
    const existing = this._normalizeProviderName(existingProvider);
    const candidate = this._normalizeProviderName(candidateProvider);
    if (!existing || !candidate) return null;
    return existing === candidate;
  }

  private _storedBankProvider(existing: any): string | null {
    const raw = existing?.rawData;
    if (!raw || typeof raw !== 'object') return null;
    const provider =
      raw.provider ??
      raw.paymentProvider ??
      raw.bank ??
      raw.checkEtBank ??
      null;
    return typeof provider === 'string' || typeof provider === 'number'
      ? String(provider)
      : null;
  }

  private _identityTextEquals(left: unknown, right: unknown): boolean | null {
    const a = this._normalizeIdentityText(left);
    const b = this._normalizeIdentityText(right);
    if (!a || !b) return null;
    return a === b;
  }

  private _amountMatches(
    existingAmount: unknown,
    candidate: unknown,
  ): boolean | null {
    if (candidate === null || candidate === undefined) return null;
    const parsed = typeof candidate === 'number' ? candidate : Number(candidate);
    if (!Number.isFinite(parsed)) return null;
    return Math.abs(Number(existingAmount) - parsed) <= 0.01;
  }

  private _verifyShapeFromRaw(
    raw: any,
  ): Partial<NormalizedVerification> | null {
    if (!raw || typeof raw !== 'object') return null;
    const amountCheck = parseVerifiedAmount(
      raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount,
    );
    return {
      amount: amountCheck.ok ? Number(amountCheck.amount) : null,
      provider: raw?.provider ?? raw?.bank ?? null,
      payer: raw?.payer ?? raw?.senderName ?? null,
      receiver: raw?.receiver ?? raw?.receiverName ?? null,
    };
  }

  private _assessExistingIdentity(
    existing: any,
    input: {
      amount?: number | null;
      provider?: string | null;
      verification?: Partial<NormalizedVerification> | null;
    },
  ): { ok: boolean; mismatch: boolean; reason: string; matched: string[] } {
    const checks: Array<{ label: string; result: boolean | null }> = [
      { label: 'amount', result: this._amountMatches(existing?.amount, input.amount) },
      {
        label: 'provider',
        result: this._bankProviderMatches(
          this._storedBankProvider(existing),
          input.provider,
        ),
      },
    ];

    const verification = input.verification;
    if (verification) {
      checks.push({
        label: 'provider evidence',
        result: this._bankProviderMatches(
          this._storedBankProvider(existing),
          verification.provider,
        ),
      });
      checks.push({
        label: 'amount evidence',
        result: this._amountMatches(existing?.amount, verification.amount),
      });
      checks.push({
        label: 'payer',
        result: this._identityTextEquals(existing?.senderName, verification.payer),
      });
      checks.push({
        label: 'receiver',
        result: this._identityTextEquals(
          existing?.receiverName,
          verification.receiver,
        ),
      });
    }

    const failed = checks.find((check) => check.result === false);
    if (failed) {
      return {
        ok: false,
        mismatch: true,
        reason: `The ${failed.label} does not match the previously verified payment.`,
        matched: [],
      };
    }

    const matched = checks
      .filter((check) => check.result === true)
      .map((check) => check.label);
    if (matched.length === 0) {
      return {
        ok: false,
        mismatch: false,
        reason:
          'Provide the payment amount or receipt details to confirm this is the same transaction.',
        matched,
      };
    }

    return { ok: true, mismatch: false, reason: '', matched };
  }

  private async _findExistingVerifiedPayment(
    organizationId: string,
    referenceNumber: string,
    normalizedReference: string | null = normalizeTransactionId(referenceNumber),
  ): Promise<any | null> {
    return this.prisma.payment.findFirst({
      where: {
        organizationId,
        status: PaymentStatus.VERIFIED,
        OR: [
          { transactionId: referenceNumber },
          ...(normalizedReference
            ? [{ normalizedTransactionId: normalizedReference }]
            : []),
        ],
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  private _recheckResponse(existing: any, message?: string) {
    return {
      verified: true,
      status: 'PREVIOUSLY_VERIFIED',
      recheck: true,
      paymentId: existing.id,
      amount: Number(existing.amount),
      currency: existing.currency ?? 'ETB',
      transactionId: existing.transactionId,
      reference: existing.transactionId,
      paymentDate: existing.paymentDate?.toISOString() ?? null,
      verifiedAt: (existing.updatedAt ?? existing.createdAt)?.toISOString() ?? null,
      senderName: existing.senderName,
      receiverName: existing.receiverName,
      riskScore: existing.riskScore,
      message:
        message ??
        'Previously verified. Showing the original payment record.',
      raw: null,
    };
  }

  private _identityMismatchResponse(
    reason: string,
    transactionId: string,
    paymentDate?: string | null,
  ) {
    return {
      verified: false,
      status: 'IDENTITY_MISMATCH',
      recheck: true,
      amount: 0,
      currency: 'ETB',
      transactionId,
      reference: transactionId,
      paymentDate: paymentDate ?? null,
      riskScore: 80,
      message: reason,
      raw: null,
    };
  }

  private _providerDuplicateResponse(
    transactionId: string,
    verification?: Partial<NormalizedVerification> | null,
  ) {
    return {
      verified: false,
      status: 'PROVIDER_DUPLICATE',
      amount: 0,
      currency: 'ETB',
      transactionId,
      reference: transactionId,
      paymentDate: verification?.transactionDate ?? null,
      riskScore: 80,
      message:
        'This receipt was already verified by the provider, but no matching payment record exists in your business. Contact support if you need the original receipt details.',
      raw: null,
    };
  }

  private _recheckFailedResponse(existing: any, transactionId: string) {
    return {
      ...this._recheckResponse(
        existing,
        'A previous payment record exists, but the fresh provider check did not confirm it. Showing the original record.',
      ),
      verified: false,
      status: 'RECHECK_FAILED',
    };
  }

  private async _writeVerificationAudit(input: {
    organizationId: string;
    paymentId?: string | null;
    userId?: string | null;
    action: string;
    reason: string;
    riskScore?: number;
  }) {
    try {
      await this.prisma.verificationLog.create({
        data: {
          organizationId: input.organizationId,
          paymentId: input.paymentId ?? null,
          userId: input.userId ?? null,
          action: input.action,
          reason: input.reason,
          riskScore: input.riskScore ?? null,
          matchedProvider: null,
          matchedAccountNumber: null,
          matchedSuffix: null,
          matchedBranchId: null,
          matchedPaymentAccountId: null,
        },
      });
    } catch {}
  }

  private async _resolveExistingRecheck(
    existingPayment: any,
    input: {
      organizationId: string;
      userId: string;
      referenceNumber: string;
      amount?: number | null;
      provider?: string | null;
      verification?: Partial<NormalizedVerification> | null;
    },
  ) {
    const assessment = this._assessExistingIdentity(existingPayment, {
      amount: input.amount,
      provider: input.provider,
      verification: input.verification,
    });
    if (assessment.ok) {
      await this._writeVerificationAudit({
        organizationId: input.organizationId,
        paymentId: existingPayment.id,
        userId: input.userId,
        action: RECHECK_ACTION,
        reason: 'Provider-confirmed recheck of a previously verified payment.',
      });
      return this._recheckResponse(existingPayment);
    }
    if (assessment.mismatch) {
      await this._writeVerificationAudit({
        organizationId: input.organizationId,
        paymentId: existingPayment.id,
        userId: input.userId,
        action: RECHECK_MISMATCH_ACTION,
        reason: assessment.reason,
        riskScore: 80,
      });
      return this._identityMismatchResponse(
        assessment.reason,
        input.referenceNumber,
        input.verification?.transactionDate ??
          existingPayment.paymentDate?.toISOString() ??
          null,
      );
    }
    await this._writeVerificationAudit({
      organizationId: input.organizationId,
      paymentId: existingPayment.id,
      userId: input.userId,
      action: RECHECK_FAILED_ACTION,
      reason: assessment.reason,
      riskScore: 80,
    });
    return this._recheckFailedResponse(existingPayment, input.referenceNumber);
  }

  /**
   * Shared post-provider conclusion for a verification that matched an
   * EXISTING verified payment.
   *
   * A fresh provider rejection keeps the original record (RECHECK_FAILED);
   * a confirmation is resolved through _resolveExistingRecheck. Both entry
   * points (reference and receipt/image) use this so the duplicate rules
   * cannot drift apart.
   */
  private async _concludeExistingRecheck(
    existingPayment: any,
    raw: any,
    input: {
      organizationId: string;
      userId: string;
      referenceNumber: string;
      amount?: number | null;
      provider?: string | null;
      verification?: Partial<NormalizedVerification> | null;
    },
  ) {
    if (!raw?.success) {
      await this._writeVerificationAudit({
        organizationId: input.organizationId,
        paymentId: existingPayment.id,
        userId: input.userId,
        action: RECHECK_FAILED_ACTION,
        reason: 'Fresh provider check did not confirm the previous payment.',
        riskScore: 80,
      });
      return this._recheckFailedResponse(existingPayment, input.referenceNumber);
    }
    return this._resolveExistingRecheck(existingPayment, input);
  }

  /**
   * Client-facing copy of the provider result: full receiving-account
   * numbers are ALWAYS masked; only the masked evidence is exposed to the
   * requesting staff member.
   */
  private _sanitizeRawForClient(raw: any): any {
    if (!raw || typeof raw !== 'object') return raw;
    return this._maskAccountFields({ ...raw });
  }

  /**
   * Persistence copy of the provider result for audit (payments.rawData).
   *
   * Unmasked bank account numbers are NOT persisted — a database leak would
   * otherwise expose every payer/receiver account in full. Retained audit
   * evidence: verification verdict, bank, amount, currency, transaction
   * date/reference, payer/receiver names, and masked account tails, which is
   * sufficient to re-attribute a historical verification.
   *
   * NOTE: matching (_isPaymentToAccount) always runs on the UNSANITIZED
   * shape before persistence; only the stored copy is sanitized.
   * Legacy Veritas rows in rawData are never rewritten.
   */
  private _sanitizeRawForPersistence(raw: any): any {
    if (!raw || typeof raw !== 'object') return raw;
    return this._maskAccountFields({ ...raw });
  }

  async verifyByReference(
    referenceNumber: string,
    organizationId: string,
    userId: string,
    amount?: number,
    provider?: string,
    _extractedSuffix?: string,
    userBranchId?: string | null,
  ) {
    // Stage 1: the client-supplied suffix is deliberately ignored. All
    // receiving-account data used for upstream calls and match decisions is
    // derived server-side from the organization's registered accounts.
    void _extractedSuffix;

    const normalizedReference = normalizeTransactionId(referenceNumber);
    const suppliedAmount = amount && amount > 0 ? amount : null;

    let existingPayment = await this._findExistingVerifiedPayment(
      organizationId,
      referenceNumber,
      normalizedReference,
    );

    if (existingPayment) {
      const cachedAssessment = this._assessExistingIdentity(existingPayment, {
        amount: suppliedAmount,
        provider,
      });
      const storedProvider = this._storedBankProvider(existingPayment);
      if (cachedAssessment.ok && (!storedProvider || provider)) {
        await this._writeVerificationAudit({
          organizationId,
          paymentId: existingPayment.id,
          userId,
          action: RECHECK_ACTION,
          reason: 'Cached recheck of a previously verified payment.',
        });
        return this._recheckResponse(existingPayment);
      }
      if (cachedAssessment.mismatch) {
        await this._writeVerificationAudit({
          organizationId,
          paymentId: existingPayment.id,
          userId,
          action: RECHECK_MISMATCH_ACTION,
          reason: cachedAssessment.reason,
          riskScore: 80,
        });
        return this._identityMismatchResponse(
          cachedAssessment.reason,
          referenceNumber,
          existingPayment.paymentDate?.toISOString() ?? null,
        );
      }
    }

    const paymentAccounts = await this.prisma.paymentAccount.findMany({
      where: { organizationId, isActive: true },
    });

    // Payment-provider detection is validated independently on the server.
    // The provider MUST have been detected from the receipt (or explicitly
    // chosen by the user) and must map to a Prisma PaymentProvider. SnapVerify
    // never guesses and never falls back to a different provider's account.
    const detectedProvider = provider
      ?.trim()
      .toUpperCase()
      .replace(/[\s-]+/g, '_');
    if (!detectedProvider) {
      throw new HttpException(
        {
          verified: false,
          status: 'PAYMENT_PROVIDER_UNDETECTED',
          message:
            'Could not determine the payment provider from this receipt. Please select the payment provider and try again.',
        },
        HttpStatus.BAD_REQUEST,
      );
    }
    if (
      !Object.values(PaymentProvider).includes(
        detectedProvider as PaymentProvider,
      )
    ) {
      throw new HttpException(
        {
          verified: false,
          status: 'UNSUPPORTED_PAYMENT_PROVIDER',
          message: `The payment provider "${provider}" is not supported.`,
        },
        HttpStatus.BAD_REQUEST,
      );
    }
    const verifiedProvider = detectedProvider as PaymentProvider;

    // Match an ACTIVE receiving account for the authenticated organization
    // AND the detected provider (and the caller's branch when applicable).
    // Inactive accounts and other providers are never probed.
    let candidateAccounts = paymentAccounts.filter(
      (a) => a.provider === verifiedProvider,
    );
    if (userBranchId) {
      candidateAccounts = candidateAccounts.filter(
        (a) => a.branchId === null || a.branchId === userBranchId,
      );
    }
    if (candidateAccounts.length === 0) {
      throw new HttpException(
        {
          verified: false,
          status: 'PAYMENT_ACCOUNT_NOT_CONFIGURED',
          message: `No active ${verifiedProvider.replace(/_/g, ' ')} receiving account is configured for your business. Add it in settings, or verify against your registered bank account.`,
        },
        HttpStatus.BAD_REQUEST,
      );
    }

    let matchedAccount: PaymentAccount | null = null;
    let raw: any = null;
    let providerConfirmedUnmatchedRaw: any = null;
    let providerConfirmedTransactionId: string | null = null;
    const authoritativeNegativeProviders = new Set<PaymentProvider>();
    let hadAnyApiSuccess = false;
    let lastUpstreamError: string | null = null;
    let validationRejectionCount = 0;
    let lastValidationMessage: string | null = null;
    let otherContinuableFailureCount = 0;

    // Sanitized diagnostics: reference STYLE and length only — never the
    // full value, so payer-identifying data stays out of the logs.
    this.logger.log(
      `[verifyByReference] attempt ref=${this._maskSensitive(referenceNumber)} ` +
        `style=${(referenceNumber ?? '').slice(0, 2)} len=${(referenceNumber ?? '').length} ` +
        `accounts=${candidateAccounts.length}`,
    );

    // Probe each DISTINCT upstream request once. Accounts of providers that
    // do not forward an account number collapse to a single call, avoiding
    // redundant Check.et requests (and quota use) when an organization has
    // several accounts for the same provider.
    const probeAccounts = this._planAccountProbes(candidateAccounts);

    // SECURITY: the client-supplied suffix is never sent upstream. Receiving-
    // account evidence comes exclusively from the REGISTERED account rows.
    for (const account of probeAccounts) {
      try {
        const verification = await this.checkEt.verifyReference(
          account.provider,
          normalizedReference ?? referenceNumber,
          account.accountNumber,
        );
        hadAnyApiSuccess = true;

        // Check.et's own branch-scoped duplicate detection.
        if (verification.duplicate) {
          if (existingPayment) {
            return this._resolveExistingRecheck(existingPayment, {
              organizationId,
              userId,
              referenceNumber,
              amount: suppliedAmount,
              provider,
              verification,
            });
          }
          await this._writeVerificationAudit({
            organizationId,
            userId,
            action: PROVIDER_DUPLICATE_ACTION,
            reason: 'Provider reported a duplicate with no local verified payment.',
            riskScore: 80,
          });
          return this._providerDuplicateResponse(referenceNumber, verification);
        }

        if (verification.success) {
          // Which accounts the answer may be attributed to depends on the
          // request that produced it:
          //
          //  - Account-specific probes (CBE, BOA forward the receiving
          //    account number): the provider looked the destination up for
          //    THAT number, so a success belongs to the probed account.
          //    Matching it against other registered accounts could approve
          //    on weaker (name-only) evidence for a different destination.
          //  - Shared probes (all other providers send bank + reference):
          //    the answer is not tied to the account that happened to be
          //    probed, so match the provider-reported destination against
          //    ALL registered candidate accounts (branch-scoped first).
          const matchCandidates = checkEtForwardsAccountNumber(account.provider)
            ? [account]
            : this._orderAccountsBySpecificity(candidateAccounts);
          const match = matchCandidates.find((candidate) =>
            this._isPaymentToVerification(verification, candidate),
          );
          if (match) {
            // Reconcile using the provider-confirmed transaction reference
            // (Check.et's transaction_number), not the submitted reference,
            // so the same provider transaction verified under a different
            // submitted format is recognized as one transaction.
            providerConfirmedTransactionId =
              verification.transactionNumber ?? null;
            raw = this._toRawShape(verification);
            matchedAccount = match;
            break;
          }

          // Provider CONFIRMED the transaction but it went to a different
          // account. This is the most informative failure evidence — keep it
          // so the final message reflects the actual provider verdict
          // instead of an unrelated bank's "not found" answer.
          providerConfirmedUnmatchedRaw = this._toRawShape(verification);
        } else {
          authoritativeNegativeProviders.add(account.provider);
          if (!raw) raw = this._toRawShape(verification);
        }
      } catch (e) {
        lastUpstreamError = upstreamErrorDetail(e);
        if (e instanceof ProviderError) {
          const failClosed = this._handleProviderError(e, 'verifyByReference');
          if (failClosed) throw failClosed;
          if (e.type === ProviderErrorType.VALIDATION_ERROR) {
            validationRejectionCount++;
            lastValidationMessage = e.message || lastValidationMessage;
          } else {
            // TRANSACTION_NOT_FOUND / UNKNOWN: continuable, authoritative negative.
            otherContinuableFailureCount++;
          }
        } else {
          otherContinuableFailureCount++;
        }
      }
    }

    if (!hadAnyApiSuccess) {
      if (validationRejectionCount > 0 && otherContinuableFailureCount === 0) {
        // Provider responded authoritatively (business validation rejection),
        // so this is not an infrastructure/provider-unavailable condition.
        const rejectionRaw = {
          success: false,
          reason:
            lastValidationMessage ||
            'This payment could not be verified against the registered receiving account.',
        };
        return this._saveAndReturn(
          rejectionRaw,
          organizationId,
          userId,
          {
        method: 'REFERENCE',
        transactionId: referenceNumber,
        amount: suppliedAmount,
        provider,
      },
          null,
        );
      }
      const msg =
        'Verification service is temporarily unavailable. Please try again in a few minutes.';
      this.logger.error(
        `[verifyByReference] ALL upstream calls failed. lastError=${lastUpstreamError} — fail closed`,
      );
      throw new HttpException(
        {
          verified: false,
          status: 'PROVIDER_UNAVAILABLE',
          message: msg,
          detail: lastUpstreamError,
          retryAfterMs: 60_000,
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    // SECURITY: a provider-confirmed transaction that went to a DIFFERENT
    // receiving account must never be approved. Downgrade to a failed
    // verification regardless of the provider's success flag.
    if (providerConfirmedUnmatchedRaw) {
      raw = {
        ...providerConfirmedUnmatchedRaw,
        success: false,
        reason:
          'This payment was sent to a different account. Please ensure the payment was made to your registered business account.',
      };
      this.logger.warn(
        `[verifyByReference] provider-confirmed payment REJECTED by receiver matching — no registered account matched`,
      );
    } else if (!raw?.success && authoritativeNegativeProviders.size > 1) {
      // Multiple banks answered authoritatively with "not found / not to this
      // account". Naming only one bank (usually the first probed) misleads
      // the user — e.g. a Telebirr reference shown a CBE rejection message.
      raw = {
        success: false,
        reason:
          'This payment could not be verified against your registered accounts. Please check the reference and try again.',
      };
    }
    if (raw?.success && !matchedAccount) {
      raw = {
        ...raw,
        success: false,
        reason:
          'This payment was sent to a different account. Please ensure the payment was made to your registered business account.',
      };
    }
    this.logger.log(
      `[verifyByReference] outcome=${raw?.success ? 'VERIFIED' : 'FAILED'} matched=${matchedAccount?.provider ?? 'none'}`,
    );

    // Reconcile the provider-confirmed transaction reference with the
    // submitted reference: the same provider transaction verified under a
    // different submitted format is a duplicate of the already-verified
    // payment (stored under the provider-confirmed reference), not a new
    // transaction. An identical reference string from a different provider
    // is not treated as the same transaction. Skipped when the provider
    // reference equals the submitted one, since the pre-check already covers
    // that case.
    if (
      providerConfirmedTransactionId &&
      !existingPayment &&
      normalizeTransactionId(providerConfirmedTransactionId) !==
        normalizedReference
    ) {
      const providerNormalized = normalizeTransactionId(
        providerConfirmedTransactionId,
      );
      if (providerNormalized) {
        const providerExisting = await this._findExistingVerifiedPayment(
          organizationId,
          providerConfirmedTransactionId,
          providerNormalized,
        );
        if (
          providerExisting &&
          this._bankProviderMatches(
            this._storedBankProvider(providerExisting),
            raw?.provider ?? null,
          ) !== false
        ) {
          existingPayment = providerExisting;
        }
      }
    }

    if (existingPayment) {
      return this._concludeExistingRecheck(existingPayment, raw, {
        organizationId,
        userId,
        referenceNumber,
        amount: suppliedAmount,
        provider,
        verification: this._verifyShapeFromRaw(raw),
      });
    }

    if (!raw) {
      raw = {
        success: false,
        reason:
          'Unable to verify this payment. Please check the transaction details and try again.',
      };
    }

    return this._saveAndReturn(
      raw,
      organizationId,
      userId,
      {
        method: 'REFERENCE',
        transactionId: providerConfirmedTransactionId ?? referenceNumber,
        amount: suppliedAmount,
        provider,
      },
      matchedAccount,
    );
  }

  /**
   * Resolve Check.et receipt-file verification hints from the merchant's
   * registered receiving accounts (already scoped to organization and, when
   * applicable, the caller's branch).
   *
   * CBE and BOA require the receiving account_number. We only supply it when
   * the destination is unambiguous from existing account assignment rules;
   * otherwise we fail safely before calling the provider.
   */
  private _resolveReceiptVerificationParams(
    paymentAccounts: PaymentAccount[],
    userBranchId?: string | null,
  ): { bankHint?: 'cbe' | 'boa'; accountNumber?: string } {
    let requiring = paymentAccounts
      .map((account) => {
        const bankHint = SNAP_TO_CHECK_ET_BANK[account.provider];
        if (bankHint !== 'cbe' && bankHint !== 'boa') return null;
        const normalized = this._normalizeAccountNumber(account.accountNumber);
        if (!normalized) {
          return { account, bankHint, accountNumber: null as string | null };
        }
        return {
          account,
          bankHint,
          accountNumber: account.accountNumber as string,
        };
      })
      .filter(
        (
          v,
        ): v is {
          account: PaymentAccount;
          bankHint: 'cbe' | 'boa';
          accountNumber: string | null;
        } => v !== null,
      );

    if (requiring.length === 0) {
      return {};
    }

    // Selection preference: when the caller belongs to a branch, a
    // branch-scoped account is the more specific registered destination.
    // Organization-wide accounts are ignored for a bank only when a
    // branch-scoped account for the SAME bank exists, so the destination
    // stays unambiguous. Verification still runs against Check.et, which
    // must confirm the receipt really was paid to the selected account —
    // this never approves an unconfirmed payment.
    if (userBranchId) {
      const branchBanks = new Set(
        requiring
          .filter((r) => r.account.branchId === userBranchId)
          .map((r) => r.bankHint),
      );
      if (branchBanks.size > 0) {
        requiring = requiring.filter(
          (r) =>
            r.account.branchId === userBranchId ||
            !branchBanks.has(r.bankHint),
        );
      }
    }

    const missing = requiring.find((r) => !r.accountNumber);
    if (missing) {
      throw new BadRequestException(
        'The receiving bank account number for this bank is not configured. Please update your payment account settings and try again.',
      );
    }

    const unique = new Map<
      string,
      { bankHint: 'cbe' | 'boa'; accountNumber: string }
    >();
    for (const r of requiring) {
      const normalized = this._normalizeAccountNumber(r.accountNumber)!;
      unique.set(`${r.bankHint}:${normalized}`, {
        bankHint: r.bankHint,
        accountNumber: r.accountNumber!,
      });
    }

    if (unique.size !== 1) {
      throw new BadRequestException(
        'Unable to determine which receiving bank account this receipt belongs to. Please ensure the correct payment account is configured for this branch or organization.',
      );
    }

    return [...unique.values()][0];
  }

  /**
   * Translate a typed CheckEtError into a fail-closed user-facing exception.
   * Returns null when the error is per-account-continuable (validation and
   * negative answers do not abort the loop).
   */
  private _handleProviderError(e: ProviderError, context: string) {
    if (e.isRetryable) {
      this.logger.error(
        `[${context}] provider failure (${e.type}, HTTP ${e.httpStatus}): ${e.message} — fail closed`,
      );
      return new HttpException(
        {
          verified: false,
          status: 'PROVIDER_UNAVAILABLE',
          message:
            'Verification service is temporarily unavailable. Please try again in a few minutes.',
          detail: upstreamErrorDetail(e),
          retryAfterMs: 60_000,
        },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
    switch (e.type) {
      case ProviderErrorType.QUOTA_EXHAUSTED:
        this.logger.error(
          `[${context}] Check.et quota exhausted (HTTP ${e.httpStatus}) — fail closed`,
        );
        return new HttpException(
          {
            verified: false,
            status: 'QUOTA_EXHAUSTED',
            message:
              'Verification quota exhausted. The payment could not be verified. Please contact your administrator.',
            detail: e.message,
          },
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      case ProviderErrorType.AUTH_ERROR:
        this.logger.error(
          `[${context}] Check.et credentials rejected (HTTP ${e.httpStatus}) — fail closed`,
        );
        return new HttpException(
          {
            verified: false,
            status: 'PROVIDER_CONFIG_ERROR',
            message:
              'Payment verification is temporarily misconfigured. Please contact your administrator.',
            detail: e.message,
          },
          HttpStatus.SERVICE_UNAVAILABLE,
        );
      default:
        // VALIDATION_ERROR / TRANSACTION_NOT_FOUND / UNKNOWN: not fatal for
        // other registered accounts — continue the account loop.
        return null;
    }
  }

  /** Adapt a NormalizedVerification to the raw-shape used by match/persist. */
  private _toRawShape(v: NormalizedVerification): any {
    return {
      success: v.success,
      duplicate: v.duplicate,
      reason: v.message ?? undefined,
      provider: v.provider ?? undefined,
      checkEtBank: v.checkEtBank ?? undefined,
      verificationId: v.verificationId ?? undefined,
      transactionNumber: v.transactionNumber ?? undefined,
      transactionReference: v.transactionNumber ?? undefined,
      amount: v.amount ?? undefined,
      currency: v.currency ?? undefined,
      transactionDate: v.transactionDate ?? undefined,
      payer: v.payer ?? undefined,
      payerAccountNumber: v.payerAccount ?? undefined,
      receiver: v.receiver ?? undefined,
      receiverAccountNumber: v.receiverAccount ?? undefined,
      accountNumber: v.receiverAccount ?? undefined,
      verificationMethod: v.verificationMethod ?? undefined,
      snapverifyVerificationProvider: this.verificationProvider,
    };
  }

  /** Match a normalized Check.et answer against a registered account. */
  private _isPaymentToVerification(
    v: NormalizedVerification,
    account: PaymentAccount,
  ): boolean {
    return this._isPaymentToAccount(this._toRawShape(v), account);
  }

  /**
   * Verify by receipt file (PDF) or image + on-device OCR text.
   *
   * Check.et workflow (official docs):
   *  - PDF: parsed server-side, receipt_text not needed.
   *  - Images (JPG/PNG/WEBP): receipt_text from the client's OCR is REQUIRED.
   * OCR text is NEVER trusted for approval — only the provider's confirmed
   * verification result (success) plus receiver-account matching and the
   * financial gates in _saveAndReturn may mark a payment VERIFIED.
   */
  async verifyByImage(
    imageBuffer: Buffer,
    mimeType: string,
    organizationId: string,
    userId: string,
    receiptText?: string,
    userBranchId?: string | null,
  ) {
    let paymentAccounts = await this.prisma.paymentAccount.findMany({
      where: { organizationId, isActive: true },
    });

    if (userBranchId) {
      paymentAccounts = paymentAccounts.filter(
        (a) => a.branchId === null || a.branchId === userBranchId,
      );
    }

    if (paymentAccounts.length === 0) {
      const raw = {
        success: false,
        reason:
          'No payment accounts configured. Please add your business payment account in settings before verifying payments.',
      };
      return this._saveAndReturn(
        raw,
        organizationId,
        userId,
        { method: 'IMAGE_OCR', transactionId: `OCR-${Date.now()}` },
        null,
      );
    }

    const normalizedMime = (mimeType || '').toLowerCase();
    const isPdf = CHECK_ET_SUPPORTED_PDF_MIMES.has(normalizedMime);
    // Check.et requires OCR text for image receipts; PDFs are parsed
    // server-side. Validate before spending a provider call.
    if (!isPdf && (!receiptText || receiptText.trim().length === 0)) {
      throw new BadRequestException(
        'Could not read the receipt. Please capture a clearer image that includes the transaction details.',
      );
    }

    const { bankHint, accountNumber } =
      this._resolveReceiptVerificationParams(paymentAccounts, userBranchId);

    let verification: NormalizedVerification | null = null;
    try {
      verification = await this.checkEt.verifyReceiptFile({
        file: imageBuffer,
        filename: isPdf ? 'receipt.pdf' : 'capture.jpg',
        contentType: normalizedMime || 'image/jpeg',
        receiptText: receiptText?.slice(0, 50_000),
        ...(bankHint ? { bankHint } : {}),
        ...(accountNumber ? { accountNumber } : {}),
      });
    } catch (e: any) {
      if (e instanceof ProviderError) {
        const failClosed = this._handleProviderError(e, 'verifyByImage');
        if (failClosed) throw failClosed;
        // VALIDATION_ERROR / unknown: unreadable or unsupported receipt.
        this.logger.warn(
          `[verifyByImage] receipt rejected by provider (${e.type}): ${e.message}`,
        );
        throw new BadRequestException(
          'The receipt could not be verified. Make sure the full receipt is visible, readable, and in a supported format (PDF, JPG, PNG, WEBP).',
        );
      }
      if (e instanceof UpstreamVerificationUnavailableError) {
        throw new BadRequestException(
          'The receipt could not be verified. Supported formats are PDF, JPG, PNG, and WEBP.',
        );
      }
      throw e;
    }

    // A provider-reported transaction reference is the ONLY stable identity
    // for an OCR/PDF verification. The former timestamp fallback
    // (`OCR-${Date.now()}`) produced a different reference on every attempt,
    // so the same receipt could be approved repeatedly without ever tripping
    // duplicate detection. Synthetic labels are now display-only and are
    // never used as a stored duplicate key.
    const providerReference = verification.transactionNumber?.trim() || null;
    const receiptLabel = providerReference ?? `OCR-${Date.now()}`;
    const verificationNormalized = normalizeTransactionId(providerReference);
    const existingPayment = verificationNormalized
      ? await this._findExistingVerifiedPayment(
          organizationId,
          providerReference!,
          verificationNormalized,
        )
      : null;
    const parsedVerificationAmount =
      verification.amount === null || verification.amount === undefined
        ? Number.NaN
        : Number(verification.amount);
    const verificationAmount =
      Number.isFinite(parsedVerificationAmount) && parsedVerificationAmount > 0
        ? parsedVerificationAmount
        : null;

    // Check.et's own branch-scoped duplicate detection.
    if (verification.duplicate) {
      if (existingPayment) {
        return this._resolveExistingRecheck(existingPayment, {
          organizationId,
          userId,
          referenceNumber: providerReference!,
          amount: verificationAmount,
          provider: verification.provider,
          verification,
        });
      }
      await this._writeVerificationAudit({
        organizationId,
        userId,
        action: PROVIDER_DUPLICATE_ACTION,
        reason: 'Provider reported a duplicate with no local verified payment.',
        riskScore: 80,
      });
      return this._providerDuplicateResponse(receiptLabel, verification);
    }

    let raw: any = this._toRawShape(verification);
    let matchedAccount: PaymentAccount | null = null;

    if (verification.success && !providerReference) {
      // Fail closed: without a provider reference the receipt has no stable
      // identity, so approving it could record (and re-record) the same
      // payment indefinitely. The user can still verify by reference number.
      raw = {
        ...raw,
        success: false,
        reason:
          'The provider confirmed this receipt but did not return a transaction reference, so it cannot be recorded safely. Please verify using the transaction reference number instead.',
      };
      this.logger.warn(
        '[verifyByImage] provider-confirmed receipt without a transaction reference — refusing to record',
      );
    } else if (verification.success) {
      // Provider-confirmed transaction. Approval additionally requires the
      // receiver evidence to agree with a REGISTERED account (branch-scoped
      // accounts preferred when the caller belongs to a branch).
      const detectedProvider = verification.provider;
      const accountsToTry = this._orderAccountsBySpecificity(
        detectedProvider
          ? paymentAccounts.filter((a) => a.provider === detectedProvider)
          : paymentAccounts,
      );

      for (const account of accountsToTry) {
        if (this._isPaymentToVerification(verification, account)) {
          matchedAccount = account;
          break;
        }
      }

      if (!matchedAccount) {
        raw = {
          ...raw,
          success: false,
          reason:
            'This payment was sent to a different account. Please ensure the payment was made to your registered business account.',
        };
      }
    }

    if (existingPayment) {
      // A confirmation without a matched registered account is not a
      // confirmation (raw.success was already downgraded above); the shared
      // helper must then keep the original record instead of re-approving.
      const confirmed = raw?.success === true && !!matchedAccount;
      return this._concludeExistingRecheck(
        existingPayment,
        confirmed ? raw : { ...raw, success: false },
        {
          organizationId,
          userId,
          referenceNumber: providerReference!,
          amount: verificationAmount,
          provider: verification.provider,
          verification,
        },
      );
    }

    return this._saveAndReturn(
      raw,
      organizationId,
      userId,
      {
        method: 'IMAGE_OCR',
        transactionId: providerReference ?? receiptLabel,
      },
      matchedAccount,
    );
  }

  private async consumeVerificationQuota(
    organizationId: string,
    client: Prisma.TransactionClient,
  ) {
    const subscription = await client.subscription.findFirst({
      where: {
        organizationId,
        status: 'ACTIVE',
        OR: [{ endDate: null }, { endDate: { gt: new Date() } }],
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!subscription) {
      throw new ForbiddenException(
        'No active subscription. Select a plan to continue.',
      );
    }

    const periodStart = usagePeriodStart(subscription);
    const usage = await client.subscriptionUsage.upsert({
      where: {
        subscriptionId_periodStart: {
          subscriptionId: subscription.id,
          periodStart,
        },
      },
      create: { subscriptionId: subscription.id, periodStart },
      update: {},
    });

    const limit = subscription.verificationLimit;
    if (limit !== null && usage.count >= limit) {
      throw new ForbiddenException(
        `Verification limit reached (${limit}). Upgrade your plan to continue.`,
      );
    }

    const incremented = await client.subscriptionUsage.updateMany({
      where: {
        id: usage.id,
        ...(limit === null ? {} : { count: { lt: limit } }),
      },
      data: { count: { increment: 1 } },
    });
    if (incremented.count === 0) {
      throw new ForbiddenException(
        `Verification limit reached (${limit}). Upgrade your plan to continue.`,
      );
    }
  }

  private async _saveAndReturn(
    raw: any,
    organizationId: string,
    userId: string,
    meta: {
      method: string;
      transactionId: string;
      amount?: number | null;
      provider?: string | null;
    },
    matchedAccount: PaymentAccount | null,
  ) {
    let verified: boolean = raw?.success === true;

    // FINANCIAL INTEGRITY GATE (Stage 1):
    // A transaction may only be approved when the upstream response carries a
    // strictly valid, independently verified amount AND the currency is
    // confirmed as ETB. Invalid financial data downgrades the verification to
    // FAILED — it must never persist as a zero-value approved payment.
    if (verified) {
      const amountCheck = parseVerifiedAmount(
        raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount,
      );
      if (!amountCheck.ok) {
        verified = false;
        raw = { ...raw, success: false, reason: amountCheck.reason };
        this.logger.warn(
          `[_saveAndReturn] Rejected approval — invalid upstream amount: ${amountCheck.reason}`,
        );
      } else {
        const currencyCheck = validateVerifiedCurrency(
          raw?.currency ?? raw?.transactionCurrency ?? raw?.settledCurrency,
        );
        if (!currencyCheck.ok) {
          verified = false;
          raw = { ...raw, success: false, reason: currencyCheck.reason };
          this.logger.warn(
            `[_saveAndReturn] Rejected approval — ${currencyCheck.reason}`,
          );
        }
      }
    }

    // DUPLICATE INTEGRITY GATE: a VERIFIED row MUST carry a normalized
    // transaction reference. Without one it would escape the
    // (organizationId, normalizedTransactionId) unique constraint and could
    // be recorded repeatedly. Empty references and synthetic fallback
    // labels fail closed instead of being persisted as approvals.
    const normalizedTransactionId = verified
      ? normalizeTransactionId(meta.transactionId)
      : null;
    if (
      verified &&
      (!normalizedTransactionId ||
        SYNTHETIC_REFERENCE_PATTERN.test(normalizedTransactionId))
    ) {
      verified = false;
      raw = {
        ...raw,
        success: false,
        reason:
          'This payment cannot be recorded because no stable transaction reference is available. Please verify using the transaction reference number.',
      };
      this.logger.warn(
        '[_saveAndReturn] Rejected approval — no stable transaction reference',
      );
    }

    const status: PaymentStatus = verified
      ? PaymentStatus.VERIFIED
      : PaymentStatus.FAILED;

    // Store the independently verified transaction amount. For rejected
    // transactions the (possibly malformed) amount is stored as 0 — the
    // zero-value row is always FAILED, never approved.
    const amountCheckForStorage = parseVerifiedAmount(
      raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount,
    );
    const amount = amountCheckForStorage.ok
      ? amountCheckForStorage.amount
      : new Prisma.Decimal(0);
    const senderName = raw?.payer ?? raw?.senderName ?? raw?.payerName ?? null;
    const receiverName = raw?.receiver ?? raw?.receiverName ?? null;

    const paymentData: Prisma.PaymentUncheckedCreateInput = {
      organizationId,
      userId,
      amount,
      currency: 'ETB',
      paymentMethod: meta.method,
      transactionId: meta.transactionId,
      normalizedTransactionId: verified ? normalizedTransactionId : null,
      paymentDate: this._parsePaymentDate(
        raw?.transactionDate ?? raw?.transaction_date,
      ),
      senderName,
      receiverName,
      status,
      riskScore: verified ? 0 : 80,
      rawData: this._sanitizeRawForPersistence(raw),
      verificationProvider: this.verificationProvider,
    };

    let payment: any;
    try {
      if (verified) {
        payment = await this.prisma.$transaction(async (tx) => {
          await this.consumeVerificationQuota(organizationId, tx);
          return tx.payment.create({ data: paymentData });
        });
      } else {
        payment = await this.prisma.payment.create({ data: paymentData });
      }
    } catch (dbErr: any) {
      if (dbErr instanceof ForbiddenException) {
        throw dbErr;
      }
      if (dbErr?.code === 'P2002' && isPaymentReferenceDuplicateError(dbErr)) {
        this.logger.warn(
          `[_saveAndReturn] Concurrent duplicate blocked by database constraint (org=${organizationId})`,
        );
        const winner = await this._findExistingVerifiedPayment(
          organizationId,
          meta.transactionId,
        );
        if (winner) {
          return this._resolveExistingRecheck(winner, {
            organizationId,
            userId,
            referenceNumber: meta.transactionId,
            amount: meta.amount,
            provider: meta.provider,
            verification: this._verifyShapeFromRaw(raw),
          });
        }
        throw new HttpException(
          {
            verified: false,
            status: 'RECHECK_FAILED',
            paymentDate: null,
            message:
              'A matching payment record exists but could not be loaded. Please try again.',
          },
          HttpStatus.CONFLICT,
        );
      }
      throw new InternalServerErrorException(
        `Database error: ${dbErr?.message}`,
      );
    }

    try {
      await this.prisma.verificationLog.create({
        data: {
          organizationId,
          paymentId: payment.id,
          userId,
          action: verified ? 'VERIFIED' : 'REJECTED',
          reason:
            raw?.reason ??
            raw?.message ??
            (verified
              ? 'Payment verified successfully'
              : 'Payment could not be verified'),
          riskScore: verified ? 0 : 80,
          matchedProvider: matchedAccount?.provider ?? null,
          // Stage 1 (data minimization): never persist the full account
          // number in logs.
          matchedAccountNumber: matchedAccount
            ? this._maskSensitive(matchedAccount.accountNumber)
            : null,
          matchedSuffix: matchedAccount?.suffix ?? null,
          matchedBranchId: matchedAccount?.branchId ?? null,
          matchedPaymentAccountId: matchedAccount?.id ?? null,
        },
      });
    } catch {
      // non-fatal
    }

    return {
      verified,
      status,
      paymentId: payment.id,
      amount: Number(payment.amount),
      currency: 'ETB',
      transactionId: payment.transactionId,
      reference: payment.transactionId,
      paymentDate: payment.paymentDate?.toISOString() ?? null,
      verifiedAt: (payment.updatedAt ?? payment.createdAt)?.toISOString() ?? null,
      senderName: payment.senderName,
      receiverName: payment.receiverName,
      riskScore: verified ? 0 : 80,
      message:
        raw?.reason ??
        raw?.message ??
        (verified
          ? 'Payment verified successfully'
          : 'Unable to verify payment. Please check the details and try again.'),
      raw: this._sanitizeRawForClient(raw),
    };
  }

  async getVerificationHistory(
    organizationId: string,
    userId?: string,
    role?: string,
  ) {
    const where: any = { organizationId };
    if (role !== 'OWNER' && role !== 'MANAGER' && userId) {
      where.userId = userId;
    }

    const payments = await this.prisma.payment.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        user: {
          select: { id: true, fullName: true, phone: true },
        },
      },
    });

    return payments.map((p) => ({
      id: p.id,
      amount: Number(p.amount),
      currency: p.currency,
      status: p.status,
      paymentMethod: p.paymentMethod,
      transactionId: p.transactionId,
      reference: p.transactionId,
      paymentDate: p.paymentDate,
      senderName: p.senderName,
      receiverName: p.receiverName,
      riskScore: p.riskScore,
      createdAt: p.createdAt,
      verifiedAt: p.updatedAt ?? p.createdAt,
      verifiedBy: p.user
        ? {
            id: p.user.id,
            name: p.user.fullName ?? p.user.phone,
            phone: p.user.phone,
          }
        : null,
    }));
  }
}
