import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/storage_provider.dart';
import '../models/blob_item.dart';
import '../utils/app_theme.dart';
import 'dashboard_screen.dart';
import 'files_screen.dart';
import 'vault_screen.dart';
import 'upload_screen.dart';
import '../widgets/sidebar_widget.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  BlobCategory? _selectedCategory;
  bool _sidebarOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageProvider>().loadBlobs();
    });
  }

  List<Widget> get _screens => [
    const DashboardScreen(),
    FilesScreen(category: _selectedCategory),
    const VaultScreen(),
    const UploadScreen(),
  ];

  void _onCategorySelected(BlobCategory? category) {
    setState(() {
      _selectedCategory = category;
      _selectedIndex = 1;
      _sidebarOpen = false;
    });
    context.read<StorageProvider>().setCategory(category);
  }

  void _onNavSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _sidebarOpen = false;
      if (index != 1) _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= AppConstants.mobileBreakpoint;
    final provider = context.watch<StorageProvider>();
    final isSecret = provider.currentVault == VaultMode.secret;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Animated Background Orbs
          _buildAnimatedBackground(size, isSecret),

          // Content Layout
          Row(
            children: [
              if (isWide)
                SidebarWidget(
                  selectedIndex: _selectedIndex,
                  selectedCategory: _selectedCategory,
                  onNavSelected: _onNavSelected,
                  onCategorySelected: _onCategorySelected,
                ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.1, end: 0),
              
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('$_selectedIndex-${provider.currentVault}'),
                      child: _screens[_selectedIndex],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Mobile Drawer Overlay
          if (!isWide && _sidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.black45),
              ),
            ).animate().fadeIn(),

          if (!isWide && _sidebarOpen)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: SidebarWidget(
                selectedIndex: _selectedIndex,
                selectedCategory: _selectedCategory,
                onNavSelected: _onNavSelected,
                onCategorySelected: _onCategorySelected,
              ),
            ).animate().slideX(begin: -1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),

          // Download Progress Overlay
          if (provider.isDownloading)
            Positioned(
              left: 24,
              right: 24,
              bottom: isWide ? 24 : 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.file_download_rounded,
                            color: AppTheme.accent,
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .shimmer(duration: 1.5.seconds),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Downloading ${provider.downloadingFileName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: provider.downloadProgress,
                                  backgroundColor: AppTheme.border,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '${(provider.downloadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack),
        ],
      ),
      
      // Advanced Floating Action Button for Mobile
      floatingActionButton: isWide ? null : FloatingActionButton.extended(
        onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
        backgroundColor: isSecret ? AppTheme.privateColor : AppTheme.accent,
        elevation: 10,
        icon: AnimatedIcon(
          icon: AnimatedIcons.menu_close,
          progress: AlwaysStoppedAnimation(_sidebarOpen ? 1.0 : 0.0),
        ),
        label: Text(_sidebarOpen ? 'Close' : 'Menu'),
      ).animate().scale(delay: 1.seconds),
    );
  }

  Widget _buildAnimatedBackground(Size size, bool isSecret) {
    final baseColor = isSecret ? AppTheme.privateColor : AppTheme.accent;
    return Stack(
      children: [
        // Top Left Orb
        Positioned(
          top: -100, left: -100,
          child: Container(
            width: 400, height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor.withOpacity(0.08),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 5.seconds)
           .move(begin: const Offset(-20, -20), end: const Offset(50, 50), duration: 8.seconds),
        ),
        
        // Bottom Right Orb
        Positioned(
          bottom: -150, right: -150,
          child: Container(
            width: 500, height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondary.withOpacity(0.05),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8), duration: 6.seconds)
           .move(begin: const Offset(30, 30), end: const Offset(-40, -40), duration: 7.seconds),
        ),

        // Backdrop blur for glass effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
