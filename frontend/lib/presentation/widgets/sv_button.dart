import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

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
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ButtonStyle(
          backgroundColor: MaterialStatePropertyAll(_backgroundColor),
          foregroundColor: MaterialStatePropertyAll(_foregroundColor),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: _borderSide,
            ),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _foregroundColor,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
        return TwColors.brightGreen;
      case SVButtonType.secondary:
        return TwColors.slate700;
      case SVButtonType.outline:
        return Colors.transparent;
      case SVButtonType.danger:
        return TwColors.red500;
      case SVButtonType.ghost:
        return Colors.transparent;
    }
  }

  Color get _foregroundColor {
    switch (type) {
      case SVButtonType.primary:
        return TwColors.slate900;
      case SVButtonType.secondary:
        return TwColors.white;
      case SVButtonType.outline:
        return TwColors.white;
      case SVButtonType.danger:
        return TwColors.white;
      case SVButtonType.ghost:
        return TwColors.white;
    }
  }

  BorderSide get _borderSide {
    switch (type) {
      case SVButtonType.outline:
        return BorderSide(
          color: TwColors.white.withOpacity(0.2),
          width: 1.5,
        );
      default:
        return BorderSide.none;
    }
  }
}
