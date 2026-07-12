import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'home_page.dart';

class QrisPaymentPage extends StatefulWidget {
  const QrisPaymentPage({
    super.key,
    required this.packageName,
    required this.photoCount,
    required this.initialLayoutKey,
    required this.basePrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.voucherCode,
  });

  final String packageName;
  final int photoCount;
  final String initialLayoutKey;
  final int basePrice;
  final int discountAmount;
  final int finalPrice;
  final String? voucherCode;

  @override
  State<QrisPaymentPage> createState() => _QrisPaymentPageState();
}

class _QrisPaymentPageState extends State<QrisPaymentPage> {
  bool _paymentConfirmed = false;
  bool _isFullscreen = false;
  bool _isCompleting = false;
  int _autoPaySecondsLeft = 8;
  Timer? _autoPayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFullscreenState();
      _startAutoPaymentCountdown();
    });
  }

  @override
  void dispose() {
    _autoPayTimer?.cancel();
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

  Future<void> _exitApp() async {
    await windowManager.close();
  }

  void _startAutoPaymentCountdown() {
    _autoPayTimer?.cancel();
    _autoPaySecondsLeft = 8;
    _autoPayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isCompleting) {
        timer.cancel();
        return;
      }

      if (_autoPaySecondsLeft <= 1) {
        timer.cancel();
        _autoCompletePayment();
        return;
      }

      setState(() => _autoPaySecondsLeft -= 1);
    });
  }

  Future<void> _autoCompletePayment() async {
    if (_isCompleting || !mounted) return;
    _isCompleting = true;
    _autoPayTimer?.cancel();
    setState(() => _paymentConfirmed = true);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(
          packageName: widget.packageName,
          photoCount: widget.photoCount,
          initialLayoutKey: widget.initialLayoutKey,
        ),
      ),
    );
  }

  Future<void> _confirmPayment() async {
    if (_isCompleting) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi pembayaran'),
          content: Text(
            'Tandai pembayaran paket ${widget.packageName} sebesar ${_formatCurrency(widget.finalPrice)} sebagai selesai?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ya, lanjut'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) return;
    await _autoCompletePayment();
  }

  Future<void> _devBypassPayment() async {
    if (!kDebugMode) return;
    await _autoCompletePayment();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0F1C),
              Color(0xFF131C30),
              Color(0xFF06080F),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 920;
                          final summary = _buildSummaryCard(context);
                          final qris = _buildQrisCard(context);

                          return isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 10, child: summary),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 9, child: qris),
                                  ],
                                )
                              : ListView(
                                  children: [
                                    summary,
                                    const SizedBox(height: 20),
                                    qris,
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _toggleFullscreen,
                        icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                        label: Text(_isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _exitApp,
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Exit App'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Column(
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
              'QRIS CHECKOUT',
              style: TextStyle(
                color: Color(0xFFFFD77A),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Scan QR di halaman ini untuk melanjutkan.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Voucher ${widget.voucherCode ?? '-'} sudah diterapkan. Setelah pembayaran berhasil, user akan masuk ke halaman kamera.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),
          _SummaryRow(label: 'Paket', value: widget.packageName),
          _SummaryRow(label: 'Jumlah foto', value: '${widget.photoCount} foto'),
          _SummaryRow(label: 'Harga paket', value: _formatCurrency(widget.basePrice)),
          _SummaryRow(
            label: 'Diskon voucher',
            value: widget.discountAmount == 0 ? '-' : '- ${_formatCurrency(widget.discountAmount)}',
          ),
          const Divider(color: Colors.white24, height: 28),
          _SummaryRow(
            label: 'Total bayar',
            value: _formatCurrency(widget.finalPrice),
            valueStyle: const TextStyle(
              color: Color(0xFFFFD77A),
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrisCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: Colors.white.withOpacity(0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2, size: 28, color: Colors.black87),
              const SizedBox(width: 10),
              Text(
                'QRIS Payment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _QrisCodePreview(
                seed: '${widget.packageName}|${widget.voucherCode ?? 'NO-VOUCHER'}|${widget.finalPrice}',
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Scan QR di atas dengan aplikasi e-wallet atau mobile banking yang mendukung QRIS.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Text(
            'Pembayaran akan auto-finish dalam beberapa detik. Developer bisa bypass untuk testing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _paymentConfirmed ? null : _confirmPayment,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_paymentConfirmed ? 'Sudah Dibayar' : 'Saya Sudah Bayar'),
              ),
              if (kDebugMode)
                OutlinedButton.icon(
                  onPressed: _devBypassPayment,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Dev Bypass'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Auto lanjut dalam $_autoPaySecondsLeft detik',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _QrisCodePreview extends StatelessWidget {
  const _QrisCodePreview({
    required this.seed,
  });

  final String seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(260, 260),
      painter: _QrisCodePainter(seed),
    );
  }
}

class _QrisCodePainter extends CustomPainter {
  _QrisCodePainter(this.seed);

  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Offset.zero & size, paint);

    final grid = 29;
    final cellSize = size.width / grid;
    final ink = Paint()..color = const Color(0xFF111111);
    final hash = seed.hashCode & 0x7fffffff;

    bool isFinderCell(int x, int y, int startX, int startY) {
      return x >= startX && x < startX + 7 && y >= startY && y < startY + 7;
    }

    bool inFinderPattern(int x, int y) {
      return isFinderCell(x, y, 0, 0) ||
          isFinderCell(x, y, grid - 7, 0) ||
          isFinderCell(x, y, 0, grid - 7);
    }

    for (var y = 0; y < grid; y++) {
      for (var x = 0; x < grid; x++) {
        final shouldDraw = inFinderPattern(x, y)
            ? (x == 0 || y == 0 || x == grid - 1 || y == grid - 1 || (x >= 2 && x <= 4 && y >= 2 && y <= 4))
            : (((hash + x * 31 + y * 17) % 7) < 3);

        if (!shouldDraw) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
          ink,
        );
      }
    }

    final cutout = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.4, size.height * 0.4, size.width * 0.2, size.height * 0.2),
        const Radius.circular(8),
      ),
      cutout,
    );
  }

  @override
  bool shouldRepaint(covariant _QrisCodePainter oldDelegate) => oldDelegate.seed != seed;
}
