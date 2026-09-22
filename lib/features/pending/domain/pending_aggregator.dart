import '../../billing/domain/billing_models.dart';
import '../../billing/domain/billing_validation.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../finance/domain/finance_models.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../../shared/domain/entities/clinical_record.dart';
import '../../../shared/domain/entities/encounter.dart';
import '../data/pending_tracking_record.dart';
import 'automation_catalog.dart';
import 'pending_item.dart';

/// Visão mínima do paciente para segmentação CRM (sem depender de UI).
class PendingPatientSnapshot {
  const PendingPatientSnapshot({
    required this.patientId,
    required this.childId,
    required this.name,
    this.lastEncounterAt,
    this.hasOpenDraft = false,
    this.encounterCount = 0,
  });

  final String patientId;
  final String childId;
  final String name;
  final DateTime? lastEncounterAt;
  final bool hasOpenDraft;
  final int encounterCount;
}

class VaccineOverdueInput {
  const VaccineOverdueInput({
    required this.childId,
    required this.doseId,
    required this.vaccineLabel,
    required this.dueAt,
    this.patientName,
  });

  final String childId;
  final String doseId;
  final String vaccineLabel;
  final DateTime dueAt;
  final String? patientName;
}

class PendingAggregatorInput {
  const PendingAggregatorInput({
    required this.now,
    required this.patients,
    required this.encounters,
    required this.agenda,
    required this.notifications,
    required this.unsignedDocuments,
    required this.pendingLabs,
    required this.vaccineOverdue,
    required this.trackingBySourceKey,
    this.openReceivables = const <FinanceReceivable>[],
    this.authorizations = const <InsuranceAuthorization>[],
    this.billingGuides = const <BillingGuide>[],
    this.billingBatches = const <BillingBatch>[],
    this.billingGlosas = const <BillingGlosa>[],
    this.patientInsurances = const <PatientInsurance>[],
    this.inventoryItems = const <InventoryItem>[],
    this.inventoryLots = const <InventoryLot>[],
    this.inventoryCounts = const <InventoryCount>[],
  });

  final DateTime now;
  final List<PendingPatientSnapshot> patients;
  final List<Encounter> encounters;
  final List<Appointment> agenda;
  final List<AppNotification> notifications;
  final List<ClinicalDocument> unsignedDocuments;
  final List<LabResult> pendingLabs;
  final List<VaccineOverdueInput> vaccineOverdue;
  final Map<String, PendingTrackingRecord> trackingBySourceKey;
  final List<FinanceReceivable> openReceivables;
  final List<InsuranceAuthorization> authorizations;
  final List<BillingGuide> billingGuides;
  final List<BillingBatch> billingBatches;
  final List<BillingGlosa> billingGlosas;
  final List<PatientInsurance> patientInsurances;
  final List<InventoryItem> inventoryItems;
  final List<InventoryLot> inventoryLots;
  final List<InventoryCount> inventoryCounts;
}

/// Agrega fontes clínicas/administrativas em pendências operacionais (FASE 3 CRM).
class PendingAggregator {
  PendingAggregator._();

  static const Duration _inactiveAfter = Duration(days: 180);
  static const Duration _newPatientWithin = Duration(days: 30);
  static const Duration _activeFollowUpWithin = Duration(days: 90);
  static const Duration _defaultReturnAfterVisit = Duration(days: 30);

