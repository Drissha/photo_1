import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'pages/landing_page.dart';

Future<void> main() async {
  // Inisialisasi binding dan window manager sebelum UI pertama dirender.
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Konfigurasi ukuran awal agar aplikasi langsung masuk ke kanvas kerja yang nyaman.
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const PapyrusPhotoboothApp());
}

class PapyrusPhotoboothApp extends StatelessWidget {
  const PapyrusPhotoboothApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Semua service penting disuntikkan dari sini supaya page tetap tipis.
    return MultiProvider(
      providers: AppProviders.providers,
      child: Consumer<AppSettingsNotifier>(
        builder: (context, settingsNotifier, _) {
          final settings = settingsNotifier.settings;
          return MaterialApp(
            title: 'Papyrus Photobooth',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: const LandingPage(),
          );
        },
      ),
    );
  }
}
