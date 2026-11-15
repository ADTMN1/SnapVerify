import 'package:flutter_test/flutter_test.dart';
import 'package:snapverify/core/utils/qr_link.dart';

void main() {
  const id = '0123456789abcdef01234567';

  group('QrLink.parsePublicId', () {
    test('accepts the versioned SnapVerify deep link', () {
      expect(QrLink.parsePublicId('https://qr.snapverify.app/qr/v1/$id'), id);
      expect(QrLink.parsePublicId('http://10.0.2.2:3000/qr/v1/$id'), id);
    });

    test('normalises upper-case identifiers to lower case', () {
      expect(
        QrLink.parsePublicId('https://example.com/qr/v1/${id.toUpperCase()}'),
        id,
      );
    });

    test('rejects payloads that are not SnapVerify QR codes', () {
      const rejected = [
        'hello world',
        'https://example.com',
        'https://example.com/qr/v2/$id',
        'https://example.com/qr/v1/not-a-valid-id',
        'https://example.com/qr/v1/$id/extra',
        'https://example.com/qr/v1/$id?amount=100',
        'https://example.com/qr/v1/$id#fragment',
        'https://user:pass@example.com/qr/v1/$id',
        'ftp://example.com/qr/v1/$id',
        '',
      ];
      for (final payload in rejected) {
        expect(QrLink.parsePublicId(payload), isNull, reason: payload);
      }
    });

    test('rejects oversized payloads', () {
      expect(
        QrLink.parsePublicId('https://example.com/qr/v1/$id${'a' * 2048}'),
        isNull,
      );
    });
  });

  group('QrLink.build', () {
    test('builds the versioned deep link and trims trailing slashes', () {
      expect(
        QrLink.build('https://qr.snapverify.app/', id),
        'https://qr.snapverify.app/qr/v1/$id',
      );
    });

    test('round-trips through the parser', () {
      final url = QrLink.build('https://qr.snapverify.app', id);
      expect(QrLink.parsePublicId(url), id);
    });
  });

  test('isValidPublicId only accepts 24 hex characters', () {
    expect(QrLink.isValidPublicId(id), isTrue);
    expect(QrLink.isValidPublicId(id.substring(1)), isFalse);
    expect(QrLink.isValidPublicId('zzzzzzzzzzzzzzzzzzzzzzzz'), isFalse);
    expect(QrLink.isValidPublicId(null), isFalse);
  });

  test('hostOf exposes only the host for display', () {
    expect(
      QrLink.hostOf('https://qr.snapverify.app/qr/v1/$id'),
      'qr.snapverify.app',
    );
    expect(QrLink.hostOf(null), isNull);
  });
}
