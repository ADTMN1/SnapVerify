import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

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

  Color get _baseColor {
    switch (type) {
      case BadgeType.success:
        return AppTokens.success;
      case BadgeType.warning:
        return AppTokens.warning;
      case BadgeType.error:
        return AppTokens.error;
      case BadgeType.info:
        return AppTokens.info;
      case BadgeType.neutral:
        return AppTokens.textOnDark;
    }
  }

  Color get _backgroundColor {
    if (type == BadgeType.neutral) return AppTokens.surfaceDark;
    return _baseColor.withValues(alpha: AppTokens.alphaMedium);
  }

  Color get _textColor {
    if (type == BadgeType.neutral) {
      return AppTokens.textOnDark.withValues(alpha: AppTokens.alphaDisabled);
    }
    return _baseColor;
  }

  Color get _borderColor {
    if (type == BadgeType.neutral) return AppTokens.obsidian700;
    return _baseColor.withValues(alpha: AppTokens.alphaStrong);
  }

  double get _verticalPadding =>
      isSmall ? AppTokens.badgeSmallPaddingV : AppTokens.badgePaddingV;
  double get _horizontalPadding =>
      isSmall ? AppTokens.badgeSmallPaddingH : AppTokens.badgePaddingH;
  double get _fontSize =>
      isSmall ? AppTokens.badgeSmallFontSize : AppTokens.badgeFontSize;
  FontWeight get _fontWeight =>
      isSmall ? FontWeight.w500 : FontWeight.w600;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(
          isSmall ? AppTokens.badgeSmallRadius : AppTokens.badgeRadius,
        ),
        border: Border.all(
          color: _borderColor,
          width: AppTokens.componentBorderWidth,
        ),
      ),
      child: Text(
        text,
        style: AppTokens.dmSans(
          size: _fontSize,
          weight: _fontWeight,
          color: _textColor,
        ),
      ),
    );
  }
}
