import 'package:uuid/uuid.dart';

enum TransactionType { income, expense }

enum TransactionCategory {
  feed,
  vaccine,
  labor,
  eggSales,
  birdSales,
  equipment,
  utilities,
  other,
  // Appended last: the category index is persisted in SQLite/cloud rows,
  // so existing data depends on the order above never changing.
  birdPurchase,
}

class FinancialTransaction {
  final String id;
  final String? batchId;
  final DateTime date;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String? description;
  /// The record this transaction was auto-posted from (a feed log, a feed
  /// stock purchase, an egg sale, a batch). Deleting or editing that record
  /// removes/adjusts this transaction, so the books never keep an orphan.
  /// Null for transactions the farmer entered by hand. Local-only, not
  /// synced (matching the pattern used for feed_records.stockItemId).
  final String? sourceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinancialTransaction({
    String? id,
    this.batchId,
    required this.date,
    required this.type,
    required this.category,
    required this.amount,
    this.description,
    this.sourceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get categoryName {
    switch (category) {
      case TransactionCategory.feed:
        return 'Feed';
      case TransactionCategory.vaccine:
        return 'Vaccine';
      case TransactionCategory.labor:
        return 'Labor';
      case TransactionCategory.eggSales:
        return 'Egg Sales';
      case TransactionCategory.birdSales:
        return 'Bird Sales';
      case TransactionCategory.equipment:
        return 'Equipment';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.other:
        return 'Other';
      case TransactionCategory.birdPurchase:
        return 'Bird Purchase';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'date': date.toIso8601String(),
      'type': type.index,
      'category': category.index,
      'amount': amount,
      'description': description,
      'sourceId': sourceId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'],
      batchId: map['batchId'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values[map['type']],
      category: TransactionCategory.values[map['category']],
      amount: map['amount'].toDouble(),
      description: map['description'],
      sourceId: map['sourceId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  FinancialTransaction copyWith({
    String? batchId,
    DateTime? date,
    TransactionType? type,
    TransactionCategory? category,
    double? amount,
    String? description,
    String? sourceId,
  }) {
    return FinancialTransaction(
      id: id,
      batchId: batchId ?? this.batchId,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
