// ─────────────────────────────────────────────────────────────────────────────
//  SECTION 2 · TEXT STYLES
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_color.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle appBarTitle = TextStyle(
    color:      AppColors.appBarText,
    fontSize:   18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize:   15,
    fontWeight: FontWeight.bold,
    color:      AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize:   14,
    fontWeight: FontWeight.w600,
    color:      AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize:   14,
    color:      AppColors.textPrimary,
    height:     1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color:    AppColors.textSecondary,
  );

  static const TextStyle hint = TextStyle(
    fontSize: 13,
    color:    AppColors.textMuted,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize:   13,
    fontWeight: FontWeight.bold,
    color:      AppColors.textAccent,
  );

  static const TextStyle price = TextStyle(
    fontSize:   16,
    fontWeight: FontWeight.bold,
    color:      AppColors.priceGreen,
  );

  static const TextStyle priceStrike = TextStyle(
    fontSize:   13,
    color:      AppColors.strikethrough,
    decoration: TextDecoration.lineThrough,
  );

  static final TextStyle discountBadge = TextStyle(
    fontSize:   9,
    fontWeight: FontWeight.bold,
    color:      Colors.white,
  );

  static final TextStyle buttonLabel = TextStyle(
    fontSize:   15,
    fontWeight: FontWeight.bold,
    color:      AppColors.buttonPrimaryText,
  );

  static const TextStyle buttonLabelSmall = TextStyle(
    fontSize:   12,
    fontWeight: FontWeight.bold,
    color:      AppColors.buttonPrimaryText,
  );

  static const TextStyle link = TextStyle(
    fontSize:   14,
    fontWeight: FontWeight.w600,
    color:      AppColors.textLink,
    decoration: TextDecoration.underline,
  );
}