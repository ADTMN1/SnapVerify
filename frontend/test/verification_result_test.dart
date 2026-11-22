import 'package:flutter_test/flutter_test.dart';
import 'package:snapverify/core/utils/ocr_parser.dart';
import 'package:snapverify/domain/entities/verification_result.dart';
import 'package:snapverify/domain/entities/payment_account.dart';

void main() {
  Map<String, dynamic> payload(String status) => {
    'verified': status == 'VERIFIED',
    'status': status,
    'paymentId': 'p1',
    'amount': 100.0,
    'currency': 'ETB',
    'transactionId': 'REF-****',
    'riskScore': 0,
    'message': 'msg',
  };

  group('VerificationResult.fromJson status mapping', () {
    test('VERIFIED maps to verified', () {
      final r = VerificationResult.fromJson(payload('VERIFIED'));
      expect(r.status, VerificationStatus.verified);
    });

    test('FAILED maps to failed', () {
      final r = VerificationResult.fromJson(payload('FAILED'));
      expect(r.status, VerificationStatus.failed);
    });

    test('DUPLICATE_TRANSACTION maps to alreadyVerified (not invalid)', () {
      final r = VerificationResult.fromJson(payload('DUPLICATE_TRANSACTION'));
      expect(r.status, VerificationStatus.alreadyVerified);
    });

    test('ALREADY_VERIFIED maps to alreadyVerified', () {
      final r = VerificationResult.fromJson(payload('ALREADY_VERIFIED'));
      expect(r.status, VerificationStatus.alreadyVerified);
    });

    test('NEEDS_REVIEW maps to needsReview', () {
      final r = VerificationResult.fromJson(payload('NEEDS_REVIEW'));
      expect(r.status, VerificationStatus.needsReview);
    });

    test('PENDING maps to pending', () {
      final r = VerificationResult.fromJson(payload('PENDING'));
      expect(r.status, VerificationStatus.pending);
    });

    test('unknown statuses map to pending — never a hard invalid', () {
      for (final s in ['SOME_NEW_STATUS', '']) {
        final r = VerificationResult.fromJson(payload(s));
        expect(
          r.status,
          VerificationStatus.pending,
          reason: 'status "$s" must map to pending',
        );
      }
    });

    test(
      'provider outage/connectivity statuses map distinctly (never invalid)',
      () {
        expect(
          VerificationResult.fromJson(payload('PROVIDER_UNAVAILABLE')).status,
          VerificationStatus.providerUnavailable,
        );
        expect(
          VerificationResult.fromJson(payload('SERVICE_UNAVAILABLE')).status,
          VerificationStatus.providerUnavailable,
        );
        expect(
          VerificationResult.fromJson(payload('QUOTA_EXHAUSTED')).status,
          VerificationStatus.quotaExhausted,
        );
        expect(
          VerificationResult.fromJson(payload('PROVIDER_CONFIG_ERROR')).status,
          VerificationStatus.providerConfigError,
        );
      },
    );

    test('provider outage helper flags outage statuses only', () {
      expect(
        VerificationResult.fromJson(
          payload('PROVIDER_UNAVAILABLE'),
        ).isProviderOutage,
        isTrue,
      );
      expect(
        VerificationResult.fromJson(
          payload('QUOTA_EXHAUSTED'),
        ).isProviderOutage,
        isTrue,
      );
      expect(
        VerificationResult.fromJson(payload('FAILED')).isProviderOutage,
        isFalse,
      );
    });

    test(
      'provider/account configuration statuses map distinctly (never invalid)',
      () {
        expect(
          VerificationResult.fromJson(
            payload('PAYMENT_ACCOUNT_NOT_CONFIGURED'),
          ).status,
          VerificationStatus.paymentAccountNotConfigured,
        );
        expect(
          VerificationResult.fromJson(
            payload('PAYMENT_PROVIDER_UNDETECTED'),
          ).status,
          VerificationStatus.providerUndetected,
        );
        expect(
          VerificationResult.fromJson(
            payload('UNSUPPORTED_PAYMENT_PROVIDER'),
          ).status,
          VerificationStatus.unsupportedProvider,
        );
      },
    );
    test('missing status maps to pending', () {
      final r = VerificationResult.fromJson({
        'verified': false,
        'paymentId': 'p1',
        'amount': 0,
        'riskScore': 80,
        'message': 'x',
      });
      expect(r.status, VerificationStatus.pending);
    });
  });

  group('paymentProviderFromOcrLabel (provider detection)', () {
    test('maps known labels to canonical providers', () {
      expect(paymentProviderFromOcrLabel('Telebirr'), PaymentProvider.TELEBIRR);
      expect(paymentProviderFromOcrLabel('CBE'), PaymentProvider.CBE);
      expect(paymentProviderFromOcrLabel('Dashen'), PaymentProvider.DASHEN);
      expect(
        paymentProviderFromOcrLabel('Abyssinia'),
        PaymentProvider.ABYSSINIA,
      );
      expect(paymentProviderFromOcrLabel('CBE Birr'), PaymentProvider.CBEBIRR);
      expect(paymentProviderFromOcrLabel('CBEBirr'), PaymentProvider.CBEBIRR);
      expect(paymentProviderFromOcrLabel('M-Pesa'), PaymentProvider.M_PESA);
    });

    test('keeps CBE Birr distinct from CBE and Telebirr', () {
      final cbeBirr = paymentProviderFromOcrLabel('CBE Birr');
      expect(cbeBirr, PaymentProvider.CBEBIRR);
      expect(cbeBirr, isNot(PaymentProvider.CBE));
      expect(cbeBirr, isNot(PaymentProvider.TELEBIRR));
    });

    test(
      'returns null for uncertain/unknown labels (caller must ask user)',
      () {
        expect(paymentProviderFromOcrLabel(null), isNull);
        expect(paymentProviderFromOcrLabel(''), isNull);
        expect(paymentProviderFromOcrLabel('Unknown Wallet'), isNull);
      },
    );
  });

  group('OcrParser.maskReference (sanitized diagnostics)', () {
    test('masks full references, exposes only style and length', () {
      expect(
        OcrParser.maskReference('TB251115.1234.A123456'),
        'TB-****(21 chars)',
      );
      expect(OcrParser.maskReference('FT26318TT5JWN'), 'FT-****(13 chars)');
      expect(OcrParser.maskReference(null), 'null');
    });
  });
}
