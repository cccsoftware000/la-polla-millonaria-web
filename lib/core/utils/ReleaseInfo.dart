class ReleaseInfo {
  final String version;
  final String apkUrl;
  final int apkSize;
  final String releaseNotes;
  final String publishDate;
  final bool isRequired;

  ReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.apkSize,
    required this.releaseNotes,
    required this.publishDate,
    this.isRequired = false,
  });

  String get formattedSize {
    if (apkSize > 1024 * 1024) {
      return '${(apkSize / 1024 / 1024).toStringAsFixed(2)} MB';
    }
    return '${(apkSize / 1024).toStringAsFixed(0)} KB';
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(publishDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha no disponible';
    }
  }
}