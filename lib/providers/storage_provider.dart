import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../models/blob_item.dart';
import '../models/storage_stats.dart';
import '../services/azure_storage_service.dart';
import '../services/database_service.dart';

enum LoadState { idle, loading, success, error }
enum VaultMode { public, secret }

class StorageProvider extends ChangeNotifier {
  final _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  List<BlobItem> _allBlobs = [];
  List<BlobItem> _filteredBlobs = [];
  StorageStats? _stats;
  LoadState _loadState = LoadState.idle;
  String _errorMessage = '';
  String _searchQuery = '';
  BlobCategory? _selectedCategory;
  
  bool _isVaultUnlocked = false;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadingFileName = '';
  
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String _downloadingFileName = '';
  
  String? _vaultPassword;
  String? _accountName;
  VaultMode _currentVault = VaultMode.public;
  
  // Advanced State
  final Set<String> _selectedBlobNames = {};
  bool _isSelectionMode = false;
  String _sortBy = 'date'; // 'name', 'size', 'date'
  bool _sortAscending = false;
  bool _biometricEnabled = false;

  StorageProvider() {
    _initSettings();
  }

  Future<void> _initSettings() async {
    _vaultPassword = await DatabaseService.getSetting('vault_password');
    _accountName = await DatabaseService.getSetting('account_name');
    if (_accountName != null && _accountName!.isNotEmpty) {
      AzureStorageService.setAccountName(_accountName!);
    }
    notifyListeners();
  }

  // Getters
  List<BlobItem> get blobs => _filteredBlobs;
  List<BlobItem> get allBlobs => _allBlobs;
  StorageStats? get stats => _stats;
  LoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  BlobCategory? get selectedCategory => _selectedCategory;
  bool get isVaultUnlocked => _isVaultUnlocked;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String get uploadingFileName => _uploadingFileName;
  
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadingFileName => _downloadingFileName;

  bool get hasVaultPassword => _vaultPassword != null && _vaultPassword!.isNotEmpty;
  String? get accountName => _accountName;
  VaultMode get currentVault => _currentVault;
  
  // Advanced Getters
  Set<String> get selectedBlobNames => _selectedBlobNames;
  bool get isSelectionMode => _isSelectionMode;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  bool get biometricEnabled => _biometricEnabled;

