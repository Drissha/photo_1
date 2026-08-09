class CameraDevice {
  // Representasi satu perangkat kamera yang ditemukan dari DigiCamControl.
  const CameraDevice({
    required this.id,
    required this.name,
    required this.lensDirection,
  });

  final String id;
  final String name;
  final String lensDirection;

  String get displayName {
    // Nama ditampilkan tanpa detail tambahan agar dropdown tetap bersih.
    final trimmed = name.trim();
    final baseName = trimmed.contains('(') ? trimmed.split('(').first.trim() : trimmed;
    return baseName.isEmpty ? trimmed : baseName;
  }
}
