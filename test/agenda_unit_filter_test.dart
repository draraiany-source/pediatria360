import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';
import 'package:pediatria360/features/telemedicine/domain/agenda_unit_filter.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

void main() {
  final DateTime t = DateTime.utc(2026, 3, 1, 10);

  Appointment appt({String? unitId, String? roomLabel}) => Appointment(
        id: 'a1',
        patientId: 'p1',
        professionalId: 'pro1',
        professionalName: 'Dr',
        startsAt: t,
        durationMinutes: 30,
        status: AppointmentStatus.confirmed,
        createdAt: t,
        unitId: unitId,
        roomLabel: roomLabel,
      );

  test('no filter when membership has empty unitIds', () {
    final List<Appointment> items = <Appointment>[appt(unitId: 'u1')];
    expect(filterAgendaByMembershipUnits(items, null), items);
    expect(
      filterAgendaByMembershipUnits(
        items,
        ClinicMembership(
          id: 'm',
          clinicId: 'c',
          userId: 'u',
          role: ClinicRole.receptionist,
          createdAt: t,
        ),
      ),
      items,
    );
  });

  test('filters by unitId and keeps legacy null unitId', () {
    final ClinicMembership m = ClinicMembership(
      id: 'm',
      clinicId: 'c',
      userId: 'u',
      role: ClinicRole.receptionist,
      createdAt: t,
      unitIds: const <String>['unit-a'],
    );
    final List<Appointment> items = <Appointment>[
      appt(unitId: 'unit-a'),
      appt(unitId: 'unit-b'),
      appt(),
    ];
    final List<Appointment> filtered = filterAgendaByMembershipUnits(items, m);
    expect(filtered.length, 2);
    expect(filtered.any((Appointment a) => a.unitId == 'unit-b'), isFalse);
  });
}
