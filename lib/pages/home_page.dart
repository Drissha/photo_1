import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/troubleshooting_service.dart';
import 'diagnostics_page.dart';
import 'edit_page.dart';
import 'gallery_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.packageName,
    required this.photoCount,
    required this.initialBackgroundKey,
  });

  final String packageName;
  final int photoCount;
  final String initialBackgroundKey;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _galleryReloadToken = 0;
  bool _showControlPanel = false;
  bool _isFullscreen = false;
  bool _isCaptureSessionRunning = false;
  AppSettingsNotifier? _settingsNotifier;
  String? _lastAppliedDefaultCameraName;
  bool _isSyncingCamera = false;
  bool _cameraSyncQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _settingsNotifier = context.read<AppSettingsNotifier>();
      _settingsNotifier!.addListener(_syncCameraWithSettings);
      await _syncCameraWithSettings();
    });
  }

  @override
  void dispose() {
    _settingsNotifier?.removeListener(_syncCameraWithSettings);
    super.dispose();
  }

  Future<void> _syncCameraWithSettings() async {
    if (!mounted) return;
    if (_isSyncingCamera) {
      _cameraSyncQueued = true;
      return;
    }

    _isSyncingCamera = true;
    try {
      do {
        _cameraSyncQueued = false;

        final cameraManager = context.read<CameraManagerService>();
        final troubleshooter = context.read<TroubleshootingService>();
        final settings = context.read<AppSettingsNotifier>().settings;
        final preferredCameraName = settings.defaultCameraName.trim().isEmpty
            ? null
            : settings.defaultCameraName.trim();

        if (_lastAppliedDefaultCameraName == preferredCameraName &&
            cameraManager.selectedDevice?.name == preferredCameraName &&
            cameraManager.isInitialized) {
          continue;
        }

        _lastAppliedDefaultCameraName = preferredCameraName;

        await cameraManager.initializeCamera(cameraName: preferredCameraName);
        troubleshooter.startMonitoring();
        await _syncFullscreenState();
      } while (_cameraSyncQueued && mounted);
    } finally {
      _isSyncingCamera = false;
    }
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

  Future<void> _exitApp() async {
    await windowManager.close();
  }

  void _toggleControlPanel() {
    setState(() => _showControlPanel = !_showControlPanel);
  }

  Future<void> _selectPage(int index) async {
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _galleryReloadToken += 1;
      }
      _showControlPanel = false;
    });
  }

  Future<void> _showNavigationSheet() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(sheetContext, 0),
              ),
            ],
          ),
        );
      },
    );

    if (choice != null) {
      await _selectPage(choice);
    }
  }

  Future<void> _startCaptureSession() async {
    final cameraManager = context.read<CameraManagerService>();
    final storageService = context.read<StorageService>();
    final settings = context.read<AppSettingsNotifier>().settings;

    if (!cameraManager.isInitialized || _isCaptureSessionRunning) {
      return;
    }

    final options = await _showCaptureOptionsDialog(
      defaultCountdown: settings.autoCaptureDelaySeconds,
      defaultBackgroundKey: widget.initialBackgroundKey,
    );
    if (options == null || !mounted) return;

    setState(() => _isCaptureSessionRunning = true);
    try {
      final takeFolder = await storageService.createTakeFolder(settings.saveFolderPath);
      if (!mounted) return;
      final savedPaths = <String>[];
      for (var index = 0; index < options.photoCount; index++) {
        var accepted = false;
        while (!accepted) {
          if (options.countdownSeconds > 0) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => _CountdownDialog(
                seconds: options.countdownSeconds,
                currentShot: index + 1,
                totalShots: options.photoCount,
              ),
            );
          }

          final path = await cameraManager.capturePhoto(takeFolder);
          if (!mounted) {
            try {
              await File(path).delete();
            } catch (_) {}
            return;
          }
          final previewAction = await _showCapturePreviewDialog(
            imagePath: path,
            shotIndex: index + 1,
            totalShots: options.photoCount,
            previewSeconds: settings.capturePreviewDurationSeconds,
          );

          if (!mounted) return;
          if (previewAction == _CapturePreviewAction.retake) {
            try {
              await File(path).delete();
            } catch (_) {
              // Ignore cleanup failures and allow the user to retake.
            }
            continue;
          }

          savedPaths.add(path);
          accepted = true;
        }

        if (index < options.photoCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditPage(
              photoPaths: savedPaths,
              takeFolderPath: takeFolder,
              takeFolderName: Uri.file(takeFolder).pathSegments.last,
              initialBackgroundKey: options.backgroundKey,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCaptureSessionRunning = false);
      }
    }
  }

  Future<_CaptureSessionOptions?> _showCaptureOptionsDialog({
    required int defaultCountdown,
    required String defaultBackgroundKey,
  }) {
    return showDialog<_CaptureSessionOptions>(
      context: context,
      builder: (dialogContext) {
        var selectedCountdown = defaultCountdown;
        var selectedBackgroundKey = defaultBackgroundKey;
        var selectedPhotoCount = _photoCountForBackground(defaultBackgroundKey);
        const backgroundChoices = [
          _LayoutChoice(key: 'portrait1', label: 'Portrait 1 Take', description: 'Template portrait, 1 foto'),
          _LayoutChoice(key: 'portrait2', label: 'Portrait 2 Take', description: 'Template portrait, 2 foto'),
          _LayoutChoice(key: 'portrait3', label: 'Portrait 3 Take', description: 'Template portrait, 3 foto'),
          _LayoutChoice(key: 'landscape4', label: 'Landscape 4 Take', description: 'Template landscape, 4 foto'),
          _LayoutChoice(key: 'landscape6', label: 'Landscape 6 Take', description: 'Template landscape, 6 foto'),
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final countdownChoices = <int>{0, 3, 5, 10, selectedCountdown}.toList()..sort();
            return AlertDialog(
              title: Text('Capture Options - ${widget.packageName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jumlah foto mengikuti template: $selectedPhotoCount',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedBackgroundKey,
                    decoration: const InputDecoration(
                      labelText: 'Background awal',
                      border: OutlineInputBorder(),
                    ),
                    items: backgroundChoices
                        .map(
                          (background) => DropdownMenuItem(
                            value: background.key,
                            child: Text('${background.label} - ${background.description}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedBackgroundKey = value;
                        selectedPhotoCount = _photoCountForBackground(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedCountdown,
                    decoration: const InputDecoration(
                      labelText: 'Countdown',
                      border: OutlineInputBorder(),
                    ),
                    items: countdownChoices
                        .map((seconds) => DropdownMenuItem(
                              value: seconds,
                              child: Text(seconds == 0 ? 'Tanpa countdown' : '$seconds detik'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedCountdown = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      _CaptureSessionOptions(
                        countdownSeconds: selectedCountdown,
                        backgroundKey: selectedBackgroundKey,
                        photoCount: selectedPhotoCount,
                      ),
                    );
                  },
                  child: const Text('Mulai'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<_CapturePreviewAction> _showCapturePreviewDialog({
    required String imagePath,
    required int shotIndex,
    required int totalShots,
    required int previewSeconds,
  }) {
    return showDialog<_CapturePreviewAction>(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (dialogContext) => _CapturePreviewDialog(
        imagePath: imagePath,
        shotIndex: shotIndex,
        totalShots: totalShots,
        previewSeconds: previewSeconds,
      ),
    ).then((result) => result ?? _CapturePreviewAction.continueShot);
  }

  @override
  Widget build(BuildContext context) {
    final cameraManager = context.watch<CameraManagerService>();

    final pages = <Widget>[
      _buildCameraPage(cameraManager),
      _buildSafePage(GalleryPage(key: ValueKey(_galleryReloadToken))),
      _buildSafePage(const SettingsPage()),
      _buildSafePage(const DiagnosticsPage()),
    ];

    return Scaffold(
      backgroundColor: _selectedIndex == 0 ? Colors.black : null,
      body: Stack(
        children: [
          Positioned.fill(child: pages[_selectedIndex]),
          Positioned(
            top: 16,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'nav-menu',
              onPressed: _showNavigationSheet,
              child: const Icon(Icons.menu),
            ),
          ),
          if (_selectedIndex == 0)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildCameraStatusPill(cameraManager),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'toggle-controls',
                    onPressed: _toggleControlPanel,
                    child: Icon(_showControlPanel ? Icons.close : Icons.tune),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showControlPanel
                        ? _buildFloatingControlPanel(cameraManager)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          if (_selectedIndex == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'capture-photo',
                    onPressed: cameraManager.isInitialized && !_isCaptureSessionRunning
                        ? _startCaptureSession
                        : null,
                    icon: const Icon(Icons.camera_alt_outlined, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Text(
                        'Capture',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPage(CameraManagerService cameraManager) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraStage(cameraManager),
        Positioned(
          left: 16,
          bottom: 16,
          child: _buildInfoChip(
            'Status',
            cameraManager.status,
          ),
        ),
      ],
    );
  }

  Widget _buildSafePage(Widget child) {
    return SafeArea(
      minimum: const EdgeInsets.all(40),
      child: child,
    );
  }

  Widget _buildCameraStatusPill(CameraManagerService cameraManager) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              cameraManager.selectedDevice?.displayName ?? 'No camera',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControlPanel(CameraManagerService cameraManager) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Material(
        key: const ValueKey('control-panel'),
        elevation: 12,
        color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Camera Controls', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: cameraManager.selectedDevice?.name,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih Camera',
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
                        if (cameraName == null) return;
                        await cameraManager.switchCamera(cameraName);
                        if (!mounted || cameraManager.selectedDevice?.name != cameraName) return;
                        final notifier = context.read<AppSettingsNotifier>();
                        await notifier.updateSettings(
                          notifier.settings.copyWith(defaultCameraName: cameraName),
                        );
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: cameraManager.restartCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: cameraManager.reconnectCamera,
                    icon: const Icon(Icons.link),
                    label: const Text('Reconnect'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _toggleFullscreen,
                    icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                    label: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exitApp,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Exit App'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraStage(CameraManagerService cameraManager) {
  final controller = cameraManager.controller;
  final isReady = controller != null && controller.value.isInitialized;
  final isInitializing = cameraManager.isInitializing;

  return ColoredBox(
    color: Colors.black,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (isReady)
          LayoutBuilder(
            builder: (context, constraints) {
              final previewSize = controller.value.previewSize;
              final width = previewSize?.width ?? constraints.maxWidth;
              final height = previewSize?.height ?? constraints.maxHeight;

              return ClipRect(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              );
            },
          )
        else if (isInitializing)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(
                  'Waiting for camera...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam_off_outlined,
                  color: Colors.white54,
                  size: 42,
                ),
                SizedBox(height: 12),
                Text(
                  'Camera not ready',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

  Widget _buildInfoChip(String label, String value) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          '$label: $value',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _CaptureSessionOptions {
  const _CaptureSessionOptions({
    required this.countdownSeconds,
    required this.backgroundKey,
    required this.photoCount,
  });

  final int countdownSeconds;
  final String backgroundKey;
  final int photoCount;
}

class _LayoutChoice {
  const _LayoutChoice({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;
}

int _photoCountForBackground(String backgroundKey) {
  switch (backgroundKey) {
    case 'portrait1':
      return 1;
    case 'portrait2':
      return 2;
    case 'portrait3':
      return 3;
    case 'landscape4':
      return 4;
    case 'landscape6':
      return 6;
    default:
      return 3;
  }
}

enum _CapturePreviewAction {
  continueShot,
  retake,
}

class _CapturePreviewDialog extends StatefulWidget {
  const _CapturePreviewDialog({
    required this.imagePath,
    required this.shotIndex,
    required this.totalShots,
    required this.previewSeconds,
  });

  final String imagePath;
  final int shotIndex;
  final int totalShots;
  final int previewSeconds;

  @override
  State<_CapturePreviewDialog> createState() => _CapturePreviewDialogState();
}

class _CapturePreviewDialogState extends State<_CapturePreviewDialog> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.previewSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        Navigator.of(context).pop(_CapturePreviewAction.continueShot);
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _finish(_CapturePreviewAction action) {
    _timer?.cancel();
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF111111),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hasil ${widget.shotIndex} dari ${widget.totalShots}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih retake atau lanjut. Otomatis lanjut dalam $_remainingSeconds detik.',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Text(
                          '$_remainingSeconds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 760),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            color: const Color(0xFF050505),
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.32), width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => _finish(_CapturePreviewAction.retake),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEAEAEA),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          onPressed: () => _finish(_CapturePreviewAction.continueShot),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Use Photo'),
                        ),
                      ),
                    ],
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

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({
    required this.seconds,
    required this.currentShot,
    required this.totalShots,
  });

  final int seconds;
  final int currentShot;
  final int totalShots;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      title: Text(
        'Foto ${widget.currentShot} dari ${widget.totalShots}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 56, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _remainingSeconds.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Siap-siap!',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
