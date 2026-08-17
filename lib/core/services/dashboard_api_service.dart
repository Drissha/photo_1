import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'storage_service.dart';

class RemoteTemplateRecord {
  const RemoteTemplateRecord({
    required this.raw,
    required this.id,
    required this.name,
    required this.photoCount,
    required this.layoutMode,
  });

  final Map<String, dynamic> raw;
  final String? id;
  final String name;
  final int? photoCount;
  final String? layoutMode;
}

class RemoteBackgroundRecord {
  const RemoteBackgroundRecord({
    required this.raw,
    required this.id,
    required this.name,
    required this.url,
  });

  final Map<String, dynamic> raw;
  final String? id;
  final String name;
  final Uri? url;
}

class RemotePhotoRecord {
  const RemotePhotoRecord({
    required this.raw,
    required this.id,
    required this.albumId,
    required this.filename,
    required this.originalUrl,
    required this.mediumUrl,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.album,
  });

  final Map<String, dynamic> raw;
  final String? id;
  final String? albumId;
  final String? filename;
  final String? originalUrl;
  final String? mediumUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final DateTime? createdAt;
  final Map<String, dynamic>? album;
}

class SyncSummary {
  const SyncSummary({
    required this.templatesFetched,
    required this.backgroundsDownloaded,
    required this.backgroundsDeleted,
    required this.uploadsUploaded,
    required this.uploadsQueued,
    required this.albumName,
  });

  final int templatesFetched;
  final int backgroundsDownloaded;
  final int backgroundsDeleted;
  final int uploadsUploaded;
  final int uploadsQueued;
  final String? albumName;

  String get message {
    final parts = <String>[];
    parts.add('template: $templatesFetched');
    parts.add('background: $backgroundsDownloaded');
    if (backgroundsDeleted > 0) {
      parts.add('hapus background: $backgroundsDeleted');
    }
    parts.add('upload: $uploadsUploaded');
    if (uploadsQueued > 0) {
      parts.add('antrian: $uploadsQueued');
    }
    if (albumName != null && albumName!.trim().isNotEmpty) {
      parts.add('album: $albumName');
    }
    return parts.join(' | ');
  }
}

class BackgroundSyncSummary {
  const BackgroundSyncSummary({
    required this.downloaded,
    required this.deleted,
  });

  final int downloaded;
  final int deleted;

  String get message {
    return 'downloaded: $downloaded | deleted: $deleted';
  }
}

class ApiController {
  ApiController({StorageService? storageService, http.Client? httpClient})
      : _storageService = storageService ?? StorageService(),
        _httpClient = httpClient ?? http.Client();

  final StorageService _storageService;
  final http.Client _httpClient;

  static final Uri _baseUri = Uri.parse('http://localhost:3000/api/');
  static const String _queueFileName = 'pending_uploads.json';
  static const String _layoutCacheFileName = 'layouts.json';

  Future<Map<String, dynamic>> getJson(String path) async {
    return _getJson(path);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    return _postJson(path, body);
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) async {
    return _putJson(path, body);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    return _deleteJson(path);
  }

  Future<List<RemoteTemplateRecord>> fetchTemplates() async {
    final json = await getJson('templates');
    final data = _readListPayload(json);
    return data
        .map(
          (item) => RemoteTemplateRecord(
            raw: item,
            id: item['id']?.toString(),
            name: item['name']?.toString().trim().isNotEmpty == true
                ? item['name'].toString()
                : item['layoutId']?.toString().trim().isNotEmpty == true
                    ? item['layoutId'].toString()
                    : 'Template',
            photoCount: _readPhotoCount(item['photoCount']) ??
                _readPhotoCount(item['data'] is Map ? (item['data'] as Map)['photoCount'] : null) ??
                _readPhotoCount(item['data'] is Map ? (item['data'] as Map)['shots'] : null),
            layoutMode: _readLayoutMode(item['layoutMode']) ??
                _readLayoutMode(item['data'] is Map ? (item['data'] as Map)['layoutMode'] : null),
          ),
        )
        .toList();
  }

  Future<List<RemoteTemplateRecord>> fetchTemplatesWithCache() async {
    try {
      final templates = await fetchTemplates();
      await cacheTemplates(templates);
      return templates;
    } catch (_) {
      return loadCachedTemplates();
    }
  }

