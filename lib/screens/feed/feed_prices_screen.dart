import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/feed_catalog_item.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';

/// The farm's official feed prices. Everyone can see them; STRICTLY
/// the owner can change them (also enforced by the server). Workers'
/// feed logs use these prices automatically and can't be overridden.
class FeedPricesScreen extends StatelessWidget {
  const FeedPricesScreen({super.key});

  Future<void> _editPrice(BuildContext context, FeedCatalogItem item) async {
    final ctrl =
        TextEditingController(text: item.pricePerBag.toStringAsFixed(0));
    final sync = context.read<SyncService>();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.feedName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText:
                    'Price per ${item.kgPerBag.toStringAsFixed(0)}kg bag '
                    '(${CurrencyFormatter.currencySymbol})',
              ),
            ),
            if (item.marketMin != null && item.marketMax != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Market range: ${CurrencyFormatter.currencySymbol}'
                  '${item.marketMin!.toStringAsFixed(0)} – '
                  '${CurrencyFormatter.currencySymbol}'
                  '${item.marketMax!.toStringAsFixed(0)}',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Save Price'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    try {
      await sync.updateFeedPrice(item.id, value);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${item.feedName} is now ${CurrencyFormatter.currencySymbol}'
          '${value.toStringAsFixed(0)} per bag.',
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final isOwner = sync.membership?.isOwner ?? false;
    final catalog = sync.catalog;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Feed Prices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
            ),
            child: Text(
              isOwner
                  ? 'These are your farm\'s official prices. Workers\' feed '
                      'logs use them automatically — they cannot type their '
                      'own amounts. Every change you make here is recorded.'
                  : 'Official prices set by the farm owner. Your feed logs '
                      'use these automatically.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (catalog.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No prices yet — run a sync while online to load your '
                'farm\'s feed catalog.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ...catalog.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.feedName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${item.kgPerBag.toStringAsFixed(0)} kg per bag',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.currencySymbol}'
                      '${item.pricePerBag.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        tooltip: 'Change price',
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textSecondary),
                        onPressed: () => _editPrice(context, item),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
