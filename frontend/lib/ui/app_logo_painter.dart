import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter({this.color = AppTokens.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / AppTokens.logoCoordinateSize;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-AppTokens.logoOffset, -AppTokens.logoOffset);

    final brackets = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = AppTokens.logoBracketStroke;
    canvas.drawPath(_bracketsPath(), brackets);

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    accent.strokeWidth = AppTokens.logoCircleStroke;
    canvas.drawCircle(
      const Offset(AppTokens.logoSourceSize / 2, AppTokens.logoSourceSize / 2),
      AppTokens.logoCircleRadius,
      accent,
    );

    accent.strokeWidth = AppTokens.logoCheckStroke;
    canvas.drawPath(_checkPath(), accent);
    canvas.restore();
  }

  Path _bracketsPath() {
    final path = Path()
      ..moveTo(412, 294)
      ..lineTo(340, 294)
      ..arcTo(
        Rect.fromCircle(center: const Offset(340, 340), radius: 46),
        -math.pi / 2,
        -math.pi / 2,
        false,
      )
      ..lineTo(294, 410)
      ..moveTo(612, 294)
      ..lineTo(684, 294)
      ..arcTo(
        Rect.fromCircle(center: const Offset(684, 340), radius: 46),
        -math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(730, 410)
      ..moveTo(294, 612)
      ..lineTo(294, 684)
      ..arcTo(
        Rect.fromCircle(center: const Offset(340, 684), radius: 46),
        math.pi,
        -math.pi / 2,
        false,
      )
      ..lineTo(412, 730)
      ..moveTo(730, 612)
      ..lineTo(730, 684)
      ..arcTo(
        Rect.fromCircle(center: const Offset(684, 684), radius: 46),
        0,
        math.pi / 2,
        false,
      )
      ..lineTo(612, 730);
    return path;
  }

  Path _checkPath() {
    return Path()
      ..moveTo(457, 517)
      ..lineTo(495, 555)
      ..lineTo(568, 472);
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
