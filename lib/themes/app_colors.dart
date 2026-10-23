import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF087BFF);
  static const navy = Color(0xFF071C3D);
  static const cyan = Color(0xFF13C9F4);
  static const mint = Color(0xFF20D8B4);

  static const background = Color(0xFFF7FAFF);
  static const surface = Color(0xFFFFFFFF);
  static const softBlue = Color(0xFFE8F2FF);

  static const textPrimary = Color(0xFF071C3D);
  static const textSecondary = Color(0xFF6C7D99);

  static const success = Color(0xFF18B879);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFEF476F);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF13C9F4), Color(0xFF087BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF071C3D), Color(0xFF094C9E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
