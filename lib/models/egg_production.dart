import 'package:uuid/uuid.dart';

class EggProduction {
  final String id;
  final String batchId;
  final DateTime date;
  final int eggCount;
  final int damagedCount;
  final double pricePerEgg;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  EggProduction({
    String? id,
    required this.batchId,
    required this.date,
    required this.eggCount,
    this.damagedCount = 0,
    required this.pricePerEgg,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get revenue => eggCount * pricePerEgg;

  double get productionRate => 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'date': date.toIso8601String(),
      'eggCount': eggCount,
      'damagedCount': damagedCount,
      'pricePerEgg': pricePerEgg,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EggProduction.fromMap(Map<String, dynamic> map) {
    return EggProduction(
      id: map['id'],
      batchId: map['batchId'],
      date: DateTime.parse(map['date']),
      eggCount: map['eggCount'],
      damagedCount: map['damagedCount'] ?? 0,
      pricePerEgg: map['pricePerEgg']?.toDouble() ?? 1.0,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  EggProduction copyWith({
    String? batchId,
    DateTime? date,
    int? eggCount,
    int? damagedCount,
    double? pricePerEgg,
    String? notes,
  }) {
    return EggProduction(
      id: id,
      batchId: batchId ?? this.batchId,
      date: date ?? this.date,
      eggCount: eggCount ?? this.eggCount,
      damagedCount: damagedCount ?? this.damagedCount,
      pricePerEgg: pricePerEgg ?? this.pricePerEgg,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
