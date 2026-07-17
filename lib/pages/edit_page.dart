import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/storage_service.dart';

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
  bool _isPreviewRendering = false;
  bool _backgroundInFront = true;
  String? _exportedFilePath;
  ui.Image? _previewImage;
  Future<ui.Image?>? _previewImageFuture;
  int _previewRenderToken = 0;
  _EditLayout _selectedLayout = _EditLayout.grid;
  _ColorTone _selectedTone = _ColorTone.natural;
  final Map<BackgroundCategory, List<File>> _backgroundImagesByCategory = {
    BackgroundCategory.portrait: [],
    BackgroundCategory.landscape: [],
  };
  File? _selectedBackgroundFile;
  String? _backgroundFolderPath;
  BackgroundCategory _selectedBackgroundCategory = BackgroundCategory.portrait;
  late final ScrollController _previewScrollController;
  final List<Offset> _photoOffsets = [];
  final List<double> _photoScales = [];
  double _scaleGestureInitial = 1.0;
  static const Color _backgroundAccentColor = Color(0xFFFFC857);

  @override
  void initState() {
    super.initState();
    _selectedLayout = _layoutFromKey(widget.initialLayoutKey);
    _previewScrollController = ScrollController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
      _loadBackgroundImages();
      _refreshExportPreview();
    });
  }

  @override
  void dispose() {
    _previewImageFuture = null;
    _previewScrollController.dispose();
    _disposePreviewImage();
    super.dispose();
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

        ui.Image? backgroundImage;
try {
  if (_selectedBackgroundFile != null) {
    backgroundImage = await _decodeUiImage(_selectedBackgroundFile!.path);
  }

  // Kalau background HARUS di belakang -> jadi wallpaper dasar saja
  _paintExportBackground(
    canvas,
    spec,
    _backgroundInFront ? null : backgroundImage,
  );
  _paintExportHeader(canvas, spec);
  _paintExportPhotos(canvas, spec, decodedPhotos);

  // Kalau background HARUS di depan -> baru digambar sebagai overlay
  if (_backgroundInFront && backgroundImage != null) {
    _paintExportForegroundOverlay(canvas, spec, backgroundImage);
  }
} finally {
  backgroundImage?.dispose();
}
        final picture = recorder.endRecording();
        final renderedImage = await picture.toImage(spec.width, spec.height);
        final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Gagal membuat data PNG untuk export.');
        }

        final outputDirectory = Directory(widget.takeFolderPath);
        if (!outputDirectory.existsSync()) {
          await outputDirectory.create(recursive: true);
        }
        final outFile = File(
          p.join(
            widget.takeFolderPath,
            'exported_layout_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        );
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

  void _paintExportBackground(Canvas canvas, _LayoutExportSpec spec, ui.Image? backgroundImage) {
    final outerRect = Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble());

    if (backgroundImage != null) {
      _drawImageCover(canvas, backgroundImage, outerRect, Paint());
    } else {
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
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _backgroundAccentColor.withOpacity(0.22),
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
          _backgroundAccentColor.withOpacity(0.16),
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
      case _EditLayout.wantedPoster:
        _paintWantedPosterLayout(canvas, spec, photos, tonePaint);
        break;
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
          _paintExportFrame(
          canvas,
          photos[index],
          rect,
          tonePaint,
          compact: true,
          imageOffset: _photoOffsets.length > index ? _photoOffsets[index] : Offset.zero,
          imageScale: _photoScales.length > index ? _photoScales[index] : 1.0,
        );
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
          _paintExportFrame(
          canvas,
          photos[index],
          rect,
          tonePaint,
          polaroid: true,
          imageOffset: _photoOffsets.length > index ? _photoOffsets[index] : Offset.zero,
          imageScale: _photoScales.length > index ? _photoScales[index] : 1.0,
        );
        }
        break;
    }
  }

  void _paintExportForegroundOverlay(Canvas canvas, _LayoutExportSpec spec, ui.Image? overlayImage) {
    if (overlayImage == null) return;
    final outerRect = Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble());
    final paint = Paint()..colorFilter = ColorFilter.mode(Colors.black.withOpacity(0.22), BlendMode.darken);
    _drawImageCover(canvas, overlayImage, outerRect, paint);
  }

  void _paintWantedPosterLayout(
    Canvas canvas,
    _LayoutExportSpec spec,
    List<ui.Image> photos,
    Paint tonePaint,
  ) {
    final outerRect = Rect.fromLTWH(0, 0, spec.width.toDouble(), spec.height.toDouble());
    final paperRect = Rect.fromLTWH(
      34,
      34,
      spec.width.toDouble() - 68,
      spec.height.toDouble() - 68,
    );

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8DDC4),
          Color(0xFFF4E8D0),
          Color(0xFFD9C7A1),
        ],
      ).createShader(outerRect);
    canvas.drawRect(outerRect, basePaint);

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF6B4E2D).withOpacity(0.22),
        ],
        stops: const [0.65, 1.0],
      ).createShader(outerRect);
    canvas.drawRect(outerRect, vignettePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(28)),
      Paint()..color = const Color(0xFFF7F0E0).withOpacity(0.96),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(28)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF3B2B17).withOpacity(0.5),
    );

    final titleX = spec.width * 0.5;
    _drawText(
      canvas,
      'WANTED',
      offset: Offset(titleX - 300, 80),
      style: const TextStyle(
        color: Color(0xFF131313),
        fontSize: 96,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
      maxWidth: 600,
    );
    canvas.drawLine(
      Offset(paperRect.left + 54, 182),
      Offset(paperRect.right - 54, 182),
      Paint()
        ..color = const Color(0xFF111111).withOpacity(0.8)
        ..strokeWidth = 2.5,
    );

    _drawText(
      canvas,
      'REWARD: FREE PHOTO BOOTH SESSION',
      offset: Offset(paperRect.left + 72, 208),
      style: const TextStyle(
        color: Color(0xFF131313),
        fontSize: 36,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: spec.width - 180,
    );
    _drawText(
      canvas,
      'FOR INFORMATION LEADING TO CAPTURE',
      offset: Offset(paperRect.left + 86, 254),
      style: const TextStyle(
        color: Color(0xFF222222),
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
      maxWidth: spec.width - 180,
    );

    final slotRects = _wantedPosterPhotoRects(spec);
    for (var index = 0; index < slotRects.length; index++) {
      final rect = slotRects[index];
      final photo = photos.length > index ? photos[index] : null;
      _paintWantedPosterFrame(
        canvas,
        rect,
        photo,
        tonePaint,
        caption: 'PHOTO ${index + 1} - ${_wantedPosterCaptionForIndex(index)}',
      );
    }

    _drawText(
      canvas,
      'SUSPECT: ${widget.takeFolderName.toUpperCase()}',
      offset: Offset(paperRect.left + 66, paperRect.bottom - 210),
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 28,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: spec.width - 160,
    );
    _drawText(
      canvas,
      'DEAD OR ALIVE | CAPTURED BY SELFIE ZONE PHOTOBOOTH',
      offset: Offset(paperRect.left + 66, paperRect.bottom - 168),
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
      maxWidth: spec.width - 160,
    );
    _drawText(
      canvas,
      'IF SPOTTED, SMILE AND TAKE ANOTHER SHOT',
      offset: Offset(paperRect.left + 66, paperRect.bottom - 126),
      style: const TextStyle(
        color: Color(0xFF222222),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      maxWidth: spec.width - 160,
    );
    canvas.drawLine(
      Offset(paperRect.left + 64, paperRect.bottom - 96),
      Offset(paperRect.right - 64, paperRect.bottom - 96),
      Paint()
        ..color = const Color(0xFF111111).withOpacity(0.45)
        ..strokeWidth = 2,
    );
    _drawText(
      canvas,
      'CAPTURED LIVE IN THE BOOTH',
      offset: Offset(paperRect.left + 66, paperRect.bottom - 74),
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
      maxWidth: spec.width - 160,
    );
  }

  List<Rect> _wantedPosterPhotoRects(_LayoutExportSpec spec) {
    final count = widget.photoPaths.length;
    final paperLeft = 96.0;
    final paperWidth = spec.width.toDouble() - 192;

    switch (count) {
      case 1:
        return [
          Rect.fromLTWH(paperLeft + 72, 400, paperWidth - 144, 940),
        ];
      case 2:
        return [
          Rect.fromLTWH(paperLeft, 400, paperWidth, 380),
          Rect.fromLTWH(paperLeft, 860, paperWidth, 380),
        ];
      case 3:
        return [
          Rect.fromLTWH(paperLeft, 380, paperWidth, 250),
          Rect.fromLTWH(paperLeft, 690, paperWidth, 250),
          Rect.fromLTWH(paperLeft, 1000, paperWidth, 250),
        ];
      case 4:
        return [
          Rect.fromLTWH(paperLeft, 390, 460, 320),
          Rect.fromLTWH(paperLeft + 480, 390, 460, 320),
          Rect.fromLTWH(paperLeft, 790, 460, 320),
          Rect.fromLTWH(paperLeft + 480, 790, 460, 320),
        ];
      case 6:
      default:
        return [
          Rect.fromLTWH(paperLeft, 370, 460, 250),
          Rect.fromLTWH(paperLeft + 480, 370, 460, 250),
          Rect.fromLTWH(paperLeft, 670, 460, 250),
          Rect.fromLTWH(paperLeft + 480, 670, 460, 250),
          Rect.fromLTWH(paperLeft, 970, 460, 250),
          Rect.fromLTWH(paperLeft + 480, 970, 460, 250),
        ];
    }
  }

  static const List<String> _wantedPosterCaptions = [
    'CAUGHT ON TAPE',
    'LAST KNOWN APPEARANCE',
    'IDENTIFY THIS SUSPECT',
    'MOST WANTED MOMENT',
    'UNMARKED ALIAS',
    'FINAL SIGHTING',
  ];

  String _wantedPosterCaptionForIndex(int index) {
    return _wantedPosterCaptions[index % _wantedPosterCaptions.length];
  }

  void _paintWantedPosterFrame(
    Canvas canvas,
    Rect rect,
    ui.Image? photo,
    Paint tonePaint, {
    required String caption,
  }) {
    final labelStyle = const TextStyle(
      color: Color(0xFF111111),
      fontSize: 16,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 10)), const Radius.circular(8)),
      Paint()..color = Colors.black.withOpacity(0.22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF111111),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(6)),
      Paint()..color = const Color(0xFFF5F0E4),
    );

    final photoRect = rect.deflate(14);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(photoRect, const Radius.circular(5)));
    if (photo != null) {
      _drawImageCover(canvas, photo, photoRect, tonePaint);
    } else {
      canvas.drawRect(photoRect, Paint()..color = const Color(0xFF1C1C1C));
    }
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(photoRect, const Radius.circular(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFFFFF).withOpacity(0.55),
    );

    _drawText(
      canvas,
      caption,
      offset: Offset(rect.left + 6, rect.top - 26),
      style: labelStyle,
      maxWidth: rect.width - 12,
    );
  }

  void _paintExportFrame(
    Canvas canvas,
    ui.Image photo,
    Rect rect,
    Paint tonePaint, {
    bool compact = false,
    bool polaroid = false,
    Offset imageOffset = Offset.zero,
    double imageScale = 1.0,
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

    final transformedRect = Rect.fromCenter(
      center: photoRect.center + Offset(imageOffset.dx * photoRect.width, imageOffset.dy * photoRect.height),
      width: photoRect.width * imageScale,
      height: photoRect.height * imageScale,
    );

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(photoRect, const Radius.circular(16)));
    _drawImageCover(canvas, photo, transformedRect, tonePaint);
    canvas.restore();

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

  void _ensurePhotoTransform(int index) {
    while (_photoOffsets.length <= index) {
      _photoOffsets.add(Offset.zero);
      _photoScales.add(1.0);
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
      case 'wanted1':
      case 'wanted2':
      case 'wanted3':
      case 'wanted4':
      case 'wanted6':
        return _EditLayout.wantedPoster;
      default:
        return _EditLayout.wantedPoster;
    }
  }

  Future<void> _loadBackgroundImages() async {
    final storageService = context.read<StorageService>();
    final folderPath = await storageService.getDefaultBackgroundFolder();
    final library = await storageService.loadBackgroundLibrary(folderPath);
    if (!mounted) return;
    setState(() {
      _backgroundFolderPath = folderPath;
      _backgroundImagesByCategory[BackgroundCategory.portrait] = library.portraitImages;
      _backgroundImagesByCategory[BackgroundCategory.landscape] = library.landscapeImages;
      if (_selectedBackgroundFile == null ||
          ![
            ...library.portraitImages,
            ...library.landscapeImages,
          ].any((file) => file.path == _selectedBackgroundFile!.path)) {
        _selectedBackgroundFile = library.portraitImages.isNotEmpty
            ? library.portraitImages.first
            : (library.landscapeImages.isNotEmpty ? library.landscapeImages.first : null);
      }
      if ((_backgroundImagesByCategory[_selectedBackgroundCategory]?.isEmpty ?? true) &&
          (library.portraitImages.isNotEmpty || library.landscapeImages.isNotEmpty)) {
        _selectedBackgroundCategory =
            library.portraitImages.isNotEmpty ? BackgroundCategory.portrait : BackgroundCategory.landscape;
      }
    });
    _refreshExportPreview();
  }

  Future<void> _chooseBackground() async {
    await _loadBackgroundImages();
    final nextBackground = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              child: DefaultTabController(
                length: BackgroundCategory.values.length,
                initialIndex: _selectedBackgroundCategory.index,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih background',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_backgroundFolderPath != null)
                      Text(
                        'Taruh gambar di folder ini: $_backgroundFolderPath/Portrait atau $_backgroundFolderPath/Landscape',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      )
                    else
                      Text(
                        'Taruh gambar ke folder default untuk menggunakan background custom.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: const Color(0xFFFFC857).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        tabs: [
                          Tab(text: 'Portrait (${_backgroundFilesFor(BackgroundCategory.portrait).length})'),
                          Tab(text: 'Landscape (${_backgroundFilesFor(BackgroundCategory.landscape).length})'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: BackgroundCategory.values.map((category) {
                          final files = _backgroundFilesFor(category);
                          if (files.isEmpty) {
                            return Center(
                              child: Text(
                                'Tidak ada background ${_backgroundCategoryLabel(category).toLowerCase()}.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.92,
                            children: files
                                .map(
                                  (backgroundFile) => _buildBackgroundChoiceCard(
                                    backgroundFile,
                                    category,
                                    sheetContext,
                                  ),
                                )
                                .toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (nextBackground == null || !mounted) return;
    setState(() {
      _selectedBackgroundFile = nextBackground;
      _selectedBackgroundCategory = _backgroundCategoryForFile(nextBackground);
    });
    _refreshExportPreview();
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
    _refreshExportPreview();
  }

  Widget _buildBackgroundChoiceCard(
    File backgroundFile,
    BackgroundCategory category,
    BuildContext sheetContext,
  ) {
    final isSelected = _selectedBackgroundFile?.path == backgroundFile.path;
    return InkWell(
      onTap: () => Navigator.pop(sheetContext, backgroundFile),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    image: DecorationImage(
                      image: FileImage(backgroundFile),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.24),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.36),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _backgroundCategoryIcon(category),
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _backgroundCategoryLabel(category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.basename(backgroundFile.path),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${_backgroundCategoryLabel(category)} background',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<File> _backgroundFilesFor(BackgroundCategory category) {
    return _backgroundImagesByCategory[category] ?? const [];
  }

  BackgroundCategory _backgroundCategoryForFile(File file) {
    if (_backgroundFilesFor(BackgroundCategory.portrait).any((candidate) => candidate.path == file.path)) {
      return BackgroundCategory.portrait;
    }
    return BackgroundCategory.landscape;
  }

  String _backgroundCategoryLabel(BackgroundCategory category) {
    return switch (category) {
      BackgroundCategory.portrait => 'Portrait',
      BackgroundCategory.landscape => 'Landscape',
    };
  }

  IconData _backgroundCategoryIcon(BackgroundCategory category) {
    return switch (category) {
      BackgroundCategory.portrait => Icons.portrait_outlined,
      BackgroundCategory.landscape => Icons.landscape_outlined,
    };
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
                        // Expanded(
                        //   child: Column(
                        //     crossAxisAlignment: CrossAxisAlignment.start,
                        //     children: [
                        //         Container(
                        //           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        //           decoration: BoxDecoration(
                        //             color: const Color(0xFFFFC857).withOpacity(0.14),
                        //             borderRadius: BorderRadius.circular(999),
                        //             border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.32)),
                        //           ),
                        //           child: const Text(
                        //             'PHOTO EDIT STAGE',
                        //             style: TextStyle(
                        //               color: Color(0xFFFFD77A),
                        //               fontWeight: FontWeight.w800,
                        //               letterSpacing: 1.2,
                        //             ),
                        //           ),
                        //         ),
                        //         const SizedBox(height: 16),
                        //         Text(
                        //           'Hasil foto siap diedit',
                        //           style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        //                 color: Colors.white,
                        //                 fontWeight: FontWeight.w900,
                        //               ),
                        //       ),
                        //       const SizedBox(height: 8),
                        //       Text(
                        //         'Setelah tahap edit selesai, tekan tombol kembali untuk masuk ke halaman awal.',
                        //         style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        //               color: Colors.white70,
                        //             ),
                        //       ),
                        //       ],
                        //     ),
                        //   ),
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
                            final isWide = constraints.maxWidth >= 1400;

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
                'Preview Layout',
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
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                color: Colors.black.withOpacity(0.20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildExportPreviewBody(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportPreviewBody() {
    final previewImage = _previewImage;
    if (previewImage != null) {
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: previewImage.width.toDouble(),
            height: previewImage.height.toDouble(),
            child: RawImage(image: previewImage),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFD77A)),
            const SizedBox(height: 16),
            Text(
              _isPreviewRendering ? 'Membuat preview export...' : 'Preview belum tersedia',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _refreshExportPreview() {
    if (!mounted) return;
    final renderToken = ++_previewRenderToken;
    final previewFuture = _renderExportPreviewImage();
    setState(() {
      _isPreviewRendering = true;
      _previewImageFuture = previewFuture;
    });

    previewFuture.then((image) {
      if (!mounted || renderToken != _previewRenderToken) {
        image.dispose();
        return;
      }
      final previous = _previewImage;
      setState(() {
        _previewImage = image;
        _isPreviewRendering = false;
        _previewImageFuture = null;
      });
      previous?.dispose();
    }).catchError((error, stackTrace) {
      if (!mounted || renderToken != _previewRenderToken) return;
      setState(() {
        _isPreviewRendering = false;
        _previewImageFuture = null;
      });
    });
  }

  void _disposePreviewImage() {
    _previewImage?.dispose();
    _previewImage = null;
  }

  Future<ui.Image> _renderExportPreviewImage() async {
    final decodedPhotos = <ui.Image>[];
    ui.Image? backgroundImage;
    try {
      for (final path in widget.photoPaths) {
        decodedPhotos.add(await _decodeUiImage(path));
      }
      if (_selectedBackgroundFile != null) {
        backgroundImage = await _decodeUiImage(_selectedBackgroundFile!.path);
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

      _paintExportBackground(
        canvas,
        spec,
        _backgroundInFront ? null : backgroundImage,
      );
      _paintExportHeader(canvas, spec);
      _paintExportPhotos(canvas, spec, decodedPhotos);
      if (_backgroundInFront && backgroundImage != null) {
        _paintExportForegroundOverlay(canvas, spec, backgroundImage);
      }

      final picture = recorder.endRecording();
      final renderedImage = await picture.toImage(spec.width, spec.height);
      return renderedImage;
    } finally {
      backgroundImage?.dispose();
      for (final image in decodedPhotos) {
        image.dispose();
      }
    }
  }

  List<Rect> _gridPreviewRects(_LayoutExportSpec spec) {
    final top = spec.margin + spec.headerHeight;
    final left = spec.margin + spec.innerPadding;
    final contentWidth = spec.width - spec.margin * 2 - spec.innerPadding * 2;
    final contentHeight = spec.height - spec.margin * 2 - spec.headerHeight - spec.footerHeight - spec.innerPadding * 2;
    const cols = 2;
    final rows = math.max(1, (widget.photoPaths.length / cols).ceil());
    final gap = spec.gap;
    final cardWidth = (contentWidth - gap * (cols - 1)) / cols;
    final cardHeight = (contentHeight - gap * (rows - 1)) / rows;
    final rects = <Rect>[];
    for (var index = 0; index < widget.photoPaths.length; index++) {
      final row = index ~/ cols;
      final col = index % cols;
      rects.add(Rect.fromLTWH(
        left + col * (cardWidth + gap),
        top + spec.innerPadding + row * (cardHeight + gap),
        cardWidth,
        cardHeight,
      ));
    }
    return rects;
  }

  List<Rect> _verticalPreviewRects() {
    const spec = _LayoutExportSpec(
      width: 1200,
      height: 1800,
      margin: 20,
      headerHeight: 90,
      footerHeight: 90,
      innerPadding: 8,
      gap: 20,
    );
    final top = spec.margin + spec.headerHeight;
    final left = spec.margin + spec.innerPadding;
    final contentWidth = spec.width - spec.margin * 2 - spec.innerPadding * 2;
    final contentHeight = spec.height - spec.margin * 2 - spec.headerHeight - spec.footerHeight - spec.innerPadding * 2;
    final gap = spec.gap;
    final count = math.max(1, widget.photoPaths.length);
    final cardHeight = (contentHeight - gap * (count - 1)) / count;
    return List.generate(widget.photoPaths.length, (index) {
      return Rect.fromLTWH(
        left,
        top + spec.innerPadding + index * (cardHeight + gap),
        contentWidth,
        cardHeight,
      );
    });
  }

  List<Rect> _horizontalPreviewRects() {
    const spec = _LayoutExportSpec(
      width: 1200,
      height: 1800,
      margin: 20,
      headerHeight: 90,
      footerHeight: 90,
      innerPadding: 8,
      gap: 20,
    );
    final top = spec.margin + spec.headerHeight;
    final left = spec.margin + spec.innerPadding;
    final contentWidth = spec.width - spec.margin * 2 - spec.innerPadding * 2;
    final contentHeight = spec.height - spec.margin * 2 - spec.headerHeight - spec.footerHeight - spec.innerPadding * 2;
    final gap = spec.gap;
    final count = math.max(1, widget.photoPaths.length);
    final cardWidth = (contentWidth - gap * (count - 1)) / count;
    return List.generate(widget.photoPaths.length, (index) {
      return Rect.fromLTWH(
        left + index * (cardWidth + gap),
        top + spec.innerPadding,
        cardWidth,
        contentHeight,
      );
    });
  }

  List<Rect> _polaroidPreviewRects() {
    const spec = _LayoutExportSpec(
      width: 1200,
      height: 1800,
      margin: 20,
      headerHeight: 90,
      footerHeight: 100,
      innerPadding: 8,
      gap: 34,
    );
    final top = spec.margin + spec.headerHeight;
    final left = spec.margin + spec.innerPadding;
    final contentWidth = spec.width - spec.margin * 2 - spec.innerPadding * 2;
    final contentHeight = spec.height - spec.margin * 2 - spec.headerHeight - spec.footerHeight - spec.innerPadding * 2;
    final gap = spec.gap;
    const cols = 2;
    final rows = math.max(1, (widget.photoPaths.length / cols).ceil());
    final cardWidth = (contentWidth - gap * (cols - 1)) / cols;
    final cardHeight = (contentHeight - gap * (rows - 1)) / rows;
    final rects = <Rect>[];
    for (var index = 0; index < widget.photoPaths.length; index++) {
      final row = index ~/ cols;
      final col = index % cols;
      rects.add(Rect.fromLTWH(
        left + col * (cardWidth + gap),
        top + spec.innerPadding + row * (cardHeight + gap),
        cardWidth,
        cardHeight,
      ));
    }
    return rects;
  }

  Offset _backgroundScrollOffset() {
    if (!_previewScrollController.hasClients) {
      return Offset.zero;
    }
    final offset = _previewScrollController.offset;
    return _selectedLayout == _EditLayout.horizontalStrip
        ? Offset(-offset, 0)
        : Offset(0, -offset);
  }

  Widget _buildLayoutPreview() {
    switch (_selectedLayout) {
      case _EditLayout.wantedPoster:
        return _buildWantedPosterPreview();
      case _EditLayout.grid:
        return GridView.builder(
          controller: _previewScrollController,
          key: const ValueKey('layout-grid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: widget.photoPaths.length,
          itemBuilder: (context, index) => _buildPhotoFrame(
            index: index,
            path: widget.photoPaths[index],
            label: 'Frame ${index + 1}',
            layout: _selectedLayout,
          ),
        );
      case _EditLayout.verticalStrip:
        return ListView.separated(
          controller: _previewScrollController,
          key: const ValueKey('layout-vertical-strip'),
          itemCount: widget.photoPaths.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => SizedBox(
            height: 100,
            child: _buildPhotoFrame(
              index: index,
              path: widget.photoPaths[index],
              // label: 'Frame ${index + 1}',
              layout: _selectedLayout,
            ),
          ),
        );
      case _EditLayout.horizontalStrip:
        return ListView.separated(
          controller: _previewScrollController,
          key: const ValueKey('layout-horizontal-strip'),
          scrollDirection: Axis.horizontal,
          itemCount: widget.photoPaths.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) => SizedBox(
            width: 220,
            child: _buildPhotoFrame(
              index: index,
              path: widget.photoPaths[index],
              label: 'Frame ${index + 1}',
              layout: _selectedLayout,
            ),
          ),
        );
      case _EditLayout.polaroid:
        return GridView.builder(
          controller: _previewScrollController,
          key: const ValueKey('layout-polaroid'),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.70,
          ),
          itemCount: widget.photoPaths.length,
          itemBuilder: (context, index) => _buildPhotoFrame(
            index: index,
            path: widget.photoPaths[index],
            label: 'Polaroid ${index + 1}',
            layout: _selectedLayout,
          ),
        );
    }
  }

  Widget _buildWantedPosterPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = const Size(1200, 1800);
        final scale = math.min(constraints.maxWidth / size.width, constraints.maxHeight / size.height);
        return Center(
          child: Transform.scale(
            scale: scale.isFinite && scale > 0 ? scale : 1,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE8DDC4),
                          Color(0xFFF4E8D0),
                          Color(0xFFD9C7A1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(34),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F0E0),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFF3B2B17).withOpacity(0.5), width: 3),
                    ),
                  ),
                  Positioned(
                    top: 74,
                    left: 0,
                    right: 0,
                    child: Text(
                      'WANTED',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF131313),
                        fontSize: 94,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 182,
                    left: 110,
                    right: 110,
                    child: Container(height: 2.5, color: const Color(0xFF111111).withOpacity(0.8)),
                  ),
                  Positioned(
                    top: 210,
                    left: 116,
                    right: 116,
                    child: const Text(
                      'REWARD: FREE PHOTO BOOTH SESSION',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF131313),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 255,
                    left: 112,
                    right: 112,
                    child: const Text(
                      'FOR INFORMATION LEADING TO CAPTURE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  _buildWantedPosterPreviewFrame(
                    top: 320,
                    caption: 'PHOTO 1 - CAUGHT ON TAPE',
                    index: 0,
                  ),
                  _buildWantedPosterPreviewFrame(
                    top: 564,
                    caption: 'PHOTO 2 - LAST KNOWN APPEARANCE',
                    index: 1,
                  ),
                  _buildWantedPosterPreviewFrame(
                    top: 808,
                    caption: 'PHOTO 3 - IDENTIFY THIS SUSPECT',
                    index: 2,
                  ),
                  Positioned(
                    left: 100,
                    right: 100,
                    bottom: 214,
                    child: Text(
                      'SUSPECT: ${widget.takeFolderName.toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 100,
                    right: 100,
                    bottom: 176,
                    child: const Text(
                      'DEAD OR ALIVE | CAPTURED BY SELFIE ZONE PHOTOBOOTH',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 100,
                    right: 100,
                    bottom: 132,
                    child: const Text(
                      'IF SPOTTED, SMILE AND TAKE ANOTHER SHOT',
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWantedPosterPreviewFrame({
    required double top,
    required String caption,
    required int index,
  }) {
    final rectTop = top;
    final rectLeft = 116.0;
    const rectWidth = 968.0;
    const rectHeight = 204.0;

    return Positioned(
      left: rectLeft,
      top: rectTop,
      width: rectWidth,
      height: rectHeight + 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Container(
              height: rectHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E4),
                  borderRadius: BorderRadius.circular(5),
                ),
                clipBehavior: Clip.antiAlias,
                child: index < widget.photoPaths.length
                    ? Image.file(
                        File(widget.photoPaths[index]),
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: const Color(0xFF1C1C1C),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 6,
            child: Text(
              caption,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoFrame({
    required int index,
    required String path,
    String? label,
    required _EditLayout layout,
  }) {
    final isPolaroid = layout == _EditLayout.polaroid;

    _ensurePhotoTransform(index);
    final imageOffset = _photoOffsets[index];
    final imageScale = _photoScales[index];

    return Container(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              // onScaleStart: (ScaleStartDetails details) {
              //   _scaleGestureInitial = imageScale;
              // },
              // onScaleUpdate: (ScaleUpdateDetails details) {
              //   if (details.scale != 1.0 || details.focalPointDelta != Offset.zero) {
              //     final frameSize = context.size ?? Size.zero;
              //     if (frameSize.width == 0 || frameSize.height == 0) return;
              //     final dx = details.focalPointDelta.dx / frameSize.width;
              //     final dy = details.focalPointDelta.dy / frameSize.height;
              //     setState(() {
              //       _photoOffsets[index] = Offset(
              //         (_photoOffsets[index].dx + dx).clamp(-1.5, 1.5),
              //         (_photoOffsets[index].dy + dy).clamp(-1.5, 1.5),
              //       );
              //       _photoScales[index] = (_scaleGestureInitial * details.scale).clamp(0.7, 3.0);
              //     });
              //   }
              // },
              onPanUpdate: (DragUpdateDetails details) {
                final frameSize = context.size ?? Size.zero;
                if (frameSize.width == 0 || frameSize.height == 0) return;
                final dx = details.delta.dx / frameSize.width;
                final dy = details.delta.dy / frameSize.height;
                setState(() {
                  _photoOffsets[index] = Offset(
                    (_photoOffsets[index].dx + dx).clamp(-1.5, 1.5),
                    (_photoOffsets[index].dy + dy).clamp(-1.5, 1.5),
                  );
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final translateOffset = Offset(
                    imageOffset.dx * constraints.maxWidth,
                    imageOffset.dy * constraints.maxHeight,
                  );
                  return Transform.translate(
                    offset: translateOffset,
                    child: Transform.scale(
                      scale: imageScale,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: _selectedTone.filter == null
                            ? Image.file(
                                File(path),
                                fit: BoxFit.cover,
                              )
                            : ColorFiltered(
                                colorFilter: _selectedTone.filter!,
                                child: Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Text(
          //   label!,
          //   style: TextStyle(
          //     color: isPolaroid ? Colors.black87 : Colors.white,
          //     fontWeight: FontWeight.w700,
          //   ),
          // ),
          const SizedBox(height: 4),
          // Text(
          //   widget.takeFolderName,
          //   overflow: TextOverflow.ellipsis,
          //   style: TextStyle(
          //     color: isPolaroid ? Colors.black54 : Colors.white54,
          //     fontSize: 12,
          //   ),
          // ),
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
            'Halaman ini bisa kamu pakai untuk retouch, pilih background, atau sekadar cek hasil sebelum kembali ke awal.',
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
            title: 'Pilih background',
            subtitle: _selectedBackgroundFile != null ? p.basename(_selectedBackgroundFile!.path) : 'Default',
            onTap: _chooseBackground,
          ),
          const SizedBox(height: 10),
          _buildEditActionChip(
            icon: _backgroundInFront ? Icons.layers_outlined : Icons.layers_clear_outlined,
            title: _backgroundInFront ? 'Background di depan' : 'Background di belakang',
            subtitle: _backgroundInFront ? 'Tampilkan di hadapan foto' : 'Tampilkan di belakang foto',
            onTap: () => setState(() => _backgroundInFront = !_backgroundInFront),
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
    const fixedWidth = 1200;
    const fixedHeight = 1800;
    final isStrip = layout == _EditLayout.verticalStrip || layout == _EditLayout.horizontalStrip;
    final isPolaroid = layout == _EditLayout.polaroid;
    final isWantedPoster = layout == _EditLayout.wantedPoster;

    return _LayoutExportSpec(
      width: fixedWidth,
      height: fixedHeight,
      margin: 20,
      headerHeight: isStrip ? 90 : 90, // dinaikkan, beri jarak aman ~40px
      footerHeight: isWantedPoster
          ? (photoCount <= 2 ? 120 : 100)
          : (isPolaroid ? 100 : 90),
      innerPadding: isPolaroid ? 8 : 8,
      gap: isStrip ? 20 : 18,
    );
  }
}

enum _EditLayout {
  grid,
  verticalStrip,
  horizontalStrip,
  polaroid,
  wantedPoster,
}

extension on _EditLayout {
  String get label => switch (this) {
        _EditLayout.grid => 'Grid 2x2',
        _EditLayout.verticalStrip => 'Vertical Strip',
        _EditLayout.horizontalStrip => 'Horizontal Strip',
        _EditLayout.polaroid => 'Polaroid',
        _EditLayout.wantedPoster => 'Wanted Poster',
      };

  String get description => switch (this) {
        _EditLayout.grid => 'Susunan kotak rapi dan balance.',
        _EditLayout.verticalStrip => 'Susunan memanjang ke bawah.',
        _EditLayout.horizontalStrip => 'Susunan memanjang ke samping.',
        _EditLayout.polaroid => 'Frame putih ala cetak polaroid.',
        _EditLayout.wantedPoster => 'Poster vintage ala wanted board.',
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
