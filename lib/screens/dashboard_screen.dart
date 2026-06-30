import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/storage_provider.dart';
import '../models/blob_item.dart';
import '../models/storage_stats.dart';
import '../utils/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();
    final stats = provider.currentStats;
    final isSecret = provider.currentVault == VaultMode.secret;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: provider.loadState == LoadState.loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : provider.loadState == LoadState.error
              ? _buildError(context, provider)
              : RefreshIndicator(
                  onRefresh: () => provider.loadBlobs(),
                  backgroundColor: AppTheme.surface,
                  color: isSecret ? AppTheme.privateColor : AppTheme.accent,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      _buildHeader(context, provider),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildStorageCard(context, stats, isSecret),
                            const SizedBox(height: 32),
                            _buildSectionHeader('File Categories'),
                            const SizedBox(height: 16),
                            _buildCategoriesGrid(context, stats),
                            const SizedBox(height: 32),
                            _buildSectionHeader('Recent Activities'),
                            const SizedBox(height: 16),
                            _buildRecentFiles(context, provider),
                            const SizedBox(height: 120),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }

  Widget _buildError(BuildContext context, StorageProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 64),
          const SizedBox(height: 24),
          const Text('Storage connection lost', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(provider.errorMessage, style: const TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 32),
          ElevatedButton(onPressed: () => provider.loadBlobs(), child: const Text('Reconnect')),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StorageProvider provider) {
    final isSecret = provider.currentVault == VaultMode.secret;
    return SliverAppBar(
      expandedHeight: 140,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 20),
        centerTitle: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSecret ? 'Private Vault' : 'Public Cloud',
              style: TextStyle(
                color: isSecret ? AppTheme.privateColor : AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              'Dashboard',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => provider.loadBlobs(),
          icon: const Icon(Icons.sync_rounded),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildStorageCard(BuildContext context, StorageStats stats, bool isSecret) {
    final activeColor = isSecret ? AppTheme.privateColor : AppTheme.accent;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppTheme.glassBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Data Analysis', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(isSecret ? 'ENCRYPTED' : 'SECURE', style: TextStyle(color: activeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              SizedBox(
                height: 180,
                width: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 6,
                    centerSpaceRadius: 55,
                    sections: [
                      _pieSection(stats.videoCount, AppTheme.videoColor),
                      _pieSection(stats.imageCount, AppTheme.imageColor),
                      _pieSection(stats.musicCount, AppTheme.musicColor),
                      _pieSection(stats.documentCount, AppTheme.documentColor),
                      _pieSection(stats.otherCount, AppTheme.otherColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    _legendItem('Videos', stats.videoCount, AppTheme.videoColor),
                    _legendItem('Images', stats.imageCount, AppTheme.imageColor),
                    _legendItem('Music', stats.musicCount, AppTheme.musicColor),
                    _legendItem('Docs', stats.documentCount, AppTheme.documentColor),
                    _legendItem('Others', stats.otherCount, AppTheme.otherColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 24),
          Row(
            children: [
              _statItem('Storage Used', stats.formattedTotalSize, activeColor),
              const Spacer(),
              _statItem('Total Items', '${stats.totalFiles}', AppTheme.textPrimary),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  PieChartSectionData _pieSection(int count, Color color) {
    return PieChartSectionData(
      value: count == 0 ? 0.01 : count.toDouble(),
      color: color,
      title: '',
      radius: 14,
      badgeWidget: null,
    );
  }

  Widget _legendItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Text('$count', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ],
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, StorageStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _categoryCard(context, BlobCategory.video, 'Videos', stats.videoCount, Icons.play_circle_filled_rounded, AppTheme.videoColor),
        _categoryCard(context, BlobCategory.image, 'Images', stats.imageCount, Icons.image_rounded, AppTheme.imageColor),
        _categoryCard(context, BlobCategory.music, 'Music', stats.musicCount, Icons.audiotrack_rounded, AppTheme.musicColor),
        _categoryCard(context, BlobCategory.document, 'Documents', stats.documentCount, Icons.description_rounded, AppTheme.documentColor),
      ],
    );
  }

  Widget _categoryCard(BuildContext context, BlobCategory category, String label, int count, IconData icon, Color color) {
    return InkWell(
      onTap: () => context.read<StorageProvider>().setCategory(category),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('$count items', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildRecentFiles(BuildContext context, StorageProvider provider) {
    final recentBlobs = provider.blobs.toList();
    recentBlobs.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    final displayFiles = recentBlobs.take(5).toList();

    if (displayFiles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: AppTheme.glassBox(opacity: 0.2),
        child: const Center(child: Text('No recent files available', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    return Column(
      children: displayFiles.asMap().entries.map((entry) => _recentItem(context, entry.value, entry.key)).toList(),
    );
  }

  Widget _recentItem(BuildContext context, BlobItem blob, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: blob.categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(blob.icon, color: blob.categoryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blob.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${blob.categoryName} • ${blob.formattedSize}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: 0.05);
  }
}
