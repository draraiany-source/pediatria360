import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/clinic_workflow.dart';
import 'package:pediatria360/features/clinic/domain/triage_record.dart';

void main() {
  group('ClinicWorkflowStatus.fromAppointmentStatus', () {
    test('requested -> scheduled', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('requested'),
        ClinicWorkflowStatus.scheduled,
      );
    });

    test('confirmed -> confirmed', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('confirmed'),
        ClinicWorkflowStatus.confirmed,
      );
    });

    test('inProgress -> inService', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('inProgress'),
        ClinicWorkflowStatus.inService,
      );
    });

    test('completed -> finished', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('completed'),
        ClinicWorkflowStatus.finished,
      );
    });

    test('cancelled -> cancelled', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('cancelled'),
        ClinicWorkflowStatus.cancelled,
      );
    });

    test('noShow -> noShow', () {
      expect(
        ClinicWorkflowStatus.fromAppointmentStatus('noShow'),
        ClinicWorkflowStatus.noShow,
      );
    });
  });

  group('labels pt-BR', () {
    test('todos os status tem label nao vazio', () {
      for (final ClinicWorkflowStatus s in ClinicWorkflowStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('toAppointmentStatusName', () {
    test('inService mapeia para inProgress', () {
      expect(
        ClinicWorkflowStatus.inService.toAppointmentStatusName(),
        'inProgress',
      );
    });

    test('waitingDoctor mantem confirmed na agenda', () {
      expect(
        ClinicWorkflowStatus.waitingDoctor.toAppointmentStatusName(),
        'confirmed',
      );
    });
  });

  group('TriageRecord.bmi', () {
    test('calcula IMC quando peso e altura existem', () {
      final TriageRecord r = TriageRecord(
        id: 't1',
        appointmentId: 'a1',
        childId: 'c1',
        professionalId: 'p1',
        recordedBy: 'p1',
        recordedAt: DateTime(2026, 1, 1),
        weightKg: 16,
        heightCm: 100,
      );
      expect(r.bmi, closeTo(16.0, 0.01));
    });

    test('bmi null sem altura', () {
      final TriageRecord r = TriageRecord(
        id: 't1',
        appointmentId: 'a1',
        childId: 'c1',
        professionalId: 'p1',
        recordedBy: 'p1',
        recordedAt: DateTime(2026, 1, 1),
        weightKg: 16,
      );
      expect(r.bmi, isNull);
    });
  });
}
