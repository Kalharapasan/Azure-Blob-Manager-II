import 'blob_item.dart';

class StorageStats {
  final int totalFiles;
  final int totalSize;
  final int videoCount;
  final int imageCount;
  final int musicCount;
  final int documentCount;
  final int otherCount;
  final int privateCount;
  final List<BlobItem> blobs;

  StorageStats({
    required this.totalFiles,
    required this.totalSize,
    required this.videoCount,
    required this.imageCount,
    required this.musicCount,
    required this.documentCount,
    required this.otherCount,
    required this.privateCount,
    required this.blobs,
  });

  String get formattedTotalSize {
    if (totalSize < 1024) return '${totalSize}B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    if (totalSize < 1024 * 1024 * 1024) return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  double videoPercent  => totalFiles == 0 ? 0 : videoCount / totalFiles;
  double imagePercent  => totalFiles == 0 ? 0 : imageCount / totalFiles;
  double musicPercent  => totalFiles == 0 ? 0 : musicCount / totalFiles;
  double documentPercent => totalFiles == 0 ? 0 : documentCount / totalFiles;
  double otherPercent  => totalFiles == 0 ? 0 : otherCount / totalFiles;

  Map<String, int> get categoryCounts => {
    'Videos': videoCount,
    'Images': imageCount,
    'Music': musicCount,
    'Documents': documentCount,
    'Other': otherCount,
  };
}
