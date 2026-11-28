import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class SVInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const SVInputField({
    super.key,
    this.controller,
    this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.focusNode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTokens.dmSans(
              size: AppTokens.textBodySmall,
              weight: FontWeight.w500,
              color: AppTokens.white.withValues(
                alpha: AppTokens.alphaPrimaryMuted,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.formLabelGap),
        ],
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppTokens.obsidian700 : AppTokens.obsidian800,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(
              color: AppTokens.white.withValues(alpha: AppTokens.alphaSubtle),
              width: AppTokens.componentBorderWidth,
            ),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLines: maxLines,
            maxLength: maxLength,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            validator: validator,
            style: AppTokens.dmSans(
              size: AppTokens.textBodyLarge,
              weight: FontWeight.w500,
              color: enabled
                  ? AppTokens.textOnDark
                  : AppTokens.textOnDark.withValues(
                      alpha: AppTokens.alphaSecondary,
                    ),
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.formPaddingH,
                vertical: AppTokens.formPaddingV,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(
                      prefixIcon,
                      color: AppTokens.textOnDark.withValues(
                        alpha: AppTokens.alphaTertiary,
                      ),
                      size: AppTokens.formPrefixIconSize,
                    )
                  : null,
              suffixIcon: suffixIcon,
              hintText: hint,
              hintStyle: AppTokens.dmSans(
                size: AppTokens.formHintSize,
                weight: FontWeight.w400,
                color: AppTokens.textOnDark.withValues(
                  alpha: AppTokens.alphaMuted,
                ),
              ),
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}
