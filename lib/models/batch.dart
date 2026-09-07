import 'package:uuid/uuid.dart';

enum BatchType { dayOldChicks, growers, layers }

/// The stage a flock is actually in, derived from its age rather than
/// the type it was registered as. A flock entered as day-old chicks
/// becomes a grower and then a layer as it ages, without the owner
/// having to change anything.
enum BatchStage { brooding, grower, layer }

extension BatchStageInfo on BatchStage {
  String get label {
    switch (this) {
      case BatchStage.brooding:
        return 'Brooding';
      case BatchStage.grower:
        return 'Grower';
      case BatchStage.layer:
        return 'Layer';
    }
  }
}

class Batch {
  final String id;
  final String name;
  final String? description;
  final BatchType type;
  final int initialCount;
  final int currentCount;
  final DateTime hatchDate;

  /// The breed / strain of the flock (labelled "Breed" in the UI).
  final String? source;

  /// Where the chicks came from — hatchery or supplier ("Source of chicks").
  final String? supplier;
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
    this.supplier,
    this.initialCost,
    this.coopId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get ageInDays => DateTime.now().difference(hatchDate).inDays;

  /// Current stage, worked out from the flock's age. Point of lay is
  /// 16-22 weeks, so a flock is treated as a layer from week 16. The
  /// registered [type] is a floor: a flock the owner entered as growers
  /// or layers never shows younger than that, even before its age would
  /// imply it (useful when the entry date is approximate).
  BatchStage get currentStage {
    if (type == BatchType.layers) return BatchStage.layer;
    final weeks = ageInDays / 7;
    if (weeks >= 16) return BatchStage.layer;
    if (type == BatchType.growers || weeks >= 4) return BatchStage.grower;
    return BatchStage.brooding;
  }

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
      'supplier': supplier,
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
      supplier: map['supplier'],
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
    String? supplier,
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
      supplier: supplier ?? this.supplier,
      initialCost: initialCost ?? this.initialCost,
      coopId: coopId ?? this.coopId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
