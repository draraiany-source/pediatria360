import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/agenda_scheduling.dart';
import 'package:pediatria360/features/children/domain/child_guardian.dart';

void main() {
  group('findAgendaConflict', () {
    final DateTime t0 = DateTime(2026, 9, 24, 10);

    test('detecta conflito de profissional no mesmo horario', () {
      final AgendaConflict? c = findAgendaConflict(
        startsAt: t0,
        durationMinutes: 30,
        professionalId: 'dr1',
        existing: <AgendaInterval>[
          AgendaInterval(
            id: 'a1',
            startsAt: t0.add(const Duration(minutes: 15)),
            durationMinutes: 30,
            professionalId: 'dr1',
            roomId: 'salaA',
          ),
        ],
      );
      expect(c, isNotNull);
      expect(c!.reason, contains('profissional'));
    });

    test('detecta conflito de sala com profissionais diferentes', () {
      final AgendaConflict? c = findAgendaConflict(
        startsAt: t0,
        durationMinutes: 40,
        professionalId: 'dr2',
        roomId: 'salaA',
        existing: <AgendaInterval>[
          AgendaInterval(
            id: 'a1',
            startsAt: t0,
            durationMinutes: 40,
            professionalId: 'dr1',
            roomId: 'salaA',
          ),
        ],
      );
      expect(c, isNotNull);
      expect(c!.reason, contains('sala'));
    });

    test('bloqueio impede agendamento', () {
      final AgendaConflict? c = findAgendaConflict(
        startsAt: t0,
        durationMinutes: 30,
        professionalId: 'dr1',
        existing: const <AgendaInterval>[],
        blocks: <ScheduleBlock>[
          ScheduleBlock(
            id: 'b1',
            startsAt: t0.subtract(const Duration(minutes: 10)),
            endsAt: t0.add(const Duration(hours: 1)),
            professionalId: 'dr1',
            reason: 'Almoco',
          ),
        ],
      );
      expect(c, isNotNull);
      expect(c!.reason, contains('Almoco'));
    });

    test('cancelado nao gera conflito', () {
      final AgendaConflict? c = findAgendaConflict(
        startsAt: t0,
        durationMinutes: 30,
        professionalId: 'dr1',
        existing: <AgendaInterval>[
          AgendaInterval(
            id: 'a1',
            startsAt: t0,
            durationMinutes: 30,
            professionalId: 'dr1',
            status: 'cancelled',
          ),
        ],
      );
      expect(c, isNull);
    });

    test('reagendar ignora o proprio id', () {
      final AgendaConflict? c = findAgendaConflict(
        startsAt: t0,
        durationMinutes: 30,
        professionalId: 'dr1',
        ignoreAppointmentId: 'a1',
        existing: <AgendaInterval>[
          AgendaInterval(
            id: 'a1',
            startsAt: t0,
            durationMinutes: 30,
            professionalId: 'dr1',
          ),
        ],
      );
      expect(c, isNull);
    });
  });

  group('ChildGuardianLink permissoes', () {
    test('pendente quando ativo sem flags', () {
      final ChildGuardianLink link = ChildGuardianLink(
        guardianUid: 'g2',
        ownerId: 'g1',
        childId: 'c1',
        relationship: GuardianRelationship.father,
        status: GuardianAuthStatus.active,
        createdAt: DateTime(2026),
        canViewData: false,
      );
      expect(link.isPendingAuthorization, isTrue);
      expect(link.mayViewChildData, isFalse);
    });

    test('dois responsaveis com permissoes diferentes', () {
      final ChildGuardianLink mae = ChildGuardianLink(
        guardianUid: 'mae',
        ownerId: 'mae',
        childId: 'c1',
        relationship: GuardianRelationship.mother,
        status: GuardianAuthStatus.active,
        createdAt: DateTime(2026),
        canViewData: true,
        canSendDocuments: true,
        canMakeRequests: true,
      );
      final ChildGuardianLink pai = ChildGuardianLink(
        guardianUid: 'pai',
        ownerId: 'mae',
        childId: 'c1',
        relationship: GuardianRelationship.father,
        status: GuardianAuthStatus.active,
        createdAt: DateTime(2026),
        canViewData: false,
        canSendDocuments: true,
        canMakeRequests: false,
      );
      expect(mae.mayViewChildData, isTrue);
      expect(pai.mayViewChildData, isFalse);
      expect(pai.canSendDocuments, isTrue);
    });
  });
}
