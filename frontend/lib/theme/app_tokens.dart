import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTokens {
  AppTokens._();

  static const Color obsidian950 = Color(0xFF0B0D10);
  static const Color obsidian900 = Color(0xFF11141A);
  static const Color obsidian800 = Color(0xFF181C23);
  static const Color obsidian700 = Color(0xFF222731);
  static const Color ice50 = Color(0xFFF5F7FA);
  static const Color ice100 = Color(0xFFEAEEF3);
  static const Color ice200 = Color(0xFFD9DFE7);
  static const Color ice400 = Color(0xFF8A94A3);
  static const Color ink = Color(0xFF0B0D10);
  static const Color inkMuted = Color(0xFF5B6573);
  static const Color white = Color(0xFFFFFFFF);
  static const Color danger = Color(0xFFA32A1F);
  static const Color dangerBg = Color(0xFFFBE8E6);
  static const Color alertOnDanger = Color(0xFF7E1F16);
  static const Color triangleLight = Color(0xFF14171D);
  static const Color triangleDark = Color(0xFF0F1216);
  static const Color hintInkMuted = Color(0xE65B6573);
  static const Color inkOverlay14 = Color(0x240B0D10);
  static const Color whiteOverlay = Color(0x14FFFFFF);
  static const Color transparent = Color(0x00000000);

  static const Color headerBase = Color(0xFF050D18);
  static const Color headerFacetA = Color(0xFF0D1926);
  static const Color headerFacetB = Color(0xFF0A1421);
  static const Color headerFacetC = Color(0xFF07101B);

  static const Color bgDark = Color(0xFF06182C);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF3F6FA);
  static const Color surfaceDark = Color(0xFF102A43);
  static const Color primary = Color(0xFF2D7FF9);
  static const Color accent = Color(0xFFB8FF3B);
  static const Color teal = Color(0xFF00C2A8);
  static const Color orange = Color(0xFFFFA63B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color error = Color(0xFFFF5D5D);
  static const Color success = accent;
  static const Color warning = orange;
  static const Color info = teal;
  static const Color text = Color(0xFF0A1A2F);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFE6F1FF);
  static const Color border = Color(0xFFD8E2EF);
  static const Color focusRing = Color(0x332D7FF9);
  static const Color shadow = Color(0x140B0D10);

  static const String fontDisplay = 'Poppins';
  static const String fontBody = 'Manrope';
  static const String fontCaption = 'DM Sans';

  static const List<String> fontFallback = ['NotoSansEthiopic', 'sans-serif'];

  static const double textDisplay = 32;
  static const double textHeadline = 24;
  static const double textTitle = 28;
  static const double textSubtitle = 18;
  static const double textBodyLarge = 16;
  static const double textBody = 15;
  static const double textBodySmall = 14;
  static const double textLabel = 13;
  static const double textCaption = 12;
  static const double textOverline = 11;
  static const double trackingTight = -0.5;
  static const double trackingNormal = 0;
  static const double trackingWide = 0.5;

  static const double lineHeightTight = 1;
  static const double lineHeightNormal = 1.2;
  static const double lineHeightRelaxed = 1.4;

  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;
  static const double space3xl = 32;

  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radius2xl = 24;
  static const double radiusLogo = 18;
  static const double radiusToggle = 17;
  static const double radiusField = 28;
  static const double radiusButton = 22;
  static const double radiusSheet = 96;
  static const double radiusPill = 999;
  static const double radiusCard = radiusXl;

  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(radiusCard),
  );
  static const BorderRadius fieldBorderRadius = BorderRadius.all(
    Radius.circular(radiusField),
  );
  static const BorderRadius buttonBorderRadius = BorderRadius.all(
    Radius.circular(radiusButton),
  );
  static const BorderRadius toggleBorderRadius = BorderRadius.all(
    Radius.circular(radiusToggle),
  );
  static const BorderRadius sheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(radiusSheet),
  );

  static const double headerVisibleHeight = 180;
  static const double authTopBarHeight = 150;
  static const double authTopBarLogoTop = 64;
  static const double authTopBarLogoSize = 52;
  static const double authTopBarInset = spaceLg;
  static const double backButtonSize = tapTarget;
  static const double backButtonRadius = radiusMd;
  static const double backButtonIconSize = 20;
  static const double errorRetryTextSize = 13;
  static const double sheetOverlap = 12;
  static const double sheetTopRadius = radiusSheet;
  static const double sheetTopPadding = 12;
  static const double sheetHorizontalPadding = 24;
  static const double sheetBottomPadding = 20;
  static const double formMaxWidth = 460;

  static const double patternTileWidth = 80;
  static const double patternTileHeight = 70;

  static const double languageRightPadding = 12;
  static const double languageTopPadding = 10;
  static const double languagePillPadding = 3;
  static const double languagePillRadius = radiusPill;
  static const double languageItemHeight = 34;
  static const double languageItemMinWidth = 40;
  static const double languageItemRadius = radiusToggle;
  static const double languageItemPaddingH = 7;
  static const double languageTextSize = 12;

  static const double logoTopGap = 60;
  static const double logoTileSize = 64;
  static const double logoTileRadius = radiusLogo;
  static const double logoIconSize = 40;
  static const double logoCoordinateSize = 484;
  static const double logoSourceSize = 1024;
  static const double logoOffset = 270;
  static const double logoBracketStroke = 20;
  static const double logoCircleStroke = 18;
  static const double logoCircleRadius = 116;
  static const double logoCheckStroke = 20;

  static const double titleSize = 28;
  static const double titleLanguageGap = 6;
  static const double titleToggleGap = 32;
  static const double toggleContainerRadius = radiusCard;
  static const double togglePadding = 3;
  static const double toggleButtonHeight = 47;
  static const double toggleButtonRadius = radiusToggle;
  static const double toggleTextSize = 14;
  static const double toggleFieldsGap = 20;

  static const double fieldGap = 16;
  static const double inputHeight = 59;
  static const double inputRadius = radiusField;
  static const double inputBorderWidth = 1;
  static const double focusBorderWidth = 1.5;
  static const double focusRingWidth = 3;
  static const double inputPaddingH = 18;
  static const double labelNotchPaddingH = 4;
  static const double labelSize = 13;
  static const double inputTextSize = 15;
  static const double helperSize = 12;
  static const double errorTextSize = 12;
  static const double fieldErrorGap = 4;
  static const double dropdownIconGap = 10;
  static const double eyeIconSize = 20;

  static const double buttonGap = 20;
  static const double buttonHeight = 56;
  static const double buttonRadius = radiusButton;
  static const double buttonTextSize = 15;
  static const double progressSize = 18;
  static const double progressStroke = 2;

  static const double bottomGap = 20;
  static const double footerTextSize = 14;
  static const double tapTarget = 44;

  static const double errorRadius = radiusMd;
  static const double errorPadding = 12;
  static const double errorIconSize = 18;

  static const double optionPaddingH = 12;
  static const double optionPaddingV = 10;
  static const double dividerHeight = 1;
  static const double handleWidth = 36;
  static const double handleHeight = 4;
  static const double optionIconSize = 24;
  static const double checkIconSize = 16;

  static const double componentBorderWidth = 1;
  static const double componentBorderWidthStrong = 1.5;
  static const double componentIconSm = 14;
  static const double componentIconMd = 20;
  static const double componentIconLg = 24;

  static const double loaderPageSize = 28;
  static const double loaderPageStroke = 2.6;
  static const double loaderButtonSize = 18;
  static const double loaderButtonStroke = 2.2;
  static const double loaderInlineSize = 16;
  static const double loaderInlineStroke = 2;
  static const double loaderLargeSize = 56;
  static const double loaderLargeStroke = 3;

  static const double alphaSubtle = 0.08;
  static const double alphaLow = 0.12;
  static const double alphaMedium = 0.15;
  static const double alphaStrong = 0.3;
  static const double alphaMuted = 0.4;
  static const double alphaSecondary = 0.5;
  static const double alphaTertiary = 0.6;
  static const double alphaPrimaryMuted = 0.7;
  static const double alphaDisabled = 0.8;
  static const double alphaOverlay = 0.45;

  static const double badgePaddingV = 6;
  static const double badgePaddingH = 14;
  static const double badgeSmallPaddingV = 4;
  static const double badgeSmallPaddingH = 10;
  static const double badgeFontSize = 14;
  static const double badgeSmallFontSize = 12;
  static const double badgeRadius = radiusSm;
  static const double badgeSmallRadius = radiusXs;

  static const double formLabelGap = 8;
  static const double formPaddingH = 20;
  static const double formPaddingV = 16;
  static const double formPrefixIconSize = 22;
  static const double formHintSize = 16;

  static const double statCardPadding = 20;
  static const double statTileSize = 48;
  static const double statIconSize = 24;
  static const double statChangePaddingH = 10;
  static const double statChangePaddingV = 6;
  static const double statChangeIconSize = 14;
  static const double statChangeFontSize = 13;
  static const double statGap = 16;
  static const double statTitleGap = 6;
  static const double statTitleSize = 14;
  static const double statValueSize = 26;

  static const double heroRadius = radius2xl;
  static const double heroWideHeight = 400;
  static const double heroMobileHeight = 280;
  static const double heroBreakpoint = 768;
  static const double heroPadding = 32;
  static const double heroStatusPaddingH = 14;
  static const double heroStatusPaddingV = 8;
  static const double heroDotSize = 8;
  static const double heroTitleSize = 42;
  static const double heroSubtitleSize = 16;
  static const double heroStatValueSize = 28;
  static const double heroStatLabelSize = 12;
  static const double heroIndicatorActiveWidth = 32;
  static const double heroIndicatorWidth = 8;
  static const double heroIndicatorHeight = 8;
  static const double heroIndicatorRadius = 4;
  static const double heroIndicatorGap = 4;
  static const double heroIndicatorOffset = 24;
  static const double heroParallaxShift = 30;
  static const double heroScaleEnd = 1.08;
  static const double heroTrackingTight = -1.5;
  static const double heroTrackingStatus = 0.5;
  static const double heroTrackingSubtitle = 0.2;
  static const double heroTrackingStat = -0.8;
  static const double heroLineHeightTitle = 1.1;
  static const double heroLineHeightSubtitle = 1.6;
  static const int motionHeroTransition = 1500;
  static const int motionHeroImage = 4000;
  static const int motionHeroIndicator = 300;

  static const Color heroGradientStart = Color(0xFF0D1F0A);
  static const Color heroGradientEnd = Color(0xFF050D18);
  static const Color heroImageOverlayStart = Color(0x73000000);
  static const Color heroOverlayFadeStart = Color(0x66000000);

  static const double heroRadialRadius = 1.5;
  static const double heroOverlayStop = 0.5;

  static const double shadowBlurSmall = 8;
  static const double shadowBlurMedium = 12;
  static const double shadowSpreadMedium = 2;
  static const double cardElevation = 0;
  static const double dialogElevation = 8;
  static const double menuElevation = 4;

  static const int motionFast = 150;
  static const int motionMedium = 250;
  static const int motionSlow = 350;
  static const Curve curveStandard = Curves.easeOut;
  static const Curve curveEmphasized = Curves.easeInOut;
  static const Curve curveHeroPage = Curves.easeInOutCubic;

  static const BoxShadow cardShadow = BoxShadow(
    color: shadow,
    blurRadius: shadowBlurMedium,
    offset: Offset(0, spaceSm),
  );

  static TextStyle poppins({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle manrope({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle dmSans({
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
