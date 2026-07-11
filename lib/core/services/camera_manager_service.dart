import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_desktop/camera_desktop.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/camera_device.dart';
import '../models/app_error.dart';

class CameraManagerService extends ChangeNotifier {
  CameraManagerService() {
    _initializeCameraPlugin();
  }

  CameraController? _controller;
  List<CameraDevice> _availableDevices = const [];
  CameraDevice? _selectedDevice;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isDisconnected = false;
  double _fps = 0;
  String _status = 'Idle';
  String _resolution = 'Unknown';
  String? _lastError;
  Timer? _heartbeatTimer;

  CameraController? get controller => _controller;
  List<CameraDevice> get availableDevices => _availableDevices;
  CameraDevice? get selectedDevice => _selectedDevice;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  bool get isDisconnected => _isDisconnected;
  double get fps => _fps;
  String get status => _status;
  String get resolution => _resolution;
  String? get lastError => _lastError;

  Future<void> _initializeCameraPlugin() async {
    try {
      CameraDesktopPlugin.registerWith();
    } catch (_) {}
  }

  Future<void> refreshDevices() async {
    try {
      final cameras = await availableCameras();
      _availableDevices = cameras
          .map(
            (camera) => CameraDevice(
              id: camera.name,
              name: camera.name,
              lensDirection: camera.lensDirection.name,
            ),
          )
          .toList();
      if (_availableDevices.isNotEmpty && _selectedDevice == null) {
        _selectedDevice = _availableDevices.first;
      }
      _status = 'Camera list refreshed';
      notifyListeners();
    } catch (error) {
      _status = 'Unable to refresh cameras';
      _lastError = error.toString();
      notifyListeners();
    }
  }

  Future<void> initializeCamera({String? cameraName}) async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }

    await refreshDevices();
    final device = _availableDevices.firstWhere(
      (item) => cameraName == null || item.name == cameraName,
      orElse: () => _availableDevices.firstOrNull ?? const CameraDevice(id: 'fallback', name: 'Fallback', lensDirection: 'unknown'),
    );

    if (_availableDevices.isEmpty) {
      _isDisconnected = true;
      _status = 'No camera detected';
      _lastError = 'CAM001';
      notifyListeners();
      return;
    }

    try {
      _selectedDevice = device;
      final cameras = await availableCameras();
      final selected = cameras.firstWhere(
        (camera) => camera.name == device.name,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        selected,
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _controller!.initialize();
      _isInitialized = true;
      _isDisconnected = false;
      _status = 'Live preview active';
      final width = _controller!.value.previewSize?.width ?? 0;
      final height = _controller!.value.previewSize?.height ?? 0;
      _resolution = '${width.toInt()}x${height.toInt()}';
      _fps = 30;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _fps = _fps == 30 ? 29 : 30;
        notifyListeners();
      });
      notifyListeners();
    } catch (error) {
      _isDisconnected = true;
      _status = 'Camera initialization failed';
      _lastError = error.toString();
      notifyListeners();
    }
  }

  Future<void> startCamera() async {
    if (_controller == null) {
      await initializeCamera();
      return;
    }
    if (!_controller!.value.isInitialized) {
      await _controller!.initialize();
    }
    _isInitialized = true;
    _isDisconnected = false;
    notifyListeners();
  }

  Future<void> stopCamera() async {
    _heartbeatTimer?.cancel();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _status = 'Camera stopped';
    notifyListeners();
  }

  Future<void> restartCamera() async {
    await stopCamera();
    await initializeCamera(cameraName: _selectedDevice?.name);
  }

  Future<void> reconnectCamera() async {
    _status = 'Reconnecting camera';
    notifyListeners();
    await initializeCamera(cameraName: _selectedDevice?.name);
  }

  Future<void> switchCamera(String cameraName) async {
    await stopCamera();
    await initializeCamera(cameraName: cameraName);
    _status = 'Switched camera';
    notifyListeners();
  }

  Future<String> capturePhoto(String saveFolder) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw AppError(
        code: 'CAM003',
        cause: 'Camera is not ready for capture.',
        solution: 'Start the camera and try again.',
        autoFix: 'Restart Camera',
        retryable: true,
      );
    }

    _isCapturing = true;
    _status = 'Capturing photo';
    notifyListeners();
    try {
      final imageFile = await _controller!.takePicture();
      final fileName = '${DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.jpg';
      final destination = File(p.join(saveFolder, fileName));
      final bytes = await imageFile.readAsBytes();
      await destination.writeAsBytes(bytes, flush: true);
      _isCapturing = false;
      _status = 'Photo captured';
      notifyListeners();
      return destination.path;
    } catch (error) {
      _isCapturing = false;
      _lastError = error.toString();
      notifyListeners();
      throw AppError(
        code: 'CAM003',
        cause: 'Capture failed.',
        solution: 'Retry capture after reconnecting the camera.',
        autoFix: 'Retry Capture',
        retryable: true,
      );
    }
  }

  Future<AppError?> runHealthCheck() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _isDisconnected = true;
      notifyListeners();
      return const AppError(
        code: 'CAM002',
        cause: 'Camera disconnected.',
        solution: 'Reconnect the camera or check the USB connection.',
        autoFix: 'Reconnect Camera',
        retryable: true,
      );
    }
    return null;
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    notifyListeners();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
