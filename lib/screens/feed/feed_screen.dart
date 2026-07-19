import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/feed_catalog_item.dart';
import '../../models/feed_record.dart';
import '../../models/financial_transaction.dart';
import '../../services/sync_service.dart';
import '../../providers/feed_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/financial_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/html_widgets.dart';
import '../../utils/units.dart';

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
        _fcrRating = 'Excellent efficiency';
      } else if (fcr < 2.5) {
        _fcrColor  = AppColors.amber;
        _fcrRating = 'Average — monitor feed';
      } else {
        _fcrColor  = AppColors.red;
        _fcrRating = 'Poor — investigate feeding';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FeedProvider, BatchProvider>(
      builder: (context, feedProvider, batchProvider, _) {
        final records  = feedProvider.records;
        final totalKg  = feedProvider.totalFeedConsumed;
        final stockKg  = feedProvider.totalStockKg;
        final avgDaily = records.isEmpty ? 0.0 : totalKg / records.length;
        final daysLeft = avgDaily > 0 && stockKg > 0
            ? '~${(stockKg / avgDaily).toStringAsFixed(0)} days left'
            : '— days left';
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
                icon: Icons.grass,
                title: 'Feed Monitoring System',
                subtitle: 'Feed is tracked in bags (1 bag = 50 kg) — inventory, daily logs, and FCR',
                action: Row(mainAxisSize: MainAxisSize.min, children: [
                  GhostBtn(label: 'Add Stock', onPressed: () => _showStockDialog(context, feedProvider)),
                  const SizedBox(width: 8),
                  PrimaryBtn(label: '+ Log Consumption', onPressed: () => _showLogDialog(context, feedProvider)),
                ]),
              ),

              ..._buildAlerts(feedProvider),

              KpiGrid(children: [
                KpiCard(label: 'Stock (bags)', value: Units.bagShort(stockKg), sub: '${stockKg.toStringAsFixed(0)} kg · $daysLeft', accentColor: AppColors.amber),
                KpiCard(label: 'Avg Daily (bags)', value: Units.bagShort(avgDaily), sub: '${avgDaily.toStringAsFixed(0)} kg/day', accentColor: AppColors.green),
                KpiCard(label: 'FCR (7-day)', value: fcr7, accentColor: AppColors.cyan),
                KpiCard(label: 'Total Logs', value: '${records.length}', accentColor: AppColors.purple),
              ]),
              const SizedBox(height: 18),

              // Stock inventory card
              HtmlCard(
                header: HtmlCardHeader(
                  icon: Icons.inventory_2_outlined,
                  title: 'Feed Stock Inventory',
                  trailing: feedProvider.stockAlertCount > 0
                      ? TagChip(label: '${feedProvider.stockAlertCount} alert${feedProvider.stockAlertCount != 1 ? "s" : ""}', color: AppColors.red)
                      : TagChip(label: '${feedProvider.inventory.length} item${feedProvider.inventory.length != 1 ? "s" : ""}', color: AppColors.green),
                ),
                bodyPadding: EdgeInsets.zero,
                body: feedProvider.inventory.isEmpty
                    ? HtmlEmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'No stock recorded. Add feed purchases to track inventory and days-left estimates.',
                        action: PrimaryBtn(label: '+ Add Stock', small: true, onPressed: () => _showStockDialog(context, feedProvider)),
                      )
                    : _stockTable(context, feedProvider),
              ),

              _twoCol(
                left: HtmlCard(
                  header: const HtmlCardHeader(icon: Icons.list_alt_outlined, title: 'Daily Consumption Logs'),
                  bodyPadding: EdgeInsets.zero,
                  body: records.isEmpty
                      ? HtmlEmptyState(
                          icon: Icons.grass,
                          message: 'No logs yet. Start logging daily feed.',
                          action: PrimaryBtn(label: '+ Log Consumption', small: true, onPressed: () => _showLogDialog(context, feedProvider)),
                        )
                      : _logsTable(context, records, feedProvider),
                ),
                right: HtmlCard(
                  header: HtmlCardHeader(icon: Icons.balance, title: 'FCR Calculator', trailing: const TagChip(label: 'Auto-computed', color: AppColors.green)),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FCR = Total Feed Consumed ÷ Total Eggs (or Weight). Lower FCR = better efficiency.',
                        style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11),
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
                          Text('FCR RESULT', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 2)),
                          const SizedBox(height: 6),
                          Text(_fcrResult, style: GoogleFonts.poppins(color: _fcrColor, fontSize: 34, fontWeight: FontWeight.w800)),
                          if (_fcrRating.isNotEmpty)
                            Text(_fcrRating, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 10)),
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

  /// Prominent low-stock and expiry alerts, the way FarmNest surfaces
  /// them — so a farmer never runs out of feed by surprise.
  List<Widget> _buildAlerts(FeedProvider provider) {
    final low = provider.inventory.where((i) => i.isLowStock).toList();
    final expired = provider.inventory.where((i) => i.isExpired).toList();
    if (low.isEmpty && expired.isEmpty) return const [];

    Widget banner(String text, Color color, IconData icon) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 12)),
            ),
          ]),
        );

    return [
      if (expired.isNotEmpty)
        banner(
          'Expired feed: ${expired.map((e) => e.feedTypeName).join(", ")}. '
          'Remove or replace before feeding.',
          AppColors.red,
          Icons.warning_amber_rounded,
        ),
      if (low.isNotEmpty)
        banner(
          'Low stock: ${low.map((e) => "${e.feedTypeName} (${Units.bagShort(e.quantityKg)} bags)").join(", ")}. '
          'Reorder soon to avoid running out.',
          AppColors.amber,
          Icons.inventory_2_outlined,
        ),
    ];
  }

  Widget _fcrField(TextEditingController ctrl, String label, String hint) {
    return HtmlFormField(
      label: label,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => _calcFCR(),
        style: TextStyle(color: AppColors.textPrimary),
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
    final bp = context.read<BatchProvider>();
    return HtmlTable(
      headers: ['Date', 'Amount (bags)', 'Type', 'Batch', ''],
      rows: sorted.map((r) {
        final label = bp.batchLabel(r.batchId);
        return [
        Text(DateFormat('d MMM yyyy').format(r.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Text('${Units.bagShort(r.totalKg)} bags', style: GoogleFonts.inter(color: AppColors.cyan, fontWeight: FontWeight.w500, fontSize: 12)),
        Text(r.feedTypeName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
        Text(label.length > 12 ? '${label.substring(0, 12)}…' : label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
        Row(mainAxisSize: MainAxisSize.min, children: [
          EditBtn(onTap: () => _showEditDialog(context, r, provider)),
          DelBtn(onTap: () => provider.removeRecord(r.id)),
        ]),
      ];
      }).toList(),
    );
  }

  Widget _stockTable(BuildContext context, FeedProvider provider) {
    return HtmlTable(
      headers: ['Feed Type', 'Qty (bags)', 'Expiry', 'Status', ''],
      rows: provider.inventory.map((i) {
        final String status;
        final Color statusColor;
        if (i.isExpired) {
          status = 'Expired';
          statusColor = AppColors.red;
        } else if (i.isLowStock) {
          status = 'Low';
          statusColor = AppColors.amber;
        } else {
          status = 'OK';
          statusColor = AppColors.green;
        }
        return [
          Text(i.feedTypeName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 12)),
          Text(Units.bagShort(i.quantityKg), style: GoogleFonts.inter(color: AppColors.cyan, fontWeight: FontWeight.w500, fontSize: 12)),
          Text(DateFormat('d MMM yyyy').format(i.expiryDate), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
          TagChip(label: status, color: statusColor),
          Row(mainAxisSize: MainAxisSize.min, children: [
            EditBtn(onTap: () => _showStockDialog(context, provider, existing: i)),
            DelBtn(onTap: () => _confirmDeleteStock(context, i, provider)),
          ]),
        ];
      }).toList(),
    );
  }

  /// Add (existing == null) or edit a stock item.
  void _showStockDialog(BuildContext context, FeedProvider provider, {FeedInventory? existing}) {
    final typeCtrl  = TextEditingController(text: existing?.feedTypeName ?? '');
    final qtyCtrl   = TextEditingController(text: existing != null ? Units.bagShort(existing.quantityKg) : '');
    final priceCtrl = TextEditingController(text: existing != null && existing.unitPrice > 0 ? (existing.unitPrice * Units.kgPerBag).toStringAsFixed(0) : '');
    final supplierCtrl = TextEditingController(text: existing?.supplier ?? '');
    DateTime expiryDate = existing?.expiryDate ?? DateTime.now().add(const Duration(days: 90));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: Text(existing == null ? 'Add Feed Stock' : 'Edit Feed Stock'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Feed Type',
                child: TextField(controller: typeCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Layer Mash')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Quantity (bags — 1 bag = 50 kg)',
                child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 10')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Price per bag (${CurrencyFormatter.currencySymbol}) — optional',
                child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('New stock cost auto-logged as expense')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Expiry Date',
                child: HtmlDateTile(
                  date: expiryDate,
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: expiryDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365 * 3)));
                    if (d != null) ss(() => expiryDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Supplier — optional',
                child: TextField(controller: supplierCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Agrifeeds Ltd')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final type = typeCtrl.text.trim();
                final bags = double.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (type.isEmpty || bags <= 0) return;
                final qty = Units.bagsToKg(bags);               // stored base unit: kg
                final pricePerBag = double.tryParse(priceCtrl.text.trim()) ?? 0;
                final price = pricePerBag / Units.kgPerBag;      // stored base unit: per kg
                final supplier = supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim();

                if (existing == null) {
                  final item = FeedInventory(
                    feedTypeName: type,
                    quantityKg: qty,
                    unitPrice: price,
                    expiryDate: expiryDate,
                    supplier: supplier,
                  );
                  provider.addToInventory(item);
                  // Auto-post the purchase to Financials
                  if (item.totalValue > 0) {
                    context.read<FinancialProvider>().addTransaction(
                      FinancialTransaction(
                        date: DateTime.now(),
                        type: TransactionType.expense,
                        category: TransactionCategory.feed,
                        amount: item.totalValue,
                        description: 'Feed stock: ${Units.bagShort(qty)} bags $type',
                      ),
                    );
                  }
                } else {
                  provider.updateInventory(existing.copyWith(
                    feedTypeName: type,
                    quantityKg: qty,
                    unitPrice: price,
                    expiryDate: expiryDate,
                    supplier: supplier,
                  ));
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(existing == null ? 'Stock added' : 'Stock updated'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Text(existing == null ? 'Add Stock' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStock(BuildContext context, FeedInventory item, FeedProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Stock Item?'),
        content: Text('Remove "${item.feedTypeName}" (${Units.bagShort(item.quantityKg)} bags) from inventory?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () { provider.removeInventory(item.id); Navigator.pop(ctx); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context, FeedProvider feedProvider) {
    final amountCtrl = TextEditingController();
    final typeCtrl   = TextEditingController();
    final costCtrl   = TextEditingController();
    final batches = context.read<BatchProvider>().batches;
    // Records reference batches by ID; 'All' means the whole flock.
    final batchOptions = {for (final b in batches) b.id: b.name, 'All': 'All'};
    String selectedBatch = batchOptions.keys.first;
    DateTime selectedDate = DateTime.now();

    // Owner-priced catalog: when the farm has official prices, the
    // worker picks a feed and enters BAGS — the cost is computed from
    // the owner's price and cannot be typed in.
    final catalog = context.read<SyncService>().catalog;
    final useCatalog = catalog.isNotEmpty;
    FeedCatalogItem? selectedFeed = useCatalog ? catalog.first : null;
    double bags = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Log Daily Feed Consumption'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (useCatalog) ...[
                HtmlFormField(
                  label: 'Feed Type (official prices)',
                  child: DropdownButtonFormField<FeedCatalogItem>(
                    initialValue: selectedFeed,
                    dropdownColor: AppColors.surfaceLight,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: htmlInputDec(),
                    items: catalog
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                '${c.feedName} — ${CurrencyFormatter.currencySymbol}${c.pricePerBag.toStringAsFixed(0)}/bag',
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => ss(() => selectedFeed = v),
                  ),
                ),
                const SizedBox(height: 12),
                HtmlFormField(
                  label: 'Bags Used',
                  child: TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: htmlInputDec('e.g. 3 or 2.5'),
                    onChanged: (v) => ss(() => bags = double.tryParse(v.trim()) ?? 0),
                  ),
                ),
                const SizedBox(height: 12),
                // Locked cost — computed, never typed.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: AppColors.amber),
                          const SizedBox(width: 6),
                          Text('COST (SET BY OWNER)',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFeed == null || bags <= 0
                            ? '—'
                            : '${CurrencyFormatter.currencySymbol}${(bags * selectedFeed!.pricePerBag).toStringAsFixed(2)}'
                              '  ·  ${(bags * selectedFeed!.kgPerBag).toStringAsFixed(0)} kg',
                        style: TextStyle(color: AppColors.amber, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                HtmlFormField(
                  label: 'Amount Consumed (bags — 1 bag = 50 kg)',
                  child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 3 or 2.5')),
                ),
                const SizedBox(height: 12),
                HtmlFormField(
                  label: 'Feed Type',
                  child: TextField(controller: typeCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. Layer Mash')),
                ),
                const SizedBox(height: 12),
                HtmlFormField(
                  label: 'Cost (${CurrencyFormatter.currencySymbol}) — optional',
                  child: TextField(controller: costCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Auto-logged as feed expense')),
                ),
              ],
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Batch / Flock',
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBatch,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: batchOptions.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedBatch = v ?? selectedBatch),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final double kg;
                final double cost;
                final FeedType type;
                if (useCatalog) {
                  final feed = selectedFeed;
                  final b = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (feed == null || b <= 0) return;
                  kg = b * feed.kgPerBag;
                  cost = b * feed.pricePerBag; // owner's price — locked
                  type = _parseFeedType(feed.feedName);
                } else {
                  final b = double.tryParse(amountCtrl.text.trim()) ?? 0;
                  if (b <= 0) return;
                  kg = Units.bagsToKg(b);
                  cost = double.tryParse(costCtrl.text.trim()) ?? 0;
                  type = _parseFeedType(typeCtrl.text.trim());
                }
                final record = FeedRecord(
                  batchId: selectedBatch,
                  feedType: type,
                  bagsUsed: 1,
                  kgPerBag: kg,
                  unitPricePerBag: cost,
                  date: selectedDate,
                );
                feedProvider.addRecord(record);

                // Auto-post the cost to Financials
                if (cost > 0) {
                  context.read<FinancialProvider>().addTransaction(
                    FinancialTransaction(
                      date: selectedDate,
                      type: TransactionType.expense,
                      category: TransactionCategory.feed,
                      amount: cost,
                      batchId: selectedBatch,
                      description: 'Feed: ${Units.bagShort(kg)} bags ${record.feedTypeName}',
                    ),
                  );
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(cost > 0
                      ? 'Consumption logged — expense posted to Financials'
                      : 'Consumption logged'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save Log'),
            ),
          ],
        ),
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
    final amountCtrl = TextEditingController(text: Units.bagShort(feed.totalKg));
    FeedType selectedType = feed.feedType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Feed Record'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            HtmlFormField(
              label: 'Amount (bags)',
              child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('bags')),
            ),
            const SizedBox(height: 12),
            HtmlFormField(
              label: 'Feed Type',
              child: DropdownButtonFormField<FeedType>(
                initialValue: selectedType,
                dropdownColor: AppColors.surfaceLight,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: htmlInputDec(),
                items: FeedType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1), style: TextStyle(color: AppColors.textPrimary)))).toList(),
                onChanged: (v) => ss(() => selectedType = v ?? selectedType),
              ),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final bags = double.tryParse(amountCtrl.text) ?? 0;
                if (bags <= 0) return;
                provider.updateRecord(feed.copyWith(feedType: selectedType, bagsUsed: 1, kgPerBag: Units.bagsToKg(bags)));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated'), backgroundColor: AppColors.cyan, behavior: SnackBarBehavior.floating));
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
