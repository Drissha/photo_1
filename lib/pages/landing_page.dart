import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/camera_manager_service.dart';
import 'diagnostics_page.dart';
import 'gallery_page.dart';
import 'layout_selection_page.dart';
import 'settings_page.dart';

class LandingPage extends StatefulWidget {
  // Halaman pembuka ini menjadi titik masuk ke menu utama dan flow capture.
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isFullscreen = false;
  bool _showUtilityMenu = false;

  @override
  void initState() {
    super.initState();
    // Setelah frame pertama siap, sync fullscreen dan refresh daftar kamera.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
      context.read<CameraManagerService>().refreshDevices();
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

  Future<void> _openUtilityPage(Widget page) async {
    if (!mounted) return;
    setState(() => _showUtilityMenu = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _startJourney() async {
    // Tombol start langsung masuk ke pemilihan layout sebelum sesi kamera.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LayoutSelectionPage(
          packageName: 'Portrait 3 Take',
          photoCount: 3,
          initialBackgroundKey: 'portrait3',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hero screen dirancang sebagai landing visual, bukan sekadar menu tekstual.
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF081120),
                  Color(0xFF111B30),
                  Color(0xFF05070C),
                ],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: _GlowOrb(color: const Color(0xFFFFC857), size: 260),
          ),
          Positioned(
            bottom: -100,
            right: -70,
            child: _GlowOrb(color: const Color(0xFF7BDFF2), size: 240),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _FloatingIconField(
                wide: MediaQuery.sizeOf(context).width >= 1100,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1100;

                  final content = isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Expanded(child: _buildHero(context)),
                            // const SizedBox(width: 24),
                            Expanded(child: _buildCta(context)),
                          ],
                        )
                      : Column(
                          children: [
                            // Expanded(child: _buildHero(context)),
                            const SizedBox(height: 24),
                            Expanded(child: _buildCta(context)),
                          ],
                        );

                  return Stack(
                    children: [
                      Positioned.fill(child: content),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FloatingActionButton.small(
                              onPressed: _toggleUtilityMenu,
                              child: Icon(_showUtilityMenu ? Icons.close : Icons.menu),
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
                                                  onPressed: () => _openUtilityPage(const GalleryPage()),
                                                  icon: const Icon(Icons.photo_library_outlined),
                                                  label: const Text('Gallery'),
                                                ),
                                                const SizedBox(height: 10),
                                                FilledButton.tonalIcon(
                                                  onPressed: () => _openUtilityPage(const SettingsPage()),
                                                  icon: const Icon(Icons.settings_outlined),
                                                  label: const Text('Settings'),
                                                ),
                                                const SizedBox(height: 10),
                                                FilledButton.tonalIcon(
                                                  onPressed: () => _openUtilityPage(const DiagnosticsPage()),
                                                  icon: const Icon(Icons.health_and_safety_outlined),
                                                  label: const Text('Diagnostics'),
                                                ),
                                                const SizedBox(height: 10),
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
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
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
                  'PAPYRUS PHOTOBOOTH',
                  style: TextStyle(
                    color: Color(0xFFFFD77A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Masuk ke sesi foto dengan satu tombol.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih layout dulu, lalu mulai sesi capture dalam tampilan yang bersih, cepat, dan langsung ke inti.',
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
              _StepChip(number: '02', label: 'Masuk kamera'),
              _StepChip(number: '03', label: 'Ambil foto'),
            ],
          ),
          const SizedBox(height: 28),
          const _HeroIllustration(),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 32,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Icon(  
              Icons.photo_camera_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 24),
          // const Spacer(),
          SizedBox(
            height: 62,
            width: 240,
            child: FilledButton.icon(
              onPressed: _startJourney,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Text(
                'Start',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.38,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A2844),
              Color(0xFF0C1324),
              Color(0xFF090B12),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 18,
              top: 18,
              child: _GlintDot(color: const Color(0xFFFFC857), size: 18),
            ),
            Positioned(
              right: 18,
              bottom: 18,
              child: _GlintDot(color: const Color(0xFF7BDFF2), size: 22),
            ),
            Center(
              child: Container(
                width: 0.72 * 420,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFBF4E7),
                            Color(0xFFF1E5CD),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 18,
                            top: 18,
                            right: 18,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                _MiniStrip(height: 58, width: 58),
                                _MiniStrip(height: 58, width: 58),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 18,
                            child: Container(
                              height: 122,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0E1524),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.photo_camera_outlined,
                                  size: 64,
                                  color: Color(0xFFFFD77A),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFC857), Color(0xFFFF8A5B)],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            child: const Center(
                              child: Text(
                                'CTA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
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
      ),
    );
  }
}

class _FloatingIconField extends StatelessWidget {
  const _FloatingIconField({
    required this.wide,
  });

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final icons = wide ? _FloatingIconSpec.wideSpecs : _FloatingIconSpec.compactSpecs;

    return Stack(
      children: [
        for (final spec in icons)
          Positioned(
            left: spec.left,
            top: spec.top,
            right: spec.right,
            bottom: spec.bottom,
            child: Align(
              alignment: spec.alignment,
              child: _FloatingIconBubble(
                icon: spec.icon,
                size: spec.size,
                tint: spec.tint,
                amplitude: spec.amplitude,
                duration: spec.duration,
                delay: spec.delay,
                rotation: spec.rotation,
              ),
            ),
          ),
      ],
    );
  }
}

class _FloatingIconBubble extends StatefulWidget {
  const _FloatingIconBubble({
    required this.icon,
    required this.size,
    required this.tint,
    required this.amplitude,
    required this.duration,
    required this.delay,
    required this.rotation,
  });

