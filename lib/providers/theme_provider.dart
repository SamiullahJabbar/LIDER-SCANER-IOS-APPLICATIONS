import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final DatabaseService _db = DatabaseService.instance;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await _db.getSetting('theme');
    _isDarkMode = theme == 'dark';
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _db.saveSetting('theme', _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }

  ThemeData get themeData {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // Light Theme
  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0A2463),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0A2463),
          secondary: Color(0xFF3E92CC),
          surface: Colors.white,
        ),
        useMaterial3: true,
      );

  // Dark Theme
  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3E92CC),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3E92CC),
          secondary: Color(0xFF5DADE2),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      );
}
