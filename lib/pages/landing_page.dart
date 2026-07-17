import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/camera_manager_service.dart';
import 'diagnostics_page.dart';
import 'gallery_page.dart';
import 'qris_payment_page.dart';
import 'settings_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final TextEditingController _voucherController = TextEditingController();
  final Map<String, double> _voucherDiscounts = const {
    'PROMO10': 0.10,
    'WELCOME20': 0.20,
    'PAPYRUS25': 0.25,
  };

  final List<_PackageOption> _packages = const [
    _PackageOption(
      id: 'wanted1',
      title: 'Wanted 1x Take',
      subtitle: '1 foto tunggal',
      price: 25000,
      durationMinutes: 5,
      photos: 1,
      accentColor: Color(0xFFFFC857),
    ),
    _PackageOption(
      id: 'wanted2',
      title: 'Wanted 2x Take',
      subtitle: '2 foto berpasangan',
      price: 40000,
      durationMinutes: 7,
      photos: 2,
      accentColor: Color(0xFF7AE582),
    ),
    _PackageOption(
      id: 'wanted3',
      title: 'Wanted 3x Take',
      subtitle: '3 foto paling seimbang',
      price: 55000,
      durationMinutes: 10,
      photos: 3,
      accentColor: Color(0xFF7BDFF2),
    ),
    _PackageOption(
      id: 'wanted4',
      title: 'Wanted 4x Take',
      subtitle: '4 foto gaya grid',
      price: 70000,
      durationMinutes: 14,
      photos: 4,
      accentColor: Color(0xFFF4B942),
    ),
    _PackageOption(
      id: 'wanted6',
      title: 'Wanted 6x Take',
      subtitle: '6 foto full session',
      price: 90000,
      durationMinutes: 20,
      photos: 6,
      accentColor: Color(0xFFFF8A5B),
    ),
  ];

  late _PackageOption _selectedPackage;
  String? _appliedVoucher;
  double _voucherDiscount = 0;
  bool _isFullscreen = false;
  bool _showUtilityMenu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
      context.read<CameraManagerService>().refreshDevices();
    });
    _selectedPackage = _packages[2];
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  int get _basePrice => _selectedPackage.price;

  int get _discountAmount => (_basePrice * _voucherDiscount).round();

  int get _finalPrice => (_basePrice - _discountAmount).clamp(0, _basePrice);

  void _applyVoucher() {
    final code = _voucherController.text.trim().toUpperCase();
    final discount = _voucherDiscounts[code];

    setState(() {
      _appliedVoucher = discount == null ? null : code;
      _voucherDiscount = discount ?? 0;
    });
  }

  void _selectPackage(_PackageOption package) {
    setState(() {
      _selectedPackage = package;
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

  Future<void> _openUtilityPage(Widget page) async {
    if (!mounted) return;
    setState(() => _showUtilityMenu = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _toggleUtilityMenu() {
    setState(() => _showUtilityMenu = !_showUtilityMenu);
  }

  Future<void> _goToQrisPayment() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
      builder: (_) => QrisPaymentPage(
          packageName: _selectedPackage.title,
          photoCount: _selectedPackage.photos,
          initialLayoutKey: _selectedPackage.id,
          basePrice: _basePrice,
          discountAmount: _discountAmount,
          finalPrice: _finalPrice,
          voucherCode: _appliedVoucher,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;

              final hero = _buildHero(context);
              final checkout = _buildCheckout(context);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 11, child: hero),
                                    const SizedBox(width: 24),
                                    Expanded(flex: 10, child: checkout),
                                  ],
                                )
                              : ListView(
                                  children: [
                                    hero,
                                    const SizedBox(height: 24),
                                    checkout,
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
                                            key: const ValueKey('utility-panel'),
                                            color: Theme.of(context).colorScheme.surface.withOpacity(0.96),
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
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
                  color: const Color(0xFFFFC857).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFC857).withOpacity(0.35)),
                ),
                child: const Text(
                  'PAPYRUS PHOTBOOTH',
                  style: TextStyle(
                    color: Color(0xFFFFD77A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Pilih Wanted Take, lalu bayar QRIS sebelum masuk ke kamera.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Halaman ini jadi gerbang awal. Pengunjung bisa input voucher, pilih take session, lalu scan QRIS untuk melanjutkan ke sesi foto.',
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
              _StepChip(number: '01', label: 'Masukkan voucher'),
              _StepChip(number: '02', label: 'Pilih take'),
              _StepChip(number: '03', label: 'Bayar QRIS'),
              _StepChip(number: '04', label: 'Masuk kamera'),
            ],
          ),
              const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wanted take terpilih',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white60),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedPackage.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_selectedPackage.durationMinutes} menit, ${_selectedPackage.photos} foto take',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: _selectedPackage.accentColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _selectedPackage.accentColor.withOpacity(0.45)),
                  ),
                  child: Center(
                    child: Text(
                      'Rp${_selectedPackage.price ~/ 1000}K',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedPackage.accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
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

  Widget _buildCheckout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Checkout',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 18),
            _buildVoucherSection(context),
            const SizedBox(height: 18),
            Text(
              'Pilih Wanted Take',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pilih jumlah take yang paling pas untuk layout Wanted.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 10),
            ..._packages.map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageCard(
                  package: package,
                  selected: package.id == _selectedPackage.id,
                  onTap: () => _selectPackage(package),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _goToQrisPayment,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text('Lanjut ke QRIS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherSection(BuildContext context) {
    final hasVoucher = _appliedVoucher != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Voucher',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Masukkan kode voucher',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _applyVoucher,
                child: const Text('Pakai'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasVoucher)
            Text(
              'Voucher $_appliedVoucher aktif. Diskon ${(_voucherDiscount * 100).round()}%.',
              style: const TextStyle(color: Color(0xFF9AF0B0)),
            )
          else
            const Text(
              'Contoh voucher aktif: PROMO10, WELCOME20, PAPYRUS25',
              style: TextStyle(color: Colors.white60),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1222),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ringkasan Take',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Take', value: _selectedPackage.title),
          _SummaryRow(label: 'Harga', value: _formatCurrency(_basePrice)),
          _SummaryRow(
            label: 'Diskon voucher',
            value: _discountAmount == 0 ? '-' : '- ${_formatCurrency(_discountAmount)}',
          ),
          const Divider(color: Colors.white24, height: 28),
          _SummaryRow(
            label: 'Total bayar',
            value: _formatCurrency(_finalPrice),
            valueStyle: const TextStyle(
              color: Color(0xFFFFD77A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    final digits = value.toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }
}

class _PackageOption {
  const _PackageOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.durationMinutes,
    required this.photos,
    required this.accentColor,
  });

  final String id;
  final String title;
  final String subtitle;
  final int price;
  final int durationMinutes;
  final int photos;
  final Color accentColor;
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
  });

  final _PackageOption package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? package.accentColor.withOpacity(0.14) : Colors.black.withOpacity(0.16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? package.accentColor : Colors.white.withOpacity(0.10),
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: package.accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                selected ? Icons.check_circle : Icons.photo_camera_outlined,
                color: package.accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        package.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(width: 8),
                      if (selected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: package.accentColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Dipilih',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    package.subtitle,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rp ${package.price ~/ 1000}K',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${package.durationMinutes} menit',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
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
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
