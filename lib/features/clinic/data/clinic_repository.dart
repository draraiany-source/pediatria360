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
          final ClinicWorkflowStatus wf =
              ClinicWorkflowStatus.fromAppointmentStatus(
            (data['workflowStatus'] as String?) ??
                (data['status'] as String?),
          );
          switch (wf) {
            case ClinicWorkflowStatus.arrived:
            case ClinicWorkflowStatus.triage:
            case ClinicWorkflowStatus.waitingDoctor:
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
            totalObserved == 0 ? 0 : noShow / totalObserved;

        return ClinicDashboardStats(
          todayAppointments: snap.docs.length,
          waiting: waiting,
          inService: inService,
          finished: finished,
          // TODO(consultorio): retornos pendentes a partir de plano/encounters.
          pendingReturns: 0,
          // TODO(consultorio): cruzar com vaccine_doses atrasadas.
          pendingVaccines: 0,
          // TODO(consultorio): exames laboratoriais pendentes de leitura.
          pendingExams: 0,
          // TODO(consultorio): mensagens nao lidas do profissional.
          pendingMessages: 0,
          // TODO(consultorio): pacientes novos no mes (primeira consulta).
          newPatients: 0,
          // TODO(consultorio): faturamento do dia (orders / appointments.paid).
          billingTodayCents: 0,
          // TODO(consultorio): faturamento do mes.
          billingMonthCents: 0,
          noShowRate: noShowRate,
          // TODO(consultorio): aniversarios proximos na carteira.
          upcomingBirthdays: 0,
          // TODO(consultorio): alertas clinicos (alergia, rascunhos abertos).
          clinicalAlerts: 0,
          // TODO(consultorio): tarefas administrativas pendentes.
          adminPending: 0,
        );
      });
}