  static List<PendingItem> build(PendingAggregatorInput input) {
    final DateTime now = input.now;
    final Map<String, PendingPatientSnapshot> patientsById =
        <String, PendingPatientSnapshot>{
      for (final PendingPatientSnapshot p in input.patients) p.patientId: p,
    };

    String? childIdFor(String patientId) =>
        patientsById[patientId]?.childId ?? patientId;

    String? nameFor(String patientId) => patientsById[patientId]?.name;

    final List<PendingItem> raw = <PendingItem>[];

    for (final Encounter e in input.encounters) {
      if (e.status != EncounterStatus.draft) continue;
      raw.add(
        PendingItem(
          sourceKey: 'draft:${e.id}',
          kind: PendingKind.draftEncounter,
          category: PendingCategory.clinical,
          title: 'Atendimento em rascunho',
          subtitle: e.patientName ?? nameFor(e.patientId) ?? 'Paciente',
          createdAt: e.startedAt,
          patientId: e.patientId,
          childId: childIdFor(e.patientId),
          patientName: e.patientName ?? nameFor(e.patientId),
          referenceId: e.id,
          primaryAction: PendingActionKind.openEncounterDraft,
          secondaryAction: PendingActionKind.openPatient360,
        ),
      );
    }

    raw.addAll(_returnItems(input, patientsById, childIdFor, nameFor));
    raw.addAll(_patientSegmentItems(input));

    for (final VaccineOverdueInput v in input.vaccineOverdue) {
      raw.add(
        PendingItem(
          sourceKey: 'vaccine:${v.childId}:${v.doseId}',
          kind: PendingKind.vaccineOverdue,
          category: PendingCategory.clinical,
          title: 'Vacina atrasada',
          subtitle: v.vaccineLabel,
          createdAt: v.dueAt,
          dueAt: v.dueAt,
          patientId: v.childId,
          childId: v.childId,
          patientName: v.patientName,
          referenceId: v.doseId,
          urgent: now.isAfter(v.dueAt),
          primaryAction: PendingActionKind.openVaccines,
          secondaryAction: PendingActionKind.registerVaccineDose,
          crmSegments: const <CrmSegment>[CrmSegment.vaccineOverdue],
        ),
      );
    }

    for (final LabResult lab in input.pendingLabs) {
      if (!labIsPendingReview(lab)) continue;
      raw.add(
        PendingItem(
          sourceKey: 'exam:${lab.id}',
          kind: PendingKind.examPending,
          category: PendingCategory.clinical,
          title: 'Exame para revisar',
          subtitle: lab.analyte,
          createdAt: lab.collectedAt,
          dueAt: lab.collectedAt.add(const Duration(days: 7)),
          patientId: lab.patientId,
          childId: childIdFor(lab.patientId),
          patientName: nameFor(lab.patientId),
          referenceId: lab.id,
          urgent: lab.isOutOfRange,
          primaryAction: PendingActionKind.openLabResult,
          secondaryAction: PendingActionKind.markExamReviewed,
          crmSegments: const <CrmSegment>[CrmSegment.examPending],
        ),
      );
    }

    for (final AppNotification n in input.notifications) {
      if (n.read) continue;
      raw.add(
        PendingItem(
          sourceKey: 'message:${n.id}',
          kind: PendingKind.messageUnread,
          category: PendingCategory.administrative,
          title: n.title.isNotEmpty ? n.title : 'Mensagem não lida',
          subtitle: n.body,
          createdAt: n.createdAt,
          primaryAction: PendingActionKind.replyMessage,
          crmSegments: const <CrmSegment>[CrmSegment.messageUnanswered],
        ),
      );
    }

    for (final ClinicalDocument doc in input.unsignedDocuments) {
      if (doc.cancelled || doc.isSigned) continue;
      raw.add(
        PendingItem(
          sourceKey: 'document:${doc.id}',
          kind: PendingKind.documentUnsigned,
          category: PendingCategory.clinical,
          title: 'Documento sem assinatura',
          subtitle: doc.type.label,
          createdAt: doc.issuedAt,
          patientId: doc.patientId,
          childId: childIdFor(doc.patientId),
          patientName: doc.patientName ?? nameFor(doc.patientId),
          referenceId: doc.encounterId,
          primaryAction: PendingActionKind.signDocument,
          secondaryAction: PendingActionKind.openDocument,
          crmSegments: const <CrmSegment>[CrmSegment.documentPending],
        ),
      );
    }

    final Set<String> receivableAppointmentIds = <String>{
      for (final FinanceReceivable recv in input.openReceivables)
        if (recv.appointmentId != null && recv.appointmentId!.isNotEmpty)
          recv.appointmentId!,
    };

    for (final FinanceReceivable recv in input.openReceivables) {
      if (!recv.effectiveStatus(now).isOpen) continue;
      raw.add(
        PendingItem(
          sourceKey: 'finance_recv:${recv.id}',
          kind: PendingKind.paymentPending,
          category: PendingCategory.financial,
          title: 'Pagamento pendente',
          subtitle: recv.description.isNotEmpty ? recv.description : recv.id,
          createdAt: recv.createdAt,
          dueAt: recv.dueAt,
          patientId: recv.patientId,
          childId: recv.childId ?? childIdFor(recv.patientId ?? ''),
          patientName: nameFor(recv.patientId ?? ''),
          referenceId: recv.id,
          urgent: recv.dueAt.isBefore(now),
          primaryAction: PendingActionKind.registerPayment,
          secondaryAction: PendingActionKind.openAppointment,
          crmSegments: const <CrmSegment>[CrmSegment.paymentPending],
        ),
      );
    }

    for (final Appointment appt in input.agenda) {
      if (!appt.status.isActive) continue;

      if (appt.priceCents > 0 &&
          !appt.paid &&
          !receivableAppointmentIds.contains(appt.id)) {
        raw.add(
          PendingItem(
            sourceKey: 'payment:${appt.id}',
            kind: PendingKind.paymentPending,
            category: PendingCategory.financial,
            title: 'Pagamento pendente',
            subtitle: appt.childName ?? appt.reason ?? 'Consulta',
            createdAt: appt.createdAt,
            dueAt: appt.startsAt,
            patientId: appt.patientId,
            childId: appt.childId ?? childIdFor(appt.patientId),
            patientName: appt.childName,
            referenceId: appt.id,
            urgent: appt.startsAt.isBefore(now),
            primaryAction: PendingActionKind.registerPayment,
            secondaryAction: PendingActionKind.openAppointment,
            crmSegments: const <CrmSegment>[CrmSegment.paymentPending],
          ),
        );
      }

      if (appt.type == AppointmentType.teleconsulta &&
          (appt.status == AppointmentStatus.requested ||
              appt.status == AppointmentStatus.confirmed) &&
          !appt.startsAt.isBefore(now.subtract(const Duration(hours: 2)))) {
        raw.add(
          PendingItem(
            sourceKey: 'teleconsult:${appt.id}',
            kind: PendingKind.teleconsultPending,
            category: PendingCategory.administrative,
            title: 'Teleconsulta pendente',
            subtitle: appt.childName ?? appt.professionalName,
            createdAt: appt.createdAt,
            dueAt: appt.startsAt,
            patientId: appt.patientId,
            childId: appt.childId ?? childIdFor(appt.patientId),
            patientName: appt.childName,
            referenceId: appt.id,
            primaryAction: PendingActionKind.openAppointment,
            secondaryAction: PendingActionKind.openAgenda,
            crmSegments: const <CrmSegment>[CrmSegment.teleconsultPending],
          ),
        );
      }

      if (appt.status == AppointmentStatus.requested) {
        raw.add(
          PendingItem(
            sourceKey: 'adminConfirm:${appt.id}',
            kind: PendingKind.adminAppointmentConfirm,
            category: PendingCategory.administrative,
            title: 'Confirmar agendamento',
            subtitle: appt.childName ?? appt.reason ?? 'Consulta solicitada',
            createdAt: appt.createdAt,
            dueAt: appt.startsAt,
            patientId: appt.patientId,
            childId: appt.childId ?? childIdFor(appt.patientId),
            patientName: appt.childName,
            referenceId: appt.id,
            primaryAction: PendingActionKind.openAppointment,
            secondaryAction: PendingActionKind.openAgenda,
          ),
        );
      }
    }

    raw.addAll(_billingItems(input, childIdFor, nameFor));
    raw.addAll(_inventoryItems(input));

    for (final AutomationRuleDefinition rule in automationRuleCatalog) {
      raw.add(
        PendingItem(
          sourceKey: 'automation:${rule.id}',
          kind: PendingKind.automationIntegration,
          category: PendingCategory.administrative,
          title: rule.title,
          subtitle: rule.integrationPendingLabel,
          createdAt: now,
          referenceId: rule.id,
          primaryAction: PendingActionKind.none,
        ),
      );
    }

    return raw
        .map(
          (PendingItem item) => _applyTracking(
            item,
            input.trackingBySourceKey,
          ),
        )
        .toList(growable: false);
  }

