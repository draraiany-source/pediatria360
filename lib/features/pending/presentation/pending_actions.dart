import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../emr/presentation/screens/encounter_editor_screen.dart';
import '../../emr/presentation/screens/patient_timeline_screen.dart';
import '../domain/pending_item.dart';
import 'providers/pending_providers.dart';

/// Executa a ação primária de uma pendência (navegação + status).
Future<void> runPendingAction(
  BuildContext context,
  WidgetRef ref,
  PendingItem item,
  PendingActionKind action,
) async {
  final String? childId = item.childId ?? item.patientId;
  switch (action) {
    case PendingActionKind.openPatient:
    case PendingActionKind.openPatient360:
      if (childId != null && childId.isNotEmpty) {
        context.push(Routes.clinicPatient360(childId));
      } else {
        context.go(Routes.patientsPath);
      }
    case PendingActionKind.scheduleReturn:
    case PendingActionKind.rescheduleAppointment:
    case PendingActionKind.openAgenda:
      context.go(Routes.agendaPath);
    case PendingActionKind.openVaccines:
    case PendingActionKind.registerVaccineDose:
      if (childId != null && childId.isNotEmpty) {
        context.push(Routes.vaccines(childId));
      }
    case PendingActionKind.openLabResult:
    case PendingActionKind.openSupplementLabs:
      if (item.referenceId != null) {
        context.push(
          Routes.supplementLabDetail(
            item.referenceId!,
            childId: childId,
          ),
        );
      } else {
        context.push(Routes.supplementLabsPath);
      }
    case PendingActionKind.markExamReviewed:
      await _resolvePending(ref, item, note: 'Exame revisado');
      if (context.mounted && childId != null) {
        context.push(Routes.clinicPatient360(childId));
      }
    case PendingActionKind.replyMessage:
      context.go(Routes.notificationsPath);
    case PendingActionKind.openDocument:
    case PendingActionKind.signDocument:
    case PendingActionKind.downloadDocument:
      if (item.referenceId != null) {
        final String? enc = _encounterForDocument(item);
        if (enc != null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EncounterEditorScreen(encounterId: enc),
            ),
          );
        } else if (childId != null) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PatientTimelineScreen(
                patientId: childId,
                patientName: item.patientName ?? 'Paciente',
              ),
            ),
          );
        }
      }
    case PendingActionKind.openAppointment:
      if (item.referenceId != null) {
        context.push(Routes.appointment(item.referenceId!));
      } else {
        context.go(Routes.agendaPath);
      }
    case PendingActionKind.registerPayment:
      if (item.sourceKey.startsWith('finance_recv:')) {
        final String recvId = item.referenceId ?? item.sourceKey.split(':').last;
        context.push(
          '${Routes.financeReceivablesPath}?receivableId=${Uri.encodeComponent(recvId)}',
        );
      } else if (item.referenceId != null) {
        context.push(
          '${Routes.financeReceivablesPath}?appointmentId=${Uri.encodeComponent(item.referenceId!)}',
        );
      } else {
        context.go(Routes.financePath);
      }
    case PendingActionKind.openInventory:
      context.push(Routes.inventoryPath);
    case PendingActionKind.openBilling:
      final String sub = item.referenceId ?? '';
      if (sub == 'glosas') {
        context.push(Routes.billingGlosasPath);
      } else if (sub == 'lotes') {
        context.push(Routes.billingBatchesPath);
      } else if (sub == 'guias') {
        context.push(Routes.billingGuidesPath);
      } else if (sub == 'autorizacoes') {
        context.push(Routes.billingAuthorizationsPath);
      } else {
        context.push(Routes.billingPath);
      }
    case PendingActionKind.openEncounterDraft:
      if (item.referenceId != null) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EncounterEditorScreen(encounterId: item.referenceId!),
          ),
        );
      }
    case PendingActionKind.none:
      break;
  }
}

String? _encounterForDocument(PendingItem item) {
  if (item.kind != PendingKind.documentUnsigned) return item.referenceId;
  return null;
}

Future<void> updatePendingStatus(
  WidgetRef ref,
  PendingItem item,
  PendingWorkflowStatus status, {
  String? notes,
}) async {
  final String? uid = ref.read(currentUserProvider)?.uid;
  if (uid == null) return;
  await ref.read(pendingRepositoryProvider).upsertStatus(
        professionalId: uid,
        item: item,
        status: status,
        updatedBy: uid,
        notes: notes,
      );
  ref.invalidate(professionalPendingItemsProvider);
  ref.invalidate(pendingTrackingMapProvider);
}

Future<void> _resolvePending(
  WidgetRef ref,
  PendingItem item, {
  String? note,
}) =>
    updatePendingStatus(
      ref,
      item,
      PendingWorkflowStatus.resolved,
      notes: note,
    );
