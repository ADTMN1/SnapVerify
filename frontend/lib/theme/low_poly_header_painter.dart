import 'package:flutter/material.dart';
import 'app_tokens.dart';

class LowPolyHeaderPainter extends CustomPainter {
  const LowPolyHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = AppTokens.headerBase
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, background);

    final facets = <(Offset, Offset, Offset, Color)>[
      (
        Offset.zero,
        Offset(size.width * 0.42, 0),
        Offset(size.width * 0.18, size.height * 0.62),
        AppTokens.headerFacetA,
      ),
      (
        Offset(size.width * 0.42, 0),
        Offset(size.width * 0.78, 0),
        Offset(size.width * 0.54, size.height * 0.48),
        AppTokens.headerFacetB,
      ),
      (
        Offset(size.width * 0.78, 0),
        Offset(size.width, 0),
        Offset(size.width, size.height * 0.55),
        AppTokens.headerFacetA,
      ),
      (
        Offset.zero,
        Offset(size.width * 0.18, size.height * 0.62),
        Offset(0, size.height),
        AppTokens.headerFacetC,
      ),
      (
        Offset(size.width * 0.18, size.height * 0.62),
        Offset(size.width * 0.54, size.height * 0.48),
        Offset(size.width * 0.46, size.height),
        AppTokens.headerFacetB,
      ),
      (
        Offset(size.width * 0.54, size.height * 0.48),
        Offset(size.width, size.height * 0.55),
        Offset(size.width, size.height),
        AppTokens.headerFacetC,
      ),
      (
        Offset(size.width * 0.46, size.height),
        Offset(size.width * 0.54, size.height * 0.48),
        Offset(size.width, size.height),
        AppTokens.headerFacetA,
      ),
    ];

    for (final facet in facets) {
      final paint = Paint()
        ..color = facet.$4
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(facet.$1.dx, facet.$1.dy)
        ..lineTo(facet.$2.dx, facet.$2.dy)
        ..lineTo(facet.$3.dx, facet.$3.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
