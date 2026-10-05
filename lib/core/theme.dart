import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Design System Tokens for EL METR ACADEMY
/// Based strictly on DESIGN.md and Cinematic Noir Academy specification.

class AppColors {
  AppColors._();

  // Surface Palette
  static const Color voidCanvas = Color(0xFF080808);
  static const Color surfaceLayer1 = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF181818);
  static const Color surfaceHigh = Color(0xFF202020);
  static const Color surfaceBright = Color(0xFF2A2A2A);
  static const Color surfaceContainerLowest = Color(0xFF040404);
  static const Color surfaceContainerLow = Color(0xFF0E0E0E);
  static const Color surfaceContainer = Color(0xFF141414);
  static const Color surfaceContainerHighest = Color(0xFF353534);

  // Borders & Hairlines
  static const Color subtleHairline = Color(0xFF262626);
  static const Color prominentBorder = Color(0xFF303030);
  static const Color activeBorder = Color(0xFFC1121F);

  // Accents (Strict Noir Ruby Hierarchy)
  static const Color crimson = Color(0xFFC1121F);
  static const Color deepCrimson = Color(0xFF7F0D15);
  static const Color crimsonHover = Color(0xFFA30F1A);
  static const Color crimsonTinted = Color(0x1FC1121F);
  static const Color crimsonGlow = Color(0x38C1121F);

  // Typographic Contrast (F-UX4: textTertiary, textPlaceholder and danger
  // were lightened, same hue, to reach WCAG AA 4.5:1 on the surfaces they
  // are used on; see test/theme_tokens_test.dart).
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8B8);
  static const Color textMuted = Color(0xFF9A9A9A);
  static const Color textTertiary = Color(0xFF8A8A8A);
  static const Color textPlaceholder = Color(0xFF808080);

  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusPendingBg = Color(0x26F59E0B);
  static const Color statusApproved = Color(0xFF10B981);
  static const Color statusApprovedBg = Color(0x2610B981);
  static const Color statusRejected = Color(0xFFC1121F);
  static const Color statusRejectedBg = Color(0x26C1121F);
  static const Color starRating = Color(0xFFF59E0B);

  // Semantic Colors (feedback: snackbars, inline messages, banners).
  // success/warning reuse the status hues. danger is a lighter tint than
  // crimson/statusRejected because crimson is only 3.0:1 on surfaceLayer1;
  // use crimson for brand fills and danger for red text and icons.
  // Each foreground is >= 4.5:1 on voidCanvas through surfaceHigh, and on its
  // own *Bg variant composited over those surfaces (WCAG AA for body text).
  static const Color success = statusApproved;
  static const Color successBg = statusApprovedBg;
  static const Color warning = statusPending;
  static const Color warningBg = statusPendingBg;
  static const Color danger = Color(0xFFF67E86);
  static const Color dangerBg = Color(0x26F4707A);
  static const Color info = Color(0xFF60A5FA);
  static const Color infoBg = Color(0x2660A5FA);

  // Glass chrome (translucent header and bottom bar over scrolling content)
  static const Color headerGlass = Color(0xF2090909);
  static const Color navBarGlass = Color(0xF20B0B0B);
  static const Color glassHairline = Color(0x14FFFFFF);

  // Thin rule beside the brand eyebrow (white at 30%).
  static const Color brandRule = Color(0x4DFFFFFF);

  // Pure black for scrims, text shadows and vignette gradients.
  static const Color scrimBlack = Color(0xFF000000);
}

class AppSpacing {
  AppSpacing._();

  static const double space2xs = 2.0;
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 12.0;
  static const double spaceLg = 16.0;
  static const double spaceXl = 24.0;
  static const double space2xl = 32.0;
  static const double space3xl = 40.0;

  static const double gutterMobile = 12.0;
  static const double marginMobile = 16.0;
  static const double navBarHeight = 68.0;
  static const double headerHeight = 56.0;
}

class AppRadius {
  AppRadius._();

  static const double xs = 2.0;
  static const double sm = 4.0;
  static const double md = 6.0;
  static const double lg = 8.0;
  static const double xl = 12.0;
  static const double card = 12.0;
  static const double pill = 9999.0;

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusPill = BorderRadius.all(
    Radius.circular(pill),
  );
}

class AppElevation {
  AppElevation._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> crimsonGlow = [
    BoxShadow(color: Color(0x40C1121F), offset: Offset(0, 4), blurRadius: 20),
  ];

  static const List<BoxShadow> bottomNav = [
    BoxShadow(color: Color(0xCC000000), offset: Offset(0, -4), blurRadius: 24),
  ];

  /// Same geometry as [bottomNav] with a lighter shadow; used by the main shell bar.
  static const List<BoxShadow> bottomNavSoft = [
    BoxShadow(color: Color(0x99000000), offset: Offset(0, -4), blurRadius: 24),
  ];
}

class AppMotion {
  AppMotion._();

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveEmphasized = Curves.fastOutSlowIn;
}

class AppIconSize {
  AppIconSize._();

