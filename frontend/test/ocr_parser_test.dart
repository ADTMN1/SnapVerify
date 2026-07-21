import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:snapverify/core/utils/ocr_parser.dart';

TextLine _line(String text) {
  return TextLine(
    text: text,
    elements: [],
    boundingBox: Rect.zero,
    recognizedLanguages: [],
    cornerPoints: [],
    confidence: null,
    angle: null,
  );
}

TextBlock _block(List<TextLine> lines) {
  return TextBlock(
    text: lines.map((line) => line.text).join('\n'),
    lines: lines,
    boundingBox: Rect.zero,
    recognizedLanguages: [],
    cornerPoints: [],
  );
}

RecognizedText _recognizedText(String text, List<TextBlock> blocks) {
  return RecognizedText(text: text, blocks: blocks);
}

void main() {
  group('OcrParser FT suffix extraction', () {
    test('extracts FT reference and same-line suffix', () {
      final recognizedText = _recognizedText(
        'FT26124GWODG/12345678',
        [_block([_line('FT26124GWODG/12345678')])],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, '12345678');
    });

    test('extracts FT reference and suffix on next line', () {
      final recognizedText = _recognizedText(
        'FT26124GWODG\n12345678',
        [_block([_line('FT26124GWODG'), _line('12345678')])],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, '12345678');
    });

    test('extracts FT reference and suffix with label', () {
      final recognizedText = _recognizedText(
        'FT26124GWODG\nSuffix 12345678',
        [_block([_line('FT26124GWODG'), _line('Suffix 12345678')])],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, '12345678');
    });

    test('realistic receipt with amount, ref on line 1, suffix on line 2', () {
      final recognizedText = _recognizedText(
        'Amount: 170.61\nTransaction ID: FT26124GWODG\n12345678\nStatus: Success',
        [
          _block([
            _line('Amount: 170.61'),
            _line('Transaction ID: FT26124GWODG'),
            _line('12345678'),
            _line('Status: Success'),
          ])
        ],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, '12345678');
      expect(result.amount, 170.61);
    });

    test('reference with spaced formatting FT 2612 4GWO DG and suffix', () {
      final recognizedText = _recognizedText(
        'FT 2612 4GWO DG\n12345678',
        [
          _block([
            _line('FT 2612 4GWO DG'),
            _line('12345678'),
          ])
        ],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, '12345678');
    });

    test('no suffix returns null for suffix', () {
      final recognizedText = _recognizedText(
        'FT26124GWODG',
        [_block([_line('FT26124GWODG')])],
      );

      final result = OcrParser.extractTransaction(recognizedText);
      expect(result, isNotNull);
      expect(result!.referenceId, 'FT26124GWODG');
      expect(result.suffix, null);
    });
  });
}

