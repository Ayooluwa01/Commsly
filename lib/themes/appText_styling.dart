import 'package:flutter/material.dart';

abstract final class AppTextStyling {
  static const String _fontFamily = 'PlusJakarta';
  static TextStyle jakarta({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
    ).merge(textStyle);
  }

  // Pre-defined constant text styles using the local font
  static TextStyle get displayLarge =>
      jakarta(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5);

  static TextStyle get displayMedium =>
      jakarta(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5);

  static TextStyle get headlineLarge =>
      jakarta(fontSize: 24, fontWeight: FontWeight.w600);

  static TextStyle get headlineMedium =>
      jakarta(fontSize: 20, fontWeight: FontWeight.w600);

  static TextStyle get headlineSmall =>
      jakarta(fontSize: 12, fontWeight: FontWeight.w600);

  static TextStyle get bodyLarge =>
      jakarta(fontSize: 16, fontWeight: FontWeight.normal);

  static TextStyle get bodyMedium =>
      jakarta(fontSize: 14, fontWeight: FontWeight.normal);

  static TextStyle get bodySmall =>
      jakarta(fontSize: 12, fontWeight: FontWeight.normal);

  static TextStyle get labelLarge =>
      jakarta(fontSize: 14, fontWeight: FontWeight.w500);

  static TextStyle get labelMedium =>
      jakarta(fontSize: 12, fontWeight: FontWeight.w500);
}
