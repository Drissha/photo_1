import 'dart:async';
import 'dart:io';

import '../models/app_error.dart';
import 'camera_manager_service.dart';
import 'storage_service.dart';

class TroubleshootingService {
  TroubleshootingService({
    required this.cameraManager,
    required this.storageService,
  });

  final CameraManagerService cameraManager;
  final StorageService storageService;

  final StreamController<AppError> _errorController = StreamController<AppError>.broadcast();
  Timer? _monitorTimer;

  Stream<AppError> get errors => _errorController.stream;

  void startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final error = await runDiagnostics();
      if (error != null) {
        _errorController.add(error);
        await autoRepair(error);
      }
    });
  }

  void stopMonitoring() {
    _monitorTimer?.cancel();
  }

  Future<AppError?> runDiagnostics() async {
    if (cameraManager.controller == null || !cameraManager.controller!.value.isInitialized) {
      return const AppError(
        code: 'CAM002',
        cause: 'Camera disconnected or not ready.',
        solution: 'Reconnect the camera or restart the app.',
        autoFix: 'Reconnect Camera',
        retryable: true,
      );
    }

    final directory = Directory(await storageService.getDefaultSaveFolder());
    if (!directory.existsSync()) {
      return const AppError(
        code: 'CAM005',
        cause: 'Storage folder unavailable.',
        solution: 'Select a writable folder in settings.',
        autoFix: 'Create Storage Folder',
        retryable: true,
      );
    }

    return null;
  }

  Future<void> autoRepair(AppError error) async {
    switch (error.code) {
      case 'CAM002':
        await cameraManager.reconnectCamera();
        break;
      case 'CAM003':
        await cameraManager.restartCamera();
        break;
      case 'CAM005':
        await storageService.ensureSaveDirectory(await storageService.getDefaultSaveFolder());
        break;
      default:
        await cameraManager.restartCamera();
        break;
    }
  }

  void dispose() {
    _monitorTimer?.cancel();
    _errorController.close();
  }
}
