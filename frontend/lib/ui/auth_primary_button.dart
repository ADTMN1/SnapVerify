import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTokens.buttonHeight,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.obsidian950,
          foregroundColor: AppTokens.white,
          disabledBackgroundColor: AppTokens.obsidian950,
          disabledForegroundColor: AppTokens.white,
          overlayColor: AppTokens.whiteOverlay,
          elevation: AppTokens.cardElevation,
          shadowColor: AppTokens.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.buttonRadius),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: AppTokens.progressSize,
                    height: AppTokens.progressSize,
                    child: CircularProgressIndicator(
                      strokeWidth: AppTokens.progressStroke,
                      valueColor: AlwaysStoppedAnimation(AppTokens.white),
                    ),
                  ),
                  const SizedBox(width: AppTokens.dropdownIconGap),
                  Text(loadingLabel, style: AppText.authButton),
                ],
              )
            : Text(label, style: AppText.authButton),
      ),
    );
  }
}
