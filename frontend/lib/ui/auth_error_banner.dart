import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.errorPadding),
        decoration: BoxDecoration(
          color: AppTokens.dangerBg,
          borderRadius: BorderRadius.circular(AppTokens.errorRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTokens.alertOnDanger,
              size: AppTokens.errorIconSize,
            ),
            const SizedBox(width: AppTokens.dropdownIconGap),
            Expanded(
              child: Text(
                message,
                style: AppTokens.dmSans(
                  size: AppTokens.errorTextSize,
                  weight: FontWeight.w500,
                  color: AppTokens.alertOnDanger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
