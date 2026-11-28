import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppHeaderPatternPainter extends CustomPainter {
  const AppHeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = AppTokens.obsidian950
        ..isAntiAlias = false,
    );

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final tileWidth = AppTokens.patternTileWidth;
    final tileHeight = AppTokens.patternTileHeight;
    for (double y = 0; y < size.height; y += tileHeight) {
      for (double x = 0; x < size.width; x += tileWidth) {
        canvas.save();
        canvas.translate(x, y);
        _drawTriangle(canvas, paint, AppTokens.triangleLight, [
          const Offset(0, 0),
          const Offset(40, 0),
          const Offset(20, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.triangleDark, [
          const Offset(20, 35),
          const Offset(60, 35),
          const Offset(40, 0),
        ]);
        _drawTriangle(canvas, paint, AppTokens.obsidian800, [
          const Offset(40, 0),
          const Offset(80, 0),
          const Offset(60, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.triangleDark, [
          const Offset(0, 0),
          const Offset(20, 35),
          const Offset(0, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.triangleDark, [
          const Offset(80, 0),
          const Offset(80, 35),
          const Offset(60, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.obsidian900, [
          const Offset(20, 35),
          const Offset(60, 35),
          const Offset(40, 70),
        ]);
        _drawTriangle(canvas, paint, AppTokens.obsidian800, [
          const Offset(0, 70),
          const Offset(40, 70),
          const Offset(20, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.triangleLight, [
          const Offset(40, 70),
          const Offset(80, 70),
          const Offset(60, 35),
        ]);
        _drawTriangle(canvas, paint, AppTokens.obsidian900, [
          const Offset(0, 35),
          const Offset(20, 35),
          const Offset(0, 70),
        ]);
        _drawTriangle(canvas, paint, AppTokens.obsidian900, [
          const Offset(60, 35),
          const Offset(80, 35),
          const Offset(80, 70),
        ]);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _drawTriangle(
  Canvas canvas,
  Paint paint,
  Color color,
  List<Offset> points,
) {
  paint.color = color;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  path.close();
  canvas.drawPath(path, paint);
}
