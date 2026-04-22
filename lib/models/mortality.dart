import 'package:uuid/uuid.dart';

enum MortalityCause {
  disease,
  predator,
  heatStress,
  cold,
  suffocation,
  unknown,
}

class Mortality {
  final String id;
  final String batchId;
  final DateTime date;
  final int count;
  final MortalityCause? cause;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Mortality({
    String? id,
    required this.batchId,
    required this.date,
    required this.count,
    this.cause,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get causeName {
    if (cause == null) return 'Unknown';
    switch (cause!) {
      case MortalityCause.disease:
        return 'Disease';
      case MortalityCause.predator:
        return 'Predator';
      case MortalityCause.heatStress:
        return 'Heat Stress';
      case MortalityCause.cold:
        return 'Cold';
      case MortalityCause.suffocation:
        return 'Suffocation';
      case MortalityCause.unknown:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'date': date.toIso8601String(),
      'count': count,
      'cause': cause?.index,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Mortality.fromMap(Map<String, dynamic> map) {
    return Mortality(
      id: map['id'],
      batchId: map['batchId'],
      date: DateTime.parse(map['date']),
      count: map['count'],
      cause: map['cause'] != null ? MortalityCause.values[map['cause']] : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Mortality copyWith({
    String? batchId,
    DateTime? date,
    int? count,
    MortalityCause? cause,
    String? notes,
  }) {
    return Mortality(
      id: id,
      batchId: batchId ?? this.batchId,
      date: date ?? this.date,
      count: count ?? this.count,
      cause: cause ?? this.cause,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
