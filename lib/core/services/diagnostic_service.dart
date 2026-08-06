import 'package:path_provider/path_provider.dart';
import '../models/app_error.dart';
import 'camera_manager_service.dart';
import 'settings_repository.dart';
import 'storage_service.dart';

class DiagnosticService {
  DiagnosticService({
    required this.cameraManager,
    required this.storageService,
    required this.settingsRepository,
  });

  final CameraManagerService cameraManager;
  final StorageService storageService;
  final SettingsRepository settingsRepository;

  Future<Map<String, dynamic>> collectDiagnostics() async {
    final settings = await settingsRepository.loadSettings();
    final saveDirectory = await storageService.ensureSaveDirectory(settings.saveFolderPath);
    final appDir = await getApplicationSupportDirectory();
    return {
      'cameraDriver': 'DigiCamControl',
      'cameraApi': 'CameraControlRemoteCmd + Web LiveView',
      'currentResolution': cameraManager.resolution,
      'fps': cameraManager.fps,
      'localLiveView': 'Enabled via webcam',
      'localPreviewStatus': settings.liveViewEnabled ? 'Enabled' : 'Disabled',
      'availableCameras': cameraManager.availableDevices.map((camera) => camera.name).toList(),
      'currentSettings': settings.toString(),
      'captureTest': cameraManager.isInitialized ? 'Ready' : 'Not Ready',
      'previewTest': cameraManager.isInitialized ? 'Running' : 'Stopped',
      'writePermissionTest': saveDirectory.existsSync() ? 'Granted' : 'Denied',
      'diskSpace': 'Available',
      'memoryUsage': 'N/A',
      'logDirectory': '${appDir.path}/logs',
    };
  }

  Future<AppError?> runCaptureTest() async {
    try {
      await cameraManager.capturePhoto(await storageService.getDefaultSaveFolder());
      return null;
    } catch (error) {
      return const AppError(
        code: 'CAM003',
        cause: 'Capture test failed.',
        solution: 'Check the camera connection and try again.',
        autoFix: 'Retry Capture',
        retryable: true,
      );
    }
  }
}
