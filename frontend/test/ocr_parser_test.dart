import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:snapverify/core/utils/ocr_parser.dart';

RecognizedText _text(List<String> lines) {
  final fullText = lines.join('\n');
  final blocks = <TextBlock>[
    TextBlock(
      text: fullText,
      boundingBox: const Rect.fromLTWH(0, 0, 100, 100),
      cornerPoints: const [],
      recognizedLanguages: const [],
      lines: [
        for (var i = 0; i < lines.length; i++)
          TextLine(
            text: lines[i],
            boundingBox: Rect.fromLTWH(0, i * 12.0, 100, 12),
            cornerPoints: const [],
            recognizedLanguages: const [],
            confidence: 1,
            angle: 0,
            elements: lines[i]
                .split(' ')
                .where((e) => e.isNotEmpty)
                .map((e) => TextElement(
                      text: e,
                      boundingBox: Rect.fromLTWH(0, i * 12.0, 50, 12),
                      cornerPoints: const [],
                      recognizedLanguages: const [],
                      confidence: 1,
                      angle: 0,
                      symbols: const [],
                    ))
                .toList(),
          ),
      ],
    ),
  ];
  return RecognizedText(text: fullText, blocks: blocks);
}

void main() {
  test('Telebirr receipt — numeric transaction no', () {
    final result = OcrParser.extractTransaction(_text([
      'Telebirr',
      'Transaction Successful',
      'Transaction No: 25111573829174',
      'Amount: 500.00 ETB',
      'Date: 15/11/2026 17:05',
    ]));
    expect(result, isNotNull,
        reason: 'Should extract numeric Telebirr transaction no');
  });

  test('Telebirr receipt — TB-prefixed reference keeps dotted parts', () {
    final result = OcrParser.extractTransaction(_text([
      'Telebirr',
      'Transaction ID: TB251115.1234.A123456',
      'Amount: 350.50 ETB',
    ]));
    expect(result, isNotNull);
    expect(result!.referenceId, 'TB251115.1234.A123456',
        reason: 'Dotted Telebirr reference must not be truncated');
    print('extracted: ${result.referenceId} provider=${result.provider}');
  });

  test('CBE receipt still works', () {
    final result = OcrParser.extractTransaction(_text([
      'Commercial Bank of Ethiopia',
      'Reference: FT25115A1234',
      'Suffix: 1000516323381',
      'Amount: 1,200.00 ETB',
    ]));
    expect(result, isNotNull);
    print('extracted: ${result?.referenceId} suffix=${result?.suffix}');
  });

  test('labeled token scan — real Telebirr receipt OCR layout (jumbled lines)', () {
    const text = '''
Transaction Time:
Transaction Type: Transfer Money
Transaction To: Ibrahi
Successful-
Payment Method
Transaction Number:
-2.00
(ETB)
Payment QR Code
2026/10/31 23:02:24
Transfer Money
Ibrahi
DJV9JIVHMR
''';
    expect(OcrParser.extractLabeledReference(text), 'DJV9JIVHMR');
  });

  test('labeled token scan — same-line value still works', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: DJV9JIVHMR'),
      'DJV9JIVHMR',
    );
  });

  test('labeled token scan rejects amounts, dates and plain words', () {
    const text = '''
Transaction Number:
-2.00
(ETB)
2026/10/31 23:02:24
Transfer Money
Ibrahi
''';
    expect(OcrParser.extractLabeledReference(text), isNull);
  });

  test('labeled token scan ignores non-transaction labels', () {
    expect(
      OcrParser.extractLabeledReference('Order No: 1234567 Payment Method: Telebirr'),
      isNull,
    );
  });

  test('labeled token scan rejects date-like references (DD/MM/YYYY)', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 15/11/2026'),
      isNull,
    );
  });

  test('labeled token scan rejects date-like references (DD-MM-YYYY)', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 15-11-2026'),
      isNull,
    );
  });

  test('labeled token scan rejects time-like references (HH:mm:ss)', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 23:02:24'),
      isNull,
    );
  });

  test('labeled token scan rejects time-like references (HH:mm)', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 17:05'),
      isNull,
    );
  });

  test('labeled token scan rejects decimal amounts', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 500.00'),
      isNull,
    );
    expect(
      OcrParser.extractLabeledReference('Transaction Number: 1,200.00'),
      isNull,
    );
  });

  test('labeled token scan still accepts valid alphanumeric references', () {
    expect(
      OcrParser.extractLabeledReference('Transaction Number: FT25115A1234'),
      'FT25115A1234',
    );
    expect(
      OcrParser.extractLabeledReference('Transaction Number: DJV9JIVHMR'),
      'DJV9JIVHMR',
    );
  });
}
