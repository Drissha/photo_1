import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  late final Logger _logger;
  Directory? _logDirectory;

  Future<void> initialize() async {
    final appDir = await getApplicationSupportDirectory();
    _logDirectory = Directory('${appDir.path}/logs');
    if (!_logDirectory!.existsSync()) {
      _logDirectory!.createSync(recursive: true);
    }

    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 120,
      ),
      output: FileOutput(file: File('${_logDirectory!.path}/${DateTime.now().toIso8601String().split(':').join('-')}.log')),
    );
  }

  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [Object? error]) => _logger.e(message, error: error);
  void debug(String message) => _logger.d(message);
}

class FileOutput extends LogOutput {
  FileOutput({required this.file});

  final File file;

  @override
  void output(OutputEvent event) {
    final sink = file.openWrite(mode: FileMode.append);
    for (final line in event.lines) {
      sink.writeln(line);
    }
    sink.close();
  }
}
