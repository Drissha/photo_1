class CapturedPhoto {
  // Metadata file hasil capture yang dipakai untuk gallery dan viewer.
  const CapturedPhoto({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
}
