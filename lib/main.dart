import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/app_providers.dart';
import 'core/theme/app_theme.dart';
import 'pages/landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

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
    await windowManager.setFullScreen(true);
  });

  runApp(const PapyrusPhotoboothApp());
}

class PapyrusPhotoboothApp extends StatelessWidget {
  const PapyrusPhotoboothApp({super.key});

  @override
  Widget build(BuildContext context) {
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
