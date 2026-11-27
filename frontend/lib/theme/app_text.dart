import 'package:flutter/material.dart';
import 'app_tokens.dart';

class AppText {
  AppText._();

  static TextStyle get displayLarge => AppTokens.poppins(
        size: AppTokens.textDisplay,
        weight: FontWeight.w700,
        letterSpacing: AppTokens.trackingTight,
        height: AppTokens.lineHeightTight,
      );

  static TextStyle get displayMedium => AppTokens.poppins(
        size: AppTokens.textHeadline,
        weight: FontWeight.w700,
        letterSpacing: AppTokens.trackingTight,
        height: AppTokens.lineHeightTight,
      );

  static TextStyle get headlineLarge => AppTokens.poppins(
        size: AppTokens.textHeadline,
        weight: FontWeight.w700,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get headlineMedium => AppTokens.manrope(
        size: AppTokens.textSubtitle,
        weight: FontWeight.w700,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get titleLarge => AppTokens.manrope(
        size: AppTokens.textTitle,
        weight: FontWeight.w700,
        height: AppTokens.lineHeightTight,
      );

  static TextStyle get titleMedium => AppTokens.manrope(
        size: AppTokens.textSubtitle,
        weight: FontWeight.w600,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get titleSmall => AppTokens.manrope(
        size: AppTokens.textBodyLarge,
        weight: FontWeight.w600,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get bodyLarge => AppTokens.manrope(
        size: AppTokens.textBodyLarge,
        weight: FontWeight.w400,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get bodyMedium => AppTokens.manrope(
        size: AppTokens.textBody,
        weight: FontWeight.w400,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get bodySmall => AppTokens.manrope(
        size: AppTokens.textBodySmall,
        weight: FontWeight.w400,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get labelLarge => AppTokens.manrope(
        size: AppTokens.textBody,
        weight: FontWeight.w600,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get labelMedium => AppTokens.manrope(
        size: AppTokens.textLabel,
        weight: FontWeight.w600,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get labelSmall => AppTokens.dmSans(
        size: AppTokens.textCaption,
        weight: FontWeight.w500,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get caption => AppTokens.dmSans(
        size: AppTokens.textCaption,
        weight: FontWeight.w400,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get overline => AppTokens.dmSans(
        size: AppTokens.textOverline,
        weight: FontWeight.w600,
        letterSpacing: AppTokens.trackingWide,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get button => AppTokens.manrope(
        size: AppTokens.textBody,
        weight: FontWeight.w700,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get authTitle => AppTokens.manrope(
        size: AppTokens.titleSize,
        weight: FontWeight.w700,
        color: AppTokens.ink,
        height: AppTokens.lineHeightTight,
      );

  static TextStyle get authSubtitle => AppTokens.dmSans(
        size: AppTokens.footerTextSize,
        weight: FontWeight.w400,
        color: AppTokens.inkMuted,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get authLabel => AppTokens.manrope(
        size: AppTokens.labelSize,
        weight: FontWeight.w600,
        color: AppTokens.ink,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get authInput => AppTokens.dmSans(
        size: AppTokens.inputTextSize,
        weight: FontWeight.w400,
        color: AppTokens.ink,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get authHelper => AppTokens.dmSans(
        size: AppTokens.helperSize,
        weight: FontWeight.w400,
        color: AppTokens.inkMuted,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get authError => AppTokens.dmSans(
        size: AppTokens.errorTextSize,
        weight: FontWeight.w500,
        color: AppTokens.danger,
        height: AppTokens.lineHeightRelaxed,
      );

  static TextStyle get authToggle => AppTokens.manrope(
        size: AppTokens.toggleTextSize,
        weight: FontWeight.w600,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle get authButton => AppTokens.manrope(
        size: AppTokens.buttonTextSize,
        weight: FontWeight.w700,
        color: AppTokens.white,
        height: AppTokens.lineHeightNormal,
      );

  static TextStyle onDark(TextStyle style) => style.apply(
        color: AppTokens.textOnDark,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      ).apply(
        bodyColor: AppTokens.textOnDark,
        displayColor: AppTokens.textOnDark,
        fontFamilyFallback: AppTokens.fontFallback,
      );
}
