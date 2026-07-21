"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var PaymentService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const prisma_service_1 = require("../prisma/prisma.service");
const client_1 = require("@prisma/client");
const FormData = __importStar(require("form-data"));
const fetch = require('node-fetch');
const VERIFY_TIMEOUT_MS = 90_000;
let PaymentService = PaymentService_1 = class PaymentService {
    config;
    prisma;
    logger = new common_1.Logger(PaymentService_1.name);
    apiKey;
    baseUrl;
    skipPrimaryVerification;
    constructor(config, prisma) {
        this.config = config;
        this.prisma = prisma;
        this.apiKey = this.config.get('VERIFY_API_KEY', '');
        this.baseUrl = this.config.get('VERIFY_LEUL_ET_BASE_URL', 'https://verifyapi.leulzenebe.pro');
        this.skipPrimaryVerification = this.config.get('SKIP_PRIMARY_VERIFICATION', false);
        this.logger.log(`=== PaymentService ready ===`);
        this.logger.log(`  baseUrl: ${this.baseUrl}`);
        this.logger.log(`  apiKey present: ${!!this.apiKey} (len=${this.apiKey.length})`);
        this.logger.log(`  skipPrimaryVerification: ${this.skipPrimaryVerification}`);
    }
    _detectProvider(raw) {
        const providerField = raw?.provider ?? raw?.paymentProvider;
        if (providerField) {
            const normalized = String(providerField).toUpperCase().replace('-', '_');
            if (Object.values(client_1.PaymentProvider).includes(normalized)) {
                return normalized;
            }
        }
        return null;
    }
    _isPaymentToAccount(raw, account) {
        this.logger.log(`[_isPaymentToAccount] Checking account: provider=${account.provider}, suffix=${this._maskSensitive(account.suffix)}, accountNumber=${this._maskSensitive(account.accountNumber)}, accountHolderName=${account.accountHolderName}`);
        this.logger.log(`[_isPaymentToAccount] Raw API response: ${JSON.stringify(raw)}`);
        if (!raw?.success) {
            this.logger.log(`[_isPaymentToAccount] Payment not successful`);
            return false;
        }
        const receiverName = raw?.receiver ?? raw?.receiverName;
        const accountNumber = raw?.accountNumber ?? raw?.receiverAccountNumber ?? raw?.receiverAccount;
        const suffixFromApi = raw?.suffix;
        this.logger.log(`[_isPaymentToAccount] Extracted from API: receiverName=${receiverName}, accountNumber=${this._maskSensitive(accountNumber)}, suffixFromApi=${this._maskSensitive(suffixFromApi)}`);
        if (account.suffix && suffixFromApi) {
            if (account.suffix === suffixFromApi) {
                this.logger.log(`[_isPaymentToAccount] ✓ Suffix match: ${account.suffix} === ${suffixFromApi}`);
                return true;
            }
            else {
                this.logger.warn(`[_isPaymentToAccount] ✗ Suffix mismatch: expected ${account.suffix}, got ${suffixFromApi}`);
                return false;
            }
        }
        if (account.suffix && accountNumber && typeof accountNumber === 'string') {
            const maskedSuffixMatch = accountNumber.match(/\*+(\d+)$/);
            if (maskedSuffixMatch) {
                const extractedSuffix = maskedSuffixMatch[1];
                this.logger.log(`[_isPaymentToAccount] Extracted suffix from masked account: ${extractedSuffix}`);
                if (account.suffix === extractedSuffix) {
                    this.logger.log(`[_isPaymentToAccount] ✓ Masked suffix match: ${account.suffix} === ${extractedSuffix}`);
                    return true;
                }
                if (account.suffix.endsWith(extractedSuffix)) {
                    this.logger.log(`[_isPaymentToAccount] ✓ Partial suffix match: ${account.suffix} ends with ${extractedSuffix}`);
                    return true;
                }
                this.logger.warn(`[_isPaymentToAccount] ✗ Masked suffix mismatch: expected ${account.suffix} to match ${extractedSuffix}`);
            }
        }
        if (account.accountNumber && accountNumber) {
            const normalize = (s) => s.replace(/\s/g, '').replace(/-/g, '');
            const normalizedAccountNumber = normalize(String(accountNumber));
            const normalizedRegisteredAccountNumber = normalize(account.accountNumber);
            if (normalizedAccountNumber === normalizedRegisteredAccountNumber) {
                this.logger.log(`[_isPaymentToAccount] ✓ Account number match`);
                return true;
            }
            else {
                this.logger.warn(`[_isPaymentToAccount] ✗ Account number mismatch: expected ${this._maskSensitive(normalizedRegisteredAccountNumber)}, got ${this._maskSensitive(normalizedAccountNumber)}`);
            }
        }
        if (account.accountNumber && accountNumber && typeof accountNumber === 'string') {
            const normalizedRegistered = account.accountNumber.replace(/\s/g, '').replace(/-/g, '');
            const normalizedApi = accountNumber.replace(/\s/g, '').replace(/-/g, '');
            if (normalizedApi.includes('****')) {
                const lastDigits = normalizedApi.replace(/\*+/g, '');
                if (lastDigits && normalizedRegistered.endsWith(lastDigits)) {
                    this.logger.log(`[_isPaymentToAccount] ✓ Account number ends with matching digits: ${this._maskSensitive(normalizedRegistered)} ends with ${lastDigits}`);
                    return true;
                }
            }
        }
        if (account.accountHolderName && receiverName) {
            const normalizedReceiverName = String(receiverName).toLowerCase().trim();
            const normalizedAccountHolderName = String(account.accountHolderName).toLowerCase().trim();
            if (normalizedReceiverName.includes(normalizedAccountHolderName)) {
                this.logger.log(`[_isPaymentToAccount] ✓ Account holder match`);
                return true;
            }
            else {
                this.logger.warn(`[_isPaymentToAccount] ✗ Account holder mismatch: expected "${normalizedAccountHolderName}", got "${normalizedReceiverName}"`);
            }
        }
        this.logger.warn(`[_isPaymentToAccount] ✗ No match found for any account identifier. Rejecting payment.`);
        return false;
    }
    _maskSensitive(value) {
        if (!value)
            return 'null';
        if (value.length <= 4)
            return '****';
        return value.substring(0, 2) + '****' + value.substring(value.length - 2);
    }
    async verifyByReference(referenceNumber, organizationId, userId, amount, provider, extractedSuffix) {
        const existingPayment = await this.prisma.payment.findFirst({
            where: { organizationId, transactionId: referenceNumber },
        });
        if (existingPayment) {
            this.logger.warn(`[verifyByReference] Duplicate transaction detected: ${referenceNumber} already verified for organization ${organizationId}`);
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
                message: 'This payment has already been verified. Each transaction can only be verified once.',
                raw: null,
            };
        }
        const paymentAccounts = await this.prisma.paymentAccount.findMany({
            where: { organizationId, isActive: true },
        });
        this.logger.log(`[verifyByReference] Found ${paymentAccounts.length} registered payment accounts for organization ${organizationId}: ${JSON.stringify(paymentAccounts)}`);
        if (paymentAccounts.length === 0) {
            this.logger.warn(`[verifyByReference] No registered payment accounts for organization ${organizationId}`);
            const raw = { success: false, reason: 'No payment accounts configured. Please add your business payment account in settings before verifying payments.' };
            return this._saveAndReturn(raw, organizationId, userId, {
                method: 'REFERENCE',
                transactionId: referenceNumber,
            }, null);
        }
        if (this.skipPrimaryVerification) {
            this.logger.warn(`[verifyByReference] SKIP_PRIMARY_VERIFICATION is enabled - this is a security risk in production!`);
            if (paymentAccounts.length === 0) {
                this.logger.warn(`[verifyByReference] No registered payment accounts for organization ${organizationId}`);
                const raw = { success: false, reason: 'No payment accounts configured. Please add your business payment account in settings before verifying payments.' };
                return this._saveAndReturn(raw, organizationId, userId, {
                    method: 'REFERENCE',
                    transactionId: referenceNumber,
                }, null);
            }
            const raw = { success: true, amount: amount, reference: referenceNumber };
            this.logger.warn(`[verifyByReference] Skipping Verify.ET API call but still validating account match`);
            return this._saveAndReturn(raw, organizationId, userId, {
                method: 'REFERENCE',
                transactionId: referenceNumber,
            }, paymentAccounts[0]);
        }
        let matchedAccount = null;
        let raw = null;
        let detectedProvider = null;
        if (provider) {
            const normalizedProvider = provider.toUpperCase().replace('-', '_');
            if (Object.values(client_1.PaymentProvider).includes(normalizedProvider)) {
                detectedProvider = normalizedProvider;
            }
        }
        if (extractedSuffix) {
            this.logger.log(`[verifyByReference] Using extracted suffix: ${extractedSuffix}`);
            const accountWithSuffix = paymentAccounts.find(a => a.suffix === extractedSuffix);
            try {
                raw = await this._verifyWithSuffix(referenceNumber, extractedSuffix, amount);
                if (raw?.success && accountWithSuffix) {
                    if (this._isPaymentToAccount(raw, accountWithSuffix)) {
                        matchedAccount = accountWithSuffix;
                        this.logger.log(`[verifyByReference] Matched account via extracted suffix: ${accountWithSuffix.id}`);
                    }
                    else {
                        this.logger.warn(`[verifyByReference] Payment not to registered account`);
                        raw.success = false;
                        raw.reason = 'This payment was sent to a different account. Please ensure the payment was made to your registered business account.';
                        matchedAccount = null;
                    }
                }
            }
            catch (e) {
                this.logger.warn(`[verifyByReference] Verification with extracted suffix failed`, e);
            }
        }
        if (!raw?.success && paymentAccounts.length > 0) {
            for (const account of paymentAccounts) {
                try {
                    this.logger.log(`[verifyByReference] Trying with account: ${account.provider}, suffix: ${account.suffix}`);
                    const accountRaw = await this._verifyWithSuffix(referenceNumber, account.suffix, amount, account.provider);
                    if (accountRaw?.success && this._isPaymentToAccount(accountRaw, account)) {
                        raw = accountRaw;
                        matchedAccount = account;
                        detectedProvider = account.provider;
                        this.logger.log(`[verifyByReference] Matched account: ${account.id}`);
                        break;
                    }
                }
                catch (e) {
                    this.logger.warn(`[verifyByReference] Verification with account ${account.id} failed`, e);
                }
            }
        }
        if (!raw) {
            this.logger.warn(`[verifyByReference] No verification successful, falling back`);
            raw = { success: false, reason: 'Unable to verify this payment. Please check the transaction details and try again.' };
        }
        if (!detectedProvider) {
            detectedProvider = this._detectProvider(raw);
        }
        return this._saveAndReturn(raw, organizationId, userId, {
            method: 'REFERENCE',
            transactionId: referenceNumber,
        }, matchedAccount);
    }
    async _verifyWithSuffix(referenceNumber, suffix, amount, provider) {
        const url = `${this.baseUrl}/verify`;
        const body = { reference: referenceNumber };
        if (suffix)
            body.suffix = suffix;
        if (amount)
            body.amount = amount;
        this.logger.log(`[verifyByReference] POST ${url} body=${JSON.stringify(body)}`);
        return this._fetchJson(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-api-key': this.apiKey },
            body: JSON.stringify(body),
        });
    }
    async verifyByImage(imageBuffer, mimeType, organizationId, userId) {
        const paymentAccounts = await this.prisma.paymentAccount.findMany({
            where: { organizationId, isActive: true },
        });
        if (paymentAccounts.length === 0) {
            this.logger.warn(`[verifyByImage] No registered payment accounts for organization ${organizationId}`);
            const raw = { success: false, reason: 'No payment accounts configured. Please add your business payment account in settings before verifying payments.' };
            return this._saveAndReturn(raw, organizationId, userId, {
                method: 'IMAGE_OCR',
                transactionId: `OCR-${Date.now()}`,
            }, null);
        }
        if (this.skipPrimaryVerification) {
            this.logger.warn(`[verifyByImage] SKIP_PRIMARY_VERIFICATION is enabled - this is a security risk in production!`);
            if (paymentAccounts.length === 0) {
                this.logger.warn(`[verifyByImage] No registered payment accounts for organization ${organizationId}`);
                const raw = { success: false, reason: 'No payment accounts configured. Please add your business payment account in settings before verifying payments.' };
                return this._saveAndReturn(raw, organizationId, userId, {
                    method: 'IMAGE_OCR',
                    transactionId: `OCR-${Date.now()}`,
                }, null);
            }
            const raw = { success: true, reference: `OCR-${Date.now()}` };
            this.logger.warn(`[verifyByImage] Skipping Verify.ET API call but still validating account match`);
            return this._saveAndReturn(raw, organizationId, userId, {
                method: 'IMAGE_OCR',
                transactionId: `OCR-${Date.now()}`,
            }, paymentAccounts[0]);
        }
        let raw = null;
        let matchedAccount = null;
        try {
            const url = `${this.baseUrl}/verify-image?autoVerify=true`;
            this.logger.log(`[verifyByImage] POST ${url} size=${imageBuffer.length}b mime=${mimeType}`);
            const form = new FormData();
            form.append('file', imageBuffer, {
                filename: 'capture.jpg',
                contentType: mimeType || 'image/jpeg',
            });
            raw = await this._fetchJson(url, {
                method: 'POST',
                headers: { 'x-api-key': this.apiKey, ...form.getHeaders() },
                body: form,
            });
            const detectedProvider = this._detectProvider(raw);
            const reference = raw?.reference ?? raw?.transactionReference;
            const amount = parseFloat(raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount ?? '0') || 0;
            if (reference) {
                const accountsToTry = detectedProvider
                    ? paymentAccounts.filter(a => a.provider === detectedProvider)
                    : paymentAccounts;
                for (const account of accountsToTry) {
                    try {
                        this.logger.log(`[verifyByImage] Trying with account: ${account.id}`);
                        const accountRaw = await this._verifyWithSuffix(reference, account.suffix, amount, account.provider);
                        if (accountRaw?.success && this._isPaymentToAccount(accountRaw, account)) {
                            raw = accountRaw;
                            matchedAccount = account;
                            this.logger.log(`[verifyByImage] Matched account: ${account.id}`);
                            break;
                        }
                    }
                    catch (e) {
                        this.logger.warn(`[verifyByImage] Verification with account ${account.id} failed`, e);
                    }
                }
            }
            if (raw?.success && !matchedAccount) {
                this.logger.warn(`[verifyByImage] Payment not to registered account`);
                raw.success = false;
                raw.reason = 'This payment was sent to a different account. Please ensure the payment was made to your registered business account.';
            }
        }
        catch (e) {
            this.logger.warn(`[verifyByImage] OCR verification failed, falling back to local verification. Error: ${e.message}`, e);
            raw = { success: false, reason: 'Unable to verify this payment. Please check the transaction details and try again.' };
        }
        return this._saveAndReturn(raw, organizationId, userId, {
            method: 'IMAGE_OCR',
            transactionId: raw?.reference ?? raw?.transactionReference ?? `OCR-${Date.now()}`,
        }, matchedAccount);
    }
    async _fetchJson(url, options) {
        let rawText;
        let httpStatus;
        try {
            const controller = new AbortController();
            const timer = setTimeout(() => controller.abort(), VERIFY_TIMEOUT_MS);
            const res = await fetch(url, { ...options, signal: controller.signal });
            clearTimeout(timer);
            httpStatus = res.status;
            rawText = await res.text();
        }
        catch (err) {
            const msg = err?.name === 'AbortError'
                ? `verify.leul.et timed out after ${VERIFY_TIMEOUT_MS / 1000}s`
                : `Network error: ${err?.message ?? String(err)}`;
            this.logger.error(`[_fetchJson] ${url} → ${msg}`, err);
            throw new common_1.InternalServerErrorException(msg);
        }
        this.logger.log(`[_fetchJson] ${url} → HTTP ${httpStatus}`);
        this.logger.log(`[_fetchJson] response body: ${rawText.slice(0, 500)}`);
        let json;
        try {
            json = JSON.parse(rawText);
        }
        catch (parseError) {
            const msg = `Non-JSON response (HTTP ${httpStatus}): ${rawText.slice(0, 300)}`;
            this.logger.error(`[_fetchJson] ${msg}`, parseError);
            throw new common_1.HttpException(msg, common_1.HttpStatus.BAD_GATEWAY);
        }
        if (httpStatus >= 400) {
            const msg = json?.message ?? json?.error ?? `HTTP ${httpStatus} from verify.leul.et`;
            this.logger.error(`[_fetchJson] API error: ${msg}`);
            throw new common_1.HttpException(msg, common_1.HttpStatus.BAD_GATEWAY);
        }
        return json;
    }
    async _saveAndReturn(raw, organizationId, userId, meta, matchedAccount) {
        this.logger.log(`[_saveAndReturn] raw=${JSON.stringify(raw)}`);
        const verified = raw?.success === true;
        const status = verified
            ? client_1.PaymentStatus.VERIFIED
            : client_1.PaymentStatus.FAILED;
        const amount = parseFloat(raw?.amount ?? raw?.transactionAmount ?? raw?.settledAmount ?? '0') || 0;
        const senderName = raw?.payer ??
            raw?.senderName ??
            raw?.payerName ??
            null;
        const receiverName = raw?.receiver ??
            raw?.receiverName ??
            null;
        let payment;
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
            this.logger.log(`[_saveAndReturn] saved payment id=${payment.id} verified=${verified}`);
        }
        catch (dbErr) {
            this.logger.error(`[_saveAndReturn] DB error: ${dbErr?.message}`);
            throw new common_1.InternalServerErrorException(`Database error: ${dbErr?.message}`);
        }
        try {
            await this.prisma.verificationLog.create({
                data: {
                    organizationId,
                    paymentId: payment.id,
                    userId,
                    action: verified ? 'VERIFIED' : 'REJECTED',
                    reason: raw?.reason ?? raw?.message ?? (verified ? 'Payment verified successfully' : 'Payment could not be verified'),
                    riskScore: verified ? 0 : 80,
                    matchedProvider: matchedAccount?.provider ?? null,
                    matchedAccountNumber: matchedAccount?.accountNumber ?? null,
                    matchedSuffix: matchedAccount?.suffix ?? null,
                    matchedBranchId: matchedAccount?.branchId ?? null,
                    matchedPaymentAccountId: matchedAccount?.id ?? null,
                },
            });
        }
        catch (e) {
            this.logger.warn(`[_saveAndReturn] log save failed (non-fatal): ${e?.message}`);
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
            message: raw?.reason ??
                raw?.message ??
                (verified ? 'Payment verified successfully' : 'Unable to verify payment. Please check the details and try again.'),
            raw,
        };
    }
};
exports.PaymentService = PaymentService;
exports.PaymentService = PaymentService = PaymentService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService,
        prisma_service_1.PrismaService])
], PaymentService);
//# sourceMappingURL=payment.service.js.map