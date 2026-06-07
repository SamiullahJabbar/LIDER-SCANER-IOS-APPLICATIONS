import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_history_screen.dart';
import 'screens/new_scan_screen.dart';
import 'screens/scan_quality_screen.dart';
import 'screens/scan_preview_screen.dart';
import 'screens/viewer_3d_screen.dart';
import 'screens/scan_upload_screen.dart';
import 'screens/scan_vault_upload_screen.dart';
import 'screens/scan_detail_screen.dart';
import 'screens/platform_ar_camera_screen.dart';
import 'screens/measurement_result_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/local_scan_provider.dart';
import 'services/local_scan_storage_service.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting LiDAR Pro Scanner (Offline Mode)...');

  // Initialize local scan storage (SQLite + encrypted file storage)
  try {
    await LocalScanStorageService.instance.initialize();
    debugPrint('✅ Local storage initialized');
  } catch (e) {
    debugPrint('⚠️ Storage initialization warning: $e');
  }

  // Set status bar style - transparent with light icons
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) {
          final auth = AuthProvider();
          auth.initialize();
          return auth;
        }),
        // Local scan provider — fully offline, no backend
        ChangeNotifierProvider(create: (_) {
          final provider = LocalScanProvider();
          provider.initialize();
          return provider;
        }),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'LiDAR Pro Scanner',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryBlue,
              primary: AppColors.primaryBlue,
              secondary: AppColors.accentBlue,
              brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: themeProvider.isDarkMode 
                ? const Color(0xFF0F172A) 
                : AppColors.white,
            
            // Typography - Modern 2026 style
            textTheme: TextTheme(
              displayLarge: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.charcoal,
                letterSpacing: -0.5,
              ),
              displayMedium: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
                letterSpacing: -0.3,
              ),
              displaySmall: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
              headlineMedium: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
              bodyLarge: TextStyle(
                fontSize: 16,
                color: AppColors.darkGray,
                height: 1.6,
              ),
              bodyMedium: TextStyle(
                fontSize: 14,
                color: AppColors.darkGray,
                height: 1.5,
              ),
              labelLarge: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            
            // Button themes
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            // Input decoration
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.lightGray,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.accentBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.error,
                  width: 2,
                ),
              ),
              hintStyle: TextStyle(
                color: AppColors.mediumGray,
                fontSize: 14,
              ),
            ),
            
            // Card theme
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: AppColors.white,
            ),
            
            // App bar theme
            appBarTheme: AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.charcoal,
              centerTitle: true,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
                letterSpacing: 0.5,
              ),
            ),
          ),
          home: const AuthWrapper(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/scan-history': (context) => const ScanHistoryScreen(),
            '/new-scan': (context) => const NewScanScreen(),
            '/scan-quality': (context) => const ScanQualityScreen(),
            '/scan-preview': (context) => const ScanPreviewScreen(),
            '/3d-viewer': (context) => const Viewer3DScreen(),
            '/scan-upload': (context) => const ScanUploadScreen(),
            '/scan-vault-upload': (context) => const ScanVaultUploadScreen(),
            '/scan-detail': (context) => const ScanDetailScreen(),
            '/ar-scan-camera': (context) => const PlatformARCameraScreen(scanName: 'New Scan'),
            '/measurement-result': (context) => const MeasurementResultScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // initialize() is already called in main() when creating AuthProvider.
  // Calling it again here is safe (memoized) but unnecessary.
  // No duplicate init — prevents race condition.

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.unauthenticated:
            return const OnboardingScreen();
        }
      },
    );
  }
}
