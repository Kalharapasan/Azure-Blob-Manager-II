import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/blob_item.dart';
import '../models/storage_stats.dart';

class AzureStorageService {
  static String _dynamicAccountName = '';

  static String get accountName => _dynamicAccountName.isNotEmpty 
      ? _dynamicAccountName 
      : (dotenv.env['AZURE_STORAGE_ACCOUNT_NAME'] ?? '');
      
  static void setAccountName(String name) {
    _dynamicAccountName = name;
  }

  static String get containerName => dotenv.env['AZURE_STORAGE_CONTAINER_NAME'] ?? '';
  static String get sasKey => dotenv.env['AZURE_SAS_KEY'] ?? '';

  static String get baseUrl =>
      'https://$accountName.blob.core.windows.net/$containerName';

  static Map<String, String> get _headers => {
        'x-ms-version': '2022-11-02',
        'x-ms-date': _formatDate(),
      };

  static String _formatDate() {
    return HttpDate.format(DateTime.now().toUtc());
  }

  /// List all blobs in container
  static Future<List<BlobItem>> listBlobs({String? prefix}) async {
    try {
      String url = '$baseUrl?restype=container&comp=list&$sasKey';
      if (prefix != null && prefix.isNotEmpty) {
        url += '&prefix=$prefix';
      }
      // Clean up URL formatting
      url = url.replaceAll('??', '?').replaceAll('?&', '?').replaceAll('&&', '&').replaceAll('?sv=', '&sv=').replaceFirst('&sv=', '?sv=');

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return _parseBlobs(response.body);
      } else {
        throw AzureException('Failed to list blobs: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw AzureException('List blobs error: $e');
    }
  }

  /// Parse XML response into BlobItem list
  static List<BlobItem> _parseBlobs(String xmlBody) {
    final document = XmlDocument.parse(xmlBody);
    final blobs = document.findAllElements('Blob');
    return blobs.map((blob) {
      final name = blob.findElements('Name').first.innerText;
      final properties = blob.findElements('Properties').first;
      final contentType = properties.findElements('Content-Type').isNotEmpty
          ? properties.findElements('Content-Type').first.innerText
          : 'application/octet-stream';
      final contentLength = properties.findElements('Content-Length').isNotEmpty
          ? int.tryParse(properties.findElements('Content-Length').first.innerText) ?? 0
          : 0;
      final lastModified = properties.findElements('Last-Modified').isNotEmpty
          ? properties.findElements('Last-Modified').first.innerText
          : '';
      final etag = properties.findElements('Etag').isNotEmpty
          ? properties.findElements('Etag').first.innerText
          : '';

      return BlobItem(
        name: name,
        contentType: contentType,
        contentLength: contentLength,
        lastModified: lastModified.isNotEmpty
            ? HttpDate.parse(lastModified)
            : DateTime.now(),
        etag: etag,
        url: '$baseUrl/$name',
      );
    }).toList();
  }

  /// Upload a file to Azure Blob Storage
  static Future<void> uploadBlob({
    required String blobName,
    required File file,
    required String contentType,
    bool isPrivate = false,
    Function(double)? onProgress,
  }) async {
    try {
      final prefix = isPrivate ? 'private/' : '';
      final fullName = '$prefix$blobName';
      String url = '$baseUrl/$fullName?$sasKey';
      url = url.replaceAll('??', '?');
      final bytes = await file.readAsBytes();

      final request = http.Request('PUT', Uri.parse(url));
      request.headers.addAll({
        ..._headers,
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
        'x-ms-blob-type': 'BlockBlob',
        if (isPrivate) 'x-ms-meta-private': 'true',
      });
      request.bodyBytes = bytes;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        throw AzureException('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw AzureException('Upload error: $e');
    }
  }

  /// Upload from bytes (for web or in-memory data)
  static Future<void> uploadBlobBytes({
    required String blobName,
    required Uint8List bytes,
    required String contentType,
    bool isPrivate = false,
  }) async {
    try {
      final prefix = isPrivate ? 'private/' : '';
      final fullName = '$prefix$blobName';
      String url = '$baseUrl/$fullName?$sasKey';
      url = url.replaceAll('??', '?');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          ..._headers,
          'Content-Type': contentType,
          'Content-Length': bytes.length.toString(),
          'x-ms-blob-type': 'BlockBlob',
          if (isPrivate) 'x-ms-meta-private': 'true',
        },
        body: bytes,
      );

      if (response.statusCode != 201) {
        throw AzureException('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw AzureException('Upload error: $e');
    }
  }

  /// Delete a blob
  static Future<void> deleteBlob(String blobName) async {
    try {
      final url = '$baseUrl/$blobName?$sasKey'.replaceAll('??', '?');
      final response = await http.delete(Uri.parse(url), headers: _headers);

      if (response.statusCode != 202) {
        throw AzureException('Delete failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw AzureException('Delete error: $e');
    }
  }

  /// Get blob content as bytes
  static Future<Uint8List> downloadBlob(String blobName) async {
    try {
      final url = '$baseUrl/$blobName?$sasKey'.replaceAll('??', '?');
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw AzureException('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      throw AzureException('Download error: $e');
    }
  }

  /// Rename/copy a blob (copy then delete)
  static Future<void> renameBlob(String oldName, String newName) async {
    try {
      final copyUrl = '$baseUrl/$newName?$sasKey'.replaceAll('??', '?');
      final sourceUrl = '$baseUrl/$oldName';

      final response = await http.put(
        Uri.parse(copyUrl),
        headers: {
          ..._headers,
          'x-ms-copy-source': sourceUrl,
        },
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        await deleteBlob(oldName);
      } else {
        throw AzureException('Rename failed: ${response.statusCode}');
      }
    } catch (e) {
      throw AzureException('Rename error: $e');
    }
  }

  /// Get storage statistics
  static Future<StorageStats> getStorageStats() async {
    try {
      final blobs = await listBlobs();
      int totalSize = 0;
      int videoCount = 0;
      int imageCount = 0;
      int musicCount = 0;
      int documentCount = 0;
      int otherCount = 0;
      int privateCount = 0;

      for (final blob in blobs) {
        totalSize += blob.contentLength;
        switch (blob.category) {
          case BlobCategory.video:
            videoCount++;
            break;
          case BlobCategory.image:
            imageCount++;
            break;
          case BlobCategory.music:
            musicCount++;
            break;
          case BlobCategory.document:
            documentCount++;
            break;
          case BlobCategory.other:
            otherCount++;
            break;
        }
        if (blob.isPrivate) privateCount++;
      }

      return StorageStats(
        totalFiles: blobs.length,
        totalSize: totalSize,
        videoCount: videoCount,
        imageCount: imageCount,
        musicCount: musicCount,
        documentCount: documentCount,
        otherCount: otherCount,
        privateCount: privateCount,
        blobs: blobs,
      );
    } catch (e) {
      throw AzureException('Stats error: $e');
    }
  }

  /// Generate a direct URL with SAS for a blob
  static String getBlobUrl(String blobName) {
    final sas = sasKey.startsWith('?') ? sasKey : '?$sasKey';
    return '$baseUrl/$blobName$sas';
  }
}

class AzureException implements Exception {
  final String message;
  AzureException(this.message);

  @override
  String toString() => 'AzureException: $message';
}
