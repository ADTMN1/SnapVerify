import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

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
            style: TextStyle(
              color: TwColors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: enabled ? TwColors.slate700 : TwColors.slate800,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TwColors.white.withOpacity(0.08),
              width: 1,
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
            style: TextStyle(
              color: enabled ? TwColors.white : TwColors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(
                      prefixIcon,
                      color: TwColors.white.withOpacity(0.6),
                      size: 22,
                    )
                  : null,
              suffixIcon: suffixIcon,
              hintText: hint,
              hintStyle: TextStyle(
                color: TwColors.white.withOpacity(0.4),
                fontSize: 16,
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
