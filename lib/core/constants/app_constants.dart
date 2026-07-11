class AppConstants {
  AppConstants._();

  static const String appName = 'Papyrus Photobooth';
  static const String defaultSaveFolderName = 'Papyrus';
  static const String defaultSaveFolderPath = 'C:/Users/Public/Pictures/Papyrus';
  static const String logsDirectoryName = 'logs';
  static const String diagnosticsRoute = '/diagnostics';
  static const int healthCheckIntervalSeconds = 1;
  static const int reconnectDelaySeconds = 2;
  static const int autoCaptureDelaySeconds = 3;
  static const int maxRecentPhotos = 24;
}
