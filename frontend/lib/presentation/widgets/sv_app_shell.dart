import 'package:flutter/material.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../../ui/app_header_pattern_painter.dart';
import 'sv_button.dart';

/// Shared shell and lightweight content components used by the authenticated
/// screens. Keep these primitives in one place so all post-login screens use
/// the same spacing, surfaces, typography, and controls.
class SvAppShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool showBack;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  const SvAppShell({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.onBack,
    this.trailing,
    this.showBack = false,
    this.scrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding == EdgeInsets.zero
        ? child
        : Padding(
            padding:
                padding ??
                const EdgeInsets.fromLTRB(
                  AppTokens.space2xl,
                  AppTokens.spaceXl,
                  AppTokens.space2xl,
                  AppTokens.space3xl,
                ),
            child: child,
          );

    return Scaffold(
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTokens.space2xl,
                AppTokens.spaceLg,
                AppTokens.space2xl,
                AppTokens.spaceMd,
              ),
              child: Row(
                children: [
                  if (showBack || onBack != null) ...[
                    IconButton(
                      onPressed: onBack ?? () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: AppTokens.navIconSize,
                      ),
                      color: AppTokens.ink,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTokens.poppins(
                            size: AppTokens.textHeadline,
                            weight: FontWeight.w800,
                            color: AppTokens.ink,
                            letterSpacing: AppTokens.trackingTight,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppTokens.spaceXs),
                          Text(
                            subtitle!,
                            style: AppText.bodySmall.copyWith(
                              color: AppTokens.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(child: content)
                  : content,
            ),
          ],
        ),
      ),
    );
  }
}

class SvDashboardHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final double titleSize;

  const SvDashboardHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.onBack,
    this.titleSize = AppTokens.textHeadline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppTokens.obsidian950),
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: AppHeaderPatternPainter(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppTokens.formMaxWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.sheetHorizontalPadding,
                    AppTokens.space2xl,
                    AppTokens.sheetHorizontalPadding,
                    0,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (onBack != null) ...[
                            SvDashboardHeaderButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: 'Back',
                              onTap: onBack!,
                            ),
                            const SizedBox(width: AppTokens.spaceSm),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTokens.poppins(
                                size: titleSize,
                                weight: FontWeight.w800,
                                color: AppTokens.white,
                                letterSpacing: AppTokens.trackingTight,
                              ),
                            ),
                          ),
                          for (final action in actions) ...[
                            const SizedBox(width: AppTokens.spaceSm),
                            action,
                          ],
                        ],
                      ),
                      const Divider(
                        height: AppTokens.componentBorderWidth,
                        thickness: AppTokens.componentBorderWidth,
                        color: AppTokens.obsidian700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SvDashboardHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;
  final bool enabled;
  final bool selected;
  final double iconSize;

  const SvDashboardHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
    this.enabled = true,
    this.selected = false,
    this.iconSize = AppTokens.navIconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        hoverColor: AppTokens.transparent,
        focusColor: AppTokens.transparent,
        splashColor: AppTokens.transparent,
        highlightColor: AppTokens.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: AppTokens.tapTarget,
              height: AppTokens.tapTarget,
              decoration: const BoxDecoration(
                color: AppTokens.transparent,
                borderRadius: BorderRadius.all(
                  Radius.circular(AppTokens.radiusMd),
                ),
              ),
              child: Icon(
                icon,
                color: enabled ? AppTokens.white : AppTokens.ice400,
                size: iconSize,
              ),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -AppTokens.spaceXs,
                right: -AppTokens.spaceXs,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppTokens.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 9 ? '9+' : '$badgeCount',
                    style: AppTokens.dmSans(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppTokens.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SvSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;

  const SvSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceLg),
    this.color = AppTokens.white,
    this.borderColor = AppTokens.ice200,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: borderColor,
          width: AppTokens.componentBorderWidth,
        ),
        boxShadow: null,
      ),
      child: child,
    );
    return onTap == null
        ? card
        : Material(
            color: AppTokens.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: card,
            ),
          );
  }
}

