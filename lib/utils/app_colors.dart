// PRODUCTION-READY App Colors
// Consistent color scheme across the app
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primaryDark = Color(0xFF0A2463);
  static const Color primaryBlue = Color(0xFF3E92CC);
  static const Color accentBlue = Color(0xFF1E88E5);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF29B6F6);
  
  // Neutral colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundLight = Color(0xFF1E1E1E);
  static const Color surface = Color(0xFF2C2C2C);
  static const Color surfaceLight = Color(0xFF3C3C3C);
  
  // Basic colors (missing)
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8F9FA);
  static const Color lightGray = Color(0xFFE0E0E0);
  static const Color mediumGray = Color(0xFF9E9E9E);
  static const Color darkGray = Color(0xFF616161);
  static const Color charcoal = Color(0xFF2C2C2C);
  
  // Accent colors (missing)
  static const Color mint = Color(0xFF4ECDC4);
  static const Color lavender = Color(0xFF9B59B6);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF707070);
  
  // Scan colors
  static const Color manualPin = Color(0xFFE53935); // Red
  static const Color autoPoint = Color(0xFFFFEB3B); // Yellow
  static const Color pathLine = Color(0xFF1E88E5); // Blue
  
  // Confidence colors
  static Color getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return success;
    if (confidence >= 0.7) return info;
    if (confidence >= 0.5) return warning;
    return error;
  }
  
  // Device type colors
  static const Color lidarColor = Color(0xFF4CAF50);
  static const Color arColor = Color(0xFF29B6F6);
  static const Color cameraColor = Color(0xFFFFA726);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primaryBlue],
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark, backgroundLight],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, primaryBlue],
  );
  
  static const LinearGradient coolGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
  );
}
