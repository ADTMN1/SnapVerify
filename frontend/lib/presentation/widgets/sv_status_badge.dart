import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

enum BadgeType { success, warning, error, info, neutral }

class SVStatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final bool isSmall;

  const SVStatusBadge({
    super.key,
    required this.text,
    this.type = BadgeType.info,
    this.isSmall = false,
  });

  Color get _backgroundColor {
    switch (type) {
      case BadgeType.success:
        return TwColors.brightGreen.withOpacity(0.15);
      case BadgeType.warning:
        return Colors.orange.withOpacity(0.15);
      case BadgeType.error:
        return TwColors.red500.withOpacity(0.15);
      case BadgeType.info:
        return TwColors.blue500.withOpacity(0.15);
      case BadgeType.neutral:
        return TwColors.slate700;
    }
  }

  Color get _textColor {
    switch (type) {
      case BadgeType.success:
        return TwColors.brightGreen;
      case BadgeType.warning:
        return Colors.orange;
      case BadgeType.error:
        return TwColors.red500;
      case BadgeType.info:
        return TwColors.blue500;
      case BadgeType.neutral:
        return TwColors.white.withOpacity(0.8);
    }
  }

  Color get _borderColor {
    switch (type) {
      case BadgeType.success:
        return TwColors.brightGreen.withOpacity(0.3);
      case BadgeType.warning:
        return Colors.orange.withOpacity(0.3);
      case BadgeType.error:
        return TwColors.red500.withOpacity(0.3);
      case BadgeType.info:
        return TwColors.blue500.withOpacity(0.3);
      case BadgeType.neutral:
        return TwColors.slate600;
    }
  }

  double get _verticalPadding => isSmall ? 4 : 6;
  double get _horizontalPadding => isSmall ? 10 : 14;
  double get _fontSize => isSmall ? 12 : 14;
  FontWeight get _fontWeight => isSmall ? FontWeight.w500 : FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(isSmall ? 6 : 8),
        border: Border.all(
          color: _borderColor,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _textColor,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
        ),
      ),
    );
  }
}
