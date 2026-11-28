import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'auth_field_shell.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.label,
    required this.hint,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.autofill,
    this.textInputAction,
    this.onNext,
    this.onDone,
    this.suffix,
    this.maxLength,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String label;
  final String hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? autofill;
  final TextInputAction? textInputAction;
  final VoidCallback? onNext;
  final VoidCallback? onDone;
  final Widget? suffix;
  final int? maxLength;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null;
    return Semantics(
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.text,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: () => widget.focusNode.requestFocus(),
              child: AuthFieldShell(
                label: widget.label,
                focused: widget.focused,
                hasError: hasError,
                hovered: _hovered,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        obscureText: widget.obscure,
                        autocorrect: !widget.obscure,
                        enableSuggestions: !widget.obscure,
                        keyboardType: widget.keyboardType,
                        maxLength: widget.maxLength,
                        textInputAction: widget.textInputAction,
                        autofillHints: widget.autofill == null
                            ? null
                            : [widget.autofill!],
                        cursorColor: AppTokens.obsidian950,
                        textAlignVertical: TextAlignVertical.center,
                        style: AppText.authInput,
                        onSubmitted: widget.onDone == null
                            ? (widget.onNext == null
                                  ? null
                                  : (_) => widget.onNext!())
                            : (_) => widget.onDone!(),
                        decoration: InputDecoration(
                          hintText: widget.hint,
                          hintStyle: AppText.authHint,
                          filled: false,
                          fillColor: AppTokens.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    if (widget.suffix != null) widget.suffix!,
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.fieldErrorGap),
              child: Text(widget.error!, style: AppText.authError),
            ),
        ],
      ),
    );
  }
}
