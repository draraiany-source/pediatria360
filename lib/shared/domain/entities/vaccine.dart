import 'package:equatable/equatable.dart';

/// Uma dose prevista no calendário, ainda sem vínculo com uma criança.
class VaccineDoseSchedule extends Equatable {
  const VaccineDoseSchedule({
    required this.vaccineId,
    required this.vaccineName,
    required this.doseLabel,
    required this.doseIndex,
    required this.ageMonths,
    this.protects = '',
    this.notes,
  });

  final String vaccineId;
  final String vaccineName;

  /// "1ª dose", "Reforço", "Dose única".
  final String doseLabel;

  final int doseIndex;

  /// Idade recomendada, em meses. Zero significa ao nascer.
  final int ageMonths;

  /// Doenças que a dose previne — o que o responsável realmente quer saber.
  final String protects;

  final String? notes;

  String get id => '$vaccineId-$doseIndex';

  /// Rótulo de idade em linguagem corrente.
  String get ageLabel {
    if (ageMonths == 0) return 'Ao nascer';
    if (ageMonths < 24) return '$ageMonths ${ageMonths == 1 ? 'mês' : 'meses'}';
    final int years = ageMonths ~/ 12;
    final int months = ageMonths % 12;
    if (months == 0) return '$years ${years == 1 ? 'ano' : 'anos'}';
    return '$years anos e $months meses';
  }

  @override
  List<Object?> get props => <Object?>[vaccineId, doseIndex];
}

/// Registro de uma dose para uma criança específica.
class VaccineDose extends Equatable {
  const VaccineDose({
    required this.id,
    required this.childId,
    required this.vaccineId,
    required this.doseIndex,
    required this.updatedAt,
    this.dueAt,
    this.appliedAt,
    this.lot,
    this.clinic,
    this.proofUrl,
    this.pendingSync = false,
  });

  final String id;
  final String childId;
  final String vaccineId;
  final int doseIndex;
  final DateTime updatedAt;

  /// Data prevista, calculada a partir do nascimento.
  final DateTime? dueAt;

  /// Data de aplicação. `null` = ainda não tomada.
  final DateTime? appliedAt;

  final String? lot;
  final String? clinic;

  /// Foto da caderneta guardada no Storage.
  final String? proofUrl;

  final bool pendingSync;

  bool get isApplied => appliedAt != null;

  /// Atrasada: passou da data prevista e não foi aplicada.
  bool isOverdue({DateTime? at}) {
    if (isApplied || dueAt == null) return false;
    return dueAt!.isBefore(at ?? DateTime.now());
  }

  /// Próxima: vence nos próximos 30 dias.
  bool isUpcoming({DateTime? at}) {
    if (isApplied || dueAt == null) return false;
    final DateTime now = at ?? DateTime.now();
    return dueAt!.isAfter(now) &&
        dueAt!.difference(now).inDays <= 30;
  }

  VaccineDose copyWith({
    DateTime? dueAt,
    DateTime? appliedAt,
    String? lot,
    String? clinic,
    String? proofUrl,
    DateTime? updatedAt,
    bool? pendingSync,
    bool clearApplied = false,
  }) =>
      VaccineDose(
        id: id,
        childId: childId,
        vaccineId: vaccineId,
        doseIndex: doseIndex,
        dueAt: dueAt ?? this.dueAt,
        appliedAt: clearApplied ? null : (appliedAt ?? this.appliedAt),
        lot: lot ?? this.lot,
        clinic: clinic ?? this.clinic,
        proofUrl: proofUrl ?? this.proofUrl,
        updatedAt: updatedAt ?? this.updatedAt,
        pendingSync: pendingSync ?? this.pendingSync,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        childId,
        vaccineId,
        doseIndex,
        dueAt,
        appliedAt,
        lot,
        clinic,
        proofUrl,
        updatedAt,
        pendingSync,
      ];
}

/// Situação de uma dose, para agrupar a lista na tela.
enum DoseStatus {
  applied,
  overdue,
  upcoming,
  scheduled;

  String get label => switch (this) {
        DoseStatus.applied => 'Aplicada',
        DoseStatus.overdue => 'Em atraso',
        DoseStatus.upcoming => 'Próxima',
        DoseStatus.scheduled => 'Prevista',
      };
}
