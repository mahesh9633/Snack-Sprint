import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Snack Sprint Brand Palette - Derived from Logo
  static const Color primaryBlue = Color(0xFF7A1F2B);      // Primary Burgundy
  static const Color deepBlue = Color(0xFF5A1621);         // Deep Burgundy
  static const Color primaryOrange = Color(0xFFC58A22);    // Premium Antique Gold
  static const Color primaryYellow = Color(0xFFE0A83A);    // Bright Gold
  static const Color freshGreen = Color(0xFF3F7D3A);       // Success Green
  static const Color lightGreen = Color(0xFFE8F3E5);       // Light Success
  static const Color gradientTop    = Color(0xFF7A1F2B);   // Burgundy
  static const Color gradientBottom = Color(0xFF5A1621);   // Deep Burgundy

  static const Color creamBackground = Color(0xFFFFF8E8);  // Warm Cream Background
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color scaffoldBg = creamBackground;

  static const Color textDark = Color(0xFF2B1B16);         // Dark Chocolate Text
  static const Color textGrey = Color(0xFF76665D);         // Secondary Text
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color white = Colors.white;
  static const Color appBarBg = creamBackground;
  static const Color appBarIcon = primaryBlue;             // Burgundy
  static const Color appBarText = textDark;               // Dark Chocolate

  static const Color buttonPrimary = primaryBlue;          // Burgundy
  static const Color buttonSecondary = primaryOrange;      // Gold
  static const Color buttonPrimaryText = Colors.white;
  static const Color buttonSecondaryText = primaryBlue;
  static const Color buttonPrimaryDisabled = Color(0xFFA87E84); // Muted Burgundy

  static const Color addBtnGreen = freshGreen;
  static const Color activeNav = primaryBlue;              // Burgundy
  static const Color inactiveNav = Color(0xFF9A8C82);      // Muted Brownish Grey

  static const Color success = freshGreen;
  static const Color successLight = lightGreen;
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFDECEC);
  static const Color warning = Color(0xFFC58A22);          // Gold
  static const Color warningLight = Color(0xFFF3D58A);     // Light Gold
  static const Color info = primaryBlue;

  static const Color border = Color(0xFFE5D8C8);
  static const Color divider = Color(0xFFEFE5D8);
  static const Color floatingCartBg = primaryOrange;       // Gold
  static const Color discountBg = Color(0xFFF3D58A);       // Light Gold

  static const Color headerBanner = deepBlue;              // Deep Burgundy
  static const Color sectionHeader = primaryBlue;          // Burgundy
  static const Color priceGreen = freshGreen;
  static const Color accentDark = Color(0xFF5A3525);       // Chocolate
  static const Color accentLight = Color(0xFFF3D58A);      // Light Gold
  static const Color sidebarBg = creamBackground;
  static const Color loader = primaryBlue;

  static const Color textPrimary = textDark;
  static const Color textSecondary = textGrey;
  static const Color textMuted = Color(0xFF9A8C82);

  static const Color strikethrough = Color(0xFF9A8C82);

  static const Color pink = primaryBlue;
  static const Color lightBrown = Color(0xFF5A3525);       // Chocolate
  static const Color groceryGreen = freshGreen;
  static const Color groceryGreenLight = lightGreen;
  static const Color textAccent = primaryOrange;           // Gold
}
