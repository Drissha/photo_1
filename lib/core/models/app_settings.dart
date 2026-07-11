import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.language = 'English',
    this.saveFolderPath = 'C:/Users/Public/Pictures/Papyrus',
    this.defaultCameraName = '',
    this.autoStartCamera = true,
    this.autoCaptureDelaySeconds = 3,
    this.autoRetry = true,
    this.cameraBrightness = 0.5,
    this.cameraContrast = 0.5,
    this.cameraGamma = 0.5,
    this.cameraSharpness = 0.5,
    this.cameraSaturation = 0.5,
    this.cameraHue = 0.5,
    this.cameraExposure = 0.5,
    this.cameraGain = 0.5,
    this.cameraFocus = 0.5,
    this.cameraZoom = 0.5,
    this.cameraWhiteBalance = 0.5,
    this.cameraBacklightCompensation = 0.5,
    this.cameraPowerLineFrequency = 0.5,
    this.cameraMirror = false,
    this.cameraFlipHorizontal = false,
    this.cameraFlipVertical = false,
  });

  final ThemeMode themeMode;
  final String language;
  final String saveFolderPath;
  final String defaultCameraName;
  final bool autoStartCamera;
  final int autoCaptureDelaySeconds;
  final bool autoRetry;

  final double cameraBrightness;
  final double cameraContrast;
  final double cameraGamma;
  final double cameraSharpness;
  final double cameraSaturation;
  final double cameraHue;
  final double cameraExposure;
  final double cameraGain;
  final double cameraFocus;
  final double cameraZoom;
  final double cameraWhiteBalance;
  final double cameraBacklightCompensation;
  final double cameraPowerLineFrequency;
  final bool cameraMirror;
  final bool cameraFlipHorizontal;
  final bool cameraFlipVertical;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? language,
    String? saveFolderPath,
    String? defaultCameraName,
    bool? autoStartCamera,
    int? autoCaptureDelaySeconds,
    bool? autoRetry,
    double? cameraBrightness,
    double? cameraContrast,
    double? cameraGamma,
    double? cameraSharpness,
    double? cameraSaturation,
    double? cameraHue,
    double? cameraExposure,
    double? cameraGain,
    double? cameraFocus,
    double? cameraZoom,
    double? cameraWhiteBalance,
    double? cameraBacklightCompensation,
    double? cameraPowerLineFrequency,
    bool? cameraMirror,
    bool? cameraFlipHorizontal,
    bool? cameraFlipVertical,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      saveFolderPath: saveFolderPath ?? this.saveFolderPath,
      defaultCameraName: defaultCameraName ?? this.defaultCameraName,
      autoStartCamera: autoStartCamera ?? this.autoStartCamera,
      autoCaptureDelaySeconds:
          autoCaptureDelaySeconds ?? this.autoCaptureDelaySeconds,
      autoRetry: autoRetry ?? this.autoRetry,
      cameraBrightness: cameraBrightness ?? this.cameraBrightness,
      cameraContrast: cameraContrast ?? this.cameraContrast,
      cameraGamma: cameraGamma ?? this.cameraGamma,
      cameraSharpness: cameraSharpness ?? this.cameraSharpness,
      cameraSaturation: cameraSaturation ?? this.cameraSaturation,
      cameraHue: cameraHue ?? this.cameraHue,
      cameraExposure: cameraExposure ?? this.cameraExposure,
      cameraGain: cameraGain ?? this.cameraGain,
      cameraFocus: cameraFocus ?? this.cameraFocus,
      cameraZoom: cameraZoom ?? this.cameraZoom,
      cameraWhiteBalance: cameraWhiteBalance ?? this.cameraWhiteBalance,
      cameraBacklightCompensation:
          cameraBacklightCompensation ?? this.cameraBacklightCompensation,
      cameraPowerLineFrequency:
          cameraPowerLineFrequency ?? this.cameraPowerLineFrequency,
      cameraMirror: cameraMirror ?? this.cameraMirror,
      cameraFlipHorizontal: cameraFlipHorizontal ?? this.cameraFlipHorizontal,
      cameraFlipVertical: cameraFlipVertical ?? this.cameraFlipVertical,
    );
  }
}
