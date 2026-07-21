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
    );
  }

  static void showError(String message) {
    _showToast(
      message,
      TwColors.red500,
      Colors.white,
      Icons.error_outline,
    );
  }

  static void showInfo(String message) {
    _showToast(
      message,
      TwColors.sky500,
      Colors.white,
      Icons.info_outline,
    );
  }

  static void _showToast(
    String message,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
