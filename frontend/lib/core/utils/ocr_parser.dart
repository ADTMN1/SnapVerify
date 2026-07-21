
import 'dart:developer' as dev;
import 'dart:math' as Math;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ExtractedTransaction {
  final String referenceId;
  final double? amount;
  final String? provider; // Telebirr, CBE, Dashen, Abyssinia, CBEBirr, M-Pesa
  final DateTime? dateTime;
  final String? suffix; // For FT references (8 digits for CBE, 5 digits for Abyssinia

  ExtractedTransaction({
    required this.referenceId,
    this.amount,
    this.provider,
    this.dateTime,
    this.suffix,
  });
}

class OcrParser {
  static final List<String> providers = [
    'Telebirr',
    'CBE',
    'Dashen',
    'Abyssinia',
    'CBEBirr',
    'M-Pesa',
    'mpesa',
    'Commercial Bank',
    'Dashen Bank',
    'Abyssinia Bank',
  ];

  static ExtractedTransaction? extractTransaction(RecognizedText recognizedText) {
    final allText = recognizedText.text;
    dev.log('[OcrParser] Full text extracted: ${allText.length} chars');

    // Extract reference ID and suffix
    Map<String, String?>? referenceAndSuffix = _extractReferenceAndSuffix(recognizedText);
    
    // If V1 didn't find FT reference with suffix, try V2 with multi-line search
    if (referenceAndSuffix != null && 
        referenceAndSuffix['referenceId']?.startsWith('FT') == true && 
        referenceAndSuffix['suffix'] == null) {
      dev.log('[OcrParser] FT reference found but no suffix, trying V2 multi-line extraction...');
      final v2Result = _extractReferenceAndSuffixV2(recognizedText);
      if (v2Result != null && v2Result['suffix'] != null) {
        dev.log('[OcrParser] ✓ V2 found suffix: ${v2Result['suffix']}');
        referenceAndSuffix = v2Result;
      }
    }
    
    final referenceId = referenceAndSuffix?['referenceId'];
    final suffix = referenceAndSuffix?['suffix'];
    if (referenceId == null) {
      return null;
    }

    final amount = _extractAmount(recognizedText);
    final provider = _extractProvider(recognizedText);
    final dateTime = _extractDateTime(recognizedText);

    dev.log('[OcrParser] Extracted: ref=$referenceId, suffix=$suffix, amount=$amount, provider=$provider');

    return ExtractedTransaction(
      referenceId: referenceId,
      amount: amount,
      provider: provider,
      dateTime: dateTime,
      suffix: suffix,
    );
  }

  static Map<String, String?>? _extractReferenceAndSuffix(RecognizedText text) {
    final allText = text.text;
    dev.log('[_extractReferenceAndSuffix] Starting extraction from ${text.blocks.length} blocks');
    
    // First try FT pattern: FT + digits + suffix (optional)
    final ftMatch = RegExp(r'(FT[0-9A-Z]+)\s*\/?\s*([0-9]{5,8})?', caseSensitive: false).firstMatch(allText);
    if (ftMatch != null) {
      final ref = ftMatch.group(1)?.toUpperCase();
      final suffix = ftMatch.group(2);
      if (ref != null) {
        dev.log('[_extractReferenceAndSuffix] Found FT reference: $ref, suffix: $suffix');
        return {'referenceId': ref, 'suffix': suffix};
      }
    }
    
    // Common reference patterns (alphanumeric, sometimes with hyphens)
    final patterns = [
      RegExp(r'TRX[-\s]?[0-9A-Fa-f]{8,32}'),
      RegExp(r'Ref(?:erence)?[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'Transaction[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'ID[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'([0-9A-Fa-f]{8,20})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final ref = match.groupCount > 0 ? (match.group(1) ?? match.group(0)!) : match.group(0)!;
        final cleanRef = ref.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').trim();
        if (cleanRef.length >= 6) {
          return {'referenceId': cleanRef, 'suffix': null};
        }
      }
    }

    // Fallback: look for long numbers in individual blocks
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final lineText = line.text;
        final numMatch = RegExp(r'\d{8,}').firstMatch(lineText);
        if (numMatch != null) {
          return {'referenceId': numMatch.group(0)!, 'suffix': null};
        }
      }
    }

