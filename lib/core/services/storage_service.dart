import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/captured_photo.dart';
import '../models/photo_take.dart';

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
}
