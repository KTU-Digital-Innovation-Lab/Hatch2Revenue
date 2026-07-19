import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/egg_production.dart';
import '../../models/feed_catalog_item.dart';
import '../../models/feed_record.dart';
import '../../models/financial_transaction.dart';
import '../../models/mortality.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/financial_provider.dart';
import '../../providers/mortality_provider.dart';
import '../../services/sync_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/html_widgets.dart';
import '../../utils/units.dart';

/// The farmer's daily ritual on ONE screen: eggs collected, feed used,
/// and deaths — one date, one batch, one Save. Sections left empty are
/// simply skipped, and the same auto-postings fire as in the full
/// module dialogs (egg income, feed expense, bird-count adjustment).
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key});

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  DateTime _date = DateTime.now();
  String _batch = 'All';

  final _crates = TextEditingController();
  final _loose = TextEditingController();
  final _damaged = TextEditingController();
  final _pricePerCrate = TextEditingController();

  final _bags = TextEditingController();
  final _feedCost = TextEditingController();
  FeedCatalogItem? _catalogFeed;
  FeedType _feedType = FeedType.layer;

  final _deaths = TextEditingController();
  int _cause = 0;

  @override
  void dispose() {
    for (final c in [_crates, _loose, _damaged, _pricePerCrate, _bags, _feedCost, _deaths]) {
      c.dispose();
    }
    super.dispose();
  }

  FeedType _feedTypeFromName(String name) {
    final t = name.toLowerCase();
    if (t.contains('starter')) return FeedType.starter;
    if (t.contains('grower')) return FeedType.grower;
    if (t.contains('finisher')) return FeedType.finisher;
    return FeedType.layer;
  }

  void _save() {
    final crates = double.tryParse(_crates.text.trim()) ?? 0;
    final loose = int.tryParse(_loose.text.trim()) ?? 0;
    final eggCount = (crates * Units.eggsPerCrate).round() + loose;
    final damaged = int.tryParse(_damaged.text.trim()) ?? 0;
    final pricePerCrate = double.tryParse(_pricePerCrate.text.trim()) ?? 0;
    final bags = double.tryParse(_bags.text.trim()) ?? 0;
    final deaths = int.tryParse(_deaths.text.trim()) ?? 0;

    if (eggCount <= 0 && bags <= 0 && deaths <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nothing to save — enter eggs, feed or deaths first.'),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final fin = context.read<FinancialProvider>();
    final parts = <String>[];

    // --- Eggs ---
    if (eggCount > 0) {
      final h = DateTime.now().hour;
      final period = h < 12 ? 'Morning' : (h < 16 ? 'Afternoon' : 'Evening');
      final pricePerEgg = pricePerCrate / Units.eggsPerCrate;
      context.read<EggProductionProvider>().addRecord(EggProduction(
            batchId: _batch,
            date: _date,
            eggCount: eggCount,
            damagedCount: damaged,
            pricePerEgg: pricePerEgg,
            period: period,
          ));
      final saleValue = (eggCount - damaged) * pricePerEgg;
      if (saleValue > 0) {
        fin.addTransaction(FinancialTransaction(
          date: _date,
          type: TransactionType.income,
          category: TransactionCategory.eggSales,
          amount: saleValue,
          batchId: _batch,
          description:
              'Egg sales: ${Units.crateLabel(eggCount - damaged)} @ ${CurrencyFormatter.currencySymbol}${pricePerCrate.toStringAsFixed(0)}/crate',
        ));
      }
      parts.add(Units.crateLabel(eggCount));
    }

    // --- Feed ---
    if (bags > 0) {
      final catalog = context.read<SyncService>().catalog;
      final useCatalog = catalog.isNotEmpty;
      final feed = _catalogFeed ?? (useCatalog ? catalog.first : null);
      final double kg;
      final double cost;
      final FeedType type;
      if (feed != null) {
        kg = bags * feed.kgPerBag;
        cost = bags * feed.pricePerBag; // owner's locked price
        type = _feedTypeFromName(feed.feedName);
      } else {
        kg = Units.bagsToKg(bags);
        cost = double.tryParse(_feedCost.text.trim()) ?? 0;
        type = _feedType;
      }
      context.read<FeedProvider>().addRecord(FeedRecord(
            batchId: _batch,
            feedType: type,
            bagsUsed: 1,
            kgPerBag: kg,
            unitPricePerBag: cost,
            date: _date,
          ));
      if (cost > 0) {
        fin.addTransaction(FinancialTransaction(
          date: _date,
          type: TransactionType.expense,
          category: TransactionCategory.feed,
          amount: cost,
          batchId: _batch,
          description: 'Feed: ${Units.bagShort(kg)} bags',
        ));
      }
      parts.add('${bags.toStringAsFixed(bags == bags.roundToDouble() ? 0 : 1)} bags feed');
    }

    // --- Deaths ---
    if (deaths > 0) {
      context.read<MortalityProvider>().addRecord(Mortality(
            batchId: _batch,
            count: deaths,
            date: _date,
            cause: MortalityCause.values[_cause],
          ));
      context.read<BatchProvider>().adjustCount(_batch, -deaths);
      parts.add('$deaths death${deaths == 1 ? '' : 's'}');
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Daily log saved: ${parts.join(' · ')}'),
      backgroundColor: AppColors.green.withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _numField(TextEditingController ctrl, String label, String hint,
      {bool decimal = false}) {
    return HtmlFormField(
      label: label,
      child: TextField(
        controller: ctrl,
        keyboardType: decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.number,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: htmlInputDec(hint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BatchProvider>();
    final batchOptions = {'All': 'All', for (final b in bp.batches) b.id: b.name};
    final birds = _batch == 'All'
        ? bp.totalBirds
        : (bp.getBatchByRef(_batch)?.currentCount ?? 0);
    final catalog = context.read<SyncService>().catalog;
    final useCatalog = catalog.isNotEmpty;
    final selFeed = _catalogFeed ?? (useCatalog ? catalog.first : null);
    final bags = double.tryParse(_bags.text.trim()) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Daily Log'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Eggs, feed and deaths for the day — leave any section empty to skip it.',
            style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: _date,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HtmlFormField(
                label: 'Batch ($birds birds)',
                child: DropdownButtonFormField<String>(
                  initialValue: _batch,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: batchOptions.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                style: TextStyle(color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _batch = v ?? _batch),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // --- Eggs section ---
          HtmlCard(
            header: const HtmlCardHeader(icon: Icons.egg_outlined, title: 'Eggs Collected'),
            body: Column(children: [
              Row(children: [
                Expanded(child: _numField(_crates, 'Crates', 'e.g. 3', decimal: true)),
                const SizedBox(width: 12),
                Expanded(child: _numField(_loose, 'Loose Eggs', '0–29')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _numField(_damaged, 'Damaged (eggs)', 'e.g. 2')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_pricePerCrate,
                    'Price/Crate (${CurrencyFormatter.currencySymbol})', 'optional',
                    decimal: true)),
              ]),
            ]),
          ),

          // --- Feed section ---
          HtmlCard(
            header: const HtmlCardHeader(icon: Icons.grass, title: 'Feed Used'),
            body: Column(children: [
              if (useCatalog) ...[
                HtmlFormField(
                  label: 'Feed Type (official prices)',
                  child: DropdownButtonFormField<FeedCatalogItem>(
                    initialValue: selFeed,
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
                    onChanged: (v) => setState(() => _catalogFeed = v),
                  ),
                ),
                const SizedBox(height: 12),
                _numFieldLive(_bags, 'Bags Used (1 bag = 50 kg)', 'e.g. 2 or 1.5'),
                if (selFeed != null && bags > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cost (set by owner): ${CurrencyFormatter.currencySymbol}${(bags * selFeed.pricePerBag).toStringAsFixed(2)}',
                      style: TextStyle(
                          color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ] else ...[
                Row(children: [
                  Expanded(child: _numField(_bags, 'Bags Used', 'e.g. 2 or 1.5', decimal: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_feedCost,
                      'Cost (${CurrencyFormatter.currencySymbol})', 'optional',
                      decimal: true)),
                ]),
                const SizedBox(height: 12),
                HtmlFormField(
                  label: 'Feed Type',
                  child: DropdownButtonFormField<FeedType>(
                    initialValue: _feedType,
                    dropdownColor: AppColors.surfaceLight,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: htmlInputDec(),
                    items: FeedType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.name[0].toUpperCase() + t.name.substring(1),
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _feedType = v ?? _feedType),
                  ),
                ),
              ],
            ]),
          ),

          // --- Deaths section ---
          HtmlCard(
            header: const HtmlCardHeader(
                icon: Icons.monitor_heart_outlined, title: 'Deaths (if any)'),
            body: Row(children: [
              Expanded(child: _numField(_deaths, 'Number of Deaths', 'e.g. 0')),
              const SizedBox(width: 12),
              Expanded(
                child: HtmlFormField(
                  label: 'Cause',
                  child: DropdownButtonFormField<int>(
                    initialValue: _cause,
                    dropdownColor: AppColors.surfaceLight,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: htmlInputDec(),
                    items: MortalityCause.values
                        .map((c) => DropdownMenuItem(
                              value: c.index,
                              child: Text(
                                c.name[0].toUpperCase() + c.name.substring(1),
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _cause = v ?? 0),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Save Daily Log'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Number field that rebuilds the screen as it changes (live cost).
  Widget _numFieldLive(TextEditingController ctrl, String label, String hint) {
    return HtmlFormField(
      label: label,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AppColors.textPrimary),
        decoration: htmlInputDec(hint),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
