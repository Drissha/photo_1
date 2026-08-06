import 'dart:async';

import 'package:camera/camera.dart' as camera;
import 'package:flutter/foundation.dart';

class LocalCameraPreviewService extends ChangeNotifier {
  List<camera.CameraDescription> _availableCameras = const [];
  camera.CameraController? _controller;
  bool _isInitializing = false;
  bool _isInitialized = false;
  bool _isUnavailable = false;
  bool _isEnabled = true;
  String _status = 'Idle';
  String? _lastError;
  int _initializationToken = 0;
  String? _selectedCameraName;

  List<camera.CameraDescription> get availableCameras => _availableCameras;
  camera.CameraController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _isInitialized;
  bool get isUnavailable => _isUnavailable;
  bool get isEnabled => _isEnabled;
  String get status => _status;
  String? get lastError => _lastError;
  String? get selectedCameraName => _selectedCameraName;

  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) {
      return;
    }

    _isEnabled = enabled;
    if (!enabled) {
      await _disposeController();
      _status = 'Local live view disabled';
      _isUnavailable = false;
    } else {
      _status = 'Local live view enabled';
    }
    notifyListeners();
  }

  Future<void> initializePreview({String? preferredCameraName, bool forceRefresh = false}) async {
    if (!_isEnabled) {
      await _disposeController();
      _status = 'Local live view disabled';
      _isUnavailable = false;
      notifyListeners();
      return;
    }

    final preferredName = preferredCameraName?.trim();
    if (!forceRefresh &&
        _isInitialized &&
        preferredName != null &&
        preferredName.isNotEmpty &&
        preferredName == _selectedCameraName) {
      return;
    }

    final token = ++_initializationToken;
    _isInitializing = true;
    notifyListeners();

    try {
      await _disposeController();

      final cameras = await _loadAvailableCamerasWithRetry();
      if (token != _initializationToken) return;

      _availableCameras = cameras;
      if (cameras.isEmpty) {
        _controller = null;
        _isInitialized = false;
        _isUnavailable = true;
        _status = 'No local camera found. Check Windows Camera privacy settings.';
        _lastError = 'CAMERA_LOCAL_001';
        notifyListeners();
        return;
      }

      final selected = _selectCamera(cameras, preferredName);
      _selectedCameraName = selected.name;

      final controller = camera.CameraController(
        selected,
        camera.ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();

      if (token != _initializationToken) {
        await controller.dispose();
        return;
      }

      _isInitialized = true;
      _isUnavailable = false;
      _status = 'Local live view ready';
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _controller = null;
      _isInitialized = false;
      _isUnavailable = true;
      _status = 'Local live view unavailable';
      _lastError = error.toString();
      notifyListeners();
    } finally {
      if (token == _initializationToken) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> switchCamera(String cameraName) async {
    await initializePreview(preferredCameraName: cameraName);
  }

  Future<void> refreshCameras() async {
    if (!_isEnabled) {
      await _disposeController();
      _availableCameras = const [];
      _status = 'Local live view disabled';
      _isUnavailable = false;
      notifyListeners();
      return;
    }
    await initializePreview(preferredCameraName: _selectedCameraName, forceRefresh: true);
  }

  @override
  void dispose() {
    _initializationToken++;
    unawaited(_disposeController());
    super.dispose();
  }

  camera.CameraDescription _selectCamera(List<camera.CameraDescription> cameras, String? preferredCameraName) {
    if (preferredCameraName != null && preferredCameraName.isNotEmpty) {
      for (final cameraDescription in cameras) {
        if (cameraDescription.name == preferredCameraName) {
          return cameraDescription;
        }
      }
    }

    for (final cameraDescription in cameras) {
      if (cameraDescription.lensDirection == camera.CameraLensDirection.front) {
        return cameraDescription;
      }
    }

    return cameras.first;
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    _isInitialized = false;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<List<camera.CameraDescription>> _loadAvailableCamerasWithRetry() async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final cameras = await camera.availableCameras();
        if (cameras.isNotEmpty || attempt == 2) {
          return cameras;
        }
      } catch (error) {
        lastError = error;
        if (attempt == 2) {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    if (lastError != null) {
      throw lastError!;
    }
    return const [];
  }
}
