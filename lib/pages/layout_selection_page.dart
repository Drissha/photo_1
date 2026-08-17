import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/dashboard_api_service.dart';
import 'home_page.dart';

class LayoutSelectionPage extends StatefulWidget {
  // Halaman ini dipakai sebelum masuk kamera untuk memilih format sesi foto.
  const LayoutSelectionPage({
    super.key,
    required this.packageName,
    required this.photoCount,
    required this.initialBackgroundKey,
    this.layoutTemplateData,
  });

  final String packageName;
  final int photoCount;
  final String initialBackgroundKey;
  final Map<String, dynamic>? layoutTemplateData;

  @override
  State<LayoutSelectionPage> createState() => _LayoutSelectionPageState();
}

class _LayoutSelectionPageState extends State<LayoutSelectionPage> {
  bool _isFullscreen = false;
  bool _showUtilityMenu = false;
  bool _isSyncingData = false;
  bool _isLoadingLayouts = false;
  int _remoteTemplateCount = 0;
  String? _lastSyncMessage;
  Timer? _lastSyncMessageTimer;
  late final TextEditingController _takeNameController;
  late String _selectedLayoutId;
  List<_LayoutOption> _layouts = _defaultLayouts;

  static const List<_LayoutOption> _defaultLayouts = [
    _LayoutOption(
      id: 'portrait1',
      title: 'Portrait 1 Take',
      subtitle: '1 foto, tampilan poster portrait yang tegas.',
      layoutMode: 'wantedPoster',
      photoCount: 1,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFFFFC857),
      previewType: _LayoutPreviewType.portrait1,
    ),
    _LayoutOption(
      id: 'portrait2',
      title: 'Portrait 2 Take',
      subtitle: '2 foto bertumpuk untuk komposisi yang rapi.',
      layoutMode: 'wantedPoster',
      photoCount: 2,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFF7AE582),
      previewType: _LayoutPreviewType.portrait2,
    ),
    _LayoutOption(
      id: 'portrait3',
      title: 'Portrait 3 Take',
      subtitle: '3 foto dengan ritme visual yang seimbang.',
      layoutMode: 'wantedPoster',
      photoCount: 3,
      orientation: _LayoutOrientation.portrait,
      accentColor: Color(0xFF7BDFF2),
      previewType: _LayoutPreviewType.portrait3,
    ),
    _LayoutOption(
      id: 'landscape4',
      title: 'Landscape 4 Take',
      subtitle: 'Layout lebar 4 foto, cocok untuk grup.',
      layoutMode: 'landscapePoster',
      photoCount: 4,
      orientation: _LayoutOrientation.landscape,
      accentColor: Color(0xFFF4B942),
      previewType: _LayoutPreviewType.landscape4,
    ),
    _LayoutOption(
      id: 'landscape6',
      title: 'Landscape 6 Take',
      subtitle: '6 foto dalam grid landscape yang padat.',
      layoutMode: 'landscapePoster',
      photoCount: 6,
      orientation: _LayoutOrientation.landscape,
      accentColor: Color(0xFFFF8A5B),
      previewType: _LayoutPreviewType.landscape6,
    ),
    _LayoutOption(
      id: 'portrait6',
      title: 'Portrait 6 Take',
      subtitle: '6 foto portrait dengan susunan vertikal.',
      layoutMode: 'wantedPoster',
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
    _takeNameController = TextEditingController(text: widget.packageName);
    _selectedLayoutId = widget.initialBackgroundKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
      _loadLayoutsFromApi();
    });
  }

  Future<void> _loadLayoutsFromApi() async {
    if (_isLoadingLayouts) return;
    setState(() => _isLoadingLayouts = true);

    try {
      final api = context.read<ApiController>();
      final templates = await api.fetchTemplatesWithCache();
      if (!mounted) return;

      final remoteLayouts = _dedupeLayouts(templates.map(_layoutFromTemplate).whereType<_LayoutOption>());
      if (remoteLayouts.isNotEmpty) {
        setState(() {
          _layouts = remoteLayouts;
          if (!_layouts.any((layout) => layout.id == _selectedLayoutId)) {
            _selectedLayoutId = _layouts.first.id;
          }
          _remoteTemplateCount = remoteLayouts.length;
        });
        _showTransientMessage('Layout dimuat dari API dan cache');
      } else {
        setState(() {
          _layouts = _defaultLayouts;
        });
        _showTransientMessage('Layout fallback dipakai dari storage lokal');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _layouts = _defaultLayouts;
      });
      _showTransientMessage('Offline: layout diambil dari cache/fallback');
    } finally {
      if (mounted) {
        setState(() => _isLoadingLayouts = false);
      }
    }
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

  Future<void> _syncRemoteData() async {
    if (_isSyncingData) return;
    setState(() => _isSyncingData = true);

    try {
      final api = context.read<ApiController>();
      final previousLayouts = List<_LayoutOption>.from(_layouts);
      final templates = await api.fetchTemplatesWithCache();
      final remoteLayouts = _dedupeLayouts(templates.map(_layoutFromTemplate).whereType<_LayoutOption>());
      if (!mounted) return;

      final nextLayouts = remoteLayouts.isNotEmpty ? remoteLayouts : _defaultLayouts;
      final previousIds = previousLayouts.map((layout) => layout.id).toSet();
      final nextIds = remoteLayouts.map((layout) => layout.id).toSet();
      final addedCount = nextIds.difference(previousIds).length;
      final removedCount = previousIds.difference(nextIds).length;

      setState(() {
        _layouts = nextLayouts;
        if (!_layouts.any((layout) => layout.id == _selectedLayoutId)) {
          _selectedLayoutId = _layouts.first.id;
        }
        _remoteTemplateCount = remoteLayouts.length;
      });
      _showTransientMessage(
        remoteLayouts.isNotEmpty
            ? 'Sync layout selesai: +$addedCount / -$removedCount template disesuaikan dari server'
            : 'Sync layout selesai: server kosong, layout default dipakai',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lastSyncMessage!)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync layout gagal: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncingData = false);
      }
    }
  }

  void _toggleUtilityMenu() {
    setState(() => _showUtilityMenu = !_showUtilityMenu);
  }

  void _showTransientMessage(String message) {
    _lastSyncMessageTimer?.cancel();
    if (!mounted) return;
    setState(() => _lastSyncMessage = message);
    _lastSyncMessageTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _lastSyncMessage = null);
    });
  }

  _LayoutOption get _selectedLayout =>
      _layouts.firstWhere((layout) => layout.id == _selectedLayoutId, orElse: () => _layouts.first);

  String get _takeNameValue {
    final value = _takeNameController.text.trim();
    return value.isEmpty ? widget.packageName.trim() : value;
  }

  String _takeFolderPreview() {
    final safeName = _sanitizeTakeName(_takeNameValue);
    final dateStamp = _buildDateStamp(DateTime.now());
    return safeName.isEmpty ? 'Take_${dateStamp}take' : '${safeName}_${dateStamp}take';
  }

  String _sanitizeTakeName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), ' ');
    final collapsed = normalized.replaceAll(RegExp(r'\s+'), '_');
    return collapsed.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _buildDateStamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  List<_LayoutOption> _dedupeLayouts(Iterable<_LayoutOption> layouts) {
    final seen = <String>{};
    final uniqueLayouts = <_LayoutOption>[];

    for (final layout in layouts) {
      // Beberapa template bisa punya ID berbeda tetapi isinya sama persis.
      // Pakai signature visual supaya kartu yang sama tidak muncul dua kali.
      final visualKey = [
        layout.title.trim().toLowerCase(),
        layout.photoCount,
        layout.orientation.name,
        layout.layoutMode.trim().toLowerCase(),
        layout.accentColor.toARGB32(),
      ].join('|');
      if (!seen.add(visualKey)) {
        continue;
      }
      uniqueLayouts.add(layout);
    }

    return uniqueLayouts;
  }

  _LayoutOption? _layoutFromTemplate(RemoteTemplateRecord template) {
    final rawData = template.raw['data'];
    final Map<String, dynamic> data = switch (rawData) {
      String value when value.trim().isNotEmpty => _decodeTemplateData(value),
      Map value => value.cast<String, dynamic>(),
      _ => const <String, dynamic>{},
    };

    final layoutId = (data['layoutId'] ?? template.id ?? template.name).toString().trim();
    final photoCount =
        template.photoCount ?? _readPhotoCount(data['photoCount']) ?? _readPhotoCount(data['shots']) ?? widget.photoCount;
    final orientation = _parseLayoutMode(
      template.layoutMode ?? data['layoutMode']?.toString() ?? data['orientation']?.toString(),
    );
    final accentColor =
        _parseColor(data['accentColor']?.toString()) ?? _fallbackAccentColor(layoutId, orientation, photoCount);
    final previewType = _previewTypeFor(photoCount, orientation);

    return _LayoutOption(
      id: layoutId.isNotEmpty ? layoutId : template.name,
      title: template.name,
      layoutMode: _layoutModeForTemplate(
        template.layoutMode ?? data['layoutMode']?.toString() ?? data['orientation']?.toString(),
        orientation,
        photoCount,
      ),
      templateData: template.raw,
      subtitle: data['description']?.toString().trim().isNotEmpty == true
          ? data['description'].toString()
          : '$photoCount foto, ${orientation.label} layout',
      photoCount: photoCount,
      orientation: orientation,
      accentColor: accentColor,
      previewType: previewType,
    );
  }

  Map<String, dynamic> _decodeTemplateData(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  int? _readPhotoCount(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  _LayoutOrientation _parseLayoutMode(String? value) {
    final normalized = value?.toLowerCase().trim();
    if (normalized == null || normalized.isEmpty) {
      return _LayoutOrientation.portrait;
    }

    if (normalized.contains('landscape')) {
      return _LayoutOrientation.landscape;
    }
    if (normalized.contains('portrait')) {
      return _LayoutOrientation.portrait;
    }

    return _LayoutOrientation.portrait;
  }

  String _layoutModeForTemplate(String? value, _LayoutOrientation orientation, int photoCount) {
    final normalized = value?.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

    switch (normalized) {
      case 'grid':
        return 'grid';
      case 'verticalstrip':
        return 'verticalStrip';
      case 'horizontalstrip':
        return 'horizontalStrip';
      case 'polaroid':
        return 'polaroid';
      case 'wanted':
      case 'wantedposter':
        return 'wantedPoster';
      case 'landscape':
      case 'landscapeposter':
        return 'landscapePoster';
    }

    if (orientation == _LayoutOrientation.landscape) {
      return 'landscapePoster';
    }

    if (photoCount >= 4) {
      return 'wantedPoster';
    }

    return 'wantedPoster';
  }

  Color? _parseColor(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    var normalized = value.trim().replaceFirst('#', '');
    if (normalized.length == 6) {
      normalized = 'FF$normalized';
    }
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  Color _fallbackAccentColor(String layoutId, _LayoutOrientation orientation, int photoCount) {
    return switch ((layoutId, orientation, photoCount)) {
      (_, _LayoutOrientation.landscape, 4) => const Color(0xFFF4B942),
      (_, _LayoutOrientation.landscape, 6) => const Color(0xFFFF8A5B),
      (_, _LayoutOrientation.portrait, 1) => const Color(0xFFFFC857),
      (_, _LayoutOrientation.portrait, 2) => const Color(0xFF7AE582),
      (_, _LayoutOrientation.portrait, 3) => const Color(0xFF7BDFF2),
      (_, _LayoutOrientation.portrait, 6) => const Color(0xFFE58AF7),
      _ => const Color(0xFFFFC857),
    };
  }

  _LayoutPreviewType _previewTypeFor(int photoCount, _LayoutOrientation orientation) {
    if (orientation == _LayoutOrientation.landscape) {
      return photoCount >= 6 ? _LayoutPreviewType.landscape6 : _LayoutPreviewType.landscape4;
    }

    return switch (photoCount) {
      1 => _LayoutPreviewType.portrait1,
      2 => _LayoutPreviewType.portrait2,
      3 => _LayoutPreviewType.portrait3,
      6 => _LayoutPreviewType.portrait6,
      _ => _LayoutPreviewType.portrait3,
    };
  }

  Future<void> _startCameraSession() async {
    // Setelah layout dipilih, user diarahkan ke home page untuk mulai capture.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          packageName: _takeNameValue,
          photoCount: _selectedLayout.photoCount,
          initialBackgroundKey: _selectedLayout.layoutMode,
          layoutTemplateData: _selectedLayout.templateData,
        ),
      ),
    );
  }

  void _selectLayout(_LayoutOption layout) {
    setState(() => _selectedLayoutId = layout.id);
  }

  @override
  void dispose() {
    _lastSyncMessageTimer?.cancel();
    _takeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Layout chooser dibuat visual agar cepat dibandingkan antar template.
    final selectedLayout = _selectedLayout;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
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
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1120;
                  final hero = _buildHero(context, selectedLayout);
                  final chooser = _buildChooser(context);

                  return isWide
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
                        );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: FloatingActionButton.extended(
                        onPressed: _toggleUtilityMenu,
                        icon: Icon(_showUtilityMenu ? Icons.close : Icons.menu),
                        label: Text(_showUtilityMenu ? 'Close Menu' : 'Menu'),
                      ),
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
                                          onPressed: _isSyncingData ? null : _syncRemoteData,
                                          icon: _isSyncingData
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.sync),
                                          label: Text(_isSyncingData ? 'Syncing...' : 'Sync Data'),
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
                    if (_lastSyncMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 240),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_lastSyncMessage\nRemote templates: $_remoteTemplateCount',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nama take',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white60,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _takeNameController,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Family Party',
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFFFC857), width: 1.4),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Folder hasil: ${_takeFolderPreview()}',
                      style: const TextStyle(color: Colors.white70, height: 1.3),
                    ),
                  ],
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
                  if (_isLoadingLayouts) ...[
                    const LinearProgressIndicator(minHeight: 2),
                    const SizedBox(height: 12),
                  ],
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
    required this.layoutMode,
    this.templateData,
    required this.photoCount,
    required this.orientation,
    required this.accentColor,
    required this.previewType,
  });

  final String id;
  final String title;
  final String subtitle;
  final String layoutMode;
  final Map<String, dynamic>? templateData;
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
