import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    super.key,
    required this.message,
    this.title,
    this.retryLabel,
    this.onRetry,
  });

  final String message;
  final String? title;
  final String? retryLabel;
  final VoidCallback? onRetry;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: AppTokens.dmSans(
                        size: AppTokens.errorTextSize,
                        weight: FontWeight.w600,
                        color: AppTokens.alertOnDanger,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                  ],
                  Text(
                    message,
                    style: AppTokens.dmSans(
                      size: AppTokens.errorTextSize,
                      weight: FontWeight.w500,
                      color: AppTokens.alertOnDanger,
                    ),
                  ),
                  if (onRetry != null && retryLabel != null) ...[
                    const SizedBox(height: AppTokens.spaceXs),
                    Semantics(
                      button: true,
                      label: retryLabel,
                      child: GestureDetector(
                        onTap: onRetry,
                        child: Text(retryLabel!, style: AppText.authErrorRetry),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
