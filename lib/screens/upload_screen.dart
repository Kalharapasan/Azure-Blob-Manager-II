import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mime/mime.dart';
import '../providers/storage_provider.dart';
import '../utils/app_theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedFile;
  String? _fileName;
  String? _contentType;
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StorageProvider>();
    _isPrivate = provider.currentVault == VaultMode.secret;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _contentType = lookupMimeType(_selectedFile!.path) ?? 'application/octet-stream';
      });
    }
  }

  void _handleUpload() async {
    if (_selectedFile == null) return;

    final provider = context.read<StorageProvider>();
    final success = await provider.uploadFile(
      file: _selectedFile!,
      fileName: _fileName!,
      contentType: _contentType!,
      isPrivate: _isPrivate,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${_isPrivate ? "to vault" : "successfully"}!'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _selectedFile = null;
          _fileName = null;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${provider.errorMessage}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('UPLOAD')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPickerArea(),
            const SizedBox(height: 32),
            if (_selectedFile != null) ...[
              _buildFileInfo(),
              const SizedBox(height: 24),
              _buildUploadOptions(),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: provider.isUploading ? null : _handleUpload,
                icon: provider.isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(provider.isUploading ? 'Uploading...' : 'Upload File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isPrivate ? AppTheme.privateColor : AppTheme.accent,
                ),
              ),
            ],
            if (provider.isUploading) ...[
              const SizedBox(height: 24),
              _buildProgressIndicator(provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPickerArea() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border, width: 2, style: BorderStyle.solid), // Should be dashed if possible but solid is fine
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.add_to_photos_rounded, color: AppTheme.accent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Tap to select a file', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Images, Videos, Music, Documents', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ).animate().fadeIn().scale(begin: const Offset(0.98, 0.98)),
    );
  }

  Widget _buildFileInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fileName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_contentType ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.error, size: 20),
            onPressed: () => setState(() => _selectedFile = null),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0);
  }

  Widget _buildUploadOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Options', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _isPrivate,
            onChanged: (val) => setState(() => _isPrivate = val),
            title: const Text('Private Upload'),
            subtitle: const Text('Hide this file in your secure vault'),
            secondary: Icon(Icons.lock_rounded, color: _isPrivate ? AppTheme.privateColor : AppTheme.textMuted),
            activeColor: AppTheme.privateColor,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(StorageProvider provider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Uploading...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            Text('${(provider.uploadProgress * 100).toInt()}%', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: provider.uploadProgress,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(_isPrivate ? AppTheme.privateColor : AppTheme.accent),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
