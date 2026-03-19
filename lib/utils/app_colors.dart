import 'package:flutter/material.dart';

class AppColors {
  // 2026 Modern Premium Color Palette
  // Deep Ocean Blue Theme with Vibrant Accents
  
  // Primary Colors - Deep Blue Spectrum
  static const Color primaryBlue = Color(0xFF0A2463); // Deep navy blue
  static const Color accentBlue = Color(0xFF3E92CC); // Vibrant blue
  static const Color lightBlue = Color(0xFF5DADE2); // Sky blue
  static const Color electricBlue = Color(0xFF00D9FF); // Electric cyan
  
  // Secondary Colors - Warm Accents
  static const Color coral = Color(0xFFFF6B6B); // Coral red
  static const Color gold = Color(0xFFFFD93D); // Golden yellow
  static const Color mint = Color(0xFF6BCB77); // Mint green
  static const Color lavender = Color(0xFFA78BFA); // Soft purple
  
  // Neutral Colors - Premium Grays
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F9FA);
  static const Color lightGray = Color(0xFFE9ECEF);
  static const Color mediumGray = Color(0xFFADB5BD);
  static const Color darkGray = Color(0xFF495057);
  static const Color charcoal = Color(0xFF212529);
  static const Color black = Color(0xFF000000);
  
  // Glassmorphism Colors
  static Color glassWhite = Colors.white.withOpacity(0.1);
  static Color glassBlue = const Color(0xFF3E92CC).withOpacity(0.15);
  
  // Status Colors
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Gradients - 2026 Style
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A2463), // Deep navy
      Color(0xFF3E92CC), // Vibrant blue
      Color(0xFF5DADE2), // Sky blue
    ],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00D9FF), // Electric cyan
      Color(0xFF3E92CC), // Vibrant blue
    ],
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6B6B), // Coral
      Color(0xFFFFD93D), // Gold
    ],
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6BCB77), // Mint
      Color(0xFF3E92CC), // Blue
    ],
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A2463), // Deep navy
      Color(0xFF1E3A8A), // Dark blue
    ],
  );
  
  // Shimmer Gradient
  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.0, -0.5),
    end: Alignment(1.0, 0.5),
    colors: [
      Color(0xFFE9ECEF),
      Color(0xFFF8F9FA),
      Color(0xFFE9ECEF),
    ],
  );
}
