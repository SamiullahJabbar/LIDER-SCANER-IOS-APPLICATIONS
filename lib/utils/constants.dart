class AppConstants {
  // Storage — fully local SQLite
  static const String dbName = 'lidar_scans_v3.db';
  static const int dbVersion = 4;
  
  // Scan Settings
  static const double minScanQuality = 0.6; // 60% minimum quality
  static const int maxRetryAttempts = 3;
  
  // File Settings
  static const String scanFileExtension = '.scan';
  static const int maxLocalScans = 50;
}
