import { PaymentProvider } from '@prisma/client';

export type BankPaymentQrKind = 'EMVCO_MPM_INTEROPERABLE' | 'UNSUPPORTED';

export type BankPaymentQrReasonCode =
  | 'NO_VERIFIED_FORMAT'
  | 'REQUIRES_ACQUIRER_ONBOARDING'
  | 'REQUIRES_SCHEME_CREDENTIALS'
  | 'ACCOUNT_NUMBER_INSUFFICIENT'
  | 'PROVIDER_SPECIFIC_CLOSED_LOOP';

export interface BankPaymentQrInput {
  provider: PaymentProvider;
  accountNumber: string | null;
  accountHolderName: string | null;
  suffix: string | null;
}

export interface BankPaymentQrResult {
  /** True only when a verified, bank-scannable payment payload is produced. */
  supported: boolean;
  /** The exact string to encode in the QR image when supported; never a URL. */
  payload: string | null;
  /** Payload standard/format identifier for supported payloads. */
  format: BankPaymentQrKind;
  /** Human-readable reason when unsupported; null when supported. */
  reasonCode: BankPaymentQrReasonCode | null;
  /** Detailed, user-safe explanation for unsupported providers. */
  reason: string | null;
  /** Evidence/spec reference used to decide support (for auditability). */
  evidence: string[];
}
