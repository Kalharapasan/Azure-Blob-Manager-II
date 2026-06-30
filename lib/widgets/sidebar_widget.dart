import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/blob_item.dart';
import '../providers/storage_provider.dart';
import '../utils/app_theme.dart';

class SidebarWidget extends StatelessWidget {
  final int selectedIndex;
  final BlobCategory? selectedCategory;
  final Function(int) onNavSelected;
  final Function(BlobCategory?) onCategorySelected;

  const SidebarWidget({
    super.key,
    required this.selectedIndex,
    required this.selectedCategory,
    required this.onNavSelected,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();
    final isSecret = provider.currentVault == VaultMode.secret;

    return Container(
      width: AppConstants.sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(right: BorderSide(color: AppTheme.border.withOpacity(0.5))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Row(
                children: [
                  _buildLogo(isSecret),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSecret ? 'SECRET' : 'CLOUD',
                        style: TextStyle(
                          color: isSecret ? AppTheme.privateColor : AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'VAULT',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Vault Switcher (Premium Design)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    _vaultSwitchItem(provider, VaultMode.public, 'Public', Icons.cloud_queue_rounded),
                    _vaultSwitchItem(provider, VaultMode.secret, 'Secret', Icons.lock_outline_rounded),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Navigation Groups
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _groupLabel('MENU'),
                  _menuItem(0, Icons.grid_view_rounded, 'Dashboard'),
                  _menuItem(1, Icons.folder_copy_rounded, 'All Objects'),
                  _menuItem(3, Icons.cloud_upload_rounded, 'Transfer'),
                  
                  const SizedBox(height: 32),
                  
                  _groupLabel('CATEGORIES'),
                  _categoryItem(null, Icons.apps_rounded, 'Everything', isSecret ? AppTheme.privateColor : AppTheme.accent),
                  _categoryItem(BlobCategory.video, Icons.play_circle_outline_rounded, 'Videos', AppTheme.videoColor),
                  _categoryItem(BlobCategory.image, Icons.image_outlined, 'Images', AppTheme.imageColor),
                  _categoryItem(BlobCategory.music, Icons.headset_outlined, 'Audio', AppTheme.musicColor),
                  _categoryItem(BlobCategory.document, Icons.description_outlined, 'Documents', AppTheme.documentColor),
                  _categoryItem(BlobCategory.other, Icons.extension_outlined, 'Miscellaneous', AppTheme.otherColor),
                ],
              ),
            ),

            // Bottom Usage Widget
            _bottomUsage(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isSecret) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSecret 
              ? [AppTheme.privateColor, AppTheme.secondary]
              : [AppTheme.accent, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isSecret ? AppTheme.privateColor : AppTheme.accent).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(isSecret ? Icons.shield_rounded : Icons.cloud_rounded, color: Colors.white, size: 24),
    );
  }

  Widget _vaultSwitchItem(StorageProvider provider, VaultMode mode, String label, IconData icon) {
    final isSelected = provider.currentVault == mode;
    final isLocked = mode == VaultMode.secret && !provider.isVaultUnlocked;
    final color = mode == VaultMode.secret ? AppTheme.privateColor : AppTheme.accent;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (mode == VaultMode.secret && !provider.isVaultUnlocked) {
            onNavSelected(2);
          } else {
            provider.setVaultMode(mode);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.background : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isLocked ? Icons.lock_rounded : icon, size: 14, color: isSelected ? color : AppTheme.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 12),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _menuItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index && selectedCategory == null;
    return _sidebarItem(
      isSelected: isSelected,
      icon: icon,
      label: label,
      onTap: () => onNavSelected(index),
    );
  }

  Widget _categoryItem(BlobCategory? category, IconData icon, String label, Color color) {
    final isSelected = selectedIndex == 1 && selectedCategory == category;
    return _sidebarItem(
      isSelected: isSelected,
      icon: icon,
      label: label,
      activeColor: color,
      onTap: () => onCategorySelected(category),
      isCategory: true,
    );
  }

  Widget _sidebarItem({
    required bool isSelected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? activeColor,
    bool isCategory = false,
  }) {
    final color = activeColor ?? AppTheme.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? color : AppTheme.textSecondary, size: 20),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomUsage(StorageProvider provider) {
    final stats = provider.currentStats;
    final isSecret = provider.currentVault == VaultMode.secret;
    final color = isSecret ? AppTheme.privateColor : AppTheme.accent;
    final percent = (stats.totalSize / (5 * 1024 * 1024 * 1024)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        border: Border(top: BorderSide(color: AppTheme.border.withOpacity(0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isSecret ? 'SECURE SPACE' : 'CLOUD USAGE', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(stats.formattedTotalSize, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppTheme.background,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text('${stats.totalFiles} items stored', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
