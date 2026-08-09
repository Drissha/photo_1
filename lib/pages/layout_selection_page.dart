import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'home_page.dart';

class LayoutSelectionPage extends StatefulWidget {
  // Halaman ini dipakai sebelum masuk kamera untuk memilih format sesi foto.
  const LayoutSelectionPage({
    super.key,
    required this.packageName,
    required this.photoCount,
    required this.initialBackgroundKey,
  });

  final String packageName;
  final int photoCount;
  final String initialBackgroundKey;

  @override
  State<LayoutSelectionPage> createState() => _LayoutSelectionPageState();
}

class _LayoutSelectionPageState extends State<LayoutSelectionPage> {
  bool _isFullscreen = false;
  bool _showUtilityMenu = false;
  late String _selectedLayoutId;

  final List<_LayoutOption> _layouts = const [
    _LayoutOption(
      id: 'portrait1',
      title: 'Portrait 1 Take',
      subtitle: '1 foto, tampilan poster portrait yang tegas.',
      photoCount: 1,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFFFFC857),
      previewType: _LayoutPreviewType.portrait1,
    ),
    _LayoutOption(
      id: 'portrait2',
      title: 'Portrait 2 Take',
      subtitle: '2 foto bertumpuk untuk komposisi yang rapi.',
      photoCount: 2,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFF7AE582),
      previewType: _LayoutPreviewType.portrait2,
    ),
    _LayoutOption(
      id: 'portrait3',
      title: 'Portrait 3 Take',
      subtitle: '3 foto dengan ritme visual yang seimbang.',
      photoCount: 3,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFF7BDFF2),
      previewType: _LayoutPreviewType.portrait3,
    ),
    _LayoutOption(
      id: 'landscape4',
      title: 'Landscape 4 Take',
      subtitle: 'Layout lebar 4 foto, cocok untuk grup.',
      photoCount: 4,
      orientation: _LayoutOrientation.landscape,
      accentColor: Color(0xFFF4B942),
      previewType: _LayoutPreviewType.landscape4,
    ),
    _LayoutOption(
      id: 'landscape6',
      title: 'Landscape 6 Take',
      subtitle: '6 foto dalam grid landscape yang padat.',
      photoCount: 6,
      orientation: _LayoutOrientation.landscape,
      accentColor: Color(0xFFFF8A5B),
      previewType: _LayoutPreviewType.landscape6,
    ),
    _LayoutOption(
      id: 'portrait6',
      title: 'Portrait 6 Take',
      subtitle: '6 foto portrait dengan susunan vertikal.',
      photoCount: 6,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFFE58AF7),
      previewType: _LayoutPreviewType.portrait6,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Sync fullscreen dilakukan setelah frame pertama agar window manager sudah siap.
    _selectedLayoutId = widget.initialBackgroundKey;
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

  Future<void> _exitApp() async {
    await windowManager.close();
  }

  void _toggleUtilityMenu() {
    setState(() => _showUtilityMenu = !_showUtilityMenu);
  }

  _LayoutOption get _selectedLayout =>
      _layouts.firstWhere((layout) => layout.id == _selectedLayoutId, orElse: () => _layouts.first);

  Future<void> _startCameraSession() async {
    // Setelah layout dipilih, user diarahkan ke home page untuk mulai capture.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          packageName: _selectedLayout.title,
          photoCount: _selectedLayout.photoCount,
          initialBackgroundKey: _selectedLayout.id,
        ),
      ),
    );
  }

  void _selectLayout(_LayoutOption layout) {
    setState(() => _selectedLayoutId = layout.id);
  }

  @override
  Widget build(BuildContext context) {
    // Layout chooser dibuat visual agar cepat dibandingkan antar template.
    final selectedLayout = _selectedLayout;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1020),
              Color(0xFF12192C),
              Color(0xFF06080F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1120;
                final hero = _buildHero(context, selectedLayout);
                final chooser = _buildChooser(context);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 10, child: hero),
                                const SizedBox(width: 24),
                                Expanded(flex: 11, child: chooser),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(child: hero),
                                const SizedBox(height: 24),
                                Expanded(child: chooser),
                              ],
                            ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FloatingActionButton.extended(
                              onPressed: _toggleUtilityMenu,
                              icon: Icon(_showUtilityMenu ? Icons.close : Icons.menu),
                              label: Text(_showUtilityMenu ? 'Close Menu' : 'Menu'),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: _showUtilityMenu
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Material(
                                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                                        elevation: 14,
                                        borderRadius: BorderRadius.circular(24),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 240),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                FilledButton.tonalIcon(
                                                  onPressed: _toggleFullscreen,
                                                  icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                                                  label: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                                                ),
                                                const SizedBox(height: 10),
                                                FilledButton.tonalIcon(
                                                  onPressed: _exitApp,
                                                  icon: const Icon(Icons.power_settings_new),
                                                  label: const Text('Exit App'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, _LayoutOption selectedLayout) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18233A),
            Color(0xFF0F1728),
            Color(0xFF0A0D16),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'PILIH LAYOUT',
                  style: TextStyle(
                    color: Color(0xFFFFD77A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Atur layout sebelum masuk kamera.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih komposisi foto yang paling cocok. Preview di kanan menunjukkan bentuk layout yang akan dipakai di sesi berikutnya.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      height: 1.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _StepChip(number: '01', label: 'Pilih layout'),
              _StepChip(number: '02', label: 'Cek preview'),
              _StepChip(number: '03', label: 'Masuk kamera'),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Layout terpilih',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white60),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedLayout.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedLayout.photoCount} foto, ${selectedLayout.orientation.label}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: selectedLayout.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: selectedLayout.accentColor.withValues(alpha: 0.45)),
                  ),
                  child: Center(
                    child: Text(
                      '${selectedLayout.photoCount}x',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selectedLayout.accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
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

  Widget _buildChooser(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Preview Layout',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Klik layout untuk melihat bentuk tampilan sebelum sesi foto dimulai.',
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 960
                          ? 2
                          : width >= 620
                              ? 2
                              : 1;
                      final spacing = 14.0;
                      final itemWidth = (width - ((columns - 1) * spacing)) / columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: _layouts
                            .map(
                              (layout) => SizedBox(
                                width: itemWidth,
                                child: _LayoutCard(
                                  layout: layout,
                                  selected: layout.id == _selectedLayoutId,
                                  onTap: () => _selectLayout(layout),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _startCameraSession,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Masuk Kamera'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.layout,
    required this.selected,
    required this.onTap,
  });

  final _LayoutOption layout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? layout.accentColor.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected ? layout.accentColor : Colors.white.withValues(alpha: 0.10),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: layout.orientation == _LayoutOrientation.portrait ? 2 / 3 : 3 / 2,
              child: _LayoutPreview(
                layout: layout,
                selected: selected,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layout.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        layout.subtitle,
                        style: const TextStyle(color: Colors.white70, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? layout.accentColor : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${layout.photoCount} foto',
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutPreview extends StatelessWidget {
  const _LayoutPreview({
    required this.layout,
    required this.selected,
  });

  final _LayoutOption layout;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? layout.accentColor : Colors.white.withValues(alpha: 0.85);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF151C2C),
              const Color(0xFF0A0F19),
            ],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LayoutPreviewPainter(layout, selected: selected),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  layout.orientation == _LayoutOrientation.portrait ? 'Portrait' : 'Landscape',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Text(
                '${layout.photoCount} shots',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutPreviewPainter extends CustomPainter {
  _LayoutPreviewPainter(
    this.layout, {
    required this.selected,
  });

  final _LayoutOption layout;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF101726),
          Color(0xFF06080F),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = (selected ? layout.accentColor : Colors.white).withValues(alpha: 0.2);

    final frameRect = Rect.fromLTWH(size.width * 0.05, size.height * 0.05, size.width * 0.9, size.height * 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(18)),
      border,
    );

    final headerPaint = Paint()..color = const Color(0xFFFFD77A).withValues(alpha: 0.12);
    final footerPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(frameRect.left, frameRect.top, frameRect.width, frameRect.height * 0.14),
        const Radius.circular(18),
      ),
      headerPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(frameRect.left, frameRect.bottom - frameRect.height * 0.12, frameRect.width, frameRect.height * 0.12),
        const Radius.circular(18),
      ),
      footerPaint,
    );

    final slotPaint = Paint()..color = selected ? layout.accentColor : Colors.white;
    final slotOpacity = selected ? 0.28 : 0.20;
    final slots = _slotsFor(layout.previewType, frameRect);
    for (final rect in slots) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        slotPaint..color = slotPaint.color.withValues(alpha: slotOpacity),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = selected ? layout.accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.15),
      );
    }
  }

  List<Rect> _slotsFor(_LayoutPreviewType type, Rect frame) {
    switch (type) {
      case _LayoutPreviewType.portrait1:
        return [
          _rect(frame, 0.14, 0.22, 0.72, 0.46),
        ];
      case _LayoutPreviewType.portrait2:
        return [
          _rect(frame, 0.10, 0.20, 0.80, 0.20),
          _rect(frame, 0.10, 0.48, 0.80, 0.20),
        ];
      case _LayoutPreviewType.portrait3:
        return [
          _rect(frame, 0.10, 0.18, 0.80, 0.14),
          _rect(frame, 0.10, 0.38, 0.80, 0.14),
          _rect(frame, 0.10, 0.58, 0.80, 0.14),
        ];
      case _LayoutPreviewType.landscape4:
        return [
          _rect(frame, 0.10, 0.18, 0.34, 0.22),
          _rect(frame, 0.56, 0.18, 0.34, 0.22),
          _rect(frame, 0.10, 0.52, 0.34, 0.22),
          _rect(frame, 0.56, 0.52, 0.34, 0.22),
        ];
      case _LayoutPreviewType.landscape6:
        return [
          _rect(frame, 0.10, 0.18, 0.24, 0.18),
          _rect(frame, 0.38, 0.18, 0.24, 0.18),
          _rect(frame, 0.66, 0.18, 0.24, 0.18),
          _rect(frame, 0.10, 0.48, 0.24, 0.18),
          _rect(frame, 0.38, 0.48, 0.24, 0.18),
          _rect(frame, 0.66, 0.48, 0.24, 0.18),
        ];
      case _LayoutPreviewType.portrait6:
        return [
          _rect(frame, 0.10, 0.16, 0.34, 0.12),
          _rect(frame, 0.56, 0.16, 0.34, 0.12),
          _rect(frame, 0.10, 0.32, 0.34, 0.12),
          _rect(frame, 0.56, 0.32, 0.34, 0.12),
          _rect(frame, 0.10, 0.48, 0.34, 0.12),
          _rect(frame, 0.56, 0.48, 0.34, 0.12),
        ];
    }
  }

  Rect _rect(Rect frame, double left, double top, double width, double height) {
    return Rect.fromLTWH(
      frame.left + frame.width * left,
      frame.top + frame.height * top,
      frame.width * width,
      frame.height * height,
    );
  }

  @override
  bool shouldRepaint(covariant _LayoutPreviewPainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.selected != selected;
  }
}

enum _LayoutOrientation { portrait, landscape }

extension on _LayoutOrientation {
  String get label {
    switch (this) {
      case _LayoutOrientation.portrait:
        return 'portrait';
      case _LayoutOrientation.landscape:
        return 'landscape';
    }
  }
}

enum _LayoutPreviewType {
  portrait1,
  portrait2,
  portrait3,
  landscape4,
  landscape6,
  portrait6,
}

class _LayoutOption {
  const _LayoutOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.photoCount,
    required this.orientation,
    required this.accentColor,
    required this.previewType,
  });

  final String id;
  final String title;
  final String subtitle;
  final int photoCount;
  final _LayoutOrientation orientation;
  final Color accentColor;
  final _LayoutPreviewType previewType;
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
  });

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              color: Color(0xFFFFD77A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
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
