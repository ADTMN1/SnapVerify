import 'package:flutter/material.dart';
import 'app_text.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: AppTokens.accent,
      onPrimary: AppTokens.ink,
      secondary: AppTokens.primary,
      onSecondary: AppTokens.white,
      tertiary: AppTokens.teal,
      onTertiary: AppTokens.ink,
      surface: AppTokens.surfaceDark,
      onSurface: AppTokens.textOnDark,
      onSurfaceVariant: AppTokens.ice400,
      surfaceContainerHighest: AppTokens.obsidian800,
      outline: AppTokens.ice400,
      outlineVariant: AppTokens.obsidian700,
      error: AppTokens.error,
      onError: AppTokens.white,
    );

    final primaryButtonStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle>(AppText.authButton),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return AppTokens.ice400;
        return AppTokens.ink;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return AppTokens.obsidian700;
        return AppTokens.accent;
      }),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXl,
          vertical: AppTokens.spaceMd,
        ),
      ),
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(double.infinity, AppTokens.buttonHeight),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppTokens.buttonBorderRadius),
      ),
      elevation: WidgetStatePropertyAll<double>(AppTokens.cardElevation),
    );

    final secondaryButtonStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle>(
        AppText.onDark(AppText.labelLarge),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return AppTokens.ice400;
        return AppTokens.textOnDark;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) return AppTokens.obsidian900;
        return AppTokens.obsidian800;
      }),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: AppTokens.spaceXl,
          vertical: AppTokens.spaceMd,
        ),
      ),
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(AppTokens.tapTarget, AppTokens.buttonHeight),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppTokens.buttonBorderRadius),
      ),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(
          color: AppTokens.obsidian700,
          width: AppTokens.inputBorderWidth,
        ),
      ),
      elevation: WidgetStatePropertyAll<double>(AppTokens.cardElevation),
    );

    final textButtonStyle = ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle>(
        AppText.onDark(AppText.labelLarge),
      ),
      foregroundColor: WidgetStatePropertyAll<Color>(AppTokens.accent),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
      ),
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(AppTokens.tapTarget, AppTokens.tapTarget),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppTokens.buttonBorderRadius),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppTokens.bgDark,
      cardColor: AppTokens.surfaceDark,
      canvasColor: AppTokens.obsidian950,
      dividerColor: AppTokens.obsidian700,
      colorScheme: colorScheme,
      textTheme: AppText.textTheme,
      iconTheme: IconThemeData(
        color: AppTokens.textOnDark,
        size: AppTokens.space2xl,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppTokens.obsidian950,
        foregroundColor: AppTokens.textOnDark,
        surfaceTintColor: AppTokens.transparent,
        elevation: AppTokens.cardElevation,
        centerTitle: true,
        titleTextStyle: AppText.onDark(AppText.titleMedium),
        iconTheme: IconThemeData(
          color: AppTokens.textOnDark,
          size: AppTokens.space2xl,
        ),
        actionsIconTheme: IconThemeData(
          color: AppTokens.textOnDark,
          size: AppTokens.space2xl,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceDark,
        hintStyle: AppTokens.dmSans(
          size: AppTokens.inputTextSize,
          weight: FontWeight.w400,
          color: AppTokens.ice400,
          height: AppTokens.lineHeightRelaxed,
        ),
        labelStyle: AppText.labelMedium.copyWith(color: AppTokens.ice400),
        floatingLabelStyle: AppText.labelSmall.copyWith(
          color: AppTokens.accent,
        ),
        errorStyle: AppTokens.dmSans(
          size: AppTokens.helperSize,
          weight: FontWeight.w500,
          color: AppTokens.error,
          height: AppTokens.lineHeightRelaxed,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTokens.inputPaddingH,
          vertical: AppTokens.spaceMd,
        ),
        border: _fieldBorder(AppTokens.obsidian700, AppTokens.inputBorderWidth),
        enabledBorder: _fieldBorder(
          AppTokens.obsidian700,
          AppTokens.inputBorderWidth,
        ),
        focusedBorder: _fieldBorder(
          AppTokens.accent,
          AppTokens.focusBorderWidth,
        ),
        errorBorder: _fieldBorder(AppTokens.error, AppTokens.inputBorderWidth),
        focusedErrorBorder: _fieldBorder(
          AppTokens.error,
          AppTokens.focusBorderWidth,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.obsidian900,
        surfaceTintColor: AppTokens.transparent,
        indicatorColor: AppTokens.accent,
        iconTheme: WidgetStatePropertyAll<IconThemeData>(
          IconThemeData(color: AppTokens.textOnDark, size: AppTokens.space2xl),
        ),
        labelTextStyle: WidgetStatePropertyAll<TextStyle>(AppText.labelSmall),
        height: AppTokens.tapTarget + AppTokens.space2xl,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppTokens.inkMuted,
        linearTrackColor: AppTokens.ice100,
        circularTrackColor: AppTokens.ice100,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTokens.white,
        contentTextStyle: AppText.bodySmall.copyWith(color: AppTokens.ink),
        behavior: SnackBarBehavior.floating,
        elevation: AppTokens.dialogElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(
            color: AppTokens.ice200,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppTokens.obsidian700,
        thickness: AppTokens.dividerHeight,
        space: AppTokens.dividerHeight,
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: AppTokens.fieldBorderRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