  static bool labIsPendingReview(LabResult lab) {
    if (lab.isOutOfRange) return true;
    final String? note = lab.note?.toLowerCase();
    return note != null &&
        (note.contains('pendente') || note.contains('revisar'));
  }

  static PendingAttentionCounts attentionCounts(List<PendingItem> items) {
    int countKind(PendingKind kind) => items
        .where(
          (PendingItem i) => i.isActive && i.kind == kind,
        )
        .length;

    final int drafts = countKind(PendingKind.draftEncounter);
    final int returns = items
        .where(
          (PendingItem i) =>
              i.isActive &&
              (i.kind == PendingKind.returnNotScheduled ||
                  i.kind == PendingKind.returnOverdue),
        )
        .length;

    return PendingAttentionCounts(
      vaccineOverdue: countKind(PendingKind.vaccineOverdue),
      unreadMessages: countKind(PendingKind.messageUnread),
      returnsAndDrafts: drafts + returns,
      examsPending: countKind(PendingKind.examPending),
    );
  }

  static List<PendingItem> filterByCenterFilter(
    List<PendingItem> items,
    PendingCenterFilter filter,
    DateTime now,
  ) {
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    bool isThisWeek(DateTime d) {
      final DateTime start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final DateTime end = start.add(const Duration(days: 7));
      return !d.isBefore(start) && d.isBefore(end);
    }

    return items.where((PendingItem item) {
      switch (filter) {
        case PendingCenterFilter.resolved:
          return !item.isActive ||
              item.workflowStatus == PendingWorkflowStatus.resolved ||
              item.workflowStatus == PendingWorkflowStatus.ignored;
        case PendingCenterFilter.clinical:
          return item.category == PendingCategory.clinical && item.isActive;
        case PendingCenterFilter.administrative:
          return item.category == PendingCategory.administrative &&
              item.isActive;
        case PendingCenterFilter.financial:
          return item.category == PendingCategory.financial && item.isActive;
        case PendingCenterFilter.urgent:
          return item.isActive &&
              (item.urgent ||
                  item.displayStatus(now) == PendingDisplayStatus.overdue);
        case PendingCenterFilter.today:
          if (!item.isActive) return false;
          final DateTime anchor = item.dueAt ?? item.createdAt;
          return isToday(anchor);
        case PendingCenterFilter.thisWeek:
          if (!item.isActive) return false;
          final DateTime anchor = item.dueAt ?? item.createdAt;
          return isThisWeek(anchor);
      }
    }).toList(growable: false);
  }

