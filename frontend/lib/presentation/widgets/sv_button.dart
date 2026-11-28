import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';
import 'sv_loader.dart';

enum SVButtonType { primary, secondary, outline, danger, ghost }

class SVButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final SVButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? height;
  final double borderRadius;

  const SVButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = SVButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = AppTokens.buttonHeight,
    this.borderRadius = AppTokens.buttonRadius,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? AppTokens.buttonHeight;
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(_backgroundColor),
          foregroundColor: WidgetStateProperty.all(_foregroundColor),
          minimumSize: WidgetStateProperty.all(
            Size(isFullWidth ? double.infinity : 0, buttonHeight),
          ),
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              horizontal: isFullWidth ? AppTokens.spaceXl : AppTokens.spaceLg,
              vertical: buttonHeight <= AppTokens.buttonHeightSmall
                  ? AppTokens.spaceXs
                  : AppTokens.spaceMd,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: _borderSide,
            ),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [SvLoader.button(color: _foregroundColor)],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppTokens.componentIconMd),
                    const SizedBox(width: AppTokens.spaceSm),
                  ],
                  Text(
                    text,
                    style: AppTokens.manrope(
                      size: AppTokens.textBodyLarge,
                      weight: FontWeight.w600,
                      color: _foregroundColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (type) {
      case SVButtonType.primary:
        return AppTokens.accent;
      case SVButtonType.secondary:
        return AppTokens.obsidian950;
      case SVButtonType.outline:
      case SVButtonType.ghost:
        return AppTokens.transparent;
      case SVButtonType.danger:
        return AppTokens.error;
    }
  }

  Color get _foregroundColor {
    switch (type) {
      case SVButtonType.primary:
        return AppTokens.obsidian950;
      case SVButtonType.secondary:
      case SVButtonType.outline:
      case SVButtonType.danger:
      case SVButtonType.ghost:
        return AppTokens.white;
    }
  }

  BorderSide get _borderSide {
    switch (type) {
      case SVButtonType.outline:
        return BorderSide(
          color: AppTokens.white.withValues(alpha: AppTokens.alphaStrong),
          width: AppTokens.componentBorderWidthStrong,
        );
      default:
        return BorderSide.none;
    }
  }
}
