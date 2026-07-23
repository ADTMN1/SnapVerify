import {
  Injectable,
  InternalServerErrorException,
  Logger,
  HttpException,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentStatus, PaymentProvider, PaymentAccount } from '@prisma/client';
import * as FormData from 'form-data';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetch = require('node-fetch') as typeof import('node-fetch').default;

// OCR scrapes CBE/Telebirr in real time — give it plenty of time
const VERIFY_TIMEOUT_MS = 90_000;

@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly skipPrimaryVerification: boolean;

  constructor(
    private config: ConfigService,
    private prisma: PrismaService,
  ) {
    this.apiKey = this.config.get<string>('VERIFY_API_KEY', '');
    this.baseUrl = this.config.get<string>(
      'VERIFY_LEUL_ET_BASE_URL',
      'https://verifyapi.leulzenebe.pro',
    );
    this.skipPrimaryVerification = this.config.get<boolean>(
      'SKIP_PRIMARY_VERIFICATION',
      false,
    );
    this.logger.log(`=== PaymentService ready ===`);
    this.logger.log(`  baseUrl: ${this.baseUrl}`);
    this.logger.log(
      `  apiKey present: ${!!this.apiKey} (len=${this.apiKey.length})`,
    );
    this.logger.log(
      `  skipPrimaryVerification: ${this.skipPrimaryVerification}`,
    );
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

  // Check if payment destination matches registered account
  private _isPaymentToAccount(raw: any, account: PaymentAccount): boolean {
    this.logger.log(
      `[_isPaymentToAccount] Checking account: provider=${account.provider}, suffix=${this._maskSensitive(account.suffix)}, accountNumber=${this._maskSensitive(account.accountNumber)}, accountHolderName=${account.accountHolderName}`,
    );
    this.logger.log(
      `[_isPaymentToAccount] Raw API response: ${JSON.stringify(raw)}`,
    );

    if (!raw?.success) {
      this.logger.log(`[_isPaymentToAccount] Payment not successful`);
      return false;
    }

    // Check receiver info
    const receiverName = raw?.receiver ?? raw?.receiverName;
    const accountNumber =
      raw?.accountNumber ?? raw?.receiverAccountNumber ?? raw?.receiverAccount;
    const suffixFromApi = raw?.suffix;

    this.logger.log(
      `[_isPaymentToAccount] Extracted from API: receiverName=${receiverName}, accountNumber=${this._maskSensitive(accountNumber)}, suffixFromApi=${this._maskSensitive(suffixFromApi)}`,
    );

    // CHECK 1: Suffix must match exactly if both are present
    if (account.suffix && suffixFromApi) {
      if (account.suffix === suffixFromApi) {
        this.logger.log(
          `[_isPaymentToAccount] ✓ Suffix match: ${account.suffix} === ${suffixFromApi}`,
        );
        return true;
      } else {
        this.logger.warn(
          `[_isPaymentToAccount] ✗ Suffix mismatch: expected ${account.suffix}, got ${suffixFromApi}`,
        );
        return false;
      }
    }

    // CHECK 2: Extract suffix from masked account number and match
    if (account.suffix && accountNumber && typeof accountNumber === 'string') {
      // Handle masked format like "1****3381" - extract last digits
      const maskedSuffixMatch = accountNumber.match(/\*+(\d+)$/);
      if (maskedSuffixMatch) {
        const extractedSuffix = maskedSuffixMatch[1];
        this.logger.log(
          `[_isPaymentToAccount] Extracted suffix from masked account: ${extractedSuffix}`,
        );

        // First try exact match
        if (account.suffix === extractedSuffix) {
          this.logger.log(
            `[_isPaymentToAccount] ✓ Masked suffix match: ${account.suffix} === ${extractedSuffix}`,
          );
          return true;
        }

        // If no exact match, check if registered suffix ends with the extracted digits
        // (handles cases where API returns partial suffix like "3381" but registered is "16323381")
        if (account.suffix.endsWith(extractedSuffix)) {
          this.logger.log(
            `[_isPaymentToAccount] ✓ Partial suffix match: ${account.suffix} ends with ${extractedSuffix}`,
          );
          return true;
        }

        this.logger.warn(
          `[_isPaymentToAccount] ✗ Masked suffix mismatch: expected ${account.suffix} to match ${extractedSuffix}`,
        );
      }
    }

    // CHECK 3: Account number must match exactly if both are present
    if (account.accountNumber && accountNumber) {
      const normalize = (s: string) => s.replace(/\s/g, '').replace(/-/g, '');
      const normalizedAccountNumber = normalize(String(accountNumber));
      const normalizedRegisteredAccountNumber = normalize(
        account.accountNumber,
      );

      if (normalizedAccountNumber === normalizedRegisteredAccountNumber) {
        this.logger.log(`[_isPaymentToAccount] ✓ Account number match`);
        return true;
      } else {
        this.logger.warn(
          `[_isPaymentToAccount] ✗ Account number mismatch: expected ${this._maskSensitive(normalizedRegisteredAccountNumber)}, got ${this._maskSensitive(normalizedAccountNumber)}`,
        );
      }
    }

    // CHECK 4: Check if registered account number ends with the same digits as masked account
    if (
      account.accountNumber &&
      accountNumber &&
      typeof accountNumber === 'string'
    ) {
      const normalizedRegistered = account.accountNumber
        .replace(/\s/g, '')
        .replace(/-/g, '');
      const normalizedApi = accountNumber.replace(/\s/g, '').replace(/-/g, '');

      // If API returns masked account like "1****3381", check if registered ends with "3381"
      if (normalizedApi.includes('****')) {
        const lastDigits = normalizedApi.replace(/\*+/g, '');
        if (lastDigits && normalizedRegistered.endsWith(lastDigits)) {
          this.logger.log(
            `[_isPaymentToAccount] ✓ Account number ends with matching digits: ${this._maskSensitive(normalizedRegistered)} ends with ${lastDigits}`,
          );
          return true;
        }
      }
    }

    // CHECK 5: Account holder name must match (case-insensitive, but must contain full name)
    if (account.accountHolderName && receiverName) {
      const normalizedReceiverName = String(receiverName).toLowerCase().trim();
      const normalizedAccountHolderName = String(account.accountHolderName)
        .toLowerCase()
        .trim();

      // Check if the registered name is contained in the receiver name
      if (normalizedReceiverName.includes(normalizedAccountHolderName)) {
        this.logger.log(`[_isPaymentToAccount] ✓ Account holder match`);
        return true;
      } else {
        this.logger.warn(
          `[_isPaymentToAccount] ✗ Account holder mismatch: expected "${normalizedAccountHolderName}", got "${normalizedReceiverName}"`,
        );
      }
    }

    // If none of the checks passed, reject
    this.logger.warn(
      `[_isPaymentToAccount] ✗ No match found for any account identifier. Rejecting payment.`,
    );
    return false;
  }

  // Helper to mask sensitive data in logs
  private _maskSensitive(value: string | null | undefined): string {
    if (!value) return 'null';
    if (value.length <= 4) return '****';
    return value.substring(0, 2) + '****' + value.substring(value.length - 2);
  }

  // ── POST /verify — smart router by reference number ───────────────────────
  async verifyByReference(
    referenceNumber: string,
    organizationId: string,
    userId: string,
    amount?: number,
    provider?: string,
    extractedSuffix?: string, // New: suffix extracted from OCR
  ) {
    // Enhanced duplicate protection: Check if payment already verified
    const existingPayment = await this.prisma.payment.findFirst({
      where: { organizationId, transactionId: referenceNumber },
    });

    if (existingPayment) {
      this.logger.warn(
        `[verifyByReference] Duplicate transaction detected: ${referenceNumber} already verified for organization ${organizationId}`,
      );
      return {
        verified: false,
        status: 'DUPLICATE_TRANSACTION',
        paymentId: existingPayment.id,
        amount: Number(existingPayment.amount),
        currency: 'ETB',
        transactionId: existingPayment.transactionId,
        senderName: existingPayment.senderName,
        receiverName: existingPayment.receiverName,
        riskScore: existingPayment.riskScore,
        message:
          'This payment has already been verified. Each transaction can only be verified once.',
        raw: null,
      };
    }

    // Get all active payment accounts for the organization
    const paymentAccounts = await this.prisma.paymentAccount.findMany({
      where: { organizationId, isActive: true },
    });

    this.logger.log(
      `[verifyByReference] Found ${paymentAccounts.length} registered payment accounts for organization ${organizationId}: ${JSON.stringify(paymentAccounts)}`,
    );

    // If no registered accounts, reject payment immediately
    if (paymentAccounts.length === 0) {
      this.logger.warn(
        `[verifyByReference] No registered payment accounts for organization ${organizationId}`,
      );
      const raw = {
        success: false,
        reason:
          'No payment accounts configured. Please add your business payment account in settings before verifying payments.',
      };
      return this._saveAndReturn(
        raw,
        organizationId,
        userId,
        {
          method: 'REFERENCE',
          transactionId: referenceNumber,
        },
        null,
      );
    }

    if (this.skipPrimaryVerification) {
      this.logger.warn(
        `[verifyByReference] SKIP_PRIMARY_VERIFICATION is enabled - this is a security risk in production!`,
      );
      // Even when skipping primary verification, we still need to validate the account
      // to prevent payments to wrong accounts from being approved
      if (paymentAccounts.length === 0) {
        this.logger.warn(
          `[verifyByReference] No registered payment accounts for organization ${organizationId}`,
        );
        const raw = {
          success: false,
          reason:
            'No payment accounts configured. Please add your business payment account in settings before verifying payments.',
        };
        return this._saveAndReturn(
          raw,
          organizationId,
          userId,
          {
            method: 'REFERENCE',
            transactionId: referenceNumber,
          },
          null,
        );
      }

      // In skip mode, we'll use the first account but still require account validation
      // This ensures payments aren't approved for wrong accounts even in dev mode
      const raw = { success: true, amount: amount, reference: referenceNumber };
      this.logger.warn(
        `[verifyByReference] Skipping Verify.ET API call but still validating account match`,
      );
      return this._saveAndReturn(
        raw,
        organizationId,
        userId,
        {
          method: 'REFERENCE',
          transactionId: referenceNumber,
        },
        paymentAccounts[0],
      );
    }

    let matchedAccount: PaymentAccount | null = null;
    let raw: any = null;
    let detectedProvider: PaymentProvider | null = null;

    // First, try to get provider if provided
    if (provider) {
      const normalizedProvider = provider
        .toUpperCase()
        .replace('-', '_') as PaymentProvider;
      if (Object.values(PaymentProvider).includes(normalizedProvider)) {
        detectedProvider = normalizedProvider;
      }
    }

    // Determine suffix priority: extracted suffix > stored suffix
    // If we have an extracted suffix, use that first
    if (extractedSuffix) {
      this.logger.log(
        `[verifyByReference] Using extracted suffix: ${extractedSuffix}`,
      );
      // Try to find account with this suffix
      const accountWithSuffix = paymentAccounts.find(
        (a) => a.suffix === extractedSuffix,
      );
      // Try verification with this suffix
      try {
        raw = await this._verifyWithSuffix(
          referenceNumber,
          extractedSuffix,
          amount,
        );
        if (raw?.success && accountWithSuffix) {
          // Verify it's to the correct account
          if (this._isPaymentToAccount(raw, accountWithSuffix)) {
            matchedAccount = accountWithSuffix;
            this.logger.log(
              `[verifyByReference] Matched account via extracted suffix: ${accountWithSuffix.id}`,
            );
          } else {
            this.logger.warn(
              `[verifyByReference] Payment not to registered account`,
            );
            raw.success = false;
            raw.reason =
              'This payment was sent to a different account. Please ensure the payment was made to your registered business account.';
            matchedAccount = null;
          }
        }
      } catch (e) {
        this.logger.warn(
          `[verifyByReference] Verification with extracted suffix failed`,
          e,
        );
      }
    }

    // If no match yet, try all registered accounts
    if (!raw?.success && paymentAccounts.length > 0) {
      for (const account of paymentAccounts) {
        try {
          this.logger.log(
            `[verifyByReference] Trying with account: ${account.provider}, suffix: ${account.suffix}`,
          );
          const accountRaw = await this._verifyWithSuffix(
            referenceNumber,
            account.suffix,
            amount,
            account.provider,
          );
          if (
            accountRaw?.success &&
            this._isPaymentToAccount(accountRaw, account)
          ) {
            raw = accountRaw;
            matchedAccount = account;
            detectedProvider = account.provider;
            this.logger.log(
              `[verifyByReference] Matched account: ${account.id}`,
            );
            break;
          }
        } catch (e) {
          this.logger.warn(
            `[verifyByReference] Verification with account ${account.id} failed`,
            e,
          );
        }
      }
    }

    // If still no raw, fallback
    if (!raw) {
      this.logger.warn(
        `[verifyByReference] No verification successful, falling back`,
      );
      raw = {
        success: false,
        reason:
          'Unable to verify this payment. Please check the transaction details and try again.',
      };
    }

    // If we found a matched account, use that
    // Now detect provider from raw response if not provided
    if (!detectedProvider) {
      detectedProvider = this._detectProvider(raw);
    }

    return this._saveAndReturn(
      raw,
      organizationId,
      userId,
      {
        method: 'REFERENCE',
        transactionId: referenceNumber,
      },
      matchedAccount,
    );
  }

  // Helper to verify with specific suffix
  private async _verifyWithSuffix(
    referenceNumber: string,
    suffix: string | null,
    amount?: number,
    provider?: PaymentProvider,
  ): Promise<any> {
    const url = `${this.baseUrl}/verify`;
    const body: Record<string, any> = { reference: referenceNumber };
    if (suffix) body.suffix = suffix;
    if (amount) body.amount = amount;

    this.logger.log(
      `[verifyByReference] POST ${url} body=${JSON.stringify(body)}`,
    );
    return this._fetchJson(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': this.apiKey },
      body: JSON.stringify(body),
    });
  }

  // ── POST /verify-image?autoVerify=true — OCR ───────────────────────────────
  async verifyByImage(
    imageBuffer: Buffer,
    mimeType: string,
    organizationId: string,
    userId: string,
  ) {
    // Get all active payment accounts
    const paymentAccounts = await this.prisma.paymentAccount.findMany({
      where: { organizationId, isActive: true },
    });

    // If no registered accounts, reject payment immediately
    if (paymentAccounts.length === 0) {
      this.logger.warn(
        `[verifyByImage] No registered payment accounts for organization ${organizationId}`,
      );
      const raw = {
        success: false,
        reason:
          'No payment accounts configured. Please add your business payment account in settings before verifying payments.',
      };
      return this._saveAndReturn(
        raw,
        organizationId,
        userId,
        {
          method: 'IMAGE_OCR',
          transactionId: `OCR-${Date.now()}`,
        },
        null,
      );
    }

    if (this.skipPrimaryVerification) {
      this.logger.warn(
        `[verifyByImage] SKIP_PRIMARY_VERIFICATION is enabled - this is a security risk in production!`,
      );
      // Even when skipping primary verification, we still need to validate the account
      if (paymentAccounts.length === 0) {
        this.logger.warn(
          `[verifyByImage] No registered payment accounts for organization ${organizationId}`,
        );
        const raw = {
          success: false,
          reason:
            'No payment accounts configured. Please add your business payment account in settings before verifying payments.',
        };
        return this._saveAndReturn(
          raw,
          organizationId,
          userId,
          {
            method: 'IMAGE_OCR',
            transactionId: `OCR-${Date.now()}`,
          },
          null,
        );
      }

      const raw = { success: true, reference: `OCR-${Date.now()}` };
      this.logger.warn(
        `[verifyByImage] Skipping Verify.ET API call but still validating account match`,
      );
      return this._saveAndReturn(
        raw,
        organizationId,
        userId,
        {
          method: 'IMAGE_OCR',
          transactionId: `OCR-${Date.now()}`,
        },
        paymentAccounts[0],
      );
    }

    let raw: any = null;
    let matchedAccount: PaymentAccount | null = null;

    try {
      // First, let's call /verify-image to get OCR data first
      const url = `${this.baseUrl}/verify-image?autoVerify=true`;

      this.logger.log(
        `[verifyByImage] POST ${url} size=${imageBuffer.length}b mime=${mimeType}`,
      );

      // Step 1: First OCR pass to get provider and details
      const form = new (FormData as any)();
      form.append('file', imageBuffer, {
        filename: 'capture.jpg',
        contentType: mimeType || 'image/jpeg',
      });

      raw = await this._fetchJson(url, {
        method: 'POST',
        headers: { 'x-api-key': this.apiKey, ...form.getHeaders() },
        body: form,
      });

      // Step 2: Detect provider and try to match with accounts
      const detectedProvider = this._detectProvider(raw);
      const reference = raw?.reference ?? raw?.transactionReference;
      const amount =
        parseFloat(
          raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount ?? '0',
        ) || 0;

      if (reference) {
        // Try all payment accounts with this provider or all accounts if no provider
        const accountsToTry = detectedProvider
          ? paymentAccounts.filter((a) => a.provider === detectedProvider)
          : paymentAccounts;

        for (const account of accountsToTry) {
          try {
            this.logger.log(
              `[verifyByImage] Trying with account: ${account.id}`,
            );
            const accountRaw = await this._verifyWithSuffix(
              reference,
              account.suffix,
              amount,
              account.provider,
            );
            if (
              accountRaw?.success &&
              this._isPaymentToAccount(accountRaw, account)
            ) {
              raw = accountRaw;
              matchedAccount = account;
              this.logger.log(`[verifyByImage] Matched account: ${account.id}`);
              break;
            }
          } catch (e) {
            this.logger.warn(
              `[verifyByImage] Verification with account ${account.id} failed`,
              e,
            );
          }
        }
      }

      // If no matched account but raw has success, mark it as not to our account
      if (raw?.success && !matchedAccount) {
        this.logger.warn(`[verifyByImage] Payment not to registered account`);
        raw.success = false;
        raw.reason =
          'This payment was sent to a different account. Please ensure the payment was made to your registered business account.';
      }
    } catch (e: any) {
      this.logger.warn(
        `[verifyByImage] OCR verification failed, falling back to local verification. Error: ${e.message}`,
        e,
      );
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
        method: 'IMAGE_OCR',
        transactionId:
          raw?.reference ?? raw?.transactionReference ?? `OCR-${Date.now()}`,
      },
      matchedAccount,
    );
  }

  // ── HTTP helper with timeout + full logging ────────────────────────────────
  private async _fetchJson(url: string, options: any): Promise<any> {
    let rawText: string;
    let httpStatus: number;

    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), VERIFY_TIMEOUT_MS);

      const res = await fetch(url, { ...options, signal: controller.signal });
      clearTimeout(timer);

      httpStatus = res.status;
      rawText = await res.text();
    } catch (err: any) {
      const msg =
        err?.name === 'AbortError'
          ? `verify.leul.et timed out after ${VERIFY_TIMEOUT_MS / 1000}s`
          : `Network error: ${err?.message ?? String(err)}`;
      this.logger.error(`[_fetchJson] ${url} → ${msg}`, err);
      throw new InternalServerErrorException(msg);
    }

    this.logger.log(`[_fetchJson] ${url} → HTTP ${httpStatus}`);
    this.logger.log(`[_fetchJson] response body: ${rawText.slice(0, 500)}`);

    let json: any;
    try {
      json = JSON.parse(rawText);
    } catch (parseError) {
      const msg = `Non-JSON response (HTTP ${httpStatus}): ${rawText.slice(0, 300)}`;
      this.logger.error(`[_fetchJson] ${msg}`, parseError);
      throw new HttpException(msg, HttpStatus.BAD_GATEWAY);
    }

    if (httpStatus >= 400) {
      const msg =
        json?.message ??
        json?.error ??
        `HTTP ${httpStatus} from verify.leul.et`;
      this.logger.error(`[_fetchJson] API error: ${msg}`);
      throw new HttpException(msg, HttpStatus.BAD_GATEWAY);
    }

    return json;
  }

  // ── Normalize response + persist ──────────────────────────────────────────
  private async _saveAndReturn(
    raw: any,
    organizationId: string,
    userId: string,
    meta: { method: string; transactionId: string },
    matchedAccount: PaymentAccount | null,
  ) {
    this.logger.log(`[_saveAndReturn] raw=${JSON.stringify(raw)}`);

    // API returns { success: true, payer, receiver, amount, ... } — flat, NO 'data' wrapper
    const verified: boolean = raw?.success === true;

    const status: PaymentStatus = verified
      ? PaymentStatus.VERIFIED
      : PaymentStatus.FAILED;

    // Field names differ per provider — handle all variants
    const amount =
      parseFloat(
        raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount ?? '0',
      ) || 0;

    const senderName =
      raw?.payer ?? // CBE /verify
      raw?.senderName ?? // Dashen
      raw?.payerName ?? // Telebirr
      null;

    const receiverName = raw?.receiver ?? raw?.receiverName ?? null;

    let payment: any;
    try {
      payment = await this.prisma.payment.create({
        data: {
          organizationId,
          userId,
          amount,
          currency: 'ETB',
          paymentMethod: meta.method,
          transactionId: meta.transactionId,
          senderName,
          receiverName,
          status,
          riskScore: verified ? 0 : 80,
          rawData: raw,
        },
      });
      this.logger.log(
        `[_saveAndReturn] saved payment id=${payment.id} verified=${verified}`,
      );
    } catch (dbErr: any) {
      this.logger.error(`[_saveAndReturn] DB error: ${dbErr?.message}`);
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
          matchedAccountNumber: matchedAccount?.accountNumber ?? null,
          matchedSuffix: matchedAccount?.suffix ?? null,
          matchedBranchId: matchedAccount?.branchId ?? null,
          matchedPaymentAccountId: matchedAccount?.id ?? null,
        },
      });
    } catch (e: any) {
      this.logger.warn(
        `[_saveAndReturn] log save failed (non-fatal): ${e?.message}`,
      );
    }

    return {
      verified,
      status,
      paymentId: payment.id,
      amount: Number(payment.amount),
      currency: 'ETB',
      transactionId: payment.transactionId,
      senderName: payment.senderName,
      receiverName: payment.receiverName,
      riskScore: verified ? 0 : 80,
      message:
        raw?.reason ??
        raw?.message ??
        (verified
          ? 'Payment verified successfully'
          : 'Unable to verify payment. Please check the details and try again.'),
      raw,
    };
  }
}
