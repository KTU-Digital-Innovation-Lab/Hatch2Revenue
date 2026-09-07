import 'package:uuid/uuid.dart';

/// A single flock reading. One row holds one typed value, so weight,
/// temperature and water share the `measurements` table and cloud mirror.
enum MeasurementType { weight, temperature, water }

extension MeasurementTypeInfo on MeasurementType {
  String get label {
    switch (this) {
      case MeasurementType.weight:
        return 'Weight';
      case MeasurementType.temperature:
        return 'Temperature';
      case MeasurementType.water:
        return 'Water';
    }
  }

  /// Display unit for the reading.
  String get unit {
    switch (this) {
      case MeasurementType.weight:
        return 'g';
      case MeasurementType.temperature:
        return '°C';
      case MeasurementType.water:
        return 'L';
    }
  }
}

class Measurement {
  final String id;
  final String batchId;
  final DateTime date;
  final MeasurementType type;

  /// Reading in the type's unit: grams (weight), Celsius (temperature),
  /// or litres (water).
  final double value;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Measurement({
    String? id,
    required this.batchId,
    required this.date,
    required this.type,
    required this.value,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'date': date.toIso8601String(),
      'type': type.index,
      'value': value,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'],
      batchId: map['batchId'],
      date: DateTime.parse(map['date']),
      type: MeasurementType.values[map['type'] ?? 0],
      value: (map['value'] as num).toDouble(),
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Measurement copyWith({
    DateTime? date,
    MeasurementType? type,
    double? value,
    String? notes,
  }) {
    return Measurement(
      id: id,
      batchId: batchId,
      date: date ?? this.date,
      type: type ?? this.type,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
