import 'package:flutter/foundation.dart';
import '../models/financial_transaction.dart';
import '../services/database_service.dart';
import '../utils/app_feedback.dart';

class FinancialProvider extends ChangeNotifier {
  final List<FinancialTransaction> _transactions = [];
  bool _initialized = false;

  List<FinancialTransaction> get transactions => _transactions;

  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get netProfit => totalIncome - totalExpenses;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  /// Re-reads state from the database. Used at startup and to roll
  /// back optimistic in-memory updates after a failed write.
  Future<void> reload() async {
    try {
      final data = await DatabaseService.instance.getAllTransactions();
      _transactions
        ..clear()
        ..addAll(data.map(FinancialTransaction.fromMap));
      notifyListeners();
    } catch (e) {
      debugPrint(
        'FinancialProvider: DB load failed ($e) — running in memory.',
      );
    }
  }

  void addTransaction(FinancialTransaction transaction) {
    _transactions.add(transaction);
    notifyListeners();
    _persist(
      () => DatabaseService.instance.insertTransaction(transaction.toMap()),
    );
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    _persist(() => DatabaseService.instance.deleteTransaction(id));
  }

  void removeByBatchRefs(Set<String> refs) {
    final doomed =
        _transactions.where((t) => refs.contains(t.batchId)).toList();
    if (doomed.isEmpty) return;
    _transactions.removeWhere((t) => refs.contains(t.batchId));
    notifyListeners();
    for (final t in doomed) {
      _persist(() => DatabaseService.instance.deleteTransaction(t.id));
    }
  }

  void updateTransaction(FinancialTransaction transaction) {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
      _persist(
        () => DatabaseService.instance.updateTransaction(transaction.toMap()),
      );
    }
  }

  List<FinancialTransaction> getTransactionsForBatch(String batchId) {
    return _transactions.where((t) => t.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _transactions
      ..clear()
      ..addAll(data.map(FinancialTransaction.fromMap));
    notifyListeners();
  }

  /// Write-through persistence: awaits the DB write and, if it
  /// fails, reloads state from the database (undoing the optimistic
  /// update) and tells the user instead of failing silently.
  Future<void> _persist(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('FinancialProvider: DB write failed: $e');
      showAppError(
        'Could not save — the change was not stored. Please try again.',
      );
      await reload();
    }
  }
}
