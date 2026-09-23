import '../../../shared/domain/entities/clinic_organization.dart';
import '../data/telemedicine_repository.dart';

/// Filtro soft por unidade: consultas sem [Appointment.unitId] permanecem
/// visiveis (legado). Com [ClinicMembership.unitIds] vazio, nao filtra.
List<Appointment> filterAgendaByMembershipUnits(
  List<Appointment> items,
  ClinicMembership? membership,
) {
  if (membership == null || membership.unitIds.isEmpty) {
    return items;
  }
  final Set<String> allowed = membership.unitIds.toSet();
  return items
      .where((Appointment a) => _appointmentVisibleForUnits(a, allowed))
      .toList();
}

bool _appointmentVisibleForUnits(Appointment a, Set<String> allowed) {
  final String? unit = a.unitId;
  if (unit != null && unit.isNotEmpty) {
    return allowed.contains(unit);
  }
  final String? room = a.roomLabel;
  if (room != null && room.isNotEmpty) {
    return allowed.contains(room);
  }
  return true;
}
