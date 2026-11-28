import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthBottomLine extends StatelessWidget {
  const AuthBottomLine({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            prompt,
            style: AppText.authBottomPrompt,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(AppTokens.tapTarget, AppTokens.tapTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.togglePadding,
            ),
          ),
          child: Text(action, style: AppText.authBottomAction),
        ),
      ],
    );
  }
}