  static const double xs = 14.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppTypography {
  AppTypography._();

  // Font family fallbacks: Syne for display/headings, Plus Jakarta Sans for body, Cairo for Arabic
  static TextStyle displayHero({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.syne(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          );
  }

  static TextStyle headlineLg({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.syne(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          );
  }

  static TextStyle headlineMd({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.syne(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.2,
            color: AppColors.textPrimary,
          );
  }

  static TextStyle headlineSm({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.syne(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.textPrimary,
          );
  }

  static TextStyle academyEyebrow({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          )
        : GoogleFonts.syne(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
            color: AppColors.textMuted,
          );
  }

  /// Brand wordmark on full-bleed hero screens (login). Latin only: the app
  /// title is not translated, so the wide letter spacing never meets Arabic.
  static TextStyle wordmarkTitle({bool isArabic = false}) {
    return displayHero(isArabic: isArabic).copyWith(
      fontSize: 32,
      letterSpacing: 6.0,
      shadows: const [
        Shadow(
          color: AppColors.scrimBlack,
          blurRadius: 16,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static TextStyle wordmarkSubtitle({bool isArabic = false}) {
    return academyEyebrow(isArabic: isArabic).copyWith(
      fontSize: 11,
      letterSpacing: 4.5,
      color: AppColors.textPrimary.withValues(alpha: 0.8),
      shadows: const [
        Shadow(
          color: AppColors.scrimBlack,
          blurRadius: 10,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  /// Two-line brand lockup in a screen header (title over eyebrow).
  static TextStyle headerWordmark({bool isArabic = false}) {
    return headlineSm(
      isArabic: isArabic,
    ).copyWith(letterSpacing: 2.0, fontWeight: FontWeight.w800);
  }

  static TextStyle headerEyebrow({bool isArabic = false}) {
    return academyEyebrow(isArabic: isArabic).copyWith(fontSize: 8);
  }

  /// Timestamps and other tertiary captions (10).
  static TextStyle caption({bool isArabic = false}) {
    return bodySm(
      isArabic: isArabic,
    ).copyWith(fontSize: 10, color: AppColors.textTertiary);
  }

  /// Dense secondary body text in lists (11, tight leading).
  static TextStyle bodyXs({bool isArabic = false}) {
    return bodySm(isArabic: isArabic).copyWith(fontSize: 11, height: 1.4);
  }

  /// Small header action such as "Mark read" (11, muted).
  static TextStyle actionSm({bool isArabic = false}) {
    return labelSm(
      isArabic: isArabic,
    ).copyWith(fontSize: 11, letterSpacing: 1.0, color: AppColors.textMuted);
  }

  /// Footer line under settings (9, tertiary, wide spacing).
  static TextStyle footerEyebrow({bool isArabic = false}) {
    return academyEyebrow(isArabic: isArabic).copyWith(
      color: AppColors.textTertiary,
      fontSize: 9,
      letterSpacing: isArabic ? 0 : 2.0,
    );
  }

  /// Main-shell header lockup: title (18) over a ruled eyebrow (9).
  static TextStyle shellWordmark({bool isArabic = false}) {
    return headlineSm(
      isArabic: isArabic,
    ).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800, fontSize: 18);
  }

  static TextStyle shellEyebrow({bool isArabic = false}) {
    return academyEyebrow(
      isArabic: isArabic,
    ).copyWith(fontSize: 9, letterSpacing: isArabic ? 0 : 2.8);
  }

  /// Headline of the home hero banner (22 on narrow screens, otherwise 26).
  static TextStyle heroHeadline({bool isArabic = false, bool compact = false}) {
    return headlineLg(isArabic: isArabic).copyWith(
      fontSize: compact ? 22 : 26,
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: isArabic ? 0 : -0.5,
    );
  }

  /// The only sanctioned uppercase transform. Screens must not call
  /// `.toUpperCase()`; use this for button and section labels. Arabic has no
  /// letter case, so Arabic text passes through unchanged.
  static String uppercaseLabel(String text) => text.toUpperCase();

  static TextStyle bodyLg({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: AppColors.textSecondary,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: AppColors.textSecondary,
          );
  }

  static TextStyle bodyMd({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: AppColors.textSecondary,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: AppColors.textSecondary,
          );
  }

  static TextStyle bodySm({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: AppColors.textMuted,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.35,
            color: AppColors.textMuted,
          );
  }

  static TextStyle labelMd({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.textPrimary,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textPrimary,
          );
  }

  static TextStyle labelSm({bool isArabic = false}) {
    return isArabic
        ? GoogleFonts.cairo(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textSecondary,
          );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.voidCanvas,
      canvasColor: AppColors.voidCanvas,
      primaryColor: AppColors.crimson,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.crimson,
        onPrimary: AppColors.textPrimary,
        surface: AppColors.voidCanvas,
        onSurface: AppColors.textPrimary,
        error: AppColors.crimson,
        onError: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerGlass,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppTypography.bodyMd().copyWith(
          color: AppColors.textPrimary,
        ),
        actionTextColor: AppColors.crimson,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.subtleHairline,
        thickness: 1,
        space: 1,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
          side: BorderSide(color: AppColors.subtleHairline, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textTertiary,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(
            color: AppColors.subtleHairline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(
            color: AppColors.subtleHairline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          borderSide: const BorderSide(color: AppColors.crimson, width: 1),
        ),
      ),
    );
  }
}
