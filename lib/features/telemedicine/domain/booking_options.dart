import 'package:equatable/equatable.dart';

import '../data/telemedicine_repository.dart';

/// Criança que a equipe pode agendar: só dados de agenda (sem prontuário).
class BookingPatient extends Equatable {
  const BookingPatient({
    required this.ownerUid,
    required this.childId,
    required this.childName,
    this.guardianName,
    this.lastProfessionalId,
  });

  final String ownerUid;
  final String childId;
  final String childName;
  final String? guardianName;
  final String? lastProfessionalId;

  String get label {
    final String g = (guardianName ?? '').trim();
    return g.isEmpty ? childName : '$childName · resp. $g';
  }

  @override
  List<Object?> get props => <Object?>[ownerUid, childId];
}

int _byName(BookingPatient a, BookingPatient b) =>
    a.childName.toLowerCase().compareTo(b.childName.toLowerCase());

/// Contatos de `clinics/{c}/crm_contacts` (recepção e gestão). Ignora
/// contatos mesclados e os que não têm titular ou criança.
List<BookingPatient> bookingPatientsFromCrm(
  Iterable<Map<String, dynamic>> contacts,
) {
  final Map<String, BookingPatient> out = <String, BookingPatient>{};
  for (final Map<String, dynamic> c in contacts) {
    if (c['mergedInto'] != null) continue;
    final String owner = (c['ownerUid'] as String?) ?? '';
    final String child = (c['childId'] as String?) ?? '';
    if (owner.isEmpty || child.isEmpty) continue;
    final String name = ((c['childName'] as String?) ?? '').trim();
    out.putIfAbsent(
      '$owner|$child',
      () => BookingPatient(
        ownerUid: owner,
        childId: child,
        childName: name.isEmpty ? 'Criança sem nome' : name,
        guardianName: c['guardianName'] as String?,
        lastProfessionalId: c['lastProfessionalId'] as String?,
      ),
    );
  }
  return out.values.toList()..sort(_byName);
}

/// Crianças já atendidas, a partir da agenda visível ao usuário (profissional
/// que não lê o CRM). A consulta mais recente define o último profissional.
List<BookingPatient> bookingPatientsFromAppointments(
  Iterable<Appointment> appointments,
) {
  final List<Appointment> sorted = appointments.toList()
    ..sort((Appointment a, Appointment b) => b.startsAt.compareTo(a.startsAt));
  final Map<String, BookingPatient> out = <String, BookingPatient>{};
  for (final Appointment a in sorted) {
    final String child = a.childId ?? '';
    if (child.isEmpty || a.patientId.isEmpty) continue;
    final String name = (a.childName ?? '').trim();
    out.putIfAbsent(
      '${a.patientId}|$child',
      () => BookingPatient(
        ownerUid: a.patientId,
        childId: child,
        childName: name.isEmpty ? 'Criança sem nome' : name,
        lastProfessionalId: a.professionalId,
      ),
    );
  }
  return out.values.toList()..sort(_byName);
}

/// Profissional e clínica com quem a família já tem consulta. Agendar pelo
/// app só vale para esses vínculos; o primeiro contato é pelo convite.
class FamilyBookingTarget extends Equatable {
  const FamilyBookingTarget({
    required this.professionalId,
    required this.professionalName,
    required this.clinicId,
    this.specialty,
  });

  final String professionalId;
  final String professionalName;
  final String clinicId;
  final String? specialty;

  String get label {
    final String s = (specialty ?? '').trim();
    return s.isEmpty ? professionalName : '$professionalName · $s';
  }

  @override
  List<Object?> get props => <Object?>[professionalId, clinicId];
}

List<FamilyBookingTarget> familyBookingTargets(
  Iterable<Appointment> mine,
) {
  final List<Appointment> sorted = mine.toList()
    ..sort((Appointment a, Appointment b) => b.startsAt.compareTo(a.startsAt));
  final Map<String, FamilyBookingTarget> out = <String, FamilyBookingTarget>{};
  for (final Appointment a in sorted) {
    final String clinic = a.clinicId ?? '';
    if (clinic.isEmpty || a.professionalId.isEmpty) continue;
    final String name = a.professionalName.trim();
    out.putIfAbsent(
      '${a.professionalId}|$clinic',
      () => FamilyBookingTarget(
        professionalId: a.professionalId,
        professionalName: name.isEmpty ? 'Profissional' : name,
        clinicId: clinic,
        specialty: a.specialty,
      ),
    );
  }
  return out.values.toList(growable: false);
}

/// Horários livres agrupados por dia (data local, sem hora), em ordem.
Map<DateTime, List<TimeSlot>> groupSlotsByDay(Iterable<TimeSlot> slots) {
  final List<TimeSlot> free = slots
      .where((TimeSlot s) => s.available)
      .toList()
    ..sort((TimeSlot a, TimeSlot b) => a.startsAt.compareTo(b.startsAt));
  final Map<DateTime, List<TimeSlot>> out = <DateTime, List<TimeSlot>>{};
  for (final TimeSlot s in free) {
    final DateTime d = DateTime(s.startsAt.year, s.startsAt.month, s.startsAt.day);
    final List<TimeSlot> day = out.putIfAbsent(d, () => <TimeSlot>[]);
    if (day.isEmpty || day.last.startsAt != s.startsAt) day.add(s);
  }
  return out;
}
