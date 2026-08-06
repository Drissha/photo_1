import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';
import '../models/app_error.dart';
import '../models/app_settings.dart';
import '../models/camera_device.dart';

class CameraManagerService extends ChangeNotifier {
  CameraManagerService();

  List<CameraDevice> _availableDevices = const [];
  CameraDevice? _selectedDevice;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isCapturing = false;
  bool _isLiveViewPaused = false;
  bool _isDisconnected = false;
  double _fps = 0;
  String _status = 'Idle';
  String _resolution = 'Live view';
  String? _lastError;
  Timer? _heartbeatTimer;
  int _heartbeatTick = 0;
  int _initializationToken = 0;
  int _commandPort = AppConstants.digicamControlCommandPort;
  int _liveViewPort = AppConstants.digicamControlLiveViewPort;
  String _remoteCmdPath = AppConstants.digicamControlRemoteCmdPath;

  List<CameraDevice> get availableDevices => _availableDevices;
  CameraDevice? get selectedDevice => _selectedDevice;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isCapturing => _isCapturing;
  bool get isLiveViewPaused => _isLiveViewPaused;
  bool get isDisconnected => _isDisconnected;
  bool get isLiveViewEnabled => false;
  double get fps => _fps;
  String get status => _status;
  String get resolution => _resolution;
  String? get lastError => _lastError;

  bool get _hasRemoteCmdPath {
    final path = _remoteCmdPath.trim();
    if (path.isEmpty) return false;
    return File(path).existsSync();
  }

  String get liveViewImageUrl {
    return '';
  }

  String get liveViewStreamUrl {
    return '';
  }

  void updateConnectionSettings(AppSettings settings) {
    _commandPort = _normalizePort(settings.digicamControlCommandPort, AppConstants.digicamControlCommandPort);
    _liveViewPort = _normalizeDistinctPort(
      settings.digicamControlLiveViewPort,
      _commandPort,
      AppConstants.digicamControlLiveViewPort,
    );
    _remoteCmdPath = settings.digicamControlRemoteCmdPath.trim().isEmpty
        ? AppConstants.digicamControlRemoteCmdPath
        : settings.digicamControlRemoteCmdPath.trim();
  }

  Future<void> refreshDevices() async {
    try {
      final lines = await _runListCommand('cameras');
      final cameras = lines
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .where((line) => !line.toLowerCase().startsWith('ok'))
          .map(
            (line) => CameraDevice(
              id: line,
              name: line,
              lensDirection: 'unknown',
            ),
          )
          .toList();

      _availableDevices = cameras;
      if (_availableDevices.isNotEmpty) {
        final preferredName = _selectedDevice?.name;
        _selectedDevice = preferredName == null
            ? _availableDevices.first
            : _availableDevices.firstWhere(
                (camera) => camera.name == preferredName,
                orElse: () => _availableDevices.first,
              );
      } else {
        _selectedDevice = null;
      }
      _status = 'Camera list refreshed';
      _isDisconnected = false;
      notifyListeners();
    } catch (error) {
      _status = 'Unable to refresh cameras';
      _lastError = error.toString();
      _isDisconnected = true;
      notifyListeners();
    }
  }

