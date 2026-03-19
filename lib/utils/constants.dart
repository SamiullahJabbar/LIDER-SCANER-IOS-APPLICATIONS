class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://your-django-backend.com/api';
  static const String uploadEndpoint = '/scans/upload';
  static const String scansEndpoint = '/scans';
  
  // Storage
  static const String dbName = 'lidar_scanner.db';
  static const int dbVersion = 1;
  
  // Scan Settings
  static const double minScanQuality = 0.6; // 60% minimum quality
  static const int maxRetryAttempts = 3;
  static const Duration uploadTimeout = Duration(minutes: 5);
  
  // File Settings
  static const String scanFileExtension = '.scan';
  static const int maxLocalScans = 50;
}