InputDecoration _lightInputDecoration({
  String? label,
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: AppText.labelMedium.copyWith(color: AppTokens.inkMuted),
    floatingLabelStyle: AppText.labelSmall.copyWith(color: AppTokens.ink),
    hintStyle: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
    errorStyle: AppText.caption.copyWith(color: AppTokens.errorStrong),
    filled: true,
    fillColor: AppTokens.white,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppTokens.spaceLg,
      vertical: AppTokens.spaceMd,
    ),
    border: _lightFieldBorder(AppTokens.ice200, AppTokens.inputBorderWidth),
    enabledBorder: _lightFieldBorder(
      AppTokens.ice200,
      AppTokens.inputBorderWidth,
    ),
    focusedBorder: _lightFieldBorder(AppTokens.ink, AppTokens.focusBorderWidth),
    errorBorder: _lightFieldBorder(
      AppTokens.errorStrong,
      AppTokens.inputBorderWidth,
    ),
    focusedErrorBorder: _lightFieldBorder(
      AppTokens.errorStrong,
      AppTokens.focusBorderWidth,
    ),
  );
}

OutlineInputBorder _lightFieldBorder(Color color, double width) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
    borderSide: BorderSide(color: color, width: width),
  );
}

enum SvTone { success, warning, error, info, neutral }

class SvStatusPill extends StatelessWidget {
  final String label;
  final SvTone tone;
  final bool small;

  const SvStatusPill(
    this.label, {
    super.key,
    this.tone = SvTone.info,
    this.small = false,
  });

  Color get _color => switch (tone) {
    SvTone.success => AppTokens.successStrong,
    SvTone.warning => AppTokens.warningStrong,
    SvTone.error => AppTokens.errorStrong,
    SvTone.info => AppTokens.infoStrong,
    SvTone.neutral => AppTokens.inkMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppTokens.spaceSm : AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: AppTokens.alphaLow),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
          color: _color.withValues(alpha: AppTokens.alphaMedium),
        ),
      ),
      child: Text(
        label,
        style: AppText.caption.copyWith(
          color: _color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SvActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SvTone tone;
  final bool loading;
  final bool fullWidth;
  final double? height;

  const SvActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.tone = SvTone.neutral,
    this.loading = false,
    this.fullWidth = true,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final type = switch (tone) {
      SvTone.error => SVButtonType.danger,
      SvTone.neutral => SVButtonType.secondary,
      _ => SVButtonType.primary,
    };
    return SVButton(
      text: label,
      icon: icon,
      onPressed: onPressed,
      type: type,
      isLoading: loading,
      isFullWidth: fullWidth,
      height: height ?? AppTokens.buttonHeight,
    );
  }
}

class SvEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const SvEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space3xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppTokens.logoIconSize,
                color: AppTokens.inkMuted,
              ),
              const SizedBox(height: AppTokens.spaceMd),
            ],
            Text(
              title,
              style: AppText.titleMedium.copyWith(color: AppTokens.ink),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                subtitle!,
                style: AppText.bodySmall.copyWith(color: AppTokens.inkMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTokens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class SvSectionLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SvSectionLabel(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.titleSmall.copyWith(
              color: AppTokens.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: AppTokens.trackingTight,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SvInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const SvInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTokens.inkMuted, size: AppTokens.componentIconMd),
        const SizedBox(width: AppTokens.spaceMd),
        Expanded(child: Text(label, style: AppText.caption)),
        const SizedBox(width: AppTokens.spaceMd),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.labelLarge.copyWith(
              color: valueColor ?? AppTokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class SvDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const SvDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTokens.inkMuted, size: AppTokens.componentIconMd),
        const SizedBox(width: AppTokens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.caption.copyWith(color: AppTokens.inkMuted),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                value,
                style: AppText.bodyMedium.copyWith(color: AppTokens.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SvFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const SvFormField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      cursorColor: AppTokens.ink,
      style: AppText.bodyMedium.copyWith(color: AppTokens.ink),
      decoration: _lightInputDecoration(
        label: label,
        hint: hint,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, color: AppTokens.inkMuted),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