  Future<void> initializeCamera({String? cameraName}) async {
    final token = ++_initializationToken;
    _isInitializing = true;
    notifyListeners();

    try {
      await refreshDevices();
      if (token != _initializationToken) return;

      if (_availableDevices.isEmpty) {
        _selectedDevice = null;
        _isDisconnected = true;
        _status = 'No camera detected';
        _lastError = 'CAM001';
        notifyListeners();
        return;
      }

      final selected = cameraName == null || cameraName.trim().isEmpty
          ? _availableDevices.first
          : _availableDevices.firstWhere(
              (camera) => camera.name == cameraName,
              orElse: () => _availableDevices.first,
            );
      _selectedDevice = selected;

      await _runCommand(['set', 'camera', _cameraSelectionValue(selected.name)], allowWebFallback: true);

      if (token != _initializationToken) return;
      _isInitialized = true;
      _isDisconnected = false;
      _isLiveViewPaused = false;
      _status = 'Camera ready';
      _resolution = 'Capture only';
      _fps = 0;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      notifyListeners();
    } catch (error) {
      _isDisconnected = true;
      _status = 'Camera initialization failed';
      _lastError = error.toString();
      notifyListeners();
    } finally {
      if (token == _initializationToken) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> startCamera() async {
    if (_isInitialized) {
      _status = 'Camera ready';
      _resolution = 'Capture only';
      _fps = 0;
      _isLiveViewPaused = false;
      notifyListeners();
      return;
    }
    await initializeCamera(cameraName: _selectedDevice?.name);
  }

  Future<void> stopCamera() async {
    _initializationToken++;
    _isInitializing = false;
    await stopLiveView(keepInitialized: false, notify: false);
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
    await stopLiveView(keepInitialized: true, notify: true);
    await initializeCamera(cameraName: cameraName);
    _status = 'Switched camera';
    notifyListeners();
  }

  Future<void> applyCameraSettings(AppSettings settings) async {
    if (!_isInitialized || _selectedDevice == null) {
      return;
    }

    _status = 'Applying camera settings';
    notifyListeners();

    final commands = <List<String>>[
      ['set', 'camera.brightness', _percent(settings.cameraBrightness)],
      ['set', 'camera.contrast', _percent(settings.cameraContrast)],
      ['set', 'camera.gamma', _percent(settings.cameraGamma)],
      ['set', 'camera.sharpness', _percent(settings.cameraSharpness)],
      ['set', 'camera.saturation', _percent(settings.cameraSaturation)],
      ['set', 'camera.hue', _percent(settings.cameraHue)],
      ['set', 'camera.exposurecompensation', _exposureValue(settings.cameraExposure)],
      ['set', 'camera.gain', _percent(settings.cameraGain)],
      ['set', 'camera.focus', _percent(settings.cameraFocus)],
      ['set', 'camera.zoom', _percent(settings.cameraZoom)],
      ['set', 'camera.whitebalance', _whiteBalanceValue(settings.cameraWhiteBalance)],
      ['set', 'camera.backlightcompensation', _percent(settings.cameraBacklightCompensation)],
      ['set', 'camera.powerlinefrequency', _powerLineFrequency(settings.cameraPowerLineFrequency)],
      ['set', 'liveview.fliphorizontal', _boolCommand(settings.cameraFlipHorizontal)],
      ['set', 'liveview.flipvertical', _boolCommand(settings.cameraFlipVertical)],
      ['set', 'camera.mirror', _boolCommand(settings.cameraMirror)],
    ];

    final warnings = <String>[];
    for (final command in commands) {
      try {
        await _runCommand(command, allowWebFallback: true);
      } catch (error) {
        warnings.add(error.toString());
      }
    }

    if (warnings.isEmpty) {
      _status = 'Camera settings applied';
    } else {
      _status = 'Camera settings applied with warnings';
      _lastError = warnings.first;
    }
    notifyListeners();
  }

  Future<String> capturePhoto(String saveFolder) async {
    if (!_isInitialized || _selectedDevice == null) {
      throw AppError(
        code: 'CAM003',
        cause: 'Camera is not ready for capture.',
        solution: 'Start the camera and try again.',
        autoFix: 'Restart Camera',
        retryable: true,
      );
    }

    final fileName = 'papyrus_${DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-')}.jpg';
    final destination = File(p.join(saveFolder, fileName));
    final captureStartedAt = DateTime.now();

    _isCapturing = true;
    _status = 'Capturing photo';
    notifyListeners();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await _runCommand(['capture', destination.path], allowWebFallback: true);
      final capturedPath = await _resolveCapturedFile(destination, captureStartedAt);
      _isCapturing = false;
      _status = 'Photo captured';
      notifyListeners();
      return capturedPath;
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
    if (!_isInitialized) {
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

  Future<void> stopLiveView({required bool keepInitialized, required bool notify}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isLiveViewPaused = false;
    if (!keepInitialized) {
      _isInitialized = false;
      _status = 'Camera stopped';
    } else {
      _status = 'Camera ready';
      _resolution = 'Capture only';
      _fps = 0;
    }
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _initializationToken++;
    _isInitializing = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isInitialized = false;
    _isLiveViewPaused = false;
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTick = 0;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isInitialized) return;
      _heartbeatTick += 1;
      _fps = 1;
    });
  }

  Future<String> _runCommand(
    List<String> commandParts, {
    required bool allowWebFallback,
  }) async {
    if (_hasRemoteCmdPath) {
      final result = await Process.run(
        _remoteCmdPath,
        <String>['/clean', '/c', ...commandParts],
        runInShell: false,
      );
      if (result.exitCode == 0) {
        return result.stdout?.toString() ?? '';
      }
      if (!allowWebFallback) {
        throw StateError(result.stderr?.toString().trim().isEmpty == true
            ? 'DigicamControl command failed.'
            : result.stderr.toString().trim());
      }
    }

    if (!allowWebFallback) {
      throw StateError('DigicamControl command executable was not found.');
    }

    return _runWebCommand(commandParts);
  }

  Future<String> _runWebCommand(List<String> commandParts) async {
    if (commandParts.isEmpty) {
      throw StateError('Missing DigiCamControl command.');
    }

    final command = commandParts.first.toLowerCase();
    switch (command) {
      case 'list':
        if (commandParts.length < 2) {
          throw StateError('Missing list target.');
        }
        return _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'slc': 'list',
              'param1': commandParts[1],
              'param2': '',
            },
          ),
        );
      case 'set':
        if (commandParts.length < 3) {
          throw StateError('Missing set arguments.');
        }
        return _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'slc': 'set',
              'param1': commandParts[1],
              'param2': commandParts.sublist(2).join(' '),
            },
          ),
        );
      case 'do':
        if (commandParts.length < 2) {
          throw StateError('Missing command name.');
        }
        return _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'CMD': commandParts[1],
            },
          ),
        );
      case 'capture':
        if (commandParts.length < 2) {
          throw StateError('Missing capture target path.');
        }
        final destination = commandParts[1];
        final directory = p.dirname(destination);
        final baseName = p.basenameWithoutExtension(destination);
        await _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'slc': 'set',
              'param1': 'session.folder',
              'param2': directory,
            },
          ),
        );
        await _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'slc': 'set',
              'param1': 'session.filenametemplate',
              'param2': baseName,
            },
          ),
        );
        return _getText(
          Uri.parse(_buildCommandBaseUrl()).replace(
            queryParameters: <String, String>{
              'CMD': 'Capture',
            },
          ),
        );
      default:
        throw StateError('Unsupported DigiCamControl command: $command');
    }
  }

  Future<List<String>> _runListCommand(String target) async {
    final output = await _runCommand(['list', target], allowWebFallback: true);
    return output
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<String> _getText(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 400) {
        throw StateError(text.isEmpty
            ? 'DigiCamControl request failed with ${response.statusCode}.'
            : text.trim());
      }
      return text;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _waitForFile(File file) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (await file.exists()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('Captured file was not created.');
  }

  Future<String> _resolveCapturedFile(File destination, DateTime captureStartedAt) async {
    if (await destination.exists()) {
      return destination.path;
    }

    final directory = Directory(p.dirname(destination.path));
    final destinationBaseName = p.basenameWithoutExtension(destination.path).toLowerCase();
    for (var attempt = 0; attempt < 40; attempt++) {
      final candidates = _findCaptureCandidates(directory, captureStartedAt, destinationBaseName);
      if (candidates.isNotEmpty) {
        return candidates.first.path;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw StateError('Captured file was not created.');
  }

  List<File> _findCaptureCandidates(
    Directory directory,
    DateTime captureStartedAt,
    String destinationBaseName,
  ) {
    if (!directory.existsSync()) {
      return const [];
    }

    final recentFiles = directory
        .listSync()
        .whereType<File>()
        .where((file) {
          final lowerPath = file.path.toLowerCase();
          return lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png');
        })
        .where((file) {
          final stat = file.statSync();
          return stat.modified.isAfter(captureStartedAt.subtract(const Duration(seconds: 2)));
        })
        .toList();

    if (recentFiles.isEmpty) {
      return const [];
    }

    recentFiles.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    final matching = recentFiles.where((file) {
      final name = p.basenameWithoutExtension(file.path).toLowerCase();
      return name == destinationBaseName || name.startsWith(destinationBaseName);
    }).toList();

    return matching.isNotEmpty ? matching : recentFiles;
  }

  String _percent(double value) => (value.clamp(0, 1) * 100).round().toString();

  String _exposureValue(double value) => ((value.clamp(0, 1) * 6) - 3).toStringAsFixed(1);

  String _whiteBalanceValue(double value) =>
      (2000 + (value.clamp(0, 1) * 6000)).round().toString();

  String _powerLineFrequency(double value) {
    final steps = <String>['50', '60', 'auto'];
    final index = (value.clamp(0, 1) * (steps.length - 1)).round();
    return steps[index];
  }

  String _boolCommand(bool value) => value ? '1' : '0';

  String _cameraSelectionValue(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.contains(' ') ? trimmed.replaceAll(' ', '_') : trimmed;
  }

  String _buildCommandBaseUrl() => AppConstants.buildDigicamControlBaseUrl(_commandPort);

  String _buildLiveViewBaseUrl() => AppConstants.buildDigicamControlBaseUrl(_liveViewPort);

  int _normalizePort(int value, int fallback) => value > 0 ? value : fallback;

  int _normalizeDistinctPort(int value, int otherPort, int fallback) {
    final normalized = _normalizePort(value, fallback);
    if (normalized != otherPort) {
      return normalized;
    }

    if (normalized < 65535) {
      return normalized + 1;
    }
    if (normalized > 1) {
      return normalized - 1;
    }
    return fallback == otherPort ? fallback + 1 : fallback;
  }
}
