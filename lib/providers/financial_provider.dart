import 'package:flutter/foundation.dart';
import '../models/financial_transaction.dart';

class FinancialProvider extends ChangeNotifier {
  final List<FinancialTransaction> _transactions = [];

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

  void addTransaction(FinancialTransaction transaction) {
    _transactions.add(transaction);
    notifyListeners();
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void updateTransaction(FinancialTransaction transaction) {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }
  }

  List<FinancialTransaction> getTransactionsForBatch(String batchId) {
    return _transactions.where((t) => t.batchId == batchId).toList();
  }

  void loadFromDb(List<Map<String, dynamic>> data) {
    _transactions.clear();
    for (var map in data) {
      _transactions.add(FinancialTransaction.fromMap(map));
    }
    notifyListeners();
  }

  Future<void> loadAllTransactions() async {
    notifyListeners();
  }
}
