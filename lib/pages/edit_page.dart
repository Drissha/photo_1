import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class EditPage extends StatefulWidget {
  const EditPage({
    super.key,
    required this.photoPaths,
    required this.takeFolderPath,
    required this.takeFolderName,
    required this.initialLayoutKey,
  });

  final List<String> photoPaths;
  final String takeFolderPath;
  final String takeFolderName;
  final String initialLayoutKey;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  bool _isFullscreen = false;
  bool _isReturning = false;
  bool _isExporting = false;
  String? _exportedFilePath;
  _EditLayout _selectedLayout = _EditLayout.grid;
  _ColorTone _selectedTone = _ColorTone.natural;

  @override
  void initState() {
    super.initState();
    _selectedLayout = _layoutFromKey(widget.initialLayoutKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
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

  Future<void> _returnToStart() async {
    if (_isReturning || !mounted) return;
    _isReturning = true;

    try {
      await _exportEditedLayout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export hasil edit gagal: $error')),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<String> _exportEditedLayout() async {
    if (_exportedFilePath != null) {
      return _exportedFilePath!;
    }

    if (_isExporting) {
      while (_isExporting && mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _exportedFilePath ?? '';
    }

    if (!mounted) {
      return '';
    }

    setState(() => _isExporting = true);
    try {
      final decodedPhotos = <ui.Image>[];
      try {
        for (final path in widget.photoPaths) {
          decodedPhotos.add(await _decodeUiImage(path));
        }

        final spec = _LayoutExportSpec.forLayout(
          layout: _selectedLayout,
          photoCount: decodedPhotos.length,
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(
          recorder,
          Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble()),
        );

        _paintExportBackground(canvas, spec);
        _paintExportHeader(canvas, spec);
        _paintExportPhotos(canvas, spec, decodedPhotos);

        final picture = recorder.endRecording();
        final image = await picture.toImage(spec.width, spec.height);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Unable to encode edited image.');
        }

        final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}_${_selectedLayout.name}_${_selectedTone.name}.png';
        final outFile = File(p.join(widget.takeFolderPath, fileName));
        await outFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        _exportedFilePath = outFile.path;
        return outFile.path;
      } finally {
        for (final image in decodedPhotos) {
          image.dispose();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<ui.Image> _decodeUiImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _paintExportBackground(Canvas canvas, _LayoutExportSpec spec) {
    final outerRect = Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble());
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B1020),
          Color(0xFF12192C),
          Color(0xFF05070C),
        ],
      ).createShader(outerRect);
    canvas.drawRect(outerRect, backgroundPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFC857).withOpacity(0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(spec.width * 0.18, spec.height * 0.18),
        radius: spec.width * 0.28,
      ));
    canvas.drawRect(outerRect, glowPaint);

    final glowPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7BDFF2).withOpacity(0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(spec.width * 0.85, spec.height * 0.82),
        radius: spec.width * 0.24,
      ));
    canvas.drawRect(outerRect, glowPaint2);

    final paperRect = Rect.fromLTWH(
      spec.margin.toDouble(),
      spec.margin.toDouble(),
      (spec.width - spec.margin * 2).toDouble(),
      (spec.height - spec.margin * 2).toDouble(),
    );
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect.shift(const Offset(0, 12)), const Radius.circular(38)),
      shadowPaint,
    );

    final paperPaint = Paint()..color = const Color(0xFFF5F1E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(38)),
      paperPaint,
    );
  }

  void _paintExportHeader(Canvas canvas, _LayoutExportSpec spec) {
    final headerLeft = spec.margin + 42.0;
    final headerTop = spec.margin + 34.0;

    final chipPaint = Paint()..color = const Color(0xFF111827);
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headerLeft, headerTop, 240, 40),
      const Radius.circular(999),
    );
    canvas.drawRRect(chipRect, chipPaint);

    _drawText(
      canvas,
      'PAPYRUS PHOTO STRIP',
      offset: Offset(headerLeft + 18, headerTop + 10),
      style: const TextStyle(
        color: Color(0xFFFFD77A),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );

    _drawText(
      canvas,
      widget.takeFolderName,
      offset: Offset(headerLeft, headerTop + 64),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 34,
        fontWeight: FontWeight.w900,
      ),
    );

    _drawText(
      canvas,
      'Layout ${_selectedLayout.label} | Tone ${_selectedTone.label}',
      offset: Offset(headerLeft, headerTop + 114),
      style: const TextStyle(
        color: Color(0xFF374151),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );

    final infoY = headerTop + 164;
    _drawInfoChip(canvas, Offset(headerLeft, infoY), _selectedLayout.label);
    _drawInfoChip(canvas, Offset(headerLeft + 168, infoY), _selectedTone.label);
    _drawInfoChip(canvas, Offset(headerLeft + 296, infoY), '${widget.photoPaths.length} foto');
  }

  void _drawInfoChip(Canvas canvas, Offset offset, String label) {
    final width = label.length * 10.0 + 34.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy, width, 34),
      const Radius.circular(999),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF111827).withOpacity(0.92));
    _drawText(
      canvas,
      label,
      offset: Offset(offset.dx + 14, offset.dy + 8),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _paintExportPhotos(Canvas canvas, _LayoutExportSpec spec, List<ui.Image> photos) {
    final top = spec.margin + spec.headerHeight;
    final left = spec.margin + spec.innerPadding;
    final contentWidth = spec.width - spec.margin * 2 - spec.innerPadding * 2;
    final contentHeight = spec.height - spec.margin * 2 - spec.headerHeight - spec.footerHeight - spec.innerPadding * 2;
    final tonePaint = Paint()..colorFilter = _selectedTone.filter;

    switch (_selectedLayout) {
      case _EditLayout.grid:
        final cols = 2;
        final rows = math.max(1, (photos.length / cols).ceil());
        final gap = spec.gap;
        final cardWidth = (contentWidth - gap * (cols - 1)) / cols;
        final cardHeight = (contentHeight - gap * (rows - 1)) / rows;

        for (var index = 0; index < photos.length; index++) {
          final row = index ~/ cols;
          final col = index % cols;
          final rect = Rect.fromLTWH(
            left + col * (cardWidth + gap),
            top + spec.innerPadding + row * (cardHeight + gap),
            cardWidth,
            cardHeight,
          );
          _paintExportFrame(canvas, photos[index], rect, tonePaint, compact: false);
        }
        break;
      case _EditLayout.verticalStrip:
        final gap = spec.gap;
        final cardHeight = (contentHeight - gap * (photos.length - 1)) / math.max(1, photos.length);
        final cardWidth = contentWidth;
        for (var index = 0; index < photos.length; index++) {
          final rect = Rect.fromLTWH(
            left,
            top + spec.innerPadding + index * (cardHeight + gap),
            cardWidth,
            cardHeight,
          );
          _paintExportFrame(canvas, photos[index], rect, tonePaint, compact: true);
        }
        break;
      case _EditLayout.horizontalStrip:
        final gap = spec.gap;
        final cardWidth = (contentWidth - gap * (photos.length - 1)) / math.max(1, photos.length);
        final cardHeight = contentHeight;
        for (var index = 0; index < photos.length; index++) {
          final rect = Rect.fromLTWH(
            left + index * (cardWidth + gap),
            top + spec.innerPadding,
            cardWidth,
            cardHeight,
          );
          _paintExportFrame(canvas, photos[index], rect, tonePaint, compact: false);
        }
        break;
      case _EditLayout.polaroid:
        final cols = 2;
        final rows = math.max(1, (photos.length / cols).ceil());
        final gap = spec.gap + 14;
        final cardWidth = (contentWidth - gap * (cols - 1)) / cols;
        final cardHeight = (contentHeight - gap * (rows - 1)) / rows;
        for (var index = 0; index < photos.length; index++) {
          final row = index ~/ cols;
          final col = index % cols;
          final rect = Rect.fromLTWH(
            left + col * (cardWidth + gap),
            top + spec.innerPadding + row * (cardHeight + gap),
            cardWidth,
            cardHeight,
          );
          _paintExportFrame(canvas, photos[index], rect, tonePaint, polaroid: true);
        }
        break;
    }
  }

  void _paintExportFrame(
    Canvas canvas,
    ui.Image photo,
    Rect rect,
    Paint tonePaint, {
    bool compact = false,
    bool polaroid = false,
  }) {
    final shadowOffset = polaroid ? const Offset(0, 14) : const Offset(0, 10);
    final frameRadius = polaroid ? 30.0 : 24.0;
    final frameColor = polaroid ? Colors.white : const Color(0xFF0F1728).withOpacity(0.92);
    final borderColor = polaroid ? const Color(0xFFE7DFD0) : Colors.white.withOpacity(0.12);
    final padding = polaroid ? 18.0 : 12.0;
    final captionHeight = compact ? 38.0 : 52.0;

    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(shadowOffset), Radius.circular(frameRadius)),
      shadowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(frameRadius)),
      Paint()..color = frameColor,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), Radius.circular(frameRadius - 1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );

    final photoRect = Rect.fromLTWH(
      rect.left + padding,
      rect.top + padding,
      rect.width - padding * 2,
      rect.height - padding * 2 - captionHeight,
    );

    _drawImageCover(canvas, photo, photoRect, tonePaint);

    final labelY = photoRect.bottom + 8;
    _drawText(
      canvas,
      compact ? 'Photo booth strip' : widget.takeFolderName,
      offset: Offset(rect.left + padding, labelY),
      style: TextStyle(
        color: polaroid ? Colors.black87 : Colors.white,
        fontSize: polaroid ? 16 : 14,
        fontWeight: FontWeight.w700,
      ),
    );
    if (polaroid) {
      _drawText(
        canvas,
        '${_selectedLayout.label} | ${_selectedTone.label}',
        offset: Offset(rect.left + padding, labelY + 20),
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  void _drawImageCover(Canvas canvas, ui.Image image, Rect dstRect, Paint tonePaint) {
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final srcRect = _coverSourceRect(srcSize, dstRect.size);
    canvas.drawImageRect(image, srcRect, dstRect, tonePaint);
  }

  Rect _coverSourceRect(Size source, Size target) {
    final srcAspect = source.width / source.height;
    final dstAspect = target.width / target.height;

    if (srcAspect > dstAspect) {
      final cropWidth = source.height * dstAspect;
      final left = (source.width - cropWidth) / 2;
      return Rect.fromLTWH(left, 0, cropWidth, source.height);
    } else {
      final cropHeight = source.width / dstAspect;
      final top = (source.height - cropHeight) / 2;
      return Rect.fromLTWH(0, top, source.width, cropHeight);
    }
  }

  void _drawText(
    Canvas canvas,
    String text, {
    required Offset offset,
    required TextStyle style,
    double maxWidth = 1200,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  _EditLayout _layoutFromKey(String key) {
    switch (key) {
      case 'vertical':
        return _EditLayout.verticalStrip;
      case 'horizontal':
        return _EditLayout.horizontalStrip;
      case 'polaroid':
        return _EditLayout.polaroid;
      case 'grid':
      default:
        return _EditLayout.grid;
    }
  }

  Future<void> _chooseLayout() async {
    final nextLayout = await showModalBottomSheet<_EditLayout>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _EditLayout.values
                .map(
                  (layout) => RadioListTile<_EditLayout>(
                    value: layout,
                    groupValue: _selectedLayout,
                    title: Text(layout.label),
                    subtitle: Text(layout.description),
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (nextLayout == null || !mounted) return;
    setState(() => _selectedLayout = nextLayout);
  }

  Future<void> _chooseColorTone() async {
    final nextTone = await showModalBottomSheet<_ColorTone>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _ColorTone.values
                .map(
                  (tone) => RadioListTile<_ColorTone>(
                    value: tone,
                    groupValue: _selectedTone,
                    title: Text(tone.label),
                    subtitle: Text(tone.description),
                    onChanged: (value) => Navigator.pop(sheetContext, value),
                  ),
                )
                .toList(),
          ),
        );
      },
    );

    if (nextTone == null || !mounted) return;
    setState(() => _selectedTone = nextTone);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _returnToStart();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0F1C),
                Color(0xFF111A2E),
                Color(0xFF05070C),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -60,
                child: _GlowOrb(color: const Color(0xFFFFC857), size: 220),
              ),
              Positioned(
                bottom: -70,
                right: -40,
                child: _GlowOrb(color: const Color(0xFF7BDFF2), size: 180),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFC857).withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.32)),
                                  ),
                                  child: const Text(
                                    'PHOTO EDIT STAGE',
                                    style: TextStyle(
                                      color: Color(0xFFFFD77A),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Hasil foto siap diedit',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Setelah tahap edit selesai, tekan tombol kembali untuk masuk ke halaman awal.',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.tonalIcon(
                            onPressed: _toggleFullscreen,
                            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                            label: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1000;

                            final preview = _buildPreviewCard(context);
                            final tools = _buildToolsCard(context);

                            return isWide
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 11, child: preview),
                                      const SizedBox(width: 20),
                                      Expanded(flex: 8, child: tools),
                                    ],
                                  )
                                : ListView(
                                    children: [
                                      preview,
                                      const SizedBox(height: 20),
                                      tools,
                                    ],
                                  );
                          },
                        ),
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

  Widget _buildPreviewCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                'Preview Strip',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                '${widget.photoPaths.length} foto',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7F2E8),
                  Color(0xFFE9E2D3),
                  Color(0xFFFDFBF7),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  left: -24,
                  child: _GlowOrb(
                    color: const Color(0xFFFFC857).withOpacity(0.38),
                    size: 140,
                  ),
                ),
                Positioned(
                  bottom: -30,
                  right: -18,
                  child: _GlowOrb(
                    color: const Color(0xFF7BDFF2).withOpacity(0.34),
                    size: 120,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPreviewBadge('Layout ${_selectedLayout.label}'),
                          _buildPreviewBadge('Tone ${_selectedTone.label}'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: const Color(0xFF111827).withOpacity(0.08),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 520,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _buildLayoutPreview(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutPreview() {
    switch (_selectedLayout) {
      case _EditLayout.grid:
        return GridView.builder(
          key: const ValueKey('layout-grid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.88,
          ),
          itemCount: widget.photoPaths.length,
          itemBuilder: (context, index) => _buildPhotoFrame(
            path: widget.photoPaths[index],
            label: 'Frame ${index + 1}',
            layout: _selectedLayout,
          ),
        );
      case _EditLayout.verticalStrip:
        return ListView.separated(
          key: const ValueKey('layout-vertical-strip'),
          itemCount: widget.photoPaths.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => SizedBox(
            height: 190,
            child: _buildPhotoFrame(
              path: widget.photoPaths[index],
              label: 'Frame ${index + 1}',
              layout: _selectedLayout,
            ),
          ),
        );
      case _EditLayout.horizontalStrip:
        return ListView.separated(
          key: const ValueKey('layout-horizontal-strip'),
          scrollDirection: Axis.horizontal,
          itemCount: widget.photoPaths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) => SizedBox(
            width: 220,
            child: _buildPhotoFrame(
              path: widget.photoPaths[index],
              label: 'Frame ${index + 1}',
              layout: _selectedLayout,
            ),
          ),
        );
      case _EditLayout.polaroid:
        return GridView.builder(
          key: const ValueKey('layout-polaroid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.82,
          ),
          itemCount: widget.photoPaths.length,
          itemBuilder: (context, index) => _buildPhotoFrame(
            path: widget.photoPaths[index],
            label: 'Polaroid ${index + 1}',
            layout: _selectedLayout,
          ),
        );
    }
  }

  Widget _buildPhotoFrame({
    required String path,
    required String label,
    required _EditLayout layout,
  }) {
    final isPolaroid = layout == _EditLayout.polaroid;

    return Container(
      decoration: BoxDecoration(
        color: isPolaroid ? Colors.white : Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPolaroid ? Colors.white : Colors.white.withOpacity(0.08),
        ),
      ),
      padding: EdgeInsets.all(isPolaroid ? 14 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _selectedTone.filter == null
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : ColorFiltered(
                      colorFilter: _selectedTone.filter!,
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: isPolaroid ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.takeFolderName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPolaroid ? Colors.black54 : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildToolsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit Controls',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Halaman ini bisa kamu pakai untuk retouch, pilih layout, atau sekadar cek hasil sebelum kembali ke awal.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 18),
          _buildEditActionChip(
            icon: Icons.auto_fix_high_outlined,
            title: 'Auto retouch',
            subtitle: 'Clean up look',
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _buildEditActionChip(
            icon: Icons.photo_filter_outlined,
            title: 'Choose layout',
            subtitle: _selectedLayout.label,
            onTap: _chooseLayout,
          ),
          const SizedBox(height: 10),
          _buildEditActionChip(
            icon: Icons.palette_outlined,
            title: 'Color tone',
            subtitle: _selectedTone.label,
            onTap: _chooseColorTone,
          ),
          const SizedBox(height: 10),
          _buildEditActionChip(
            icon: Icons.print_outlined,
            title: 'Ready to print',
            subtitle: 'Export preview',
            onTap: () {},
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.20),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tidak ada auto-return. Tekan tombol di bawah jika sudah selesai.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _returnToStart,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Selesai & Kembali'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditActionChip({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFD77A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _buildEditChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD77A), size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutExportSpec {
  const _LayoutExportSpec({
    required this.width,
    required this.height,
    required this.margin,
    required this.headerHeight,
    required this.footerHeight,
    required this.innerPadding,
    required this.gap,
  });

  final int width;
  final int height;
  final int margin;
  final double headerHeight;
  final double footerHeight;
  final double innerPadding;
  final double gap;

  factory _LayoutExportSpec.forLayout({
    required _EditLayout layout,
    required int photoCount,
  }) {
    final isStrip = layout == _EditLayout.verticalStrip || layout == _EditLayout.horizontalStrip;
    final isPolaroid = layout == _EditLayout.polaroid;
    final baseWidth = isStrip ? 1600 : 1400;
    final baseHeight = isStrip ? 2000 : 1700;
    final photoScale = math.max(0, photoCount - 1);

    return _LayoutExportSpec(
      width: baseWidth,
      height: baseHeight + (photoScale * 55),
      margin: 80,
      headerHeight: isStrip ? 240 : 220,
      footerHeight: isPolaroid ? 110 : 90,
      innerPadding: isPolaroid ? 36 : 28,
      gap: isStrip ? 24 : 20,
    );
  }
}

enum _EditLayout {
  grid,
  verticalStrip,
  horizontalStrip,
  polaroid,
}

extension on _EditLayout {
  String get label => switch (this) {
        _EditLayout.grid => 'Grid 2x2',
        _EditLayout.verticalStrip => 'Vertical Strip',
        _EditLayout.horizontalStrip => 'Horizontal Strip',
        _EditLayout.polaroid => 'Polaroid',
      };

  String get description => switch (this) {
        _EditLayout.grid => 'Susunan kotak rapi dan balance.',
        _EditLayout.verticalStrip => 'Susunan memanjang ke bawah.',
        _EditLayout.horizontalStrip => 'Susunan memanjang ke samping.',
        _EditLayout.polaroid => 'Frame putih ala cetak polaroid.',
      };
}

enum _ColorTone {
  natural,
  warm,
  cool,
  mono,
}

extension _ColorToneX on _ColorTone {
  String get label => switch (this) {
        _ColorTone.natural => 'Natural',
        _ColorTone.warm => 'Warm',
        _ColorTone.cool => 'Cool',
        _ColorTone.mono => 'Mono',
      };

  String get description => switch (this) {
        _ColorTone.natural => 'Warna asli foto.',
        _ColorTone.warm => 'Nuansa hangat dan lembut.',
        _ColorTone.cool => 'Nuansa dingin dan modern.',
        _ColorTone.mono => 'Hitam putih dramatis.',
      };

  ColorFilter? get filter => switch (this) {
        _ColorTone.natural => null,
        _ColorTone.warm => const ColorFilter.matrix([
            1.05, 0.06, 0.0, 0.0, 10,
            0.02, 1.00, 0.0, 0.0, 2,
            0.00, 0.00, 0.92, 0.0, -4,
            0.00, 0.00, 0.0, 1.0, 0,
          ]),
        _ColorTone.cool => const ColorFilter.matrix([
            0.92, 0.0, 0.06, 0.0, 0,
            0.0, 0.97, 0.08, 0.0, 0,
            0.10, 0.0, 1.08, 0.0, 8,
            0.0, 0.0, 0.0, 1.0, 0,
          ]),
        _ColorTone.mono => const ColorFilter.matrix([
            0.33, 0.33, 0.33, 0.0, 0,
            0.33, 0.33, 0.33, 0.0, 0,
            0.33, 0.33, 0.33, 0.0, 0,
            0.0, 0.0, 0.0, 1.0, 0,
          ]),
      };
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.08),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