    return null;
  }
  
  static Map<String, String?>? _extractReferenceAndSuffixV2(RecognizedText text) {
    final allText = text.text;
    dev.log('[_extractReferenceAndSuffixV2] Starting multi-line extraction from ${text.blocks.length} blocks');
    
    // Collect all lines with their block context
    final allLines = <(TextBlock, TextLine)>[];
    for (final block in text.blocks) {
      dev.log('[_extractReferenceAndSuffixV2] Block with ${block.lines.length} lines');
      for (final line in block.lines) {
        allLines.add((block, line));
      }
    }
    
    // Step 1: Try FT pattern with multi-line suffix search
    for (int i = 0; i < allLines.length; i++) {
      final (block, line) = allLines[i];
      final lineText = line.text;
      
      // Check for FT reference on this line
      final ftMatch = RegExp(r'(FT[0-9A-Z]+)', caseSensitive: false).firstMatch(lineText);
      if (ftMatch != null) {
        final ref = ftMatch.group(1)?.toUpperCase();
        dev.log('[_extractReferenceAndSuffixV2] Found FT reference on line $i: $ref');
        
        // Step 1a: Check same line for suffix (with separator)
        final sameLineSuffix = RegExp(r'(?:FT[0-9A-Z]+)\s*[\/\-:]?\s*([0-9]{5,8})', caseSensitive: false).firstMatch(lineText);
        if (sameLineSuffix != null) {
          final suffix = sameLineSuffix.group(1);
          dev.log('[_extractReferenceAndSuffixV2] ✓ Found suffix on same line: $suffix');
          return {'referenceId': ref, 'suffix': suffix};
        }
        
        // Step 1b: Check next 2 lines for suffix
        for (int j = i + 1; j < Math.min(i + 3, allLines.length); j++) {
          final nextLineText = allLines[j].$2.text;
          dev.log('[_extractReferenceAndSuffixV2] Checking line $j: $nextLineText');
          
          // Check for labeled suffix
          final labeledSuffix = RegExp(r'^(?:Suffix|Sfx|Code|Ref)?[\s\/\-:\|]*([0-9]{5,8})$').firstMatch(nextLineText.trim());
          if (labeledSuffix != null) {
            final suffix = labeledSuffix.group(1);
            dev.log('[_extractReferenceAndSuffixV2] ✓ Found labeled suffix on line $j: $suffix');
            return {'referenceId': ref, 'suffix': suffix};
          }
          
          // Check for standalone 5-8 digit number
          final standaloneSuffix = RegExp(r'^\s*([0-9]{5,8})\s*$').firstMatch(nextLineText);
          if (standaloneSuffix != null) {
            final suffix = standaloneSuffix.group(1);
            dev.log('[_extractReferenceAndSuffixV2] ✓ Found standalone suffix on line $j: $suffix');
            return {'referenceId': ref, 'suffix': suffix};
          }
        }
        
        // Step 1c: Global fallback - scan all lines for any 5-8 digit number
        dev.log('[_extractReferenceAndSuffixV2] No suffix found nearby, scanning entire document...');
        for (int k = 0; k < allLines.length; k++) {
          if (k == i) continue; // Skip the line with FT reference
          final globalLineText = allLines[k].$2.text;
          final globalSuffix = RegExp(r'\b([0-9]{5,8})\b').firstMatch(globalLineText);
          if (globalSuffix != null) {
            final suffix = globalSuffix.group(1);
            dev.log('[_extractReferenceAndSuffixV2] ✓ Found global fallback suffix on line $k: $suffix');
            return {'referenceId': ref, 'suffix': suffix};
          }
        }
        
        // Found FT reference but no suffix
        dev.log('[_extractReferenceAndSuffixV2] Found FT reference but no suffix anywhere');
        return {'referenceId': ref, 'suffix': null};
      }
    }
    
    // Step 2: Try other reference patterns (same as before)
    final patterns = [
      RegExp(r'TRX[-\s]?[0-9A-Fa-f]{8,32}'),
      RegExp(r'Ref(?:erence)?[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'Transaction[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'ID[#:\s]+([A-Za-z0-9\-]+)', caseSensitive: false),
      RegExp(r'([0-9A-Fa-f]{8,20})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final ref = match.groupCount > 0 ? (match.group(1) ?? match.group(0)!) : match.group(0)!;
        final cleanRef = ref.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').trim();
        if (cleanRef.length >= 6) {
          return {'referenceId': cleanRef, 'suffix': null};
        }
      }
    }

    // Fallback: look for long numbers in individual blocks
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final lineText = line.text;
        final numMatch = RegExp(r'\d{8,}').firstMatch(lineText);
        if (numMatch != null) {
          return {'referenceId': numMatch.group(0)!, 'suffix': null};
        }
      }
    }

    return null;
  }

  static double? _extractAmount(RecognizedText text) {
    // First pass: look for amounts with context clues first (highest priority)
    final contextPatterns = [
      // Pattern 1: Amount preceded by keyword like "Total", "Amount", "Paid", etc.
      RegExp(
        r'(?:Total|Amount|Paid|Payment|Debited|Sent|Received)\s*:?\s*(?:ETB|Br|Birr|₹|\$|€)?\s*([0-9]{1,3}(?:[,.][0-9]{3})*(?:[,.][0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // Pattern 2: Currency symbol followed by amount
      RegExp(
        r'(?:ETB|Br|Birr|₹|\$|€)\s*([0-9]{1,3}(?:[,.][0-9]{3})*(?:[,.][0-9]{1,2})?)',
        caseSensitive: false,
      ),
      // Pattern 3: Amount followed by currency symbol
      RegExp(
        r'([0-9]{1,3}(?:[,.][0-9]{3})*(?:[,.][0-9]{1,2})?)\s*(?:ETB|Br|Birr|₹|\$|€)',
        caseSensitive: false,
      ),
    ];

    // Second pass: more flexible patterns (fallback)
    final fallbackPatterns = [
      RegExp(
        r'([0-9]{1,3}(?:[,.][0-9]{3})*(?:[,.][0-9]{1,2})?)',
        caseSensitive: false,
      ),
    ];

    double? bestAmount;
    bool foundWithContext = false;

    // Try context patterns first
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final lineText = line.text;
        for (final pattern in contextPatterns) {
          final matches = pattern.allMatches(lineText);
          for (final match in matches) {
            final amountStr = match.group(1);
            if (amountStr != null) {
              final amount = _parseAmount(amountStr);
              if (amount != null && amount > 0) {
                // Prefer amounts with context
                if (!foundWithContext || amount > (bestAmount ?? 0)) {
                  bestAmount = amount;
                  foundWithContext = true;
                }
              }
            }
          }
        }
      }
    }

    // If no amount found with context, try fallback patterns
    if (!foundWithContext) {
      double? maxFallbackAmount;
      for (final block in text.blocks) {
        for (final line in block.lines) {
          final lineText = line.text;
          for (final pattern in fallbackPatterns) {
            final matches = pattern.allMatches(lineText);
            for (final match in matches) {
              final amountStr = match.group(1);
              if (amountStr != null) {
                final amount = _parseAmount(amountStr);
                if (amount != null && amount > 0) {
                  // Ignore numbers that are too long (likely phone numbers/ids)
                  if (amountStr.replaceAll(RegExp(r'[,.]'), '').length <= 8) {
                    if (maxFallbackAmount == null || amount > maxFallbackAmount) {
                      maxFallbackAmount = amount;
                    }
                  }
                }
              }
            }
          }
        }
      }
      bestAmount = maxFallbackAmount;
    }

    return bestAmount;
  }

  static double? _parseAmount(String amountStr) {
    try {
      // Normalize: handle both comma and dot as thousand separators and decimal separators
      String normalized;
      if (amountStr.contains(',') && amountStr.contains('.')) {
        // If both are present: the last one is decimal
        final lastSeparator = amountStr.lastIndexOf(RegExp(r'[,.]'));
        final before = amountStr.substring(0, lastSeparator).replaceAll(RegExp(r'[,.]'), '');
        final after = amountStr.substring(lastSeparator + 1);
        normalized = '$before.$after';
      } else if (amountStr.contains(',')) {
        // Only comma: check if it's thousand or decimal
        if (amountStr.split(',').last.length == 2) {
          // Comma is decimal (e.g., 123,45)
          normalized = amountStr.replaceAll(',', '.');
        } else {
          // Comma is thousand separator (e.g., 1,234)
          normalized = amountStr.replaceAll(',', '');
        }
      } else {
        // Only dot or no separators
        normalized = amountStr;
      }
      return double.tryParse(normalized);
    } catch (_) {
      return null;
    }
  }

  static String? _extractProvider(RecognizedText text) {
    final textLower = text.text.toLowerCase();
    
    if (textLower.contains('telebirr')) return 'Telebirr';
    if (textLower.contains('cbebirr') || textLower.contains('cbe birr')) return 'CBEBirr';
    if (textLower.contains('commercial bank') || textLower.contains(' cbe ')) return 'CBE';
    if (textLower.contains('dashen')) return 'Dashen';
    if (textLower.contains('abyssinia')) return 'Abyssinia';
    if (textLower.contains('m-pesa') || textLower.contains('mpesa')) return 'M-Pesa';
    
    return null;
  }

  static DateTime? _extractDateTime(RecognizedText text) {
    // Common date/time patterns
    final patterns = [
      RegExp(r'(\d{2})[\/\-](\d{2})[\/\-](\d{4})\s+(\d{1,2}):(\d{2})'),
      RegExp(r'(\d{4})[\/\-](\d{2})[\/\-](\d{2})\s+(\d{1,2}):(\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.text);
      if (match != null) {
        try {
          // Try to parse, handle different orderings
          final groups = match.groups([1, 2, 3, 4, 5]);
          int? year, month, day, hour, minute;
          
          // Check if first group is 4-digit year
          if (groups[2] != null && groups[2]!.length == 4) {
            year = int.tryParse(groups[2]!);
            month = int.tryParse(groups[0]!);
            day = int.tryParse(groups[1]!);
          } else if (groups[0] != null && groups[0]!.length == 4) {
            year = int.tryParse(groups[0]!);
            month = int.tryParse(groups[1]!);
            day = int.tryParse(groups[2]!);
          } else {
            // Assume DD/MM/YYYY or MM/DD/YYYY - default to DD/MM/YYYY for ET
            day = int.tryParse(groups[0]!);
            month = int.tryParse(groups[1]!);
            year = int.tryParse(groups[2]!);
          }
          
          hour = int.tryParse(groups[3]!);
          minute = int.tryParse(groups[4]!);
          
          if (year != null && month != null && day != null && hour != null && minute != null) {
            return DateTime(year, month, day, hour, minute);
          }
        } catch (_) {}
      }
    }
    
    return null;
  }
}
