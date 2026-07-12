import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/captured_photo.dart';
import '../core/models/photo_take.dart';
import '../core/services/app_providers.dart';
import '../core/services/storage_service.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<PhotoTake> _takes = const [];
  String _query = '';
  String? _loadedFolderPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTakes(force: true);
    });
  }

  Future<void> _loadTakes({bool force = false}) async {
    final settings = context.read<AppSettingsNotifier>().settings;
    final folderPath = settings.saveFolderPath;
    if (!force && _loadedFolderPath == folderPath && _takes.isNotEmpty) {
      return;
    }

    final takes = await context.read<StorageService>().listTakeFolders(folderPath);
    if (!mounted) return;
    setState(() {
      _loadedFolderPath = folderPath;
      _takes = takes;
    });
  }

  Future<void> _openTake(PhotoTake take) async {
    final photos = await context.read<StorageService>().listPhotos(take.path);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        take.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text('${photos.length} foto'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: photos.isEmpty
                      ? const Center(child: Text('Folder ini belum berisi foto.'))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: photos.length,
                          itemBuilder: (context, index) {
                            final photo = photos[index];
                            return InkWell(
                              onTap: () => _showPhotoViewer(photo),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Image.file(
                                        File(photo.path),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                    ListTile(
                                      dense: true,
                                      title: Text(
                                        photo.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text('${photo.sizeBytes} bytes'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPhotoViewer(CapturedPhoto photo) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.file(
                  File(photo.path),
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTakes = _takes
        .where((take) => take.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(40),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Search takes'),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _loadTakes(force: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredTakes.isEmpty
                    ? const Center(
                        child: Text('Belum ada sesi foto di folder galeri.'),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredTakes.length,
                        itemBuilder: (context, index) {
                          final take = filteredTakes[index];
                          return InkWell(
                            onTap: () => _openTake(take),
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Center(
                                        child: Icon(Icons.photo_library_outlined, size: 56),
                                      ),
                                    ),
                                  ),
                                  ListTile(
                                    title: Text(take.name, overflow: TextOverflow.ellipsis),
                                    subtitle: Text('${take.photoCount} foto'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
