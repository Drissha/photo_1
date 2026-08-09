import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/services/local_camera_preview_service.dart';

class LocalCameraLiveView extends StatelessWidget {
  // Widget ini hanya merender state preview webcam lokal yang sudah dikelola service.
  const LocalCameraLiveView({
    super.key,
    required this.previewService,
    this.borderRadius,
  });

  final LocalCameraPreviewService previewService;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    // UI disederhanakan menjadi tiga keadaan utama: off, loading, atau live.
    Widget child;
    if (!previewService.isEnabled) {
      child = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, color: Colors.white54, size: 42),
            SizedBox(height: 12),
            Text('Live view disabled', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    } else if (previewService.isInitializing) {
      child = const Center(child: CircularProgressIndicator());
    } else if (!previewService.isInitialized || previewService.controller == null) {
      child = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 42),
            const SizedBox(height: 12),
            Text(
              previewService.isUnavailable ? 'Local live view unavailable' : 'Waiting for local camera...',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    } else {
      final controller = previewService.controller!;
      child = ClipRect(
        child: CameraPreview(controller),
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }
}
