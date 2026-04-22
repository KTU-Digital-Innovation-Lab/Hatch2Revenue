import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/feed_record.dart';
import '../../providers/feed_provider.dart';
import '../../providers/batch_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _fcrFeedCtrl   = TextEditingController();
  final _fcrOutputCtrl = TextEditingController();
  String _fcrResult = '—';
  String _fcrRating = '';
  Color  _fcrColor  = AppColors.amber;

  void _calcFCR() {
    final f = double.tryParse(_fcrFeedCtrl.text) ?? 0;
    final o = double.tryParse(_fcrOutputCtrl.text) ?? 0;
    if (f <= 0 || o <= 0) {
      setState(() { _fcrResult = '—'; _fcrRating = ''; });
      return;
    }
    final fcr = f / o;
    setState(() {
      _fcrResult = fcr.toStringAsFixed(2);
      if (fcr < 2.0) {
        _fcrColor  = AppColors.green;
        _fcrRating = '✓ Excellent efficiency';
      } else if (fcr < 2.5) {
        _fcrColor  = AppColors.amber;
        _fcrRating = '⚠ Average — monitor feed';
      } else {
        _fcrColor  = AppColors.red;
        _fcrRating = '✕ Poor — investigate feeding';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FeedProvider, BatchProvider>(
      builder: (context, feedProvider, batchProvider, _) {
        final records  = feedProvider.records;
        final totalKg  = feedProvider.totalFeedConsumed;
        final avgDaily = records.isEmpty ? 0.0 : totalKg / records.length;
        final daysLeft = avgDaily > 0 ? '~${(totalKg / avgDaily).toStringAsFixed(0)} days left' : '— days left';
        final recent7  = records.length >= 2 ? records.skip(records.length >= 7 ? records.length - 7 : 0).toList() : <FeedRecord>[];
        final fcr7     = recent7.isNotEmpty
            ? (recent7.fold(0.0, (s, r) => s + r.totalKg) / recent7.length).toStringAsFixed(2)
            : '—';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: '🌾 Feed Monitoring System',
                subtitle: 'Track inventory levels, daily logs, and Feed Conversion Ratio',
                action: Row(mainAxisSize: MainAxisSize.min, children: [
                  GhostBtn(label: '📦 Update Stock', onPressed: () => _showStockDialog(context)),
                  const SizedBox(width: 8),
                  PrimaryBtn(label: '+ Log Consumption', onPressed: () => _showLogDialog(context, feedProvider)),
                ]),
              ),

              KpiCard(label: 'Stock (kg)', value: totalKg.toStringAsFixed(0), sub: daysLeft, icon: '📦', accentColor: AppColors.amber),
              const SizedBox(height: 12),
              KpiCard(label: 'Avg Daily (kg)', value: avgDaily.toStringAsFixed(0), icon: '📅', accentColor: AppColors.green),
              const SizedBox(height: 12),
              KpiCard(label: 'FCR (7-day)', value: fcr7, icon: '⚖️', accentColor: AppColors.cyan),
              const SizedBox(height: 12),
              KpiCard(label: 'Total Logs', value: '${records.length}', icon: '📋', accentColor: AppColors.purple),
              const SizedBox(height: 18),

              _twoCol(
                left: HtmlCard(
                  header: const HtmlCardHeader(title: '📋 Daily Consumption Logs'),
                  bodyPadding: EdgeInsets.zero,
                  body: records.isEmpty
                      ? HtmlEmptyState(
                          icon: '🌾',
                          message: 'No logs yet. Start logging daily feed.',
                          action: PrimaryBtn(label: '+ Log Consumption', small: true, onPressed: () => _showLogDialog(context, feedProvider)),
                        )
                      : _logsTable(context, records, feedProvider),
                ),
                right: HtmlCard(
                  header: HtmlCardHeader(title: '⚖️ FCR Calculator', trailing: const TagChip(label: 'Auto-computed', color: AppColors.green)),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FCR = Total Feed Consumed ÷ Total Eggs (or Weight). Lower FCR = better efficiency.',
                        style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 14),
                      _fcrField(_fcrFeedCtrl, 'Total Feed Consumed (kg)', 'e.g. 500'),
                      const SizedBox(height: 12),
                      _fcrField(_fcrOutputCtrl, 'Total Output (eggs or kg gain)', 'e.g. 350'),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(children: [
                          Text('FCR RESULT', style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 2)),
                          const SizedBox(height: 6),
                          Text(_fcrResult, style: GoogleFonts.syne(color: _fcrColor, fontSize: 34, fontWeight: FontWeight.w800)),
                          if (_fcrRating.isNotEmpty)
                            Text(_fcrRating, style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 10)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  Widget _fcrField(TextEditingController ctrl, String label, String hint) {
    return HtmlFormField(
      label: label,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => _calcFCR(),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: htmlInputDec(hint),
      ),
    );
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 500) return Column(children: [left, right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left), const SizedBox(width: 14), Expanded(child: right),
      ]);
    });
  }

  Widget _logsTable(BuildContext context, List<FeedRecord> records, FeedProvider provider) {
    final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
    return HtmlTable(
      headers: ['Date', 'Amount (kg)', 'Type', 'Batch', ''],
      rows: sorted.map((r) => [
        Text(DateFormat('d MMM yyyy').format(r.date), style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11)),
        Text('${r.totalKg.toStringAsFixed(1)} kg', style: GoogleFonts.dmMono(color: AppColors.cyan, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(r.feedTypeName, style: GoogleFonts.dmMono(color: AppColors.textPrimary, fontSize: 11)),
        Text(r.batchId.length > 8 ? r.batchId.substring(0, 8) : r.batchId, style: GoogleFonts.dmMono(color: AppColors.textSecondary, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          EditBtn(onTap: () => _showEditDialog(context, r, provider)),
          DelBtn(onTap: () => provider.removeRecord(r.id)),
        ]),
      ]).toList(),
    );
  }

  void _showStockDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Stock is calculated from consumption logs'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showLogDialog(BuildContext context, FeedProvider feedProvider) {
    final amountCtrl = TextEditingController();
    final typeCtrl   = TextEditingController();
    final batchCtrl  = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🌾 Log Daily Feed Consumption'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(label: 'Date', child: HtmlDateTile(date: DateTime.now())),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Amount Consumed (kg)',
              child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 520')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Feed Type',
              child: TextField(controller: typeCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Layer Mash')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Batch / Flock',
              child: TextField(controller: batchCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. All or B-2026-01')),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () {
              final kg = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (kg <= 0) return;
              final batchId = batchCtrl.text.trim().isEmpty ? 'All' : batchCtrl.text.trim();
              final type = _parseFeedType(typeCtrl.text.trim());
              feedProvider.addRecord(FeedRecord(
                batchId: batchId,
                feedType: type,
                bagsUsed: 1,
                kgPerBag: kg,
                unitPricePerBag: 0,
                date: DateTime.now(),
              ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Consumption logged ✓'),
                backgroundColor: AppColors.green.withValues(alpha: 0.9),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Save Log'),
          ),
        ],
      ),
    );
  }

  FeedType _parseFeedType(String text) {
    final t = text.toLowerCase();
    if (t.contains('starter'))  return FeedType.starter;
    if (t.contains('grower'))   return FeedType.grower;
    if (t.contains('finisher')) return FeedType.finisher;
    return FeedType.layer;
  }

  void _showEditDialog(BuildContext context, FeedRecord feed, FeedProvider provider) {
    final amountCtrl = TextEditingController(text: feed.totalKg.toStringAsFixed(1));
    FeedType selectedType = feed.feedType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Feed Record'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(
              label: 'Amount (kg)',
              child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('kg')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Feed Type',
              child: DropdownButtonFormField<FeedType>(
                initialValue: selectedType,
                dropdownColor: AppColors.surfaceLight,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: htmlInputDec(),
                items: FeedType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1), style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                onChanged: (v) => ss(() => selectedType = v ?? selectedType),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final kg = double.tryParse(amountCtrl.text) ?? 0;
                if (kg <= 0) return;
                provider.updateRecord(feed.copyWith(feedType: selectedType, bagsUsed: 1, kgPerBag: kg, unitPricePerBag: 0));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated ✏️'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
