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
}

class FinancialTransaction {
  final String id;
  final String? batchId;
  final DateTime date;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final String? description;
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
  }) {
    return FinancialTransaction(
      id: id,
      batchId: batchId ?? this.batchId,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
