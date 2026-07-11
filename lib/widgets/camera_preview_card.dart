import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/services/camera_manager_service.dart';

class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({super.key, required this.cameraManager});

  final CameraManagerService cameraManager;

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
                child: cameraManager.controller != null && cameraManager.controller!.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: CameraPreview(cameraManager.controller!),
                      )
                    : const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Waiting for camera...', style: TextStyle(color: Colors.white)),
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
                _statChip('Resolution', cameraManager.resolution),
                _statChip('FPS', cameraManager.fps.toStringAsFixed(0)),
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
