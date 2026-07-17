import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/captured_photo.dart';
import '../models/photo_take.dart';

enum BackgroundCategory {
  portrait,
  landscape,
}

class BackgroundLibrary {
  const BackgroundLibrary({
    required this.portraitImages,
    required this.landscapeImages,
    required this.folderPath,
  });

  final List<File> portraitImages;
  final List<File> landscapeImages;
  final String folderPath;

  bool get isEmpty => portraitImages.isEmpty && landscapeImages.isEmpty;
}

class StorageService {
  Future<Directory> ensureSaveDirectory(String path) async {
    final directory = Directory(path);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> getDefaultSaveFolder() async {
    final directory = await getApplicationDocumentsDirectory();
    final defaultPath = p.join(directory.path, 'PapyrusPhotos');
    final folder = Directory(defaultPath);
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    return defaultPath;
  }

  Future<String> getDefaultBackgroundFolder() async {
    final directory = await getApplicationDocumentsDirectory();
    final defaultPath = p.join(directory.path, 'PapyrusBackgrounds');
    final folder = Directory(defaultPath);
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
    }
    await Directory(p.join(defaultPath, 'Portrait')).create(recursive: true);
    await Directory(p.join(defaultPath, 'Landscape')).create(recursive: true);
    return defaultPath;
  }

  Future<List<File>> listBackgroundImages(String folderPath) async {
    final categorized = await loadBackgroundLibrary(folderPath);
    return [
      ...categorized.portraitImages,
      ...categorized.landscapeImages,
    ];
  }

  Future<BackgroundLibrary> loadBackgroundLibrary(String folderPath) async {
    final folder = Directory(folderPath);
    if (!folder.existsSync()) {
      return BackgroundLibrary(
        portraitImages: const [],
        landscapeImages: const [],
        folderPath: folderPath,
      );
    }

    final supportedExtensions = ['.jpg', '.jpeg', '.png'];
    final files = folder
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => supportedExtensions.contains(p.extension(file.path).toLowerCase()))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    final portrait = <File>[];
    final landscape = <File>[];
    for (final file in files) {
      final category = await _classifyBackgroundFile(file);
      switch (category) {
        case BackgroundCategory.portrait:
          portrait.add(file);
          break;
        case BackgroundCategory.landscape:
          landscape.add(file);
          break;
      }
    }

    return BackgroundLibrary(
      portraitImages: portrait,
      landscapeImages: landscape,
      folderPath: folderPath,
    );
  }

  Future<String> createTakeFolder(String baseFolder) async {
    final folder = await ensureSaveDirectory(baseFolder);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final takePath = p.join(folder.path, 'Take_$stamp');
    await Directory(takePath).create(recursive: true);
    return takePath;
  }

  Future<String?> pickSaveFolder() async {
    final result = await FilePicker.getDirectoryPath();
    return result;
  }

  Future<List<CapturedPhoto>> listPhotos(String folderPath) async {
    final folder = Directory(folderPath);
    if (!folder.existsSync()) {
      return const [];
    }

    final files = folder
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.jpg'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    return files
        .map(
          (file) => CapturedPhoto(
            path: file.path,
            name: p.basename(file.path),
            createdAt: file.statSync().modified,
            sizeBytes: file.statSync().size,
          ),
        )
        .toList();
  }

  Future<List<PhotoTake>> listTakeFolders(String baseFolder) async {
    final folder = Directory(baseFolder);
    if (!folder.existsSync()) {
      return const [];
    }

    final takes = folder
        .listSync()
        .whereType<Directory>()
        .map((takeFolder) {
          final photoCount = takeFolder
              .listSync()
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.jpg'))
              .length;
          return PhotoTake(
            path: takeFolder.path,
            name: p.basename(takeFolder.path),
            createdAt: takeFolder.statSync().modified,
            photoCount: photoCount,
          );
        })
        .where((take) => take.photoCount > 0)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final rootPhotos = await listPhotos(baseFolder);
    if (rootPhotos.isNotEmpty) {
      takes.add(
        PhotoTake(
          path: baseFolder,
          name: 'Legacy Photos',
          createdAt: rootPhotos.first.createdAt,
          photoCount: rootPhotos.length,
        ),
      );
    }

    return takes;
  }

  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<int> getFreeDiskSpace() async {
    final directory = await getApplicationDocumentsDirectory();
    final stat = await directory.stat();
    return stat.type == FileSystemEntityType.directory ? 1024 * 1024 * 100 : 0;
  }

  Future<BackgroundCategory> _classifyBackgroundFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final isPortrait = image.height >= image.width;
      image.dispose();
      codec.dispose();
      return isPortrait ? BackgroundCategory.portrait : BackgroundCategory.landscape;
    } catch (_) {
      return BackgroundCategory.portrait;
    }
  }
}
