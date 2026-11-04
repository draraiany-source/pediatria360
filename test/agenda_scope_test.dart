import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/clinic/domain/agenda_scope.dart';
import 'package:pediatria360/features/workspace/domain/workspace_profile.dart';
import 'package:pediatria360/shared/domain/entities/clinic_organization.dart';

ClinicMembership _m(ClinicRole role, {bool active = true, String clinic = 'c1'}) =>
    ClinicMembership(
      id: 'm',
      clinicId: clinic,
      userId: 'u',
      role: role,
      active: active,
      createdAt: DateTime.utc(2026),
    );

void main() {
  test('recepcionista ve a agenda do dia da clinica inteira', () {
    expect(
      usesClinicWideAgenda(
        _m(ClinicRole.receptionist),
        WorkspaceProfile.receptionist,
      ),
      isTrue,
    );
  });

  test('admin da clinica so ve a agenda inteira na area de recepcao', () {
    expect(
      usesClinicWideAgenda(
        _m(ClinicRole.clinicAdmin),
        WorkspaceProfile.receptionist,
      ),
      isTrue,
    );
    expect(
      usesClinicWideAgenda(
        _m(ClinicRole.clinicAdmin),
        WorkspaceProfile.professional,
      ),
      isFalse,
    );
  });

  test('profissional e financeiro ficam na propria agenda', () {
    for (final ClinicRole r in <ClinicRole>[
      ClinicRole.physician,
      ClinicRole.healthProfessional,
      ClinicRole.nursing,
      ClinicRole.finance,
    ]) {
      expect(
        usesClinicWideAgenda(_m(r), WorkspaceProfile.receptionist),
        isFalse,
        reason: r.name,
      );
    }
  });

  test('sem vinculo ativo nao amplia a consulta', () {
    expect(
      usesClinicWideAgenda(null, WorkspaceProfile.receptionist),
      isFalse,
    );
    expect(
      usesClinicWideAgenda(
        _m(ClinicRole.receptionist, active: false),
        WorkspaceProfile.receptionist,
      ),
      isFalse,
    );
    expect(
      usesClinicWideAgenda(
        _m(ClinicRole.receptionist, clinic: ''),
        WorkspaceProfile.receptionist,
      ),
      isFalse,
    );
  });
}
