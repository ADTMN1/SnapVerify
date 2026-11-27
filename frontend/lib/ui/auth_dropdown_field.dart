import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'auth_field_shell.dart';

class AuthDropdownField extends StatefulWidget {
  const AuthDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    this.error,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final String? error;
  final VoidCallback onTap;

  @override
  State<AuthDropdownField> createState() => _AuthDropdownFieldState();
}

class _AuthDropdownFieldState extends State<AuthDropdownField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    return Semantics(
      button: true,
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AuthFieldShell(
                label: widget.label,
                hasError: hasError,
                hovered: _hovered,
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: AppTokens.eyeIconSize,
                      color: hasError ? AppTokens.danger : AppTokens.inkMuted,
                    ),
                    const SizedBox(width: AppTokens.dropdownIconGap),
                    Expanded(
                      child: Text(
                        widget.value ?? widget.placeholder,
                        style: widget.value == null
                            ? AppText.authHint
                            : AppText.authInput,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_outlined,
                      size: AppTokens.eyeIconSize,
                      color: AppTokens.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
              child: Text(
                widget.error!,
                style: AppText.authError,
              ),
            ),
        ],
      ),
    );
  }
}
