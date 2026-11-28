import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class PasswordVisibilityButton extends StatelessWidget {
  const PasswordVisibilityButton({
    super.key,
    required this.obscure,
    required this.onTap,
  });

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tooltip = obscure ? 'Show password' : 'Hide password';
    return Semantics(
      button: true,
      label: tooltip,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: AppTokens.tapTarget,
          minHeight: AppTokens.tapTarget,
        ),
        padding: EdgeInsets.zero,
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: AppTokens.eyeIconSize,
          color: AppTokens.inkMuted,
        ),
      ),
    );
  }
}
