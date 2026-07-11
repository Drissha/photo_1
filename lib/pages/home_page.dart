import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/troubleshooting_service.dart';
import 'diagnostics_page.dart';
import 'gallery_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int _galleryReloadToken = 0;
  bool _showControlPanel = false;
  bool _isFullscreen = false;
  bool _isCaptureSessionRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cameraManager = context.read<CameraManagerService>();
      final troubleshooter = context.read<TroubleshootingService>();
      await cameraManager.initializeCamera();
      troubleshooter.startMonitoring();
      await _syncFullscreenState();
    });
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
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(sheetContext, 1),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () => Navigator.pop(sheetContext, 2),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Diagnostics'),
                onTap: () => Navigator.pop(sheetContext, 3),
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
      defaultCount: 3,
      defaultCountdown: settings.autoCaptureDelaySeconds,
    );
    if (options == null || !mounted) return;

    setState(() => _isCaptureSessionRunning = true);
    try {
      final takeFolder = await storageService.createTakeFolder(settings.saveFolderPath);
      final savedPaths = <String>[];
      for (var index = 0; index < options.photoCount; index++) {
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
        savedPaths.add(path);

        if (index < options.photoCount - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (mounted) {
        if (_selectedIndex == 1) {
          _galleryReloadToken += 1;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${savedPaths.length} photo(s) in ${Uri.file(takeFolder).pathSegments.last}')),
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
    required int defaultCount,
    required int defaultCountdown,
  }) {
    return showDialog<_CaptureSessionOptions>(
      context: context,
      builder: (dialogContext) {
        var selectedCount = defaultCount;
        var selectedCountdown = defaultCountdown;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Capture Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedCount,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah foto',
                      border: OutlineInputBorder(),
                    ),
                    items: const [1, 2, 3, 5, 10]
                        .map((count) => DropdownMenuItem(value: count, child: Text('$count foto')))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedCount = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedCountdown,
                    decoration: const InputDecoration(
                      labelText: 'Countdown',
                      border: OutlineInputBorder(),
                    ),
                    items: const [0, 3, 5, 10]
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
                        photoCount: selectedCount,
                        countdownSeconds: selectedCountdown,
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

  @override
  Widget build(BuildContext context) {
    final cameraManager = context.watch<CameraManagerService>();
    final settings = context.watch<AppSettingsNotifier>().settings;

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
      minimum: const EdgeInsets.all(28),
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
      ),
    );
  }

  Widget _buildCameraStage(CameraManagerService cameraManager) {
    final controller = cameraManager.controller;
    final isReady = controller != null && controller.value.isInitialized;

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
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Waiting for camera...', style: TextStyle(color: Colors.white)),
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
    required this.photoCount,
    required this.countdownSeconds,
  });

  final int photoCount;
  final int countdownSeconds;
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
