import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/batch.dart';
import '../models/egg_production.dart';
import '../models/egg_sale.dart';
import '../models/feed_record.dart';
import '../models/financial_transaction.dart';
import '../models/mortality.dart';
import '../models/vaccination.dart';
import '../utils/units.dart';

/// Exports all farm records as CSV files (one file per record type)
/// into a timestamped folder in the app's documents directory.
class CsvExportService {
  static final _date = DateFormat('yyyy-MM-dd');

  static String _esc(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static String _row(List<Object?> cells) => cells.map(_esc).join(',');

  static Future<Directory> exportAll({
    required List<Batch> batches,
    required List<Vaccination> vaccinations,
    required List<FeedRecord> feedRecords,
    required List<EggProduction> eggRecords,
    required List<Mortality> mortalityRecords,
    required List<FinancialTransaction> transactions,
    List<FeedInventory> feedInventory = const [],
    List<EggSale> eggSales = const [],
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final dir = Directory('${docs.path}${Platform.pathSeparator}hatch2revenue_export_$stamp');
    await dir.create(recursive: true);

    // Records reference batches by id — export the human name instead.
    final batchName = {for (final b in batches) b.id: b.name};
    String batchRef(String? ref) =>
        ref == null ? '' : (batchName[ref] ?? ref);

    await _write(dir, 'batches.csv', [
      _row(['Batch ID', 'Breed', 'Stage', 'Initial Birds', 'Current Birds', 'Hatch Date', 'Purchase Cost', 'Notes']),
      ...batches.map((b) => _row([
            b.name,
            b.source,
            b.typeName,
            b.initialCount,
            b.currentCount,
            _date.format(b.hatchDate),
            b.initialCost,
            b.description,
          ])),
    ]);

    await _write(dir, 'vaccinations.csv', [
      _row(['Vaccine', 'Batch', 'Type', 'Scheduled', 'Administered', 'Status', 'Route/Unit', 'Notes']),
      ...vaccinations.map((v) => _row([
            v.vaccineName,
            batchRef(v.batchId),
            v.typeName,
            _date.format(v.scheduledDate),
            v.administeredDate != null ? _date.format(v.administeredDate!) : '',
            v.statusName,
            v.unit,
            v.notes,
          ])),
    ]);

    await _write(dir, 'feed_records.csv', [
      _row(['Date', 'Batch', 'Feed Type', 'Bags', 'Total Kg', 'Cost', 'Supplier', 'Notes']),
      ...feedRecords.map((r) => _row([
            _date.format(r.date),
            batchRef(r.batchId),
            r.feedTypeName,
            Units.bagShort(r.totalKg),
            r.totalKg,
            r.totalCost,
            r.supplier,
            r.notes,
          ])),
    ]);

    await _write(dir, 'egg_production.csv', [
      _row(['Date', 'Batch', 'Crates', 'Eggs', 'Damaged', 'Price/Crate', 'Revenue', 'Notes']),
      ...eggRecords.map((e) => _row([
            _date.format(e.date),
            batchRef(e.batchId),
            Units.crateShort(e.eggCount),
            e.eggCount,
            e.damagedCount,
            (e.pricePerEgg * Units.eggsPerCrate).toStringAsFixed(2),
            e.revenue,
            e.notes,
          ])),
    ]);

    await _write(dir, 'feed_inventory.csv', [
      _row(['Feed Type', 'Bags', 'Quantity Kg', 'Price/Bag', 'Total Value', 'Expiry', 'Supplier']),
      ...feedInventory.map((i) => _row([
            i.feedTypeName,
            Units.bagShort(i.quantityKg),
            i.quantityKg,
            (i.unitPrice * Units.kgPerBag).toStringAsFixed(2),
            i.totalValue,
            _date.format(i.expiryDate),
            i.supplier,
          ])),
    ]);

    await _write(dir, 'mortality.csv', [
      _row(['Date', 'Batch', 'Deaths', 'Cause', 'Notes']),
      ...mortalityRecords.map((m) => _row([
            _date.format(m.date),
            batchRef(m.batchId),
            m.count,
            m.causeName,
            m.notes,
          ])),
    ]);

    await _write(dir, 'egg_sales.csv', [
      _row(['Date', 'Buyer', 'Crates', 'Eggs', 'Price/Crate', 'Total', 'Paid', 'Owed', 'Notes']),
      ...eggSales.map((s) => _row([
            _date.format(s.date),
            s.buyer,
            Units.crateShort(s.eggCount),
            s.eggCount,
            (s.pricePerEgg * Units.eggsPerCrate).toStringAsFixed(2),
            s.total.toStringAsFixed(2),
            s.amountPaid.toStringAsFixed(2),
            s.owed.toStringAsFixed(2),
            s.notes,
          ])),
    ]);

    await _write(dir, 'transactions.csv', [
      _row(['Date', 'Type', 'Category', 'Amount', 'Batch', 'Description']),
      ...transactions.map((t) => _row([
            _date.format(t.date),
            t.type == TransactionType.income ? 'Income' : 'Expense',
            t.categoryName,
            t.amount,
            batchRef(t.batchId),
            t.description,
          ])),
    ]);

    return dir;
  }

  static Future<void> _write(
    Directory dir,
    String name,
    List<String> lines,
  ) async {
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(lines.join('\n'));
  }

  /// Opens the platform share sheet with every CSV in [dir]
  /// (WhatsApp, email, Drive, etc.).
  static Future<void> shareExport(Directory dir) async {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .map((f) => XFile(f.path, mimeType: 'text/csv'))
        .toList();
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      files: files,
      text: 'Hatch2Revenue farm data export',
      subject: 'Hatch2Revenue export',
    ));
  }
}
