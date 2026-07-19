import 'package:flutter/foundation.dart';
import '../models/egg_sale.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class EggSalesProvider extends ChangeNotifier {
  final List<EggSale> _sales = [];
  bool _initialized = false;

  List<EggSale> get sales => _sales;

  int get totalEggsSold => _sales.fold(0, (s, e) => s + e.eggCount);

  /// Money buyers still owe across every unsettled sale.
  double get totalOutstanding => _sales.fold(0.0, (s, e) => s + e.owed);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllEggSales();
      _sales
        ..clear()
        ..addAll(data.map(EggSale.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint('EggSalesProvider: DB load failed ($e) — running in memory.');
    }
  }

  void addSale(EggSale sale) {
    _sales.insert(0, sale);
    notifyListeners();
    _persist(() => DatabaseService.instance.insertEggSale(sale.toMap()));
  }

  void updateSale(EggSale sale) {
    final i = _sales.indexWhere((s) => s.id == sale.id);
    if (i == -1) return;
    _sales[i] = sale;
    notifyListeners();
    _persist(() => DatabaseService.instance.updateEggSale(sale.toMap()));
  }

  /// Adds [amount] to what the buyer has paid on [id].
  void recordPayment(String id, double amount) {
    final i = _sales.indexWhere((s) => s.id == id);
    if (i == -1) return;
    updateSale(_sales[i].copyWith(amountPaid: _sales[i].amountPaid + amount));
  }

  void removeSale(String id) {
    _sales.removeWhere((s) => s.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteEggSale(id));
  }

  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('EggSalesProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
