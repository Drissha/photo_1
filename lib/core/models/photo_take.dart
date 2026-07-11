class PhotoTake {
  const PhotoTake({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.photoCount,
  });

  final String path;
  final String name;
  final DateTime createdAt;
  final int photoCount;
}
