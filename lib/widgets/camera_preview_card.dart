import 'package:flutter/material.dart';

import '../core/services/local_camera_preview_service.dart';
import 'local_camera_live_view.dart';

class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({super.key, required this.previewService});

  final LocalCameraPreviewService previewService;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Camera Preview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: previewService.isInitializing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Initializing local camera...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : previewService.isInitialized
                    ? LocalCameraLiveView(
                        previewService: previewService,
                        borderRadius: BorderRadius.circular(18),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Waiting for local camera...', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statChip('Camera', previewService.selectedCameraName ?? 'Default'),
                _statChip('Status', previewService.status),
                _statChip('Brightness', 'Auto'),
                _statChip('Contrast', 'Auto'),
                _statChip('Saturation', 'Auto'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
    );
  }
}
