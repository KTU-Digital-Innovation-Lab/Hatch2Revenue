import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/farm_profile_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/vaccination_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../providers/financial_provider.dart';
import '../../models/farm_profile.dart';
import '../../services/backup_service.dart';
import '../../services/csv_export_service.dart';
import '../../utils/app_colors.dart';
import 'cloud_sync_card.dart';
import 'farm_card.dart';

class FarmProfileScreen extends StatefulWidget {
  const FarmProfileScreen({super.key});

  @override
  State<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends State<FarmProfileScreen> {
  final _farmNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final profile = context.read<FarmProfileProvider>().profile;
      _farmNameController.text = profile.farmName;
      _ownerNameController.text = profile.ownerName;
      _locationController.text = profile.location;
      _farmSizeController.text = profile.farmSize;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
    }
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _ownerNameController.dispose();
    _locationController.dispose();
    _farmSizeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    final farmName = _farmNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();

    if (farmName.isEmpty || ownerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Farm name and owner name are required.'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final profile = FarmProfile(
      farmName: farmName,
      ownerName: ownerName,
      location: _locationController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      farmSize: _farmSizeController.text.trim(),
    );

    context.read<FarmProfileProvider>().save(profile);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Farm profile saved successfully!'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportCsv() async {
    try {
      final dir = await CsvExportService.exportAll(
        batches: context.read<BatchProvider>().batches,
        vaccinations: context.read<VaccinationProvider>().vaccinations,
        feedRecords: context.read<FeedProvider>().records,
        feedInventory: context.read<FeedProvider>().inventory,
        eggRecords: context.read<EggProductionProvider>().records,
        mortalityRecords: context.read<MortalityProvider>().records,
        transactions: context.read<FinancialProvider>().transactions,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Complete'),
          content: Text(
            '7 CSV files saved to:\n\n${dir.path}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share'),
              onPressed: () {
                Navigator.pop(ctx);
                CsvExportService.shareExport(dir);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _backup() async {
    try {
      await BackupService.shareBackup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Backup failed: $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
          'This replaces ALL current records with the backup file. '
          'Your current data is kept as a safety copy, but anything '
          'recorded after the backup was made will disappear from the app.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final restored = await BackupService.restoreFromFile();
      if (!restored || !mounted) return;
      // Pull the restored data into every provider.
      await Future.wait([
        context.read<BatchProvider>().reload(),
        context.read<VaccinationProvider>().reload(),
        context.read<FeedProvider>().reload(),
        context.read<EggProductionProvider>().reload(),
        context.read<MortalityProvider>().reload(),
        context.read<FinancialProvider>().reload(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Backup restored successfully.'),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Restore failed: $e'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.amber, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('🏡', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farm Profile',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Set up your farm details and preferences',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Farm Information Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Information',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _farmNameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Farm Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ownerNameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Owner Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Location / Address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _farmSizeController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Farm Size'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contact Information Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Information',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  style: TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Phone Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  style: TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email Address'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data Management Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Management',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Export all records (batches, vaccinations, feed, stock, eggs, mortality, transactions) as CSV files you can open in Excel.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.file_download_outlined, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amber,
                      side: const BorderSide(color: AppColors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    label: const Text('Export All Data (CSV)'),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Backup & Restore',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your records live only on this device until you back them '
                  'up. Share the backup file to WhatsApp, Drive, or email — '
                  'and restore it on a new phone to get everything back.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _backup,
                        icon: const Icon(Icons.backup_outlined, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.green,
                          side: const BorderSide(color: AppColors.green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        label: const Text('Back Up Now'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _restore,
                        icon: const Icon(Icons.settings_backup_restore,
                            size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.textSecondary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const CloudSyncCard(),

          const SizedBox(height: 24),

          const FarmCard(),

          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
