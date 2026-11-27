import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppTokens.backButtonSize,
          height: AppTokens.backButtonSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.white,
            borderRadius: BorderRadius.circular(AppTokens.backButtonRadius),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTokens.ink,
            size: AppTokens.backButtonIconSize,
          ),
        ),
      ),
    );
  }
}
