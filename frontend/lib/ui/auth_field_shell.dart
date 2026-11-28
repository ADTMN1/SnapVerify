import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthFieldShell extends StatelessWidget {
  const AuthFieldShell({
    super.key,
    required this.label,
    required this.child,
    this.focused = false,
    this.hasError = false,
    this.hovered = false,
  });

  final String label;
  final Widget child;
  final bool focused;
  final bool hasError;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? AppTokens.danger
        : focused
        ? AppTokens.obsidian950
        : hovered
        ? AppTokens.ice400
        : AppTokens.ice200;
    final borderWidth = focused
        ? AppTokens.focusBorderWidth
        : AppTokens.inputBorderWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTokens.motionFast),
      curve: AppTokens.curveStandard,
      constraints: const BoxConstraints(minHeight: AppTokens.inputHeight),
      padding: const EdgeInsets.all(AppTokens.focusRingWidth),
      decoration: BoxDecoration(
        color: AppTokens.transparent,
        borderRadius: BorderRadius.circular(AppTokens.inputRadius),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: AppTokens.motionFast),
            curve: AppTokens.curveStandard,
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: AppTokens.inputHeight - AppTokens.focusRingWidth * 2,
            ),
            decoration: BoxDecoration(
              color: AppTokens.transparent,
              borderRadius: BorderRadius.circular(AppTokens.inputRadius),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.inputPaddingH - AppTokens.focusRingWidth,
              ),
              child: child,
            ),
          ),
          Positioned(
            top: -AppTokens.labelSize / 2,
            left:
                AppTokens.inputPaddingH -
                AppTokens.focusRingWidth -
                AppTokens.labelNotchPaddingH,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.labelNotchPaddingH,
              ),
              color: AppTokens.ice50,
              child: Text(label, style: AppText.authFieldLabel),
            ),
          ),
        ],
      ),
    );
  }
}
