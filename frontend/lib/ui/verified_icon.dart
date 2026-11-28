import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class VerifiedIconPainter extends CustomPainter {
  const VerifiedIconPainter({this.color = AppTokens.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 120;
    canvas.save();
    canvas.scale(scale);

    final brackets = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5;
    canvas.drawPath(_bracketsPath(), brackets);

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppTokens.white
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    accent.strokeWidth = 5;
    canvas.drawCircle(const Offset(60, 60), 28.76, accent);

    accent.strokeWidth = 6.5;
    canvas.drawPath(_checkPath(), accent);

    canvas.restore();
  }

  Path _bracketsPath() {
    const radius = 11.4;
    return Path()
      ..moveTo(35.2, 5.95)
      ..lineTo(17.36, 5.95)
      ..arcTo(
        Rect.fromCircle(center: const Offset(17.36, 17.36), radius: radius),
        -math.pi / 2,
        -math.pi / 2,
        false,
      )
      ..lineTo(5.95, 34.71)
      ..moveTo(84.79, 5.95)
      ..lineTo(102.64, 5.95)
      ..arcTo(
        Rect.fromCircle(center: const Offset(102.64, 17.36), radius: radius),
        -math.pi / 2,
        math.pi / 2,
        false,
      )
      ..lineTo(114.05, 34.71)
      ..moveTo(5.95, 85.29)
      ..lineTo(5.95, 102.64)
      ..arcTo(
        Rect.fromCircle(center: const Offset(17.36, 102.64), radius: radius),
        math.pi,
        -math.pi / 2,
        false,
      )
      ..lineTo(35.2, 114.05)
      ..moveTo(114.05, 85.29)
      ..lineTo(114.05, 102.64)
      ..arcTo(
        Rect.fromCircle(center: const Offset(102.64, 102.64), radius: radius),
        0,
        math.pi / 2,
        false,
      )
      ..lineTo(84.79, 114.05);
  }

  Path _checkPath() {
    return Path()
      ..moveTo(46.36, 61.24)
      ..lineTo(55.79, 70.66)
      ..lineTo(73.88, 50.08);
  }

  @override
  bool shouldRepaint(covariant VerifiedIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class VerifiedIcon extends StatelessWidget {
  const VerifiedIcon({super.key, this.size = 80, this.color = AppTokens.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTokens.obsidian950,
        borderRadius: BorderRadius.circular(AppTokens.radiusLogo),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: VerifiedIconPainter(color: color),
      ),
    );
  }
}
