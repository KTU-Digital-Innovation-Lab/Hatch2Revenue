import 'package:uuid/uuid.dart';

/// A poultry house / coop. Flocks link to a house through
/// Batch.coopId, so the owner can group batches by where they are kept.
class PoultryHouse {
  final String id;
  final String name;
  final int capacity;
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  PoultryHouse({
    String? id,
    required this.name,
    this.capacity = 0,
    this.location,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capacity': capacity,
      'location': location,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PoultryHouse.fromMap(Map<String, dynamic> map) {
    return PoultryHouse(
      id: map['id'],
      name: map['name'] ?? '',
      capacity: map['capacity'] ?? 0,
      location: map['location'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  PoultryHouse copyWith({
    String? name,
    int? capacity,
    String? location,
    String? notes,
  }) {
    return PoultryHouse(
      id: id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
