import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/utils/result.dart';
import '../domain/clinic_intake.dart';

/// Solicitações de paciente novo e convite ao responsável. Toda escrita
/// passa pelas Functions (clinicFlow.ts); o app só lê o que as regras
/// liberam (equipe de agenda da clínica, profissional ou quem criou).
class ClinicIntakeRepository {
  ClinicIntakeRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _db = firestore,
        _functions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static DateTime? _toDate(Object? v) => v is Timestamp ? v.toDate() : null;

  List<ClinicIntake> _map(QuerySnapshot<Map<String, dynamic>> snap) {
    final List<ClinicIntake> list = snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ClinicIntake.fromMap(d.id, d.data(), toDate: _toDate),
        )
        .toList();
    list.sort(
      (ClinicIntake a, ClinicIntake b) =>
          a.requestedStartsAt.compareTo(b.requestedStartsAt),
    );
    return list;
  }

  Stream<List<ClinicIntake>> watchClinicIntakes(String clinicId) => _db
      .collection('clinic_intakes')
      .where('clinicId', isEqualTo: clinicId)
      .limit(200)
      .snapshots()
      .map(_map);

  Stream<List<ClinicIntake>> watchProfessionalIntakes(String professionalId) =>
      _db
          .collection('clinic_intakes')
          .where('professionalId', isEqualTo: professionalId)
          .limit(200)
          .snapshots()
          .map(_map);

  /// Profissionais que atendem na clínica (vínculo ativo com papel clínico).
  Future<Result<List<IntakeProfessionalOption>>> careProfessionals(
    String clinicId,
  ) =>
      guard(() async {
        final QuerySnapshot<Map<String, dynamic>> snap = await _db
            .collection('clinics')
            .doc(clinicId)
            .collection('memberships')
            .where('active', isEqualTo: true)
            .get();
        final Map<String, IntakeProfessionalOption> out =
            <String, IntakeProfessionalOption>{};
        for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
          final Map<String, dynamic> m = d.data();
          final String? uid = m['userId'] as String?;
          if (uid == null || !kIntakeCareRoles.contains(m['role'])) continue;
          final String name = (m['name'] as String?)?.trim() ?? '';
          final String spec = (m['specialty'] as String?)?.trim() ?? '';
          out[uid] = IntakeProfessionalOption(
            userId: uid,
            label: <String>[
              if (name.isNotEmpty) name else 'Profissional',
              if (spec.isNotEmpty) spec,
            ].join(' · '),
          );
        }
        return out.values.toList(growable: false);
      });

  Future<Result<IntakeInvite>> create({
    required String? clinicId,
    required String professionalId,
    required String childName,
    required DateTime childBirthDate,
    required String guardianName,
    required String guardianEmail,
    required DateTime startsAt,
    required int durationMinutes,
    String? guardianPhone,
    String? reason,
  }) =>
      guard(() async {
        String two(int v) => v.toString().padLeft(2, '0');
        final HttpsCallableResult<dynamic> res =
            await _functions.httpsCallable('createClinicIntake').call(
          <String, dynamic>{
            'clinicId': clinicId,
            'professionalId': professionalId,
            'childName': childName.trim(),
            'childBirthDate':
                '${childBirthDate.year}-${two(childBirthDate.month)}-${two(childBirthDate.day)}',
            'guardianName': guardianName.trim(),
            'guardianEmail': guardianEmail.trim(),
            'guardianPhone': guardianPhone?.trim(),
            'startsAt': startsAt.toUtc().toIso8601String(),
            'durationMinutes': durationMinutes,
            'reason': reason?.trim(),
          },
        );
        final Map<dynamic, dynamic> d = res.data as Map<dynamic, dynamic>;
        return IntakeInvite(
          intakeId: d['intakeId'] as String,
          code: d['inviteCode'] as String,
          expiresAt: DateTime.parse(d['expiresAt'] as String),
        );
      });

  Future<Result<void>> cancel(String intakeId, {String? reason}) => guard(
        () => _functions.httpsCallable('cancelClinicIntake').call(
          <String, dynamic>{'intakeId': intakeId, 'reason': reason},
        ),
      );

  Future<Result<IntakeInvite>> renewCode(String intakeId) => guard(() async {
        final HttpsCallableResult<dynamic> res = await _functions
            .httpsCallable('renewClinicIntakeCode')
            .call(<String, dynamic>{'intakeId': intakeId});
        final Map<dynamic, dynamic> d = res.data as Map<dynamic, dynamic>;
        return IntakeInvite(
          intakeId: intakeId,
          code: d['inviteCode'] as String,
          expiresAt: DateTime.parse(d['expiresAt'] as String),
        );
      });

  Future<Result<IntakePreview>> preview(String code) => guard(() async {
        final HttpsCallableResult<dynamic> res = await _functions
            .httpsCallable('previewClinicIntake')
            .call(<String, dynamic>{'code': code});
        return IntakePreview.fromMap(res.data as Map<dynamic, dynamic>);
      });

  /// Aceita o convite para uma criança do titular. [scopes] vazio confirma a
  /// consulta sem autorizar acesso clínico.
  Future<Result<String>> accept({
    required String code,
    required String childId,
    required List<String> scopes,
    required int days,
  }) =>
      guard(() async {
        final HttpsCallableResult<dynamic> res =
            await _functions.httpsCallable('acceptClinicIntake').call(
          <String, dynamic>{
            'code': code,
            'childId': childId,
            'scopes': scopes,
            if (scopes.isNotEmpty) 'days': days,
          },
        );
        return (res.data as Map<dynamic, dynamic>)['appointmentId'] as String;
      });
}
