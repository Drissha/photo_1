import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

import '../core/services/camera_manager_service.dart';

class DigiCamLiveView extends StatefulWidget {
  const DigiCamLiveView({
    super.key,
    required this.cameraManager,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final CameraManagerService cameraManager;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<DigiCamLiveView> createState() => _DigiCamLiveViewState();
}

class _DigiCamLiveViewState extends State<DigiCamLiveView> {
  @override
  Widget build(BuildContext context) {
    if (!widget.cameraManager.isLiveViewEnabled) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, color: Colors.white54, size: 42),
            SizedBox(height: 12),
            Text('Live view is disabled in settings', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    final url = widget.cameraManager.liveViewStreamUrl;
    final borderRadius = widget.borderRadius;

    Widget child;
    if (url.isEmpty) {
      child = const Center(child: CircularProgressIndicator());
    } else {
      child = Mjpeg(
        stream: url,
        isLive: true,
        fit: widget.fit,
        loading: (context) => const Center(child: CircularProgressIndicator()),
        error: (context, error, stackTrace) {
          return _LiveViewFallback(
            cameraManager: widget.cameraManager,
            fit: widget.fit,
          );
        },
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius, child: child);
    }

    return child;
  }
}

class _LiveViewFallback extends StatefulWidget {
  const _LiveViewFallback({
    required this.cameraManager,
    required this.fit,
  });

  final CameraManagerService cameraManager;
  final BoxFit fit;

  @override
  State<_LiveViewFallback> createState() => _LiveViewFallbackState();
}

class _LiveViewFallbackState extends State<_LiveViewFallback> {
  static const Duration _refreshInterval = Duration(milliseconds: 500);
  Timer? _timer;
  int _frameToken = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted || !widget.cameraManager.isInitialized) return;
      setState(() => _frameToken += 1);
    });
  }

  @override
  void didUpdateWidget(covariant _LiveViewFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraManager != widget.cameraManager) {
      _timer?.cancel();
      _timer = Timer.periodic(_refreshInterval, (_) {
        if (!mounted || !widget.cameraManager.isInitialized) return;
        setState(() => _frameToken += 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.cameraManager.liveViewImageUrl;
    if (url.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Image.network(
      '$url&fallback=$_frameToken',
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, image, loadingProgress) {
        if (loadingProgress == null) return image;
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            const Center(child: CircularProgressIndicator()),
          ],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 42),
              SizedBox(height: 12),
              Text('Live view unavailable', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      },
    );
  }
}
