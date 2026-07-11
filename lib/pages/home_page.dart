import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/app_providers.dart';
import '../core/services/camera_manager_service.dart';
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
  bool _showControlPanel = false;
  bool _isFullscreen = false;

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

  @override
  Widget build(BuildContext context) {
    final cameraManager = context.watch<CameraManagerService>();
    final settings = context.watch<AppSettingsNotifier>().settings;

    final pages = <Widget>[
      _buildCameraPage(cameraManager),
      _buildSafePage(const GalleryPage()),
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
                    onPressed: cameraManager.isInitialized
                        ? () async {
                            final path = await cameraManager.capturePhoto(settings.saveFolderPath);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved $path')));
                            }
                          }
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
