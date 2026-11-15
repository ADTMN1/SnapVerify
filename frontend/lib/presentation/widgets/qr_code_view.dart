import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/tailwind.dart';

/// Renders a SnapVerify payment-account QR code.
///
/// The widget always paints on white: QR scanners require a light quiet zone
/// and a dark module colour, regardless of the app theme.
class SVQrCode extends StatelessWidget {
  final String data;
  final double size;
  final double padding;
  final String semanticsLabel;

  const SVQrCode({
    super.key,
    required this.data,
    this.size = 220,
    this.padding = 14,
    this.semanticsLabel = 'SnapVerify payment account QR code',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        semanticsLabel: semanticsLabel,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: TwColors.slate900,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: TwColors.slate900,
        ),
      ),
    );
  }
}

/// Generates, downloads and shares QR artifacts.
///
/// PNGs are rendered directly from [QrPainter] (not by screenshotting a
/// widget), so exported files are crisp at print resolution and contain only
/// the QR code — no masked account number, holder name or other app chrome.
class QrImageExporter {
  QrImageExporter._();

  static const double defaultExportSize = 1024;
  static const double _exportPadding = 72;

  /// Render [data] to a high-resolution PNG with a white background and a
  /// quiet zone, as required for reliable scanning and printing.
  static Future<Uint8List> renderPng(
    String data, {
    double size = defaultExportSize,
    double padding = _exportPadding,
  }) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: TwColors.slate900,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: TwColors.slate900,
      ),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final canvasSize = Size(size, size);

    canvas.drawRect(Offset.zero & canvasSize, Paint()..color = Colors.white);

    final inner = size - (padding * 2);
    if (inner <= 0) {
      throw ArgumentError('QR padding is larger than the export size.');
    }
    canvas.save();
    canvas.translate(padding, padding);
    painter.paint(canvas, Size(inner, inner));
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw Exception('Could not encode the QR code image.');
      }
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  /// Save the PNG through the platform's download/save flow.
  static Future<String> download(Uint8List bytes, {required String fileName}) {
    return FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }

  /// Share the PNG file plus an optional message (usually the QR link).
  static Future<void> shareImage(
    Uint8List bytes, {
    required String fileName,
    String? text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Share just the QR deep link as text.
  static Future<void> shareLink(
    String url, {
    String? subject,
    Rect? sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: url,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Stable, human-readable file name that carries no banking data.
  static String fileNameFor({
    required String provider,
    required String publicId,
  }) {
    final slug = provider.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final shortId = publicId.length > 8 ? publicId.substring(0, 8) : publicId;
    return 'snapverify-qr-$slug-$shortId.png';
  }
}
