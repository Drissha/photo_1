import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/captured_photo.dart';
import '../core/services/app_providers.dart';
import '../core/services/storage_service.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<CapturedPhoto> _photos = const [];
  String _query = '';
  String? _loadedFolderPath;
  late AppSettingsNotifier _settingsNotifier;

  @override
  void initState() {
    super.initState();
    _settingsNotifier = context.read<AppSettingsNotifier>();
    _settingsNotifier.addListener(_handleSettingsChanged);
    _loadPhotos(force: true);
  }

  @override
  void dispose() {
    _settingsNotifier.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  void _handleSettingsChanged() {
    _loadPhotos(force: true);
  }

  Future<void> _loadPhotos({bool force = false}) async {
    final folderPath = _settingsNotifier.settings.saveFolderPath;
    if (!force && _loadedFolderPath == folderPath && _photos.isNotEmpty) {
      return;
    }

    final photos = await context.read<StorageService>().listPhotos(folderPath);
    if (!mounted) return;
    setState(() {
      _loadedFolderPath = folderPath;
      _photos = photos;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredPhotos = _photos
        .where((photo) => photo.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'Search photos'),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _loadPhotos(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filteredPhotos.isEmpty
                ? const Center(
                    child: Text('Belum ada foto di folder galeri.'),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredPhotos.length,
                    itemBuilder: (context, index) {
                      final photo = filteredPhotos[index];
                      return Card(
                        child: Column(
                          children: [
                            Expanded(
                              child: Image.file(
                                File(photo.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            ListTile(
                              title: Text(photo.name),
                              subtitle: Text('${photo.sizeBytes} bytes'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
