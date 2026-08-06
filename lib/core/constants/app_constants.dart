class AppConstants {
  AppConstants._();

  static const String appName = 'Papyrus Photobooth';
  static const String defaultSaveFolderName = 'Papyrus';
  static const String defaultSaveFolderPath = 'C:/Users/Public/Pictures/Papyrus';
  static const String defaultBackgroundFolderName = 'PapyrusBackgrounds';
  static const String logsDirectoryName = 'logs';
  static const String digicamControlHost = '127.0.0.1';
  static const int digicamControlCommandPort = 5513;
  static const int digicamControlLiveViewPort = 5514;
  static const String digicamControlCommandBaseUrl =
      'http://$digicamControlHost:$digicamControlCommandPort';
  static const String digicamControlLiveViewBaseUrl =
      'http://$digicamControlHost:$digicamControlLiveViewPort';
  static const String digicamControlRemoteCmdPath =
      'C:/Program Files/digiCamControl/CameraControlRemoteCmd.exe';
  static const String diagnosticsRoute = '/diagnostics';
  static const int healthCheckIntervalSeconds = 1;
  static const int reconnectDelaySeconds = 2;
  static const int autoCaptureDelaySeconds = 3;
  static const int capturePreviewDurationSeconds = 3;
  static const int maxRecentPhotos = 24;

  static String buildDigicamControlBaseUrl(int port) {
    return 'http://$digicamControlHost:$port';
  }
}
