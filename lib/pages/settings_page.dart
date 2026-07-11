import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/app_settings.dart';
import '../core/services/app_providers.dart';
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
    _settings = notifier.settings;

    return Padding(
      padding: const EdgeInsets.all(24),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
