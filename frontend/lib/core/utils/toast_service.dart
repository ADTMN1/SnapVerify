import 'package:flutter/material.dart';
import '../tailwind.dart';

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void showSuccess(String message) {
    _showToast(
      message,
      TwColors.brightGreen,
      Colors.black,
      Icons.check_circle_outline,
      duration: const Duration(seconds: 2),
    );
  }

  static void showError(String message) {
    _showToast(
      message,
      TwColors.red500,
      Colors.white,
      Icons.error_outline,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(String message) {
    _showToast(
      message,
      TwColors.amber500,
      Colors.white,
      Icons.warning_amber_outlined,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfo(String message) {
    _showToast(
      message,
      TwColors.sky500,
      Colors.white,
      Icons.info_outline,
      duration: const Duration(seconds: 3),
    );
  }

  static void _showToast(
    String message,
    Color backgroundColor,
    Color textColor,
    IconData icon, {
    required Duration duration,
  }) {
    scaffoldMessengerKey.currentState?.clearSnackBars();
    
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16,
          top: 16,
        ),
        duration: duration,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static BuildContext? _findContext() {
    return scaffoldMessengerKey.currentContext;
  }
}
