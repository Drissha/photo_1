import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_settings.dart';

abstract class SettingsRepository {
  // Abstraksi kecil ini memudahkan perpindahan backend storage di masa depan.
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  SharedPreferencesSettingsRepository({this._sharedPreferences});

  final SharedPreferences? _sharedPreferences;

  static const String _storageKey = 'papyrus_settings';

  @override
  Future<AppSettings> loadSettings() async {
    // Semua setting disimpan sebagai JSON tunggal untuk menjaga migrasi tetap simpel.
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return const AppSettings();
    }

    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final commandPort = _readPort(
      decoded,
      keys: const [
        'digicamControlCommandPort',
        'digicamControlCommandBaseUrl',
        'digicamControlBaseUrl',
      ],
      fallback: AppConstants.digicamControlCommandPort,
    );
    final liveViewPort = _readPort(
      decoded,
      keys: const [
        'digicamControlLiveViewPort',
        'digicamControlLiveViewBaseUrl',
        'digicamControlBaseUrl',
      ],
      fallback: AppConstants.digicamControlLiveViewPort,
    );
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == decoded['themeMode'],
        orElse: () => ThemeMode.dark,
      ),
      language: decoded['language']?.toString() ?? 'English',
      saveFolderPath: decoded['saveFolderPath']?.toString() ?? 'C:/Users/Public/Pictures/Papyrus',
      digicamControlCommandPort: commandPort,
      digicamControlLiveViewPort: liveViewPort,
      liveViewEnabled: decoded['liveViewEnabled'] as bool? ?? true,
      digicamControlRemoteCmdPath: decoded['digicamControlRemoteCmdPath']?.toString() ??
          AppConstants.digicamControlRemoteCmdPath,
      defaultCameraName: decoded['defaultCameraName']?.toString() ?? '',
      liveViewCameraName: decoded['liveViewCameraName']?.toString() ??
          decoded['defaultCameraName']?.toString() ??
          '',
      autoStartCamera: decoded['autoStartCamera'] as bool? ?? true,
      autoCaptureDelaySeconds: decoded['autoCaptureDelaySeconds'] as int? ?? AppConstants.autoCaptureDelaySeconds,
      capturePreviewDurationSeconds:
          decoded['capturePreviewDurationSeconds'] as int? ?? AppConstants.capturePreviewDurationSeconds,
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
    // Simpan snapshot lengkap agar satu sumber kebenaran tetap konsisten.
    final prefs = _sharedPreferences ?? await SharedPreferences.getInstance();
    final encoded = jsonEncode({
      'themeMode': settings.themeMode.name,
      'language': settings.language,
      'saveFolderPath': settings.saveFolderPath,
      'digicamControlCommandPort': settings.digicamControlCommandPort,
      'digicamControlLiveViewPort': settings.digicamControlLiveViewPort,
      'liveViewEnabled': settings.liveViewEnabled,
      'digicamControlCommandBaseUrl': settings.digicamControlCommandBaseUrl,
      'digicamControlLiveViewBaseUrl': settings.digicamControlLiveViewBaseUrl,
      'digicamControlBaseUrl': settings.digicamControlCommandBaseUrl,
      'digicamControlRemoteCmdPath': settings.digicamControlRemoteCmdPath,
      'defaultCameraName': settings.defaultCameraName,
      'liveViewCameraName': settings.liveViewCameraName,
      'autoStartCamera': settings.autoStartCamera,
      'autoCaptureDelaySeconds': settings.autoCaptureDelaySeconds,
      'capturePreviewDurationSeconds': settings.capturePreviewDurationSeconds,
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

  int _readPort(
    Map<String, dynamic> decoded, {
    required List<String> keys,
    required int fallback,
  }) {
    // Beberapa key lama masih didukung supaya data versi lama tetap bisa dibaca.
    for (final key in keys) {
      final value = decoded[key];
      final parsed = _parsePort(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
  }

  int? _parsePort(dynamic value) {
    // Port bisa datang sebagai angka, string, atau URL lengkap dari versi lama.
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final direct = int.tryParse(text);
    if (direct != null) {
      return direct;
    }

    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasPort) {
      return uri.port;
    }

    final match = RegExp(r':(\d+)(?:/|$)').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    return null;
  }
}
