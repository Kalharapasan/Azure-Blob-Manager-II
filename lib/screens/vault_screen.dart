import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/storage_provider.dart';
import '../models/blob_item.dart';
import '../utils/app_theme.dart';
import 'files_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  bool _obscureText = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final provider = context.read<StorageProvider>();
    _accountController.text = provider.accountName ?? '';
  }

  void _handleUnlock() async {
    final provider = context.read<StorageProvider>();
    final success = await provider.unlockVault(_passwordController.text);
    if (success) {
      _passwordController.clear();
      setState(() => _error = null);
    } else {
      setState(() => _error = 'Invalid authorization key');
    }
  }

  void _handleBiometricUnlock() async {
    final provider = context.read<StorageProvider>();
    final success = await provider.unlockWithBiometrics();
    if (success) {
      setState(() => _error = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometric authentication failed')));
    }
  }

  void _handleSetInitial() async {
    final provider = context.read<StorageProvider>();
    if (_passwordController.text.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters');
      return;
    }
    await provider.setVaultPassword(_passwordController.text);
    if (_accountController.text.isNotEmpty) {
      await provider.setAccountName(_accountController.text);
    }
    _passwordController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identity verified. Vault initialized.')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();

    if (!provider.hasVaultPassword || provider.accountName == null || provider.accountName!.isEmpty) {
      return _buildSetupView();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: provider.isVaultUnlocked ? _buildUnlockedView(provider) : _buildLockedView(),
    );
  }

  Widget _buildSetupView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: AppTheme.glassBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconCircle(Icons.admin_panel_settings_rounded, AppTheme.accent),
              const SizedBox(height: 32),
              const Text('Identity Setup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 12),
              const Text('Initialize your encrypted workspace', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 40),
              _advancedField('Azure Account Name', _accountController, Icons.alternate_email_rounded, false),
              const SizedBox(height: 16),
              _advancedField('Vault Master Password', _passwordController, Icons.key_rounded, true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSetInitial,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                  child: const Text('INITIALIZE VAULT'),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  Widget _buildLockedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: AppTheme.glassBox(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconCircle(Icons.lock_rounded, AppTheme.privateColor),
              const SizedBox(height: 32),
              const Text('Vault Locked', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(height: 12),
              const Text('Authorization required to view secret data', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 40),
              _advancedField('Master Password', _passwordController, Icons.password_rounded, true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleUnlock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.privateColor,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      child: const Text('UNLOCK ACCESS'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(color: AppTheme.privateColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.privateColor.withOpacity(0.3))),
                    child: IconButton(
                      onPressed: _handleBiometricUnlock,
                      icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.privateColor, size: 32),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => setState(() { _error = 'Contact administrator to reset'; }),
                child: const Text('Trouble accessing?', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }

  Widget _iconCircle(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.2), width: 2)),
      child: Icon(icon, color: color, size: 48),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 2.seconds, color: Colors.white24);
  }

  Widget _advancedField(String label, TextEditingController controller, IconData icon, bool obscure) {
    return TextField(
      controller: controller,
      obscureText: obscure && _obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: obscure
            ? IconButton(
                icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              )
            : null,
      ),
    );
  }

  Widget _buildUnlockedView(StorageProvider provider) {
    return Column(
      children: [
        AppBar(
          title: const Text('ENCRYPTED ENVIRONMENT'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_suggest_rounded, color: AppTheme.textSecondary),
              onPressed: () => _showEditSettingsDialog(provider),
            ),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ElevatedButton(
                onPressed: () => provider.lockVault(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error.withOpacity(0.1),
                  foregroundColor: AppTheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                  side: const BorderSide(color: AppTheme.error, width: 1),
                ),
                child: const Text('LOCK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
        Expanded(
          child: const FilesScreen(category: null),
        ),
      ],
    );
  }

  void _showEditSettingsDialog(StorageProvider provider) {
    final passCtrl = TextEditingController();
    final accCtrl = TextEditingController(text: provider.accountName);
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: const Text('Vault Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: accCtrl, decoration: const InputDecoration(labelText: 'Azure Account')),
              const SizedBox(height: 16),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'New Master Key')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (accCtrl.text.isNotEmpty) await provider.setAccountName(accCtrl.text);
                if (passCtrl.text.isNotEmpty) await provider.setVaultPassword(passCtrl.text);
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }
}
