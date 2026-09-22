import '../../../shared/domain/entities/clinical_record.dart';
import '../../../shared/domain/entities/encounter.dart';
import '../../telemedicine/data/telemedicine_repository.dart';

enum Patient360EventKind {
  encounter,
  appointment,
  document,
  lab,
}

class Patient360Event {
  const Patient360Event({
    required this.at,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.encounterId,
    this.flagged = false,
  });

  final DateTime at;
  final Patient360EventKind kind;
  final String title;
  final String subtitle;
  final String? encounterId;
  final bool flagged;
}

List<Patient360Event> buildPatient360Timeline({
  required List<Encounter> encounters,
  required List<Appointment> appointments,
  required List<ClinicalDocument> documents,
  required List<LabResult> labs,
}) {
  final List<Patient360Event> events = <Patient360Event>[];

  for (final Encounter e in encounters) {
    final String dx = e.primaryDiagnosis?.description ?? e.type.label;
    events.add(
      Patient360Event(
        at: e.startedAt,
        kind: Patient360EventKind.encounter,
        title: e.status == EncounterStatus.draft
            ? 'Rascunho de atendimento'
            : 'Atendimento',
        subtitle: e.professionalName + ' - ' + dx,
        encounterId: e.id,
        flagged: e.status == EncounterStatus.draft ||
            e.amendsEncounterId != null,
      ),
    );
  }

  for (final Appointment a in appointments) {
    final String extra = (a.reason != null && a.reason!.isNotEmpty)
        ? (' - ' + a.reason!)
        : '';
    events.add(
      Patient360Event(
        at: a.startsAt,
        kind: Patient360EventKind.appointment,
        title: a.type.label,
        subtitle: a.professionalName + ' - ' + a.status.label + extra,
        flagged: a.status == AppointmentStatus.noShow,
      ),
    );
  }

  for (final ClinicalDocument d in documents) {
    events.add(
      Patient360Event(
        at: d.issuedAt,
        kind: Patient360EventKind.document,
        title: d.type.label,
        subtitle: d.cancelled
            ? 'Cancelado'
            : (d.isSigned ? 'Assinado' : 'Emitido'),
        flagged: d.cancelled,
      ),
    );
  }

  final Map<String, List<LabResult>> byDay = <String, List<LabResult>>{};
  for (final LabResult lab in labs) {
    final DateTime at = lab.collectedAt;
    final String key = at.year.toString() + '-' +
        at.month.toString().padLeft(2, '0') + '-' +
        at.day.toString().padLeft(2, '0');
    byDay.putIfAbsent(key, () => <LabResult>[]).add(lab);
  }
  for (final List<LabResult> group in byDay.values) {
    final DateTime at = group.first.collectedAt;
    final bool flagged = group.any((LabResult l) => l.isOutOfRange);
    final String title = group.length == 1
        ? (group.first.analyte.isNotEmpty ? group.first.analyte : 'Exame')
        : (group.length.toString() + ' exames');
    events.add(
      Patient360Event(
        at: at,
        kind: Patient360EventKind.lab,
        title: title,
        subtitle: flagged ? 'Ha resultado fora da faixa' : 'Laboratorio',
        flagged: flagged,
      ),
    );
  }

  events.sort((Patient360Event a, Patient360Event b) => b.at.compareTo(a.at));
  return events;
}
