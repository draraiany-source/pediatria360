import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/core/error/failures.dart';
import 'package:pediatria360/core/router/route_authorization.dart';
import 'package:pediatria360/core/router/routes.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';
import 'package:pediatria360/features/telemedicine/domain/booking_options.dart';
import 'package:pediatria360/features/telemedicine/presentation/screens/booking_screens.dart';
import 'package:pediatria360/features/workspace/domain/workspace_profile.dart';
import 'package:pediatria360/shared/domain/entities/app_user.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

Appointment appt({
  required String id,
  required String patient,
  required String child,
  required String prof,
  required DateTime at,
  String? clinic = 'c1',
  String childName = 'Luna',
  String profName = 'Dra. Carla',
}) =>
    Appointment(
      id: id,
      patientId: patient,
      professionalId: prof,
      professionalName: profName,
      startsAt: at,
      durationMinutes: 30,
      status: AppointmentStatus.confirmed,
      createdAt: DateTime(2026),
      childId: child,
      childName: childName,
      clinicId: clinic,
    );

void main() {
  group('pacientes da equipe', () {
    test('CRM: ignora mesclados e incompletos, sem duplicar, em ordem de nome', () {
      final List<BookingPatient> out = bookingPatientsFromCrm(<Map<String, dynamic>>[
        <String, dynamic>{'ownerUid': 'ana', 'childId': 'theo', 'childName': 'Theo', 'guardianName': 'Ana'},
        <String, dynamic>{'ownerUid': 'ana', 'childId': 'luna', 'childName': 'Luna', 'lastProfessionalId': 'carla'},
        <String, dynamic>{'ownerUid': 'ana', 'childId': 'luna', 'childName': 'Luna (dup)'},
        <String, dynamic>{'ownerUid': 'bruno', 'childId': 'mia', 'childName': 'Mia', 'mergedInto': 'x'},
        <String, dynamic>{'ownerUid': '', 'childId': 'z', 'childName': 'Sem titular'},
      ]);
      expect(out.map((BookingPatient p) => p.childName), <String>['Luna', 'Theo']);
      expect(out.first.lastProfessionalId, 'carla');
      expect(out.last.label, 'Theo · resp. Ana');
    });

    test('agenda: último profissional vem da consulta mais recente', () {
      final List<BookingPatient> out = bookingPatientsFromAppointments(<Appointment>[
        appt(id: '1', patient: 'ana', child: 'luna', prof: 'antigo', at: DateTime(2026, 1, 1)),
        appt(id: '2', patient: 'ana', child: 'luna', prof: 'carla', at: DateTime(2026, 3, 1)),
        appt(id: '3', patient: '', child: 'x', prof: 'carla', at: DateTime(2026, 3, 1)),
      ]);
      expect(out, hasLength(1));
      expect(out.single.lastProfessionalId, 'carla');
    });
  });

  test('família só agenda com profissional e clínica de consultas anteriores', () {
    final List<FamilyBookingTarget> out = familyBookingTargets(<Appointment>[
      appt(id: '1', patient: 'ana', child: 'luna', prof: 'carla', at: DateTime(2026, 1, 1)),
      appt(id: '2', patient: 'ana', child: 'theo', prof: 'carla', at: DateTime(2026, 2, 1)),
      appt(id: '3', patient: 'ana', child: 'luna', prof: 'diego', at: DateTime(2026, 2, 1), clinic: null),
      appt(id: '4', patient: 'ana', child: 'luna', prof: 'carla', at: DateTime(2026, 2, 1), clinic: 'c2'),
    ]);
    expect(
      out.map((FamilyBookingTarget t) => '${t.professionalId}@${t.clinicId}').toSet(),
      <String>{'carla@c1', 'carla@c2'},
    );
  });

  test('horários: só livres, agrupados por dia, em ordem e sem repetição', () {
    TimeSlot s(int day, int h, {bool free = true}) =>
        TimeSlot(startsAt: DateTime(2026, 11, day, h), durationMinutes: 30, available: free);
    final Map<DateTime, List<TimeSlot>> out = groupSlotsByDay(<TimeSlot>[
      s(17, 14),
      s(16, 10),
      s(16, 9),
      s(16, 9),
      s(16, 11, free: false),
    ]);
    expect(out.keys, <DateTime>[DateTime(2026, 11, 16), DateTime(2026, 11, 17)]);
    expect(out[DateTime(2026, 11, 16)]!.map((TimeSlot t) => t.startsAt.hour), <int>[9, 10]);
    expect(groupSlotsByDay(<TimeSlot>[s(16, 9, free: false)]), isEmpty);
  });

  group('mensagem de recusa', () {
    test('mostra o motivo dado pelo servidor', () {
      final Failure f = PermissionFailure(
        'Você não tem acesso a este recurso.',
        'permission-denied',
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'O responsável ainda não autorizou este profissional.',
        ),
      );
      expect(bookingFailureMessage(f), 'O responsável ainda não autorizou este profissional.');
    });

    test('erro interno não vaza detalhe técnico', () {
      final Failure f = ServerFailure(
        'Nao foi possivel concluir a operacao.',
        'internal',
        FirebaseFunctionsException(code: 'internal', message: 'TypeError: x is undefined'),
      );
      expect(bookingFailureMessage(f), 'Nao foi possivel concluir a operacao.');
    });
  });

  group('rotas de agendamento', () {
    AppUser user(UserRole role) => AppUser(
          uid: 'u',
          email: 'u@exemplo.invalid',
          name: 'U',
          role: role,
          plan: UserPlan.free,
          createdAt: DateTime(2026),
          onboardingDone: true,
        );
    ClinicMembership member(ClinicRole role) => ClinicMembership(
          id: 'm',
          clinicId: 'c1',
          userId: 'u',
          role: role,
          createdAt: DateTime(2026),
        );
    String? go(String location, AppUser u, {ClinicMembership? m, WorkspaceProfile? w}) =>
        resolveRouteRedirect(
          maintenanceMode: false,
          location: location,
          authLoading: false,
          onboardingLoading: false,
          user: u,
          seenOnboarding: true,
          clinicMembership: m,
          workspace: w,
        );

    test('recepção abre o agendamento da clínica', () {
      expect(
        go(Routes.clinicBookingPath, user(UserRole.parent),
            m: member(ClinicRole.receptionist), w: WorkspaceProfile.receptionist),
        isNull,
      );
    });

    test('financeiro e família não abrem o agendamento da clínica', () {
      expect(
        go(Routes.clinicBookingPath, user(UserRole.parent),
            m: member(ClinicRole.finance), w: WorkspaceProfile.finance),
        Routes.homePath,
      );
      expect(go(Routes.clinicBookingPath, user(UserRole.parent)), Routes.homePath);
    });

    test('família abre o próprio agendamento', () {
      expect(go(Routes.familyBookingPath, user(UserRole.parent)), isNull);
    });
  });
}
