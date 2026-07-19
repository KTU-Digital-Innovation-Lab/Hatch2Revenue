import 'package:uuid/uuid.dart';

/// A sale of eggs from the store — separate from collection, because
/// eggs are gathered daily but sold later, often on credit ("book").
/// Cash-basis: income is recognised as money actually arrives
/// ([amountPaid]), and [owed] is the buyer's outstanding debt.
class EggSale {
  final String id;
  final DateTime date;
  final String buyer;
  final int eggCount;
  final double pricePerEgg;
  final double amountPaid;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EggSale({
    String? id,
    required this.date,
    required this.buyer,
    required this.eggCount,
    required this.pricePerEgg,
    this.amountPaid = 0,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get total => eggCount * pricePerEgg;

  double get owed => (total - amountPaid).clamp(0, double.infinity);

  bool get isPaid => owed <= 0.005; // tolerate float dust

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'buyer': buyer,
        'eggCount': eggCount,
        'pricePerEgg': pricePerEgg,
        'amountPaid': amountPaid,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EggSale.fromMap(Map<String, dynamic> map) => EggSale(
        id: map['id'],
        date: DateTime.parse(map['date']),
        buyer: map['buyer'] ?? '',
        eggCount: map['eggCount'] ?? 0,
        pricePerEgg: (map['pricePerEgg'] ?? 0).toDouble(),
        amountPaid: (map['amountPaid'] ?? 0).toDouble(),
        notes: map['notes'],
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
      );

  EggSale copyWith({
    DateTime? date,
    String? buyer,
    int? eggCount,
    double? pricePerEgg,
    double? amountPaid,
    String? notes,
  }) =>
      EggSale(
        id: id,
        date: date ?? this.date,
        buyer: buyer ?? this.buyer,
        eggCount: eggCount ?? this.eggCount,
        pricePerEgg: pricePerEgg ?? this.pricePerEgg,
        amountPaid: amountPaid ?? this.amountPaid,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
