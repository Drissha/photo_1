import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/storage_service.dart';

class CameraControlsCard extends StatefulWidget {
  const CameraControlsCard({super.key, required this.cameraManager});

  final CameraManagerService cameraManager;

  @override
  State<CameraControlsCard> createState() => _CameraControlsCardState();
}

class _CameraControlsCardState extends State<CameraControlsCard> {
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _syncFullscreenState();
  }

  Future<void> _syncFullscreenState() async {
    final isFullscreen = await windowManager.isFullScreen();
    if (!mounted) return;
    setState(() => _isFullscreen = isFullscreen);
  }

  Future<void> _toggleFullscreen() async {
    final nextValue = !_isFullscreen;
    await windowManager.setFullScreen(nextValue);
    if (!mounted) return;
    setState(() => _isFullscreen = nextValue);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Camera Controls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: widget.cameraManager.selectedDevice?.name,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Camera',
                border: OutlineInputBorder(),
              ),
              items: widget.cameraManager.availableDevices
                  .map(
                    (camera) => DropdownMenuItem<String>(
                      value: camera.name,
                      child: Text(camera.displayName, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: widget.cameraManager.availableDevices.isEmpty
                  ? null
                  : (cameraName) async {
                      if (cameraName == null) return;
                      await widget.cameraManager.switchCamera(cameraName);
                      if (!context.mounted || widget.cameraManager.selectedDevice?.name != cameraName) return;
                      final notifier = context.read<AppSettingsNotifier>();
                      await notifier.updateSettings(
                        notifier.settings.copyWith(defaultCameraName: cameraName),
                      );
                    },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    final settings = context.read<AppSettingsNotifier>().settings;
                    final storageService = context.read<StorageService>();
                    final takeFolder = await storageService.createTakeFolder(settings.saveFolderPath);
                    final path = await widget.cameraManager.capturePhoto(takeFolder);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $path')));
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Capture Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.cameraManager.restartCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.cameraManager.reconnectCamera,
                  icon: const Icon(Icons.link),
                  label: const Text('Reconnect Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _toggleFullscreen,
                  icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  label: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