  Future<List<RemoteTemplateRecord>> loadCachedTemplates() async {
    final file = await _layoutCacheFile();
    if (!file.existsSync()) {
      return const [];
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      final items = decoded is List ? decoded : const [];
      return items
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .map(
            (item) => RemoteTemplateRecord(
              raw: item,
              id: item['id']?.toString(),
              name: item['name']?.toString().trim().isNotEmpty == true
                  ? item['name'].toString()
                  : item['layoutId']?.toString().trim().isNotEmpty == true
                      ? item['layoutId'].toString()
                      : 'Template',
              photoCount: _readPhotoCount(item['photoCount']) ??
                  _readPhotoCount(item['data'] is Map ? (item['data'] as Map)['photoCount'] : null) ??
                  _readPhotoCount(item['data'] is Map ? (item['data'] as Map)['shots'] : null),
              layoutMode: _readLayoutMode(item['layoutMode']) ??
                  _readLayoutMode(item['data'] is Map ? (item['data'] as Map)['layoutMode'] : null),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> cacheTemplates(List<RemoteTemplateRecord> templates) async {
    final file = await _layoutCacheFile();
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    final payload = templates.map((template) => template.raw).toList();
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<Map<String, dynamic>> createTemplate({
    required String name,
    required Map<String, dynamic> data,
  }) async {
    final payload = await postJson(
      'templates',
      {
        'name': name,
        'data': data,
      },
    );
    return _readObjectPayload(payload);
  }

  Future<List<RemoteBackgroundRecord>> fetchBackgrounds() async {
    final json = await getJson('backgrounds');
    final data = _readListPayload(json);
    return data
        .map(
          (item) => RemoteBackgroundRecord(
            raw: item,
            id: item['id']?.toString(),
            name: item['name']?.toString().trim().isNotEmpty == true
                ? item['name'].toString()
                : item['filename']?.toString().trim().isNotEmpty == true
                    ? item['filename'].toString()
                    : 'Background',
            url: _resolveRemoteUri(item['url']?.toString() ?? item['path']?.toString()),
          ),
        )
        .where((record) => record.url != null)
        .toList();
  }

  Future<BackgroundSyncSummary> syncBackgrounds() async {
    final cacheFolder = await _storageService.getApiBackgroundCacheFolder();
    final backgrounds = await fetchBackgrounds();
    final remoteFiles = <String>{};
    var downloaded = 0;

    for (final background in backgrounds) {
      final url = background.url;
      if (url == null) {
        continue;
      }

      final safeName = _sanitizeFileName(
        background.raw['filename']?.toString().trim().isNotEmpty == true
            ? background.raw['filename'].toString()
            : '${background.id ?? background.name}.png',
      );
      remoteFiles.add(safeName.toLowerCase());
      final targetPath = p.join(cacheFolder, safeName);
      final targetFile = File(targetPath);
      try {
        final bytes = await _getBytes(url);
        await targetFile.writeAsBytes(bytes, flush: true);
        downloaded += 1;
      } catch (_) {
        // Jika satu file gagal, lanjutkan file lain supaya sync tetap berguna.
      }
    }

    var deleted = 0;
    final cacheDir = Directory(cacheFolder);
    if (cacheDir.existsSync()) {
      final supportedExtensions = ['.jpg', '.jpeg', '.png'];
      for (final entity in cacheDir.listSync()) {
        if (entity is! File) {
          continue;
        }
        if (!supportedExtensions.contains(p.extension(entity.path).toLowerCase())) {
          continue;
        }

        final fileName = p.basename(entity.path).toLowerCase();
        if (remoteFiles.contains(fileName)) {
          continue;
        }

        try {
          await entity.delete();
          deleted += 1;
        } catch (_) {
          // Kalau ada file lokal yang gagal dihapus, sync tetap lanjut.
        }
      }
    }

    return BackgroundSyncSummary(downloaded: downloaded, deleted: deleted);
  }

  Future<String?> ensureAlbumId({
    required String albumName,
  }) async {
    final normalizedName = albumName.trim();
    final albums = await getJson('albums');
    final list = _readListPayload(albums);
    for (final album in list) {
      final name = album['name']?.toString().trim();
      if (name != null && name.toLowerCase() == normalizedName.toLowerCase()) {
        return album['id']?.toString();
      }
    }

    final created = await postJson(
      'albums',
      {'name': normalizedName},
    );
    final payload = _readObjectPayload(created);
    return payload['id']?.toString();
  }

  Future<RemotePhotoRecord> uploadPhoto({
    required File file,
    required String albumId,
  }) async {
    final uri = _resolveUri('photos');
    final request = http.MultipartRequest('POST', uri)
      ..fields['albumId'] = albumId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final decoded = _decodeResponseBody(response.body);
    print('Upload response: ${response.statusCode} - ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw HttpException(
        decoded['error']?.toString() ?? 'Upload foto gagal.',
        uri: uri,
      );
    }

    return _readPhotoObjectPayload(decoded);
  }

  Future<List<RemotePhotoRecord>> uploadPhotos({
    required List<File> files,
    required String albumId,
  }) async {
    final uploaded = <RemotePhotoRecord>[];
    for (final file in files) {
      if (!file.existsSync()) {
        continue;
      }
      uploaded.add(await uploadPhoto(file: file, albumId: albumId));
    }
    return uploaded;
  }

  Future<SyncSummary> syncAll({
    required String albumName,
  }) async {
    var templatesFetched = 0;
    var backgroundsDownloaded = 0;
    var backgroundsDeleted = 0;
    var uploadsUploaded = 0;
    String? resolvedAlbumName;

    try {
      templatesFetched = (await fetchTemplates()).length;
    } catch (_) {}

    try {
      final backgroundSyncSummary = await syncBackgrounds();
      backgroundsDownloaded = backgroundSyncSummary.downloaded;
      backgroundsDeleted = backgroundSyncSummary.deleted;
    } catch (_) {}

    try {
      uploadsUploaded = await flushQueuedPhotoUploads(albumName: albumName);
    } catch (_) {}

    try {
      final albumId = await ensureAlbumId(albumName: albumName);
      if (albumId != null && albumId.trim().isNotEmpty) {
        resolvedAlbumName = albumName;
      }
    } catch (_) {}

    return SyncSummary(
      templatesFetched: templatesFetched,
      backgroundsDownloaded: backgroundsDownloaded,
      backgroundsDeleted: backgroundsDeleted,
      uploadsUploaded: uploadsUploaded,
      uploadsQueued: await pendingUploadCount(),
      albumName: resolvedAlbumName,
    );
  }

  Future<Map<String, dynamic>> syncCurrentLayout({
    required String layoutId,
    required String name,
    required int photoCount,
    required String layoutMode,
    required String accentColor,
  }) async {
    final templates = await fetchTemplates();
    final normalizedLayoutId = layoutId.trim();
    final normalizedName = name.trim();
    final existingIndex = templates.indexWhere(
      (template) {
        final templateLayoutId = template.raw['layoutId']?.toString().trim();
        final templateName = template.name.trim();
        return templateLayoutId == normalizedLayoutId || templateName == normalizedName;
      },
    );

    final payload = {
      'layoutId': normalizedLayoutId,
      'photoCount': photoCount,
      'layoutMode': layoutMode,
      'orientation': layoutMode,
      'accentColor': accentColor,
      'source': 'photobooth-layout-selection',
      'syncedAt': DateTime.now().toIso8601String(),
    };

    if (existingIndex >= 0) {
      final existingTemplate = templates[existingIndex];
      if (existingTemplate.id == null || existingTemplate.id!.trim().isEmpty) {
        return createTemplate(
          name: normalizedName,
          data: payload,
        );
      }
      return _putJson(
        'templates/${existingTemplate.id}',
        {
          'name': normalizedName,
          'data': payload,
        },
      );
    }

    return createTemplate(
      name: normalizedName,
      data: payload,
    );
  }

  int? _readPhotoCount(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  String? _readLayoutMode(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text.toLowerCase();
  }

  Future<int> pendingUploadCount() async {
    final queue = await _readQueue();
    return queue.length;
  }

  Future<int> flushQueuedPhotoUploads({
    required String albumName,
  }) async {
    final queue = await _readQueue();
    if (queue.isEmpty) {
      return 0;
    }

    final remaining = <Map<String, dynamic>>[];
    var uploaded = 0;

    for (final item in queue) {
      final filePath = item['filePath']?.toString();
      final file = filePath == null ? null : File(filePath);
      if (file == null || !file.existsSync()) {
        continue;
      }

      final itemAlbumName = item['albumName']?.toString().trim().isNotEmpty == true
          ? item['albumName'].toString()
          : albumName;
      try {
        final albumId = item['albumId']?.toString().trim().isNotEmpty == true
            ? item['albumId'].toString()
            : await ensureAlbumId(albumName: itemAlbumName);
        if (albumId == null || albumId.trim().isEmpty) {
          throw StateError('Album ID tidak tersedia.');
        }
        await uploadPhoto(file: file, albumId: albumId);
        uploaded += 1;
      } catch (_) {
        remaining.add({
          ...item,
          'attempts': (item['attempts'] as int? ?? 0) + 1,
          'lastAttemptAt': DateTime.now().toIso8601String(),
        });
      }
    }

    await _writeQueue(remaining);
    return uploaded;
  }

  Future<void> queuePhotoUpload({
    required String filePath,
    required String albumName,
    String? albumId,
  }) async {
    final queue = await _readQueue();
    final alreadyQueued = queue.any((item) => item['filePath']?.toString() == filePath);
    if (alreadyQueued) {
      return;
    }

    queue.add({
      'filePath': filePath,
      'albumName': albumName,
      'albumId': albumId,
      'createdAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await _writeQueue(queue);
  }

  Future<void> uploadOrQueuePhoto({
    required String filePath,
    required String albumName,
  }) async {
    await uploadOrQueuePhotos(
      filePaths: [filePath],
      albumName: albumName,
    );
  }

  Future<void> uploadOrQueuePhotos({
    required List<String> filePaths,
    required String albumName,
  }) async {
    final files = <File>[];
    final seenPaths = <String>{};
    for (final filePath in filePaths) {
      if (!seenPaths.add(filePath)) {
        continue;
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        continue;
      }
      files.add(file);
    }

    if (files.isEmpty) {
      return;
    }

    try {
      final albumId = await ensureAlbumId(albumName: albumName);
      if (albumId == null || albumId.trim().isEmpty) {
        throw StateError('Album ID tidak tersedia.');
      }

      for (final file in files) {
        try {
          await uploadPhoto(file: file, albumId: albumId);
          await _removeQueuedUpload(file.path);
        } catch (_) {
          await queuePhotoUpload(
            filePath: file.path,
            albumName: albumName,
            albumId: albumId,
          );
        }
      }
    } catch (_) {
      for (final file in files) {
        await queuePhotoUpload(filePath: file.path, albumName: albumName);
      }
    }
  }

  Uri _resolveUri(String path) {
    return _baseUri.resolve(path);
  }

  Uri? _resolveRemoteUri(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim();
    final parsed = Uri.tryParse(normalized);
    if (parsed == null) {
      return null;
    }
    if (parsed.hasScheme) {
      return parsed;
    }
    final relativePath = normalized
        .replaceFirst(RegExp(r'^/api/'), '')
        .replaceFirst(RegExp(r'^api/'), '')
        .replaceFirst(RegExp(r'^/'), '');
    return _resolveUri(relativePath);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final uri = _resolveUri(path);
    final response = await _httpClient.get(uri);
    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw HttpException(
        decoded['error']?.toString() ?? 'Request gagal.',
        uri: uri,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final uri = _resolveUri(path);
    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw HttpException(
        decoded['error']?.toString() ?? 'Request gagal.',
        uri: uri,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _putJson(String path, Map<String, dynamic> body) async {
    final uri = _resolveUri(path);
    final response = await _httpClient.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw HttpException(
        decoded['error']?.toString() ?? 'Request gagal.',
        uri: uri,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final uri = _resolveUri(path);
    final response = await _httpClient.delete(uri);
    final decoded = _decodeResponseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw HttpException(
        decoded['error']?.toString() ?? 'Request gagal.',
        uri: uri,
      );
    }
    return decoded;
  }

  Future<List<int>> _getBytes(Uri uri) async {
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Gagal mengunduh file.', uri: uri);
    }
    return response.bodyBytes;
  }

  Map<String, dynamic> _decodeResponseBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return <String, dynamic>{'data': decoded};
    }
    return <String, dynamic>{'data': decoded};
  }

  List<Map<String, dynamic>> _readListPayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
    }
    if (response['success'] == true && response.isNotEmpty) {
      return [response];
    }
    return const [];
  }

  Map<String, dynamic> _readObjectPayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return response;
  }

  RemotePhotoRecord _readPhotoObjectPayload(Map<String, dynamic> response) {
    final data = response['data'];
    final item = data is Map<String, dynamic>
        ? data
        : data is Map
            ? data.cast<String, dynamic>()
            : response;

    return RemotePhotoRecord(
      raw: item,
      id: item['id']?.toString(),
      albumId: item['albumId']?.toString(),
      filename: item['filename']?.toString(),
      originalUrl: item['originalUrl']?.toString(),
      mediumUrl: item['mediumUrl']?.toString(),
      thumbnailUrl: item['thumbnailUrl']?.toString(),
      width: int.tryParse(item['width']?.toString() ?? ''),
      height: int.tryParse(item['height']?.toString() ?? ''),
      createdAt: DateTime.tryParse(item['createdAt']?.toString() ?? ''),
      album: item['album'] is Map ? (item['album'] as Map).cast<String, dynamic>() : null,
    );
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final file = await _queueFile();
    if (!file.existsSync()) {
      return [];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return decoded.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
      }
    } catch (_) {
      // Jika file queue korup, anggap kosong agar aplikasi tetap bisa jalan.
    }
    return [];
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    final file = await _queueFile();
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(queue), flush: true);
  }

  Future<void> _removeQueuedUpload(String filePath) async {
    final queue = await _readQueue();
    final filtered = queue.where((item) => item['filePath']?.toString() != filePath).toList();
    if (filtered.length == queue.length) {
      return;
    }
    await _writeQueue(filtered);
  }

  Future<File> _queueFile() async {
    final folder = await _storageService.getApiUploadQueueFolder();
    return File(p.join(folder, _queueFileName));
  }

  Future<File> _layoutCacheFile() async {
    final folder = await _storageService.getApiLayoutCacheFolder();
    return File(p.join(folder, _layoutCacheFileName));
  }
}

typedef DashboardApiService = ApiController;
