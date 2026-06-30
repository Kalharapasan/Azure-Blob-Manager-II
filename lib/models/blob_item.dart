import 'package:flutter/material.dart';

enum BlobCategory { video, image, music, document, other }

class BlobItem {
  final String name;
  final String contentType;
  final int contentLength;
  final DateTime lastModified;
  final String etag;
  final String url;

  BlobItem({
    required this.name,
    required this.contentType,
    required this.contentLength,
    required this.lastModified,
    required this.etag,
    required this.url,
  });

  String get displayName {
    final parts = name.split('/');
    return parts.last;
  }

  String get extension {
    final parts = displayName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  bool get isPrivate => name.startsWith('private/');

  BlobCategory get category {
    // Check content type first
    if (contentType.startsWith('video/') ||
        ['mp4', 'avi', 'mov', 'mkv', 'webm', 'flv', 'wmv', 'm4v'].contains(extension)) {
      return BlobCategory.video;
    }
    if (contentType.startsWith('image/') ||
        ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'tiff', 'ico'].contains(extension)) {
      return BlobCategory.image;
    }
    if (contentType.startsWith('audio/') ||
        ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'aiff'].contains(extension)) {
      return BlobCategory.music;
    }
    if (contentType.contains('pdf') ||
        contentType.contains('document') ||
        contentType.contains('text/') ||
        contentType.contains('spreadsheet') ||
        contentType.contains('presentation') ||
        ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', 'odt'].contains(extension)) {
      return BlobCategory.document;
    }
    return BlobCategory.other;
  }

  String get formattedSize {
    if (contentLength < 1024) return '${contentLength}B';
    if (contentLength < 1024 * 1024) return '${(contentLength / 1024).toStringAsFixed(1)}KB';
    if (contentLength < 1024 * 1024 * 1024) return '${(contentLength / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(contentLength / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  IconData get icon {
    switch (category) {
      case BlobCategory.video:
        return Icons.video_library_rounded;
      case BlobCategory.image:
        return Icons.image_rounded;
      case BlobCategory.music:
        return Icons.music_note_rounded;
      case BlobCategory.document:
        return Icons.description_rounded;
      case BlobCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get categoryColor {
    switch (category) {
      case BlobCategory.video:
        return const Color(0xFFFF6B6B);
      case BlobCategory.image:
        return const Color(0xFF4ECDC4);
      case BlobCategory.music:
        return const Color(0xFFFFBE0B);
      case BlobCategory.document:
        return const Color(0xFF74B9FF);
      case BlobCategory.other:
        return const Color(0xFFA29BFE);
    }
  }

  String get categoryName {
    switch (category) {
      case BlobCategory.video:
        return 'Video';
      case BlobCategory.image:
        return 'Image';
      case BlobCategory.music:
        return 'Music';
      case BlobCategory.document:
        return 'Document';
      case BlobCategory.other:
        return 'Other';
    }
  }

  BlobItem copyWith({
    String? name,
    String? contentType,
    int? contentLength,
    DateTime? lastModified,
    String? etag,
    String? url,
  }) {
    return BlobItem(
      name: name ?? this.name,
      contentType: contentType ?? this.contentType,
      contentLength: contentLength ?? this.contentLength,
      lastModified: lastModified ?? this.lastModified,
      etag: etag ?? this.etag,
      url: url ?? this.url,
    );
  }

  @override
  String toString() => 'BlobItem(name: $name, size: $formattedSize, category: $categoryName)';
}
