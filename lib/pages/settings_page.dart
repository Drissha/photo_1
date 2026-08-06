import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/app_settings.dart';
import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/local_camera_preview_service.dart';
import '../core/services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;
  late final TextEditingController _commandPortController;
  late final TextEditingController _remoteCmdController;

  @override
  void initState() {
    super.initState();
    _settings = context.read<AppSettingsNotifier>().settings;
    _commandPortController = TextEditingController(text: _settings.digicamControlCommandPort.toString());
    _remoteCmdController = TextEditingController(text: _settings.digicamControlRemoteCmdPath);
  }

  @override
  void dispose() {
    _commandPortController.dispose();
    _remoteCmdController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(AppSettings nextSettings, {bool applyCamera = false}) async {
    final notifier = context.read<AppSettingsNotifier>();
    final cameraManager = context.read<CameraManagerService>();
    final localPreview = context.read<LocalCameraPreviewService>();
    final liveViewWasEnabled = _settings.liveViewEnabled;
    await notifier.updateSettings(nextSettings);
    if (!mounted) return;
    cameraManager.updateConnectionSettings(nextSettings);
    await localPreview.setEnabled(nextSettings.liveViewEnabled);
    if (liveViewWasEnabled != nextSettings.liveViewEnabled && nextSettings.liveViewEnabled) {
      await localPreview.initializePreview(
        preferredCameraName: nextSettings.liveViewCameraName.trim().isEmpty
            ? null
            : nextSettings.liveViewCameraName.trim(),
        forceRefresh: true,
      );
    }

    if (applyCamera) {
      await cameraManager.applyCameraSettings(nextSettings);
    }
  }

  Future<void> _saveConnectionSettings() async {
    final nextSettings = _sanitizeConnectionPorts(
      _settings.copyWith(
        digicamControlCommandPort:
            _parsePort(_commandPortController.text, _settings.digicamControlCommandPort),
        liveViewEnabled: _settings.liveViewEnabled,
        digicamControlRemoteCmdPath: _remoteCmdController.text.trim(),
      ),
    );
    context.read<CameraManagerService>().updateConnectionSettings(nextSettings);
    await _saveSettings(nextSettings);
  }

  int _parsePort(String input, int fallback) {
    final value = int.tryParse(input.trim());
    if (value == null || value <= 0 || value > 65535) {
      return fallback;
    }
    return value;
  }

  Widget _buildInfoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
    );
  }

  AppSettings _sanitizeConnectionPorts(AppSettings settings) {
    if (settings.digicamControlCommandPort != settings.digicamControlLiveViewPort) {
      return settings;
    }

    final nextLiveViewPort = settings.digicamControlCommandPort < 65535
        ? settings.digicamControlCommandPort + 1
        : settings.digicamControlCommandPort - 1;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live view port tidak boleh sama dengan control port. Saya ubah ke $nextLiveViewPort.',
          ),
        ),
      );
    }

    return settings.copyWith(digicamControlLiveViewPort: nextLiveViewPort);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AppSettingsNotifier>();
    final cameraManager = context.watch<CameraManagerService>();
    final localPreview = context.watch<LocalCameraPreviewService>();
    _settings = notifier.settings;
    final captureCameraValue = cameraManager.availableDevices.any((camera) => camera.name == _settings.defaultCameraName)
        ? _settings.defaultCameraName
        : null;
    final liveViewCameraValue = localPreview.availableCameras.any((camera) => camera.name == _settings.liveViewCameraName)
        ? _settings.liveViewCameraName
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
                      onChanged: (value) {
                        if (value == null) return;
                        _saveSettings(_settings.copyWith(themeMode: value));
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
                    Text('Webcam Live View', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Webcam ini dipakai hanya untuk live view. Capture tetap memakai kamera DigiCamControl.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (localPreview.isInitializing)
                      const LinearProgressIndicator()
                    else if (localPreview.availableCameras.isEmpty)
                      Text(
                        localPreview.lastError ??
                            'Tidak ada webcam terdeteksi. Cek Camera privacy settings di Windows.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: liveViewCameraValue,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Webcam Live View',
                          border: OutlineInputBorder(),
                        ),
                        items: localPreview.availableCameras
                            .map(
                              (camera) => DropdownMenuItem<String>(
                                value: camera.name,
                                child: Text(camera.name, overflow: TextOverflow.ellipsis),
                              ),
                            )
                            .toList(),
                        onChanged: (cameraName) async {
                          if (cameraName == null) return;
                          await localPreview.switchCamera(cameraName);
                          if (!mounted) return;
                          await _saveSettings(_settings.copyWith(liveViewCameraName: cameraName));
                        },
                      ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          await localPreview.refreshCameras();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Webcam'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip('Status', localPreview.status),
                        _buildInfoChip('Enabled', localPreview.isEnabled ? 'Yes' : 'No'),
                        _buildInfoChip('Detected', localPreview.availableCameras.length.toString()),
                      ],
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
                          await _saveSettings(_settings.copyWith(saveFolderPath: selectedFolder));
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
                    Text('DigiCamControl', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Capture memakai DigiCamControl. Live view memakai webcam lokal yang bisa dipilih terpisah.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _commandPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Control / Capture Port',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Webcam Live View'),
                      subtitle: const Text('Matikan jika ingin menampilkan layar capture saja tanpa preview webcam.'),
                      value: _settings.liveViewEnabled,
                      onChanged: (value) {
                        _saveSettings(_settings.copyWith(liveViewEnabled: value));
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.read<LocalCameraPreviewService>().refreshCameras();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh Webcam'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _remoteCmdController,
                      decoration: const InputDecoration(
                        labelText: 'CameraControlRemoteCmd.exe Path',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _saveConnectionSettings,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Connection'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Camera', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: captureCameraValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Capture Camera',
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
                          : (cameraName) {
                              final nextCamera = cameraName ?? '';
                              _saveSettings(_settings.copyWith(defaultCameraName: nextCamera));
                            },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Auto Start Camera'),
                      value: _settings.autoStartCamera,
                      onChanged: (value) {
                        _saveSettings(_settings.copyWith(autoStartCamera: value));
                      },
                    ),
                    Slider(
                      value: _settings.autoCaptureDelaySeconds.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _settings.autoCaptureDelaySeconds.toString(),
                      onChanged: (value) {
                        _saveSettings(_settings.copyWith(autoCaptureDelaySeconds: value.round()));
                      },
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
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(capturePreviewDurationSeconds: value.round()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text('Camera Profile', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Perubahan berikut akan dikirim ke DigiCamControl saat kamera aktif.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _buildCameraSlider(
                      label: 'Brightness',
                      value: _settings.cameraBrightness,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraBrightness: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Contrast',
                      value: _settings.cameraContrast,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraContrast: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Gamma',
                      value: _settings.cameraGamma,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraGamma: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Sharpness',
                      value: _settings.cameraSharpness,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraSharpness: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Saturation',
                      value: _settings.cameraSaturation,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraSaturation: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Hue',
                      value: _settings.cameraHue,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraHue: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Exposure',
                      value: _settings.cameraExposure,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraExposure: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Gain',
                      value: _settings.cameraGain,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraGain: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Focus',
                      value: _settings.cameraFocus,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraFocus: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Zoom',
                      value: _settings.cameraZoom,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraZoom: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'White Balance',
                      value: _settings.cameraWhiteBalance,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraWhiteBalance: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Backlight Compensation',
                      value: _settings.cameraBacklightCompensation,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraBacklightCompensation: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    _buildCameraSlider(
                      label: 'Power Line Frequency',
                      value: _settings.cameraPowerLineFrequency,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraPowerLineFrequency: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Mirror'),
                      value: _settings.cameraMirror,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraMirror: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Flip Horizontal'),
                      value: _settings.cameraFlipHorizontal,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraFlipHorizontal: value),
                          applyCamera: true,
                        );
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Flip Vertical'),
                      value: _settings.cameraFlipVertical,
                      onChanged: (value) {
                        _saveSettings(
                          _settings.copyWith(cameraFlipVertical: value),
                          applyCamera: true,
                        );
                      },
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

  Widget _buildCameraSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Slider(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
