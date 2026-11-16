import 'package:flutter_test/flutter_test.dart';
import 'package:snapverify/core/utils/ocr_parser.dart';
import 'package:snapverify/domain/entities/verification_result.dart';

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

    test('PENDING maps to pending', () {
      final r = VerificationResult.fromJson(payload('PENDING'));
      expect(r.status, VerificationStatus.pending);
    });

    test('unknown statuses map to pending — never a hard invalid', () {
      for (final s in ['SOME_NEW_STATUS', 'SERVICE_UNAVAILABLE', '']) {
        final r = VerificationResult.fromJson(payload(s));
        expect(r.status, VerificationStatus.pending,
            reason: 'status "$s" must map to pending');
      }
    });

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

  group('OcrParser.maskReference (sanitized diagnostics)', () {
    test('masks full references, exposes only style and length', () {
      expect(OcrParser.maskReference('TB251115.1234.A123456'),
          'TB-****(21 chars)');
      expect(OcrParser.maskReference('FT26318TT5JWN'), 'FT-****(13 chars)');
      expect(OcrParser.maskReference(null), 'null');
    });
  });
}
