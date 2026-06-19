import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Logo Colors
  static const Color primaryBlue = Color(0xFF0097E6);
  static const Color deepBlue    = Color(0xFF0077C8);
  static const Color primaryOrange = Color(0xFFFFA000);
  static const Color primaryYellow = Color(0xFFFFC107);
  static const Color freshGreen    = Color(0xFF43A047);
  static const Color lightGreen    = Color(0xFFE8F5E9);

  // Backgrounds
  static const Color creamBackground = Color(0xFFFFFDF5);
  static const Color cardWhite       = Color(0xFFFFFFFF);
  static const Color scaffoldBg      = creamBackground;

  // Text
  static const Color textDark  = Color(0xFF263238);
  static const Color textGrey  = Color(0xFF757575);
  static const Color textLight = Color(0xFFFFFFFF);

  // Buttons & Interactive
  static const Color buttonPrimary   = primaryOrange;
  static const Color buttonSecondary = primaryBlue;
  static const Color addBtnGreen     = freshGreen;
  static const Color activeNav       = primaryBlue;
  static const Color inactiveNav     = Color(0xFF9E9E9E);

  // Status & Feedback
  static const Color success = Color(0xFF43A047);
  static const Color error   = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);
  static const Color info    = Color(0xFF0097E6);

  // Miscellaneous
  static const Color border      = Color(0xFFE0E0E0);
  static const Color divider     = Color(0xFFEEEEEE);
  static const Color floatingCartBg = primaryOrange;
  static const Color discountBg  = Color(0xFFFFEB3B);
  
  // Legacy aliases (keeping them for easier migration if needed, but mapped to new palette)
  static const Color pink = primaryOrange; // Replaced pink with orange
  static const Color lightBrown = primaryOrange;
  static const Color groceryGreen = freshGreen;
  static const Color groceryGreenLight = lightGreen;
}
