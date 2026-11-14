import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';

/// Paciente em foco nos módulos clínicos (prontuário, vacinação,
/// crescimento...). Fica só em memória: não é cache de dados clínicos.
@immutable
class SelectedPatient {
  const SelectedPatient({
    required this.childId,
    required this.name,
    this.birthDate,
  });

  final String childId;
  final String name;
  final DateTime? birthDate;

  @override
  bool operator ==(Object other) =>
      other is SelectedPatient && other.childId == childId;

  @override
  int get hashCode => childId.hashCode;
}

/// Zera ao trocar de conta ou de clínica ativa, para um paciente nunca
/// atravessar sessões ou clínicas.
final StateProvider<SelectedPatient?> selectedPatientProvider =
    StateProvider<SelectedPatient?>((Ref ref) {
  ref.watch(currentUserProvider.select((user) => user?.uid));
  ref.watch(
    activeClinicMembershipProvider.select((membership) => membership?.clinicId),
  );
  return null;
});