  static List<PendingItem> forPatient(List<PendingItem> items, String id) =>
      items
          .where(
            (PendingItem i) => i.childId == id || i.patientId == id,
          )
          .toList(growable: false);

  static List<PendingItem> forCrmSegment(
    List<PendingItem> items,
    CrmSegment segment,
  ) =>
      items
          .where(
            (PendingItem i) => i.isActive && segment.matches(i),
          )
          .toList(growable: false);

  static PendingItem? recommendedNextAction(
    List<PendingItem> items,
    DateTime now,
  ) {
    final List<PendingItem> active =
        items.where((PendingItem i) => i.isActive).toList(growable: false);
    if (active.isEmpty) return null;

    int priority(PendingItem item) {
      if (item.urgent) return 0;
      if (item.displayStatus(now) == PendingDisplayStatus.overdue) return 1;
      return switch (item.kind) {
        PendingKind.draftEncounter => 2,
        PendingKind.returnOverdue => 3,
        PendingKind.vaccineOverdue => 4,
        PendingKind.examPending => 5,
        PendingKind.documentUnsigned => 6,
        PendingKind.returnNotScheduled => 7,
        PendingKind.teleconsultPending => 8,
        PendingKind.adminAppointmentConfirm => 9,
        PendingKind.paymentPending => 10,
        PendingKind.appealDeadlineSoon => 10,
        PendingKind.batchReturnPending => 11,
        PendingKind.glosaWithoutAppeal => 12,
        PendingKind.batchNotSent => 13,
        PendingKind.guideIncomplete => 14,
        PendingKind.authExpiring => 15,
        PendingKind.messageUnread => 16,
        PendingKind.patientInactive => 17,
        PendingKind.activeFollowUp => 13,
        PendingKind.patientNew => 14,
        PendingKind.automationIntegration => 99,
        PendingKind.lotExpired => 5,
        PendingKind.stockBelowMin => 8,
        PendingKind.stockZero => 7,
        PendingKind.lotNearExpiry => 9,
        PendingKind.stockDivergence => 10,
      };
    }

    active.sort((PendingItem a, PendingItem b) {
      final int pa = priority(a);
      final int pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);
      return (a.dueAt ?? a.createdAt).compareTo(b.dueAt ?? b.createdAt);
    });
    return active.first;
  }

  static List<PendingItem> _returnItems(
    PendingAggregatorInput input,
    Map<String, PendingPatientSnapshot> patientsById,
    String? Function(String patientId) childIdFor,
    String? Function(String patientId) nameFor,
  ) {
    final List<PendingItem> out = <PendingItem>[];
    final DateTime now = input.now;

    final Map<String, List<Encounter>> signedByPatient =
        <String, List<Encounter>>{};
    for (final Encounter e in input.encounters) {
      if (e.status != EncounterStatus.signed) continue;
      signedByPatient.putIfAbsent(e.patientId, () => <Encounter>[]).add(e);
    }

    for (final PendingPatientSnapshot p in input.patients) {
      final List<Encounter>? list = signedByPatient[p.patientId];
      if (list == null || list.isEmpty) continue;
      list.sort(
        (Encounter a, Encounter b) => b.startedAt.compareTo(a.startedAt),
      );
      final Encounter last = list.first;

      if (!_encounterSuggestsReturn(last)) continue;

      if (_hasUpcomingAppointment(input.agenda, p.patientId, p.childId, now)) {
        continue;
      }

      final DateTime dueAt =
          _returnDueAt(last) ?? last.startedAt.add(_defaultReturnAfterVisit);
      final bool overdue = dueAt.isBefore(now);
      final PendingKind kind = overdue
          ? PendingKind.returnOverdue
          : PendingKind.returnNotScheduled;
      final CrmSegment segment = overdue
          ? CrmSegment.returnOverdue
          : CrmSegment.noReturnScheduled;

      out.add(
        PendingItem(
          sourceKey: 'return:${kind.name}:${p.patientId}',
          kind: kind,
          category: PendingCategory.clinical,
          title: overdue ? 'Retorno atrasado' : 'Retorno não agendado',
          subtitle: p.name,
          createdAt: last.startedAt,
          dueAt: dueAt,
          patientId: p.patientId,
          childId: childIdFor(p.patientId),
          patientName: p.name,
          urgent: overdue,
          primaryAction: PendingActionKind.scheduleReturn,
          secondaryAction: PendingActionKind.openPatient360,
          crmSegments: <CrmSegment>[segment],
        ),
      );
    }

    return out;
  }

  static List<PendingItem> _patientSegmentItems(PendingAggregatorInput input) {
    final List<PendingItem> out = <PendingItem>[];
    final DateTime now = input.now;

    for (final PendingPatientSnapshot p in input.patients) {
      final DateTime? last = p.lastEncounterAt;

      if (p.encounterCount <= 1 &&
          last != null &&
          now.difference(last) <= _newPatientWithin) {
        out.add(
          PendingItem(
            sourceKey: 'segment:new:${p.patientId}',
            kind: PendingKind.patientNew,
            category: PendingCategory.clinical,
            title: 'Paciente novo',
            subtitle: p.name,
            createdAt: last,
            patientId: p.patientId,
            childId: p.childId,
            patientName: p.name,
            primaryAction: PendingActionKind.openPatient360,
            crmSegments: const <CrmSegment>[CrmSegment.patientNew],
          ),
        );
        continue;
      }

      if (last != null && now.difference(last) > _inactiveAfter) {
        out.add(
          PendingItem(
            sourceKey: 'segment:inactive:${p.patientId}',
            kind: PendingKind.patientInactive,
            category: PendingCategory.clinical,
            title: 'Paciente inativo',
            subtitle: p.name,
            createdAt: last,
            dueAt: last.add(_inactiveAfter),
            patientId: p.patientId,
            childId: p.childId,
            patientName: p.name,
            primaryAction: PendingActionKind.scheduleReturn,
            secondaryAction: PendingActionKind.openPatient360,
            crmSegments: const <CrmSegment>[CrmSegment.patientInactive],
          ),
        );
        continue;
      }

      if (p.encounterCount >= 2 &&
          last != null &&
          now.difference(last) <= _activeFollowUpWithin) {
        out.add(
          PendingItem(
            sourceKey: 'segment:followup:${p.patientId}',
            kind: PendingKind.activeFollowUp,
            category: PendingCategory.clinical,
            title: 'Acompanhamento ativo',
            subtitle: p.name,
            createdAt: last,
            patientId: p.patientId,
            childId: p.childId,
            patientName: p.name,
            primaryAction: PendingActionKind.openPatient360,
            crmSegments: const <CrmSegment>[CrmSegment.activeFollowUp],
          ),
        );
      }
    }

    return out;
  }

  static bool _encounterSuggestsReturn(Encounter encounter) {
    if (encounter.type == EncounterType.followUp) return true;
    final String blob =
        '${encounter.plan}\n${encounter.assessment}'.toLowerCase();
    return blob.contains('retorno') ||
        blob.contains('retornar') ||
        blob.contains('reavali') ||
        blob.contains('reconsult');
  }

  static DateTime? _returnDueAt(Encounter encounter) {
    final String text = '${encounter.plan}\n${encounter.assessment}';

    final RegExp iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
    final RegExpMatch? isoMatch = iso.firstMatch(text);
    if (isoMatch != null) {
      return DateTime.tryParse(isoMatch.group(0)!);
    }

    final RegExp br = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})');
    final RegExpMatch? brMatch = br.firstMatch(text);
    if (brMatch != null) {
      final int day = int.parse(brMatch.group(1)!);
      final int month = int.parse(brMatch.group(2)!);
      int year = int.parse(brMatch.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }

    final RegExp daysLater =
        RegExp(r'(?:em|ap[oó]s)\s+(\d+)\s+dias?', caseSensitive: false);
    final RegExpMatch? daysMatch = daysLater.firstMatch(text);
    if (daysMatch != null) {
      final int days = int.parse(daysMatch.group(1)!);
      return encounter.startedAt.add(Duration(days: days));
    }

    return null;
  }

  static bool _hasUpcomingAppointment(
    List<Appointment> agenda,
    String patientId,
    String childId,
    DateTime now,
  ) {
    for (final Appointment a in agenda) {
      if (!a.status.isActive) continue;
      if (a.startsAt.isBefore(now.subtract(const Duration(hours: 1)))) {
        continue;
      }
      if (a.patientId == patientId ||
          a.childId == patientId ||
          a.childId == childId) {
        return true;
      }
    }
    return false;
  }

  static List<PendingItem> _billingItems(
    PendingAggregatorInput input,
    String? Function(String patientId) childIdFor,
    String? Function(String patientId) nameFor,
  ) {
    final DateTime now = input.now;
    final List<PendingItem> out = <PendingItem>[];
    const Duration authSoon = Duration(days: 7);
    const Duration batchStale = Duration(days: 5);
    const Duration appealSoon = Duration(days: 3);

    for (final InsuranceAuthorization a in input.authorizations) {
      if (a.status != AuthorizationStatus.authorized) continue;
      if (a.validUntil == null) continue;
      if (a.validUntil!.isBefore(now)) continue;
      if (a.validUntil!.isAfter(now.add(authSoon))) continue;
      out.add(
        PendingItem(
          sourceKey: 'billing:authExpiring:${a.id}',
          kind: PendingKind.authExpiring,
          category: PendingCategory.administrative,
          title: 'Autorizacao expirando',
          subtitle: a.procedureName.isEmpty ? a.authNumber : a.procedureName,
          createdAt: a.requestedAt,
          dueAt: a.validUntil,
          childId: a.childId,
          patientId: a.patientId,
          referenceId: 'autorizacoes',
          primaryAction: PendingActionKind.openBilling,
        ),
      );
    }

    for (final BillingGuide g in input.billingGuides) {
      if (g.status == BillingGuideStatus.cancelled ||
          g.status == BillingGuideStatus.paid) {
        continue;
      }
      PatientInsurance? ins;
      for (final PatientInsurance p in input.patientInsurances) {
        if (p.childId == g.childId) {
          ins = p;
          break;
        }
      }
      InsuranceAuthorization? auth;
      if (g.authorizationId != null) {
        for (final InsuranceAuthorization a in input.authorizations) {
          if (a.id == g.authorizationId) {
            auth = a;
            break;
          }
        }
      }
      final List<BillingValidationIssue> issues = validateGuideForBatch(
        guide: g,
        now: now,
        patientInsurance: ins,
        authorization: auth,
        requiresAuth: g.type != BillingGuideType.consultation,
      );
      if (issues.isEmpty && g.status != BillingGuideStatus.draft) continue;
      if (issues.isNotEmpty || g.status == BillingGuideStatus.draft) {
        out.add(
          PendingItem(
            sourceKey: 'billing:guideIncomplete:${g.id}',
            kind: PendingKind.guideIncomplete,
            category: PendingCategory.financial,
            title: 'Guia incompleta',
            subtitle: issues.isNotEmpty
                ? issues.first.message
                : 'Rascunho de guia',
            createdAt: g.serviceDate,
            childId: g.childId,
            referenceId: 'guias',
            primaryAction: PendingActionKind.openBilling,
          ),
        );
      }
    }

    for (final BillingBatch b in input.billingBatches) {
      if (b.status == BillingBatchStatus.closed &&
          (b.sentAt == null ||
              b.sentAt!.isBefore(now.subtract(batchStale)))) {
        out.add(
          PendingItem(
            sourceKey: 'billing:batchNotSent:${b.id}',
            kind: PendingKind.batchNotSent,
            category: PendingCategory.financial,
            title: 'Lote nao enviado',
            subtitle: '${b.guideCount} guias · fechado',
            createdAt: b.periodEnd,
            dueAt: b.sentAt ?? b.periodEnd.add(batchStale),
            referenceId: 'lotes',
            primaryAction: PendingActionKind.openBilling,
          ),
        );
      }
      if (b.status == BillingBatchStatus.sent ||
          b.status == BillingBatchStatus.processing) {
        out.add(
          PendingItem(
            sourceKey: 'billing:batchReturn:${b.id}',
            kind: PendingKind.batchReturnPending,
            category: PendingCategory.financial,
            title: 'Retorno de lote pendente',
            subtitle: b.protocol.isEmpty ? b.id : b.protocol,
            createdAt: b.sentAt ?? b.periodEnd,
            dueAt: (b.sentAt ?? now).add(const Duration(days: 15)),
            referenceId: 'lotes',
            primaryAction: PendingActionKind.openBilling,
          ),
        );
      }
    }

    for (final BillingGlosa gl in input.billingGlosas) {
      if (gl.status == BillingGlosaStatus.resolved ||
          gl.status == BillingGlosaStatus.accepted) {
        continue;
      }
      if (gl.status == BillingGlosaStatus.new_ ||
          gl.status == BillingGlosaStatus.analyzing) {
        out.add(
          PendingItem(
            sourceKey: 'billing:glosaNoAppeal:${gl.id}',
            kind: PendingKind.glosaWithoutAppeal,
            category: PendingCategory.financial,
            title: 'Glosa sem recurso',
            subtitle: gl.reason.isEmpty ? 'Analisar glosa' : gl.reason,
            createdAt: gl.glosaDate,
            childId: gl.childId,
            referenceId: 'glosas',
            primaryAction: PendingActionKind.openBilling,
          ),
        );
      }
      if (gl.appealDeadline != null &&
          !gl.appealDeadline!.isBefore(now) &&
          gl.appealDeadline!.isBefore(now.add(appealSoon)) &&
          gl.status != BillingGlosaStatus.appealSent) {
        out.add(
          PendingItem(
            sourceKey: 'billing:appealSoon:${gl.id}',
            kind: PendingKind.appealDeadlineSoon,
            category: PendingCategory.financial,
            title: 'Prazo de recurso proximo',
            subtitle: gl.reason,
            createdAt: gl.glosaDate,
            dueAt: gl.appealDeadline,
            urgent: true,
            childId: gl.childId,
            referenceId: 'glosas',
            primaryAction: PendingActionKind.openBilling,
          ),
        );
      }
    }

    return out;
  }

  static List<PendingItem> _inventoryItems(PendingAggregatorInput input) {
    final DateTime now = input.now;
    final List<PendingItem> out = <PendingItem>[];
    const InventoryExpiryConfig expiryConfig = InventoryExpiryConfig();

    for (final InventoryItem item in input.inventoryItems) {
      if (!item.active) continue;
      final int stock = stockQtyForItem(
        itemId: item.id,
        lots: input.inventoryLots,
      );
      if (stock == 0 && item.idealQty > 0) {
        out.add(
          PendingItem(
            sourceKey: 'inventory:zero:${item.id}',
            kind: PendingKind.stockZero,
            category: PendingCategory.administrative,
            title: 'Estoque zerado',
            subtitle: item.name,
            createdAt: now,
            referenceId: item.id,
            primaryAction: PendingActionKind.openInventory,
          ),
        );
      } else if (item.minQty > 0 && stock < item.minQty) {
        out.add(
          PendingItem(
            sourceKey: 'inventory:belowMin:${item.id}',
            kind: PendingKind.stockBelowMin,
            category: PendingCategory.administrative,
            title: 'Estoque abaixo do minimo',
            subtitle: '${item.name} ($stock / min ${item.minQty})',
            createdAt: now,
            referenceId: item.id,
            primaryAction: PendingActionKind.openInventory,
          ),
        );
      }
    }

    for (final InventoryLot lot in input.inventoryLots) {
      if (lot.qty <= 0) continue;
      final LotExpiryStatus st = lotExpiryStatus(
        expiresAt: lot.expiresAt,
        now: now,
        config: expiryConfig,
      );
      if (st == LotExpiryStatus.expired) {
        out.add(
          PendingItem(
            sourceKey: 'inventory:expired:${lot.id}',
            kind: PendingKind.lotExpired,
            category: PendingCategory.administrative,
            title: 'Lote vencido',
            subtitle: 'Lote ${lot.lotCode}',
            createdAt: lot.receivedAt,
            dueAt: lot.expiresAt,
            urgent: true,
            referenceId: lot.id,
            primaryAction: PendingActionKind.openInventory,
          ),
        );
      } else if (st == LotExpiryStatus.nearExpiry) {
        out.add(
          PendingItem(
            sourceKey: 'inventory:nearExpiry:${lot.id}',
            kind: PendingKind.lotNearExpiry,
            category: PendingCategory.administrative,
            title: 'Lote perto do vencimento',
            subtitle: 'Lote ${lot.lotCode}',
            createdAt: lot.receivedAt,
            dueAt: lot.expiresAt,
            referenceId: lot.id,
            primaryAction: PendingActionKind.openInventory,
          ),
        );
      }
    }

    for (final InventoryCount count in input.inventoryCounts) {
      if (count.status != 'open') continue;
      for (final InventoryCountLine line in count.lines) {
        if (line.divergence == 0) continue;
        out.add(
          PendingItem(
            sourceKey: 'inventory:count:${count.id}:${line.lotId}',
            kind: PendingKind.stockDivergence,
            category: PendingCategory.administrative,
            title: 'Divergencia de inventario',
            subtitle: 'Lote ${line.lotId} (${line.divergence})',
            createdAt: count.startedAt,
            referenceId: count.id,
            primaryAction: PendingActionKind.openInventory,
          ),
        );
      }
    }

    return out;
  }

  static PendingItem _applyTracking(
    PendingItem item,
    Map<String, PendingTrackingRecord> trackingBySourceKey,
  ) {
    final PendingTrackingRecord? record = trackingBySourceKey[item.sourceKey];
    if (record == null) return item;
    return item.copyWith(
      workflowStatus: record.status,
      resolvedAt: record.resolvedAt,
      resolvedBy: record.resolvedBy,
    );
  }
}
