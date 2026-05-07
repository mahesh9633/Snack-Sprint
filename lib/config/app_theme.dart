import 'package:flutter/material.dart';

import 'app_color.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(
    useMaterial3:            false,
    scaffoldBackgroundColor:AppColors.white,
    primaryColor:            AppColors.lightBrown,

    colorScheme: ColorScheme.light(
      primary:   AppColors.lightBrown,
      secondary: AppColors.buttonPrimary,
      error:     AppColors.error,
      surface:   AppColors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBarBg,
      foregroundColor: AppColors.appBarText,
      elevation:       0,
      iconTheme:       IconThemeData(color: AppColors.appBarIcon),
      titleTextStyle:  AppTextStyles.appBarTitle,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonPrimary,
        foregroundColor: AppColors.buttonPrimaryText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
        textStyle: AppTextStyles.buttonLabel,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.buttonSecondaryText,
        side: const BorderSide(
            color: AppColors.buttonSecondaryBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        textStyle: AppTextStyles.buttonLabel,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.buttonPrimary,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color:     AppColors.divider,
      thickness: 1,
      space:     1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.loader,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:             true,
      fillColor:          Colors.white,
      hintStyle:          AppTextStyles.hint,
      border:             AppInputBorders.normal,
      enabledBorder:      AppInputBorders.normal,
      focusedBorder:      AppInputBorders.focused,
      errorBorder:        AppInputBorders.error,
      focusedErrorBorder: AppInputBorders.error,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor:  AppColors.lightBrown,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}


class AppInputBorders {
  AppInputBorders._();

  static OutlineInputBorder get normal => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide:   const BorderSide(color: AppColors.border),
  );

  static OutlineInputBorder get focused => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide:   const BorderSide(color: AppColors.lightBrown, width: 1.5),
  );

  static OutlineInputBorder get error => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide:   const BorderSide(color: AppColors.error, width: 1.2),
  );
}


class AppDecorations {
  AppDecorations._();

  static BoxDecoration get card => BoxDecoration(
    color:        AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    boxShadow:    AppShadows.card,
  );

  static BoxDecoration get cardAccent => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.lightBrown.withOpacity(0.3), width: 1.5),
    boxShadow: AppShadows.card,
  );

  static BoxDecoration get inputField => BoxDecoration(
    color:        Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    border:       Border.all(color: AppColors.border),
  );

  static BoxDecoration get successBox => BoxDecoration(
    color:        AppColors.successLight,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    border:       Border.all(color: AppColors.success.withOpacity(0.4)),
  );

  static BoxDecoration get errorBox => BoxDecoration(
    color:        AppColors.errorLight,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    border:       Border.all(color: AppColors.error.withOpacity(0.4)),
  );

  static BoxDecoration get warningBox => BoxDecoration(
    color:        AppColors.warningLight,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    border:       Border.all(color: AppColors.warning.withOpacity(0.4)),
  );

  static BoxDecoration selectedAddress() => BoxDecoration(
    color:        AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border:       Border.all(color: AppColors.buttonPrimary, width: 2),
  );

  static BoxDecoration normalAddress() => BoxDecoration(
    color:        AppColors.white,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border:       Border.all(color: AppColors.border, width: 1),
  );

  static BoxDecoration get floatingCart => BoxDecoration(
    color:        AppColors.floatingCartBg,
    borderRadius: BorderRadius.circular(18),
    boxShadow:    AppShadows.accentGlow(color: AppColors.floatingCartBg),
  );

  static BoxDecoration get priceBadge => BoxDecoration(
    color:        AppColors.priceBadgeBg,
    borderRadius: BorderRadius.circular(AppRadius.xs),
  );

  static BoxDecoration get discountBadge => BoxDecoration(
    color:        const Color(0xFF1B5E20),
    borderRadius: BorderRadius.circular(AppRadius.xs),
  );
}


class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color:      Colors.black.withOpacity(0.05),
      blurRadius: 8,
      offset:     const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color:      Colors.black.withOpacity(0.10),
      blurRadius: 14,
      offset:     const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get bottomBar => [
    BoxShadow(
      color:      Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset:     const Offset(0, -2),
    ),
  ];

  static List<BoxShadow> accentGlow({Color? color}) => [
    BoxShadow(
      color:      (color ?? AppColors.buttonPrimary).withOpacity(0.4),
      blurRadius: 16,
      offset:     const Offset(0, 6),
    ),
  ];
}


class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle primary({double radius = 30}) =>
      ElevatedButton.styleFrom(
        backgroundColor:         AppColors.buttonPrimary,
        foregroundColor:         AppColors.buttonPrimaryText,
        disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
      );

  static ButtonStyle primaryMedium({double radius = 12}) =>
      ElevatedButton.styleFrom(
        backgroundColor:         AppColors.buttonPrimary,
        foregroundColor:         AppColors.buttonPrimaryText,
        disabledBackgroundColor: AppColors.buttonPrimaryDisabled,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
      );

  static ButtonStyle primarySmall({double radius = 8}) =>
      ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonPrimary,
        foregroundColor: AppColors.buttonPrimaryText,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
      );

  static ButtonStyle outline({double radius = 30}) =>
      OutlinedButton.styleFrom(
        foregroundColor: AppColors.buttonSecondaryText,
        side: const BorderSide(
            color: AppColors.buttonSecondaryBorder, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  static ButtonStyle danger({double radius = 8}) =>
      ElevatedButton.styleFrom(
        backgroundColor: AppColors.buttonDanger,
        foregroundColor: AppColors.buttonDangerText,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
      );

  static BoxDecoration addButton() => BoxDecoration(
    color:        Colors.white,
    borderRadius: BorderRadius.circular(6),
    border:       Border.all(color: AppColors.buttonPrimary, width: 1.2),
  );

  static BoxDecoration addButtonActive() => BoxDecoration(
    color:        AppColors.buttonPrimary,
    borderRadius: BorderRadius.circular(6),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 4 · RADIUS
// ─────────────────────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 30;
  static const double card = 12;
  static const double pill = 50;
}


// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 5 · SPACING
// ─────────────────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 16;
  static const double lg   = 24;
  static const double xl   = 32;
  static const double xxl  = 48;
  static const double page = 20;
}