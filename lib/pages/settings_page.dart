import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/app_settings.dart';
import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppSettingsNotifier>().settings;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppSettingsNotifier>();
    final cameraManager = context.watch<CameraManagerService>();
    _settings = notifier.settings;
    final defaultCameraValue = cameraManager.availableDevices.any((camera) => camera.name == _settings.defaultCameraName)
        ? _settings.defaultCameraName
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(40),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListView(
            children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButton<ThemeMode>(
                      value: _settings.themeMode,
                      items: ThemeMode.values.map((mode) => DropdownMenuItem(value: mode, child: Text(mode.name))).toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await notifier.updateSettings(_settings.copyWith(themeMode: value));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Save Folder: ${_settings.saveFolderPath}'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final selectedFolder = await context.read<StorageService>().pickSaveFolder();
                        if (selectedFolder != null) {
                          await notifier.updateSettings(_settings.copyWith(saveFolderPath: selectedFolder));
                        }
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse Folder'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Camera', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: defaultCameraValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Default Camera',
                        border: OutlineInputBorder(),
                      ),
                      items: cameraManager.availableDevices
                          .map(
                            (camera) => DropdownMenuItem<String>(
                              value: camera.name,
                              child: Text(camera.displayName, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: cameraManager.availableDevices.isEmpty
                          ? null
                          : (cameraName) async {
                              final nextCamera = cameraName ?? '';
                              await notifier.updateSettings(_settings.copyWith(defaultCameraName: nextCamera));
                            },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Auto Start Camera'),
                      value: _settings.autoStartCamera,
                      onChanged: (value) async => notifier.updateSettings(_settings.copyWith(autoStartCamera: value)),
                    ),
                    Slider(
                      value: _settings.autoCaptureDelaySeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _settings.autoCaptureDelaySeconds.toString(),
                      onChanged: (value) async => notifier.updateSettings(_settings.copyWith(autoCaptureDelaySeconds: value.round())),
                    ),
                    const SizedBox(height: 8),
                    Text('Preview Duration', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'How long each photo preview stays on screen before auto-continue.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _settings.capturePreviewDurationSeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_settings.capturePreviewDurationSeconds} detik',
                      onChanged: (value) async => notifier.updateSettings(
                        _settings.copyWith(capturePreviewDurationSeconds: value.round()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
