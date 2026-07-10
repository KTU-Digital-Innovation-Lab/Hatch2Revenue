import 'package:uuid/uuid.dart';

enum VaccineType { viral, bacterial, parasitic, fungal, vitamin, antibiotic }

enum VaccinationStatus { scheduled, completed, missed, cancelled }

class Vaccination {
  final String id;
  final String batchId;
  final String vaccineName;
  final VaccineType type;
  final DateTime scheduledDate;
  final DateTime? administeredDate;
  final VaccinationStatus status;
  final double? dosage;
  final String? unit;
  final String? administeredBy;
  final String? notes;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vaccination({
    String? id,
    required this.batchId,
    required this.vaccineName,
    required this.type,
    required this.scheduledDate,
    this.administeredDate,
    this.status = VaccinationStatus.scheduled,
    this.dosage,
    this.unit,
    this.administeredBy,
    this.notes,
    this.reminderEnabled = true,
    this.reminderDaysBefore = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isOverdue =>
      status == VaccinationStatus.scheduled &&
      scheduledDate.isBefore(DateTime.now());

  int get daysUntilDue => scheduledDate.difference(DateTime.now()).inDays;

  String get typeName {
    switch (type) {
      case VaccineType.viral:
        return 'Viral';
      case VaccineType.bacterial:
        return 'Bacterial';
      case VaccineType.parasitic:
        return 'Parasitic';
      case VaccineType.fungal:
        return 'Fungal';
      case VaccineType.vitamin:
        return 'Vitamin';
      case VaccineType.antibiotic:
        return 'Antibiotic';
    }
  }

  String get statusName {
    switch (status) {
      case VaccinationStatus.scheduled:
        return 'Scheduled';
      case VaccinationStatus.completed:
        return 'Completed';
      case VaccinationStatus.missed:
        return 'Missed';
      case VaccinationStatus.cancelled:
        return 'Cancelled';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'batchId': batchId,
      'vaccineName': vaccineName,
      'type': type.index,
      'scheduledDate': scheduledDate.toIso8601String(),
      'administeredDate': administeredDate?.toIso8601String(),
      'status': status.index,
      'dosage': dosage,
      'unit': unit,
      'administeredBy': administeredBy,
      'notes': notes,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderDaysBefore': reminderDaysBefore,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Vaccination.fromMap(Map<String, dynamic> map) {
    return Vaccination(
      id: map['id'],
      batchId: map['batchId'],
      vaccineName: map['vaccineName'],
      type: VaccineType.values[map['type']],
      scheduledDate: DateTime.parse(map['scheduledDate']),
      administeredDate: map['administeredDate'] != null
          ? DateTime.parse(map['administeredDate'])
          : null,
      status: VaccinationStatus.values[map['status']],
      dosage: map['dosage'],
      unit: map['unit'],
      administeredBy: map['administeredBy'],
      notes: map['notes'],
      reminderEnabled: map['reminderEnabled'] == 1,
      reminderDaysBefore: map['reminderDaysBefore'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Vaccination copyWith({
    String? batchId,
    String? vaccineName,
    VaccineType? type,
    DateTime? scheduledDate,
    DateTime? administeredDate,
    VaccinationStatus? status,
    double? dosage,
    String? unit,
    String? administeredBy,
    String? notes,
    bool? reminderEnabled,
    int? reminderDaysBefore,
  }) {
    return Vaccination(
      id: id,
      batchId: batchId ?? this.batchId,
      vaccineName: vaccineName ?? this.vaccineName,
      type: type ?? this.type,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      administeredDate: administeredDate ?? this.administeredDate,
      status: status ?? this.status,
      dosage: dosage ?? this.dosage,
      unit: unit ?? this.unit,
      administeredBy: administeredBy ?? this.administeredBy,
      notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

// Predefined vaccination schedule templates
class VaccinationTemplate {
  final String name;
  final int dayOfAge;
  final VaccineType type;
  final String description;

  const VaccinationTemplate({
    required this.name,
    required this.dayOfAge,
    required this.type,
    required this.description,
  });

  static const List<VaccinationTemplate> templates = [
    VaccinationTemplate(
      name: 'Marek\'s Vaccine',
      dayOfAge: 1,
      type: VaccineType.viral,
      description: 'Vaccination against Marek\'s disease',
    ),
    VaccinationTemplate(
      name: 'Newcastle Disease (ND)',
      dayOfAge: 7,
      type: VaccineType.viral,
      description: 'First Newcastle disease vaccination',
    ),
    VaccinationTemplate(
      name: 'Infectious Bronchitis (IB)',
      dayOfAge: 14,
      type: VaccineType.viral,
      description: 'Infectious bronchitis vaccination',
    ),
    VaccinationTemplate(
      name: 'Gumboro/IBD',
      dayOfAge: 18,
      type: VaccineType.viral,
      description: 'Infectious Bursal Disease vaccination',
    ),
    VaccinationTemplate(
      name: 'Newcastle Disease (ND) Booster',
      dayOfAge: 21,
      type: VaccineType.viral,
      description: 'Second Newcastle disease vaccination',
    ),
    VaccinationTemplate(
      name: 'Fowl Pox',
      dayOfAge: 28,
      type: VaccineType.viral,
      description: 'Fowl pox vaccination',
    ),
    VaccinationTemplate(
      name: 'Infectious Coryza',
      dayOfAge: 35,
      type: VaccineType.bacterial,
      description: 'Infectious coryza vaccination',
    ),
    VaccinationTemplate(
      name: 'Layer Booster',
      dayOfAge: 60,
      type: VaccineType.viral,
      description: 'Booster vaccination before laying',
    ),
    VaccinationTemplate(
      name: 'Newcastle Disease (ND) Layer',
      dayOfAge: 120,
      type: VaccineType.viral,
      description: 'Layer Newcastle disease vaccination',
    ),
  ];
}
