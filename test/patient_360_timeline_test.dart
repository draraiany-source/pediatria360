import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/patient_360_timeline.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';
import 'package:pediatria360/shared/domain/entities/clinical_record.dart';
import 'package:pediatria360/shared/domain/entities/encounter.dart';

void main() {
  test('buildPatient360Timeline ordena do mais recente', () {
    final List<Patient360Event> events = buildPatient360Timeline(
      encounters: <Encounter>[
        Encounter(
          id: 'e1',
          patientId: 'p',
          professionalId: 'd',
          professionalName: 'Dra.',
          type: EncounterType.routine,
          status: EncounterStatus.signed,
          startedAt: DateTime(2024, 1, 1),
        ),
      ],
      appointments: <Appointment>[
        Appointment(
          id: 'a1',
          patientId: 'p',
          professionalId: 'd',
          professionalName: 'Dra.',
          startsAt: DateTime(2025, 1, 1),
          durationMinutes: 30,
          status: AppointmentStatus.confirmed,
          createdAt: DateTime(2024, 12, 1),
        ),
      ],
      documents: const <ClinicalDocument>[],
      labs: const <LabResult>[],
    );
    expect(events.length, 2);
    expect(events.first.kind, Patient360EventKind.appointment);
    expect(events.last.kind, Patient360EventKind.encounter);
  });
}
