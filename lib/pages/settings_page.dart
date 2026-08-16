import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/app_settings.dart';
import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/dashboard_api_service.dart';
import '../core/services/local_camera_preview_service.dart';
import '../core/services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  // Semua preferensi runtime dan koneksi kamera diatur dari halaman ini.
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;
  late final TextEditingController _commandPortController;
  late final TextEditingController _remoteCmdController;
  bool _isSyncingData = false;

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
    // Setiap perubahan settings disimpan lalu didorong ke service yang relevan.
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
    // Port control dan path remote cmd disimpan terpisah karena sering diubah bersama.
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

  Future<void> _syncBackgroundData() async {
    if (_isSyncingData) return;

    setState(() => _isSyncingData = true);
    try {
      final api = context.read<ApiController>();
      final downloaded = await api.syncBackgrounds();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync selesai. $downloaded background disimpan ke folder background lokal.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync background gagal: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingData = false);
      }
    }
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
    // Dua port DigiCamControl tidak boleh sama agar command dan live view tidak bentrok.
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
    // Settings page membaca state langsung dari provider supaya selalu sinkron.
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                _buildPageHeader(context),
                const SizedBox(height: 20),
                _buildSectionCard(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Atur tema aplikasi.',
                  children: [
                    DropdownButtonFormField<ThemeMode>(
                      value: _settings.themeMode,
                      decoration: const InputDecoration(
                        labelText: 'Theme',
                        border: OutlineInputBorder(),
                      ),
                      items: ThemeMode.values
                          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode.name)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        _saveSettings(_settings.copyWith(themeMode: value));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  icon: Icons.photo_camera_front_outlined,
                  title: 'Webcam Live View',
                  subtitle: 'Webcam hanya dipakai untuk preview live view.',
                  children: [
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await localPreview.refreshCameras();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Webcam'),
                        ),
                        _buildInfoChip('Status', localPreview.status),
                        _buildInfoChip('Enabled', localPreview.isEnabled ? 'Yes' : 'No'),
                        _buildInfoChip('Detected', localPreview.availableCameras.length.toString()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  icon: Icons.folder_open_outlined,
                  title: 'Storage',
                  subtitle: 'Tentukan folder simpan dan sinkronisasi background.',
                  children: [
                    _buildInfoRow(
                      context,
                      label: 'Save folder',
                      value: _settings.saveFolderPath,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
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
                        FilledButton.tonalIcon(
                          onPressed: _isSyncingData ? null : _syncBackgroundData,
                          icon: _isSyncingData
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_isSyncingData ? 'Syncing...' : 'Sync Data'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Download background dari API lalu simpan ke folder background lokal agar bisa dipakai di edit page.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  icon: Icons.usb_outlined,
                  title: 'DigiCamControl',
                  subtitle: 'Pengaturan koneksi kamera dan capture.',
                  children: [
                    TextFormField(
                      controller: _commandPortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Control / Capture Port',
                        border: OutlineInputBorder(),
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
                      child: FilledButton.icon(
                        onPressed: _saveConnectionSettings,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Connection'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  icon: Icons.camera_alt_outlined,
                  title: 'Capture',
                  subtitle: 'Atur kamera utama dan perilaku auto capture.',
                  children: [
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
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto Start Camera'),
                      value: _settings.autoStartCamera,
                      onChanged: (value) {
                        _saveSettings(_settings.copyWith(autoStartCamera: value));
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Auto Capture Delay: ${_settings.autoCaptureDelaySeconds} detik',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                    Text(
                      'Preview Duration: ${_settings.capturePreviewDurationSeconds} detik',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
                  ],
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  icon: Icons.tune_outlined,
                  title: 'Camera Profile',
                  subtitle: 'Perubahan di bawah dikirim ke DigiCamControl.',
                  children: [
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
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
                      contentPadding: EdgeInsets.zero,
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
                      contentPadding: EdgeInsets.zero,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Atur kamera, penyimpanan, sinkronisasi background, dan preferensi capture dari satu tempat.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
