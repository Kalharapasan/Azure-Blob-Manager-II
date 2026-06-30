import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/storage_provider.dart';
import '../models/blob_item.dart';
import '../utils/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class FilesScreen extends StatefulWidget {
  final BlobCategory? category;
  const FilesScreen({super.key, this.category});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageProvider>().setCategory(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();
    final blobs = provider.blobs;
    final isSecret = provider.currentVault == VaultMode.secret;
    final isSelectionMode = provider.isSelectionMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => provider.clearSelection())
            : null,
        title: Text(isSelectionMode ? '${provider.selectedBlobNames.length} selected' : (provider.selectedCategory?.name.toUpperCase() ?? 'ALL FILES')),
        actions: [
          if (!isSelectionMode) ...[
            _buildSortButton(provider),
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          ],
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.error),
              onPressed: () => _showBulkDeleteConfirm(context, provider),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(context),
          Expanded(
            child: provider.loadState == LoadState.loading
                ? const Center(child: CircularProgressIndicator())
                : blobs.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => provider.loadBlobs(),
                        child: _isGridView
                            ? _buildGridView(context, blobs, provider)
                            : _buildListView(context, blobs, provider),
                      ),
          ),
        ],
      ),
      floatingActionButton: isSelectionMode 
          ? FloatingActionButton.extended(
              onPressed: () => _showBulkDeleteConfirm(context, provider),
              backgroundColor: AppTheme.error,
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Delete Selected'),
            ).animate().scale()
          : null,
    );
  }

  Widget _buildSortButton(StorageProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      onSelected: (val) => provider.setSort(val),
      itemBuilder: (context) => [
        _sortItem('date', 'Date', provider),
        _sortItem('name', 'Name', provider),
        _sortItem('size', 'Size', provider),
      ],
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label, StorageProvider provider) {
    final isSelected = provider.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          if (isSelected) const Spacer(),
          if (isSelected) Icon(provider.sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => context.read<StorageProvider>().setSearch(value),
        decoration: InputDecoration(
          hintText: 'Search in this vault...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<StorageProvider>().setSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.surface.withOpacity(0.5),
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildGridView(BuildContext context, List<BlobItem> blobs, StorageProvider provider) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 0.82,
      ),
      itemCount: blobs.length,
      itemBuilder: (context, index) => _fileCard(context, blobs[index], index, provider),
    );
  }

  Widget _buildListView(BuildContext context, List<BlobItem> blobs, StorageProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: blobs.length,
      itemBuilder: (context, index) => _fileListItem(context, blobs[index], index, provider),
    );
  }

  Widget _fileCard(BuildContext context, BlobItem blob, int index, StorageProvider provider) {
    final isSelected = provider.selectedBlobNames.contains(blob.name);
    
    return InkWell(
      onTap: () => provider.isSelectionMode ? provider.toggleSelection(blob.name) : _showPreview(context, blob),
      onLongPress: () => provider.toggleSelection(blob.name),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border.withOpacity(0.5), width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: blob.categoryColor.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Center(
                      child: Icon(blob.icon, color: blob.categoryColor, size: 48),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blob.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(blob.formattedSize, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          if (!provider.isSelectionMode) _buildMiniActions(context, blob, provider),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 12, right: 12,
                child: Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 24),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
  }

  Widget _fileListItem(BuildContext context, BlobItem blob, int index, StorageProvider provider) {
    final isSelected = provider.selectedBlobNames.contains(blob.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border.withOpacity(0.5), width: isSelected ? 2 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: blob.categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(blob.icon, color: blob.categoryColor),
        ),
        title: Text(blob.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${blob.formattedSize} • ${DateFormat('MMM d').format(blob.lastModified)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        trailing: isSelected 
            ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent)
            : (!provider.isSelectionMode ? _buildMiniActions(context, blob, provider) : null),
        onTap: () => provider.isSelectionMode ? provider.toggleSelection(blob.name) : _showPreview(context, blob),
        onLongPress: () => provider.toggleSelection(blob.name),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
  }

  Widget _buildMiniActions(BuildContext context, BlobItem blob, StorageProvider provider) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: AppTheme.textMuted, size: 20),
      color: AppTheme.surfaceLight,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (val) => _handleAction(context, val, blob, provider),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'view', child: _ActionRow(Icons.visibility_rounded, 'View')),
        PopupMenuItem(
          value: 'vault', 
          child: _ActionRow(
            blob.isPrivate ? Icons.cloud_off_rounded : Icons.security_rounded, 
            blob.isPrivate ? 'Move to Public' : 'Move to Vault',
            color: AppTheme.privateColor,
          ),
        ),
        const PopupMenuItem(value: 'rename', child: _ActionRow(Icons.edit_rounded, 'Rename')),
        const PopupMenuItem(value: 'delete', child: _ActionRow(Icons.delete_outline_rounded, 'Delete', color: AppTheme.error)),
      ],
    );
  }

  void _handleAction(BuildContext context, String action, BlobItem blob, StorageProvider provider) async {
    switch (action) {
      case 'view': _showPreview(context, blob); break;
      case 'rename': _showRenameDialog(context, blob, provider); break;
      case 'delete': _showDeleteConfirm(context, blob, provider); break;
      case 'vault': 
        await provider.moveBlobToVault(blob, !blob.isPrivate);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Moved ${blob.displayName} to ${!blob.isPrivate ? "Vault" : "Public"}')));
        break;
    }
  }

  void _showPreview(BuildContext context, BlobItem blob) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: blob.categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
              child: Icon(blob.icon, color: blob.categoryColor, size: 48),
            ),
            const SizedBox(height: 24),
            Text(blob.displayName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('${blob.categoryName} • ${blob.formattedSize}', style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 40),
            _infoBox('Last Modified', DateFormat('MMMM d, yyyy • HH:mm').format(blob.lastModified)),
            const SizedBox(height: 12),
            _infoBox('Status', blob.isPrivate ? 'PRIVATE (VAULT)' : 'PUBLIC CLOUD', color: blob.isPrivate ? AppTheme.privateColor : AppTheme.success),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final url = Uri.parse(blob.url);
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                    child: const Text('Open File'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border.withOpacity(0.5))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, BlobItem blob, StorageProvider provider) {
    final controller = TextEditingController(text: blob.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await provider.renameBlob(blob, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, BlobItem blob, StorageProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('This will permanently remove ${blob.displayName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await provider.deleteBlob(blob);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteConfirm(BuildContext context, StorageProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items?'),
        content: Text('Are you sure you want to delete ${provider.selectedBlobNames.length} items permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              await provider.deleteSelected();
              Navigator.pop(context);
            },
            child: const Text('Bulk Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, color: AppTheme.textMuted, size: 80),
          const SizedBox(height: 24),
          const Text('No items here', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your vault is currently empty', style: TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _ActionRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
