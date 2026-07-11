import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import 'camera_manager_service.dart';
import 'diagnostic_service.dart';
import 'settings_repository.dart';
import 'storage_service.dart';
import 'troubleshooting_service.dart';

class AppProviders {
  static List<SingleChildWidget> providers = [
    Provider<StorageService>(create: (_) => StorageService()),
    Provider<SettingsRepository>(create: (_) => SharedPreferencesSettingsRepository()),
    ChangeNotifierProvider<CameraManagerService>(create: (_) => CameraManagerService()),
    Provider<TroubleshootingService>(
      create: (context) => TroubleshootingService(
        cameraManager: context.read<CameraManagerService>(),
        storageService: context.read<StorageService>(),
      ),
    ),
    Provider<DiagnosticService>(
      create: (context) => DiagnosticService(
        cameraManager: context.read<CameraManagerService>(),
        storageService: context.read<StorageService>(),
        settingsRepository: context.read<SettingsRepository>(),
      ),
    ),
    ChangeNotifierProvider<AppSettingsNotifier>(
      create: (context) => AppSettingsNotifier(
        repository: context.read<SettingsRepository>(),
      ),
    ),
  ];
}

class AppSettingsNotifier extends ChangeNotifier {
  AppSettingsNotifier({required this.repository}) {
    _initialize();
  }

  final SettingsRepository repository;
  AppSettings _settings = const AppSettings();

  AppSettings get settings => _settings;

  Future<void> _initialize() async {
    _settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    _settings = settings;
    await repository.saveSettings(settings);
    notifyListeners();
  }
}