  final IconData icon;
  final double size;
  final Color tint;
  final double amplitude;
  final Duration duration;
  final Duration delay;
  final double rotation;

  @override
  State<_FloatingIconBubble> createState() => _FloatingIconBubbleState();
}

class _FloatingIconBubbleState extends State<_FloatingIconBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final verticalShift = math.sin((t * math.pi * 2) + widget.delay.inMilliseconds / 1000.0) * widget.amplitude;
        final glow = (0.18 + (0.08 * t)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, verticalShift),
          child: Transform.rotate(
            angle: widget.rotation + (0.04 * math.sin(t * math.pi * 2)),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.tint.withValues(alpha: 0.24),
                    widget.tint.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.tint.withValues(alpha: 0.18),
                    blurRadius: 26,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: widget.size * 0.62,
                  height: widget.size * 0.62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: glow),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Icon(
                    widget.icon,
                    size: widget.size * 0.34,
                    color: const Color(0xFF0F1728).withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingIconSpec {
  const _FloatingIconSpec({
    required this.icon,
    required this.size,
    required this.tint,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.alignment,
    required this.amplitude,
    required this.duration,
    required this.delay,
    required this.rotation,
  });

  final IconData icon;
  final double size;
  final Color tint;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final Alignment alignment;
  final double amplitude;
  final Duration duration;
  final Duration delay;
  final double rotation;

  static List<_FloatingIconSpec> get wideSpecs => const [
        _FloatingIconSpec(
          icon: Icons.camera_alt_rounded,
          size: 74,
          tint: Color(0xFFFFC857),
          left: 54,
          top: 118,
          right: null,
          bottom: null,
          alignment: Alignment.topLeft,
          amplitude: 12,
          duration: Duration(milliseconds: 4200),
          delay: Duration(milliseconds: 0),
          rotation: -0.18,
        ),
        _FloatingIconSpec(
          icon: Icons.auto_awesome_rounded,
          size: 62,
          tint: Color(0xFF7BDFF2),
          left: 160,
          top: 32,
          right: null,
          bottom: null,
          alignment: Alignment.topLeft,
          amplitude: 16,
          duration: Duration(milliseconds: 5200),
          delay: Duration(milliseconds: 700),
          rotation: 0.22,
        ),
        _FloatingIconSpec(
          icon: Icons.photo_library_rounded,
          size: 68,
          tint: Color(0xFFFF8A5B),
          left: null,
          top: 96,
          right: 72,
          bottom: null,
          alignment: Alignment.topRight,
          amplitude: 14,
          duration: Duration(milliseconds: 4700),
          delay: Duration(milliseconds: 300),
          rotation: 0.12,
        ),
        _FloatingIconSpec(
          icon: Icons.favorite_rounded,
          size: 52,
          tint: Color(0xFFFF6B9A),
          left: null,
          top: 208,
          right: 200,
          bottom: null,
          alignment: Alignment.topRight,
          amplitude: 10,
          duration: Duration(milliseconds: 3900),
          delay: Duration(milliseconds: 1400),
          rotation: -0.12,
        ),
        _FloatingIconSpec(
          icon: Icons.lens_rounded,
          size: 88,
          tint: Color(0xFF9B8CFF),
          left: 84,
          top: null,
          right: null,
          bottom: 84,
          alignment: Alignment.bottomLeft,
          amplitude: 18,
          duration: Duration(milliseconds: 6100),
          delay: Duration(milliseconds: 600),
          rotation: 0.08,
        ),
        _FloatingIconSpec(
          icon: Icons.image_rounded,
          size: 58,
          tint: Color(0xFF7BDFF2),
          left: null,
          top: null,
          right: 84,
          bottom: 110,
          alignment: Alignment.bottomRight,
          amplitude: 12,
          duration: Duration(milliseconds: 4500),
          delay: Duration(milliseconds: 1000),
          rotation: -0.16,
        ),
        _FloatingIconSpec(
          icon: Icons.star_rounded,
          size: 44,
          tint: Color(0xFFFFD77A),
          left: 320,
          top: 76,
          right: null,
          bottom: null,
          alignment: Alignment.topLeft,
          amplitude: 8,
          duration: Duration(milliseconds: 3600),
          delay: Duration(milliseconds: 1800),
          rotation: 0.28,
        ),
      ];

  static List<_FloatingIconSpec> get compactSpecs => const [
        _FloatingIconSpec(
          icon: Icons.camera_alt_rounded,
          size: 60,
          tint: Color(0xFFFFC857),
          left: 16,
          top: 88,
          right: null,
          bottom: null,
          alignment: Alignment.topLeft,
          amplitude: 10,
          duration: Duration(milliseconds: 4300),
          delay: Duration(milliseconds: 0),
          rotation: -0.12,
        ),
        _FloatingIconSpec(
          icon: Icons.auto_awesome_rounded,
          size: 48,
          tint: Color(0xFF7BDFF2),
          left: null,
          top: 140,
          right: 18,
          bottom: null,
          alignment: Alignment.topRight,
          amplitude: 12,
          duration: Duration(milliseconds: 5000),
          delay: Duration(milliseconds: 700),
          rotation: 0.18,
        ),
        _FloatingIconSpec(
          icon: Icons.photo_library_rounded,
          size: 52,
          tint: Color(0xFFFF8A5B),
          left: 24,
          top: null,
          right: null,
          bottom: 180,
          alignment: Alignment.bottomLeft,
          amplitude: 12,
          duration: Duration(milliseconds: 4700),
          delay: Duration(milliseconds: 300),
          rotation: 0.08,
        ),
        _FloatingIconSpec(
          icon: Icons.favorite_rounded,
          size: 42,
          tint: Color(0xFFFF6B9A),
          left: null,
          top: null,
          right: 24,
          bottom: 120,
          alignment: Alignment.bottomRight,
          amplitude: 8,
          duration: Duration(milliseconds: 3900),
          delay: Duration(milliseconds: 1300),
          rotation: -0.12,
        ),
      ];
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC857).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFFFFD77A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStrip extends StatelessWidget {
  const _MiniStrip({
    required this.height,
    required this.width,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFC857),
              Color(0xFF7BDFF2),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlintDot extends StatelessWidget {
  const _GlintDot({
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
        color: color.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
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
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
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
