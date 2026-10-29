import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' hide Result;

import '../../../core/config/firestore_paths.dart';
import '../../../core/utils/result.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../domain/clinic_dashboard_stats.dart';
import '../domain/clinic_workflow.dart';
import '../domain/triage_record.dart';

/// Persistencia do fluxo de consultorio (agenda do dia, triagem, KPIs).
class ClinicRepository {
  const ClinicRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  // Reservado para callables futuros (check-in avancado, faturamento).
  // ignore: unused_field
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(FirestorePaths.appointments);

  CollectionReference<Map<String, dynamic>> get _triage =>
      _firestore.collection(FirestorePaths.triageRecords);

  /// Agendamentos do profissional com inicio no dia civil atual (local).
  Stream<List<Appointment>> watchTodayAppointments(String professionalId) {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = start.add(const Duration(days: 1));

    return _appointments
        .where('professionalId', isEqualTo: professionalId)
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startsAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            final List<Appointment> list = snap.docs
                .map(Appointment.fromFirestore)
                .toList(growable: false);
            list.sort(
              (Appointment a, Appointment b) =>
                  a.startsAt.compareTo(b.startsAt),
            );
            return list;
          },
        );
  }

  /// Atualiza o fluxo operacional e, quando aplicavel, o status legado.
  Future<Result<void>> updateWorkflowStatus(
    String appointmentId,
    ClinicWorkflowStatus status,
  ) =>
      guard(() async {
        final Map<String, dynamic> patch = <String, dynamic>{
          'workflowStatus': status.name,
          'workflowUpdatedAt': FieldValue.serverTimestamp(),
        };
        final String? legacy = status.toAppointmentStatusName();
        if (legacy != null) {
          patch['status'] = legacy;
        }
        if (status == ClinicWorkflowStatus.arrived) {
          patch['arrivedAt'] = FieldValue.serverTimestamp();
        }
        await _appointments.doc(appointmentId).update(patch);
      });

  /// Check-in na recepcao: marca chegada e opcionalmente anota.
  Future<Result<void>> checkIn(
    String appointmentId, {
    String? notes,
  }) =>
      guard(() async {
        final Map<String, dynamic> patch = <String, dynamic>{
          'workflowStatus': ClinicWorkflowStatus.arrived.name,
          'status': 'confirmed',
          'arrivedAt': FieldValue.serverTimestamp(),
          'workflowUpdatedAt': FieldValue.serverTimestamp(),
        };
        if (notes != null && notes.trim().isNotEmpty) {
          patch['checkInNotes'] = notes.trim();
        }
        await _appointments.doc(appointmentId).update(patch);
      });

  Future<Result<void>> saveTriage(TriageRecord record) => guard(() async {
        final String id = record.id.isEmpty
            ? _triage.doc().id
            : record.id;
        final TriageRecord toSave = TriageRecord(
          id: id,
          appointmentId: record.appointmentId,
          childId: record.childId,
          professionalId: record.professionalId,
          recordedBy: record.recordedBy,
          recordedAt: record.recordedAt,
          weightKg: record.weightKg,
          heightCm: record.heightCm,
          headCircumferenceCm: record.headCircumferenceCm,
          temperatureC: record.temperatureC,
          heartRate: record.heartRate,
          respiratoryRate: record.respiratoryRate,
          spo2: record.spo2,
          systolicBp: record.systolicBp,
          diastolicBp: record.diastolicBp,
          glucoseMgDl: record.glucoseMgDl,
          painScore: record.painScore,
          notes: record.notes,
        );
        final Map<String, dynamic> data = toSave.toMap();
        data['recordedAt'] = Timestamp.fromDate(toSave.recordedAt);
        await _triage.doc(id).set(data, SetOptions(merge: true));

        // Avanca o fluxo para triagem / aguardando medico.
        await _appointments.doc(record.appointmentId).update(<String, dynamic>{
          'workflowStatus': ClinicWorkflowStatus.waitingDoctor.name,
          'status': 'confirmed',
          'triageRecordId': id,
          'workflowUpdatedAt': FieldValue.serverTimestamp(),
        });
      });

  Stream<TriageRecord?> watchTriage(String appointmentId) {
    return _triage
        .where('appointmentId', isEqualTo: appointmentId)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      if (snap.docs.isEmpty) return null;
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = snap.docs.first;
      final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());
      final Object? rawAt = data['recordedAt'];
      if (rawAt is Timestamp) {
        data['recordedAt'] = rawAt.toDate().toIso8601String();
      }
      return TriageRecord.fromMap(data, id: doc.id);
    });
  }

  /// Agrega KPIs do dia a partir dos agendamentos.
  ///
  /// Faturamento, mensagens e vacinas ainda nao estao ligados — retornam zero
  /// com TODO nos comentarios abaixo.
  Future<Result<ClinicDashboardStats>> loadDashboardStats(
    String professionalId,
  ) =>
      guard(() async {
        final DateTime now = DateTime.now();
        final DateTime start = DateTime(now.year, now.month, now.day);
        final DateTime end = start.add(const Duration(days: 1));

        final QuerySnapshot<Map<String, dynamic>> snap = await _appointments
            .where('professionalId', isEqualTo: professionalId)
            .where(
              'startsAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('startsAt', isLessThan: Timestamp.fromDate(end))
            .get();

        int waiting = 0;
        int inService = 0;
        int finished = 0;
        int noShow = 0;

        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final Map<String, dynamic> data = doc.data();
          final ClinicWorkflowStatus wf = ClinicWorkflowStatus.resolve(
            workflowStatus: data['workflowStatus'] as String?,
            appointmentStatus: data['status'] as String?,
          );
          switch (wf) {
            case ClinicWorkflowStatus.arrived:
            case ClinicWorkflowStatus.triage:
            case ClinicWorkflowStatus.waitingDoctor:
            case ClinicWorkflowStatus.called:
            case ClinicWorkflowStatus.confirmed:
            case ClinicWorkflowStatus.scheduled:
              waiting++;
            case ClinicWorkflowStatus.inService:
              inService++;
            case ClinicWorkflowStatus.finished:
              finished++;
            case ClinicWorkflowStatus.noShow:
              noShow++;
            case ClinicWorkflowStatus.cancelled:
            case ClinicWorkflowStatus.rescheduled:
              break;
          }
        }

        final int totalObserved = snap.docs.length;
        final double noShowRate =
            totalObserved == 0 ? 0.0 : noShow / totalObserved;

        // Retornos: proximos 14 dias com motivo indicando retorno, ou tipo
        // de encontro "followUp" quando o campo existir no agendamento.
        final DateTime returnsEnd = start.add(const Duration(days: 14));
        final QuerySnapshot<Map<String, dynamic>> upcomingSnap =
            await _appointments
                .where('professionalId', isEqualTo: professionalId)
                .where(
                  'startsAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(start),
                )
                .where(
                  'startsAt',
                  isLessThan: Timestamp.fromDate(returnsEnd),
                )
                .get();
        int pendingReturns = 0;
        int billingTodayCents = 0;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in upcomingSnap.docs) {
          final Map<String, dynamic> data = doc.data();
          final String reason =
              ((data['reason'] as String?) ?? '').toLowerCase();
          final String status = (data['status'] as String?) ?? '';
          final bool active = status == 'requested' ||
              status == 'confirmed' ||
              status == 'inProgress';
          if (active &&
              (reason.contains('retorno') ||
                  reason.contains('follow') ||
                  reason.contains('retorno agend'))) {
            pendingReturns++;
          }
        }
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snap.docs) {
          final Map<String, dynamic> data = doc.data();
          if ((data['paid'] as bool?) == true) {
            billingTodayCents += (data['priceCents'] as num?)?.toInt() ?? 0;
          }
        }

        // Rascunhos abertos do profissional = alerta clinico operacional.
        int clinicalAlerts = 0;
        try {
          final QuerySnapshot<Map<String, dynamic>> draftsSnap =
              await _firestore
                  .collection('encounters')
                  .where('professionalId', isEqualTo: professionalId)
                  .where('status', isEqualTo: 'draft')
                  .limit(50)
                  .get();
          clinicalAlerts = draftsSnap.docs.length;
        } catch (_) {
          // Indice composto pode faltar em alguns ambientes — nao derruba painel.
          clinicalAlerts = 0;
        }

        // Proxies: novos no mes = agendamentos criados neste mes (nao e
        // "primeiro paciente", mas evita KPI mentiroso em zero fixo).
        final DateTime monthStart = DateTime(now.year, now.month, 1);
        int newPatients = 0;
        try {
          final QuerySnapshot<Map<String, dynamic>> monthSnap =
              await _appointments
                  .where('professionalId', isEqualTo: professionalId)
                  .where(
                    'createdAt',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
                  )
                  .limit(200)
                  .get();
          newPatients = monthSnap.docs.length;
        } catch (_) {
          newPatients = 0;
        }

        return ClinicDashboardStats(
          todayAppointments: snap.docs.length,
          waiting: waiting,
          inService: inService,
          finished: finished,
          pendingReturns: pendingReturns,
          // Vacinas/exames cross-collection: ainda sem join seguro — manter 0
          // com transparencia na UI (nao inventar).
          pendingVaccines: 0,
          pendingExams: 0,
          // Mensagens: preenchido pelo provider com unreadCountProvider.
          pendingMessages: 0,
          newPatients: newPatients,
          billingTodayCents: billingTodayCents,
          billingMonthCents: 0,
          noShowRate: noShowRate,
          upcomingBirthdays: 0,
          clinicalAlerts: clinicalAlerts,
          adminPending: 0,
        );
      });

  /// Variante que aceita contagem de mensagens nao lidas ja calculada no app.
  Future<Result<ClinicDashboardStats>> loadDashboardStatsWithUnread(
    String professionalId, {
    int unreadMessages = 0,
  }) =>
      guard(() async {
        final Result<ClinicDashboardStats> base =
            await loadDashboardStats(professionalId);
        final ClinicDashboardStats? s = base.valueOrNull;
        if (s == null) {
          throw StateError(base.failureOrNull?.message ?? 'stats');
        }
        return ClinicDashboardStats(
          todayAppointments: s.todayAppointments,
          waiting: s.waiting,
          inService: s.inService,
          finished: s.finished,
          pendingReturns: s.pendingReturns,
          pendingVaccines: s.pendingVaccines,
          pendingExams: s.pendingExams,
          pendingMessages: unreadMessages,
          newPatients: s.newPatients,
          billingTodayCents: s.billingTodayCents,
          billingMonthCents: s.billingMonthCents,
          noShowRate: s.noShowRate,
          upcomingBirthdays: s.upcomingBirthdays,
          clinicalAlerts: s.clinicalAlerts,
          adminPending: s.adminPending,
        );
      });
}
