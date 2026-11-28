import { Injectable } from '@nestjs/common';
import { PaymentProvider } from '@prisma/client';
import { BankPaymentQrInput, BankPaymentQrResult } from './payment-qr.types';

/**
 * Bank-payment QR payload generation.
 *
 * IMPORTANT: A QR image that renders successfully is not a valid bank payment
 * QR. This service must only return `supported: true` when the payload format,
 * required identifiers, and generation path are verified against the provider's
 * official/interoperable specification and all required credentials are
 * available. Never invent EMV tags, merchant IDs, BICs, GUIDs, checksums, or
 * provider-specific formats.
 */
@Injectable()
export class PaymentQrService {
  generate(input: BankPaymentQrInput): BankPaymentQrResult {
    switch (input.provider) {
      case PaymentProvider.CBE:
      case PaymentProvider.ABYSSINIA:
      case PaymentProvider.DASHEN:
      case PaymentProvider.CBEBIRR:
      case PaymentProvider.TELEBIRR:
      case PaymentProvider.M_PESA:
        return this.unsupportedInteroperable(input.provider);
      default:
        return {
          supported: false,
          payload: null,
          format: 'UNSUPPORTED',
          reasonCode: 'NO_VERIFIED_FORMAT',
          reason:
            'No verified bank-payment QR format is available for this provider.',
          evidence: [],
        };
    }
  }

  private unsupportedInteroperable(
    provider: PaymentProvider,
  ): BankPaymentQrResult {
    // Ethiopia's National Bank/EthSwitch Interoperable QR standard is EMVCo
    // merchant-presented (P2M) and requires acquirer-issued merchant data (e.g.
    // scheme GUID, DFSP BIC, merchant account/IBAN, MCC, merchant name/city)
    // and participant onboarding. SnapVerify currently stores only provider +
    // account number/holder/suffix for receiving accounts and has no verified
    // acquirer API or provider credentials to generate a compliant QR.
    return {
      supported: false,
      payload: null,
      format: 'UNSUPPORTED',
      reasonCode: 'REQUIRES_ACQUIRER_ONBOARDING',
      reason:
        `${provider} does not have a verified bank-scannable payment QR available in SnapVerify. ` +
        'Ethiopian interoperable payment QR (NBE/EthSwitch, EMVCo merchant-presented) requires ' +
        'acquirer/participant onboarding and merchant identifiers (such as scheme GUID, institution BIC, ' +
        'and a registered merchant account/IBAN). An account number alone is not sufficient, and ' +
        'SnapVerify must not fabricate a QR payload.',
      evidence: [
        'NBE/EthSwitch: Standard for Interoperable QR Code Payments (Interoperable P2M Payments Using QR Code), 2024-04-05 (https://nbe.gov.et/wp-content/uploads/2024/04/Interoperable-QR-Standard.pdf)',
        'NBE interoperable QR page: https://nbe.gov.et/eipqrc',
      ],
    };
  }
}
