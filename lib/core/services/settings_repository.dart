import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository({this._sharedPreferences});

  final SharedPreferences? _sharedPreferences;

  static const String _storageKey = 'papyrus_settings';

  @override
  Future<AppSettings> loadSettings() async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const AppSettings();
    }

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == decoded['themeMode'],
        orElse: () => ThemeMode.dark,
      ),
      language: decoded['language']?.toString() ?? 'English',
      saveFolderPath: decoded['saveFolderPath']?.toString() ?? 'C:/Users/Public/Pictures/Papyrus',
      defaultCameraName: decoded['defaultCameraName']?.toString() ?? '',
      autoStartCamera: decoded['autoStartCamera'] as bool? ?? true,
      autoCaptureDelaySeconds: decoded['autoCaptureDelaySeconds'] as int? ?? 3,
      autoRetry: decoded['autoRetry'] as bool? ?? true,
      cameraBrightness: (decoded['cameraBrightness'] as num?)?.toDouble() ?? 0.5,
      cameraContrast: (decoded['cameraContrast'] as num?)?.toDouble() ?? 0.5,
      cameraGamma: (decoded['cameraGamma'] as num?)?.toDouble() ?? 0.5,
      cameraSharpness: (decoded['cameraSharpness'] as num?)?.toDouble() ?? 0.5,
      cameraSaturation: (decoded['cameraSaturation'] as num?)?.toDouble() ?? 0.5,
      cameraHue: (decoded['cameraHue'] as num?)?.toDouble() ?? 0.5,
      cameraExposure: (decoded['cameraExposure'] as num?)?.toDouble() ?? 0.5,
      cameraGain: (decoded['cameraGain'] as num?)?.toDouble() ?? 0.5,
      cameraFocus: (decoded['cameraFocus'] as num?)?.toDouble() ?? 0.5,
      cameraZoom: (decoded['cameraZoom'] as num?)?.toDouble() ?? 0.5,
      cameraWhiteBalance: (decoded['cameraWhiteBalance'] as num?)?.toDouble() ?? 0.5,
      cameraBacklightCompensation: (decoded['cameraBacklightCompensation'] as num?)?.toDouble() ?? 0.5,
      cameraPowerLineFrequency: (decoded['cameraPowerLineFrequency'] as num?)?.toDouble() ?? 0.5,
      cameraMirror: decoded['cameraMirror'] as bool? ?? false,
      cameraFlipHorizontal: decoded['cameraFlipHorizontal'] as bool? ?? false,
      cameraFlipVertical: decoded['cameraFlipVertical'] as bool? ?? false,
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'themeMode': settings.themeMode.name,
      'language': settings.language,
      'saveFolderPath': settings.saveFolderPath,
      'defaultCameraName': settings.defaultCameraName,
      'autoStartCamera': settings.autoStartCamera,
      'autoCaptureDelaySeconds': settings.autoCaptureDelaySeconds,
      'autoRetry': settings.autoRetry,
      'cameraBrightness': settings.cameraBrightness,
      'cameraContrast': settings.cameraContrast,
      'cameraGamma': settings.cameraGamma,
      'cameraSharpness': settings.cameraSharpness,
      'cameraSaturation': settings.cameraSaturation,
      'cameraHue': settings.cameraHue,
      'cameraExposure': settings.cameraExposure,
      'cameraGain': settings.cameraGain,
      'cameraFocus': settings.cameraFocus,
      'cameraZoom': settings.cameraZoom,
      'cameraWhiteBalance': settings.cameraWhiteBalance,
      'cameraBacklightCompensation': settings.cameraBacklightCompensation,
      'cameraPowerLineFrequency': settings.cameraPowerLineFrequency,
      'cameraMirror': settings.cameraMirror,
      'cameraFlipHorizontal': settings.cameraFlipHorizontal,
      'cameraFlipVertical': settings.cameraFlipVertical,
    });
    await prefs.setString(_storageKey, encoded);
  }
}
