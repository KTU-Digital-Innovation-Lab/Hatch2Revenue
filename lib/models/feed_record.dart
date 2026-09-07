import 'package:uuid/uuid.dart';

enum FeedType { starter, grower, layer, finisher, custom }

class FeedRecord {
  final String id;
  final String batchId;
  final DateTime date;
  final FeedType feedType;
  final int bagsUsed;
  final double kgPerBag;
  final double unitPricePerBag;
  final String? supplier;
  final String? batchNumber;
  final String? notes;
  /// The feed_inventory item this consumption was drawn from, so logging
  /// depletes that stock and deleting or editing the log restores it.
  /// Local-only (not synced): the stock quantity itself syncs instead.
  final String? stockItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedRecord({
    String? id,
    required this.batchId,
    required this.date,
    required this.feedType,
    required this.bagsUsed,
    required this.kgPerBag,
    required this.unitPricePerBag,
    this.supplier,
    this.batchNumber,
    this.notes,
    this.stockItemId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get totalKg => bagsUsed * kgPerBag;

  double get totalCost => bagsUsed * unitPricePerBag;

  double get unitPricePerKg => unitPricePerBag / kgPerBag;

  String get feedTypeName {
    switch (feedType) {
      case FeedType.starter:
        return 'Starter';
      case FeedType.grower:
        return 'Grower';
      case FeedType.layer:
        return 'Layer';
      case FeedType.finisher:
        return 'Finisher';
      case FeedType.custom:
        return 'Custom';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'date': date.toIso8601String(),
      'feedType': feedType.index,
      'bagsUsed': bagsUsed,
      'kgPerBag': kgPerBag,
      'unitPricePerBag': unitPricePerBag,
      'supplier': supplier,
      'batchNumber': batchNumber,
      'notes': notes,
      'stockItemId': stockItemId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FeedRecord.fromMap(Map<String, dynamic> map) {
    return FeedRecord(
      id: map['id'],
      batchId: map['batchId'],
      date: DateTime.parse(map['date']),
      feedType: FeedType.values[map['feedType']],
      bagsUsed: map['bagsUsed'],
      kgPerBag: map['kgPerBag']?.toDouble() ?? 50.0,
      unitPricePerBag: map['unitPricePerBag']?.toDouble() ?? 0.0,
      supplier: map['supplier'],
      batchNumber: map['batchNumber'],
      notes: map['notes'],
      stockItemId: map['stockItemId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  FeedRecord copyWith({
    String? batchId,
    DateTime? date,
    FeedType? feedType,
    int? bagsUsed,
    double? kgPerBag,
    double? unitPricePerBag,
    String? supplier,
    String? batchNumber,
    String? notes,
    String? stockItemId,
  }) {
    return FeedRecord(
      id: id,
      batchId: batchId ?? this.batchId,
      date: date ?? this.date,
      feedType: feedType ?? this.feedType,
      bagsUsed: bagsUsed ?? this.bagsUsed,
      kgPerBag: kgPerBag ?? this.kgPerBag,
      unitPricePerBag: unitPricePerBag ?? this.unitPricePerBag,
      supplier: supplier ?? this.supplier,
      batchNumber: batchNumber ?? this.batchNumber,
      notes: notes ?? this.notes,
      stockItemId: stockItemId ?? this.stockItemId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class FeedInventory {
  final String id;
  final String feedTypeName;
  final double quantityKg;
  final double unitPrice;
  final DateTime expiryDate;
  final String? supplier;
  final String? batchNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedInventory({
    String? id,
    required this.feedTypeName,
    required this.quantityKg,
    required this.unitPrice,
    required this.expiryDate,
    this.supplier,
    this.batchNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  double get totalValue => quantityKg * unitPrice;

  bool get isExpired => expiryDate.isBefore(DateTime.now());

  bool get isLowStock => quantityKg < 50;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'feedTypeName': feedTypeName,
      'quantityKg': quantityKg,
      'unitPrice': unitPrice,
      'expiryDate': expiryDate.toIso8601String(),
      'supplier': supplier,
      'batchNumber': batchNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FeedInventory.fromMap(Map<String, dynamic> map) {
    return FeedInventory(
      id: map['id'],
      feedTypeName: map['feedTypeName'],
      quantityKg: map['quantityKg'].toDouble(),
      unitPrice: map['unitPrice'].toDouble(),
      expiryDate: DateTime.parse(map['expiryDate']),
      supplier: map['supplier'],
      batchNumber: map['batchNumber'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  FeedInventory copyWith({
    String? feedTypeName,
    double? quantityKg,
    double? unitPrice,
    DateTime? expiryDate,
    String? supplier,
    String? batchNumber,
  }) {
    return FeedInventory(
      id: id,
      feedTypeName: feedTypeName ?? this.feedTypeName,
      quantityKg: quantityKg ?? this.quantityKg,
      unitPrice: unitPrice ?? this.unitPrice,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      batchNumber: batchNumber ?? this.batchNumber,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
