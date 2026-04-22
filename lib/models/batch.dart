import 'package:uuid/uuid.dart';

enum BatchType { dayOldChicks, growers, layers }

class Batch {
  final String id;
  final String name;
  final String? description;
  final BatchType type;
  final int initialCount;
  final int currentCount;
  final DateTime hatchDate;
  final String? source;
  final double? initialCost;
  final String? coopId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Batch({
    String? id,
    required this.name,
    this.description,
    required this.type,
    required this.initialCount,
    required this.currentCount,
    required this.hatchDate,
    this.source,
    this.initialCost,
    this.coopId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get ageInDays => DateTime.now().difference(hatchDate).inDays;

  int get mortalityCount => initialCount - currentCount;

  double get mortalityRate =>
      initialCount > 0 ? (mortalityCount / initialCount) * 100 : 0;

  String get typeName {
    switch (type) {
      case BatchType.dayOldChicks:
        return 'Day-old Chicks';
      case BatchType.growers:
        return 'Growers';
      case BatchType.layers:
        return 'Layers';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.index,
      'initialCount': initialCount,
      'currentCount': currentCount,
      'hatchDate': hatchDate.toIso8601String(),
      'source': source,
      'initialCost': initialCost,
      'coopId': coopId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Batch.fromMap(Map<String, dynamic> map) {
    return Batch(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      type: BatchType.values[map['type']],
      initialCount: map['initialCount'],
      currentCount: map['currentCount'],
      hatchDate: DateTime.parse(map['hatchDate']),
      source: map['source'],
      initialCost: map['initialCost'],
      coopId: map['coopId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Batch copyWith({
    String? name,
    String? description,
    BatchType? type,
    int? initialCount,
    int? currentCount,
    DateTime? hatchDate,
    String? source,
    double? initialCost,
    String? coopId,
  }) {
    return Batch(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      initialCount: initialCount ?? this.initialCount,
      currentCount: currentCount ?? this.currentCount,
      hatchDate: hatchDate ?? this.hatchDate,
      source: source ?? this.source,
      initialCost: initialCost ?? this.initialCost,
      coopId: coopId ?? this.coopId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