  /// Load all blobs from Azure
  Future<void> loadBlobs() async {
    _loadState = LoadState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _allBlobs = await AzureStorageService.listBlobs();
      _stats = await AzureStorageService.getStorageStats();
      _applyFilters();
      _loadState = LoadState.success;
    } catch (e) {
      _errorMessage = e.toString();
      _loadState = LoadState.error;
    }
    notifyListeners();
  }

  /// Filter blobs by category and search
  void _applyFilters() {
    List<BlobItem> filtered = _allBlobs.where((b) {
      if (_currentVault == VaultMode.secret) {
        return b.isPrivate;
      } else {
        return !b.isPrivate;
      }
    }).toList();

    // Filter by category
    if (_selectedCategory != null) {
      filtered = filtered.where((b) => b.category == _selectedCategory).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((b) => b.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Sorting
    filtered.sort((a, b) {
      int cmp;
      if (_sortBy == 'name') {
        cmp = a.displayName.compareTo(b.displayName);
      } else if (_sortBy == 'size') {
        cmp = a.contentLength.compareTo(b.contentLength);
      } else {
        cmp = a.lastModified.compareTo(b.lastModified);
      }
      return _sortAscending ? cmp : -cmp;
    });

    _filteredBlobs = filtered;
  }

  void setCategory(BlobCategory? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setSort(String criteria) {
    if (_sortBy == criteria) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = criteria;
      _sortAscending = false;
    }
    _applyFilters();
    notifyListeners();
  }

  /// Unlock private vault with password
  Future<bool> unlockVault(String password) async {
    if (_vaultPassword == null) return false;
    
    final hashedInput = sha256.convert(utf8.encode(password)).toString();
    final hashedStored = sha256.convert(utf8.encode(_vaultPassword!)).toString();

    if (hashedInput == hashedStored || password == _vaultPassword) {
      _isVaultUnlocked = true;
      _currentVault = VaultMode.secret; // Automatically switch to secret on unlock
      _applyFilters();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> unlockWithBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final didAuth = await _auth.authenticate(
        localizedReason: 'Please authenticate to open your vault',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (didAuth) {
        _isVaultUnlocked = true;
        _currentVault = VaultMode.secret;
        _applyFilters();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
    }
    return false;
  }

  Future<void> setVaultPassword(String password) async {
    await DatabaseService.saveSetting('vault_password', password);
    _vaultPassword = password;
    notifyListeners();
  }

  Future<void> setAccountName(String name) async {
    await DatabaseService.saveSetting('account_name', name);
    _accountName = name;
    AzureStorageService.setAccountName(name);
    notifyListeners();
  }

  void lockVault() {
    _isVaultUnlocked = false;
    _currentVault = VaultMode.public;
    _applyFilters();
    notifyListeners();
  }

  void setVaultMode(VaultMode mode) {
    if (mode == VaultMode.secret && !_isVaultUnlocked) {
      return; // Cannot switch to secret without unlocking
    }
    _currentVault = mode;
    _applyFilters();
    notifyListeners();
  }

  /// Upload a file
  Future<bool> uploadFile({
    required File file,
    required String fileName,
    required String contentType,
    bool isPrivate = false,
  }) async {
    _isUploading = true;
    _uploadProgress = 0;
    _uploadingFileName = fileName;
    notifyListeners();

    try {
      // Simulate progress
      for (double p = 0; p <= 0.8; p += 0.1) {
        await Future.delayed(const Duration(milliseconds: 100));
        _uploadProgress = p;
        notifyListeners();
      }

      await AzureStorageService.uploadBlob(
        blobName: fileName,
        file: file,
        contentType: contentType,
        isPrivate: isPrivate,
      );

      _uploadProgress = 1.0;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      await loadBlobs(); // Refresh list
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isUploading = false;
      _uploadProgress = 0;
      notifyListeners();
    }
  }

  /// Delete a blob
  Future<bool> deleteBlob(BlobItem blob) async {
    try {
      await AzureStorageService.deleteBlob(blob.name);
      _allBlobs.removeWhere((b) => b.name == blob.name);
      _applyFilters();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Rename a blob
  Future<bool> renameBlob(BlobItem blob, String newName) async {
    try {
      final dir = blob.name.contains('/') 
          ? blob.name.substring(0, blob.name.lastIndexOf('/') + 1)
          : '';
      final newFullName = '$dir$newName';
      await AzureStorageService.renameBlob(blob.name, newFullName);
      await loadBlobs();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Move blob between vaults
  Future<bool> moveBlobToVault(BlobItem blob, bool toPrivate) async {
    try {
      String newName;
      if (toPrivate) {
        newName = 'private/${blob.displayName}';
      } else {
        newName = blob.displayName;
      }
      
      await AzureStorageService.renameBlob(blob.name, newName);
      await loadBlobs();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Selection Logic
  void toggleSelection(String blobName) {
    if (_selectedBlobNames.contains(blobName)) {
      _selectedBlobNames.remove(blobName);
    } else {
      _selectedBlobNames.add(blobName);
    }
    _isSelectionMode = _selectedBlobNames.isNotEmpty;
    notifyListeners();
  }

  void clearSelection() {
    _selectedBlobNames.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    final toDelete = _allBlobs.where((b) => _selectedBlobNames.contains(b.name)).toList();
    for (final blob in toDelete) {
      await deleteBlob(blob);
    }
    clearSelection();
  }

  String getBlobUrl(String blobName) => AzureStorageService.getBlobUrl(blobName);

  // Stats for current vault
  StorageStats get currentStats {
    final filtered = _allBlobs.where((b) => _currentVault == VaultMode.secret ? b.isPrivate : !b.isPrivate).toList();
    return _calculateStats(filtered);
  }

  StorageStats _calculateStats(List<BlobItem> blobs) {
    int totalSize = 0;
    int videoCount = 0;
    int imageCount = 0;
    int musicCount = 0;
    int documentCount = 0;
    int otherCount = 0;

    for (final blob in blobs) {
      totalSize += blob.contentLength;
      switch (blob.category) {
        case BlobCategory.video: videoCount++; break;
        case BlobCategory.image: imageCount++; break;
        case BlobCategory.music: musicCount++; break;
        case BlobCategory.document: documentCount++; break;
        case BlobCategory.other: otherCount++; break;
      }
    }

    return StorageStats(
      totalFiles: blobs.length,
      totalSize: totalSize,
      videoCount: videoCount,
      imageCount: imageCount,
      musicCount: musicCount,
      documentCount: documentCount,
      otherCount: otherCount,
      privateCount: blobs.where((b) => b.isPrivate).length,
      blobs: blobs,
    );
  }

  Future<String?> downloadFile(BlobItem blob) async {
    _isDownloading = true;
    _downloadProgress = 0;
    _downloadingFileName = blob.displayName;
    notifyListeners();

    try {
      final bytes = await AzureStorageService.downloadBlob(
        blob.name,
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );

      Directory? dir;
      if (Platform.isAndroid) {
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {
          // fallback
        }
      }
      dir ??= await getApplicationDocumentsDirectory();

      final filePath = '${dir.path}/${blob.displayName}';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      _downloadProgress = 1.0;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 200));
      return filePath;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0;
      _downloadingFileName = '';
      notifyListeners();
    }
  }

  Future<List<String>> downloadSelected() async {
    final toDownload = _allBlobs.where((b) => _selectedBlobNames.contains(b.name)).toList();
    final List<String> paths = [];
    for (final blob in toDownload) {
      final path = await downloadFile(blob);
      if (path != null) {
        paths.add(path);
      }
    }
    clearSelection();
    return paths;
  }
}
