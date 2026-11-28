import 'package:flutter/material.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showToast(
      message,
      AppTokens.successStrong,
      Icons.check_circle_outline,
      duration: const Duration(seconds: 3),
    );
  }

  static void showError(String message) {
    _showToast(
      message,
      AppTokens.errorStrong,
      Icons.error_outline,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(String message) {
    _showToast(
      message,
      AppTokens.warningStrong,
      Icons.warning_amber_outlined,
      duration: const Duration(seconds: 4),
    );
  }

  static void showInfo(String message) {
    _showToast(
      message,
      AppTokens.infoStrong,
      Icons.info_outline,
      duration: const Duration(seconds: 3),
    );
  }

  static void showNeutral(String message) {
    _showToast(
      message,
      AppTokens.inkMuted,
      Icons.info_outline,
      duration: const Duration(seconds: 3),
    );
  }

  static void _showToast(
    String message,
    Color iconColor,
    IconData icon, {
    required Duration duration,
  }) {
    scaffoldMessengerKey.currentState?.clearSnackBars();
    final displayMessage = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Error:\s*'), '');

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: AppTokens.componentIconMd),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Text(
                displayMessage,
                style: AppText.bodySmall.copyWith(color: AppTokens.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTokens.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
        margin: const EdgeInsets.all(AppTokens.spaceLg),
        duration: duration,
        elevation: AppTokens.dialogElevation,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceMd,
        ),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }
}
