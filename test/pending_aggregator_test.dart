import 'package:flutter_test/flutter_test.dart';
import 'package:pediatria360/features/billing/domain/billing_models.dart';
import 'package:pediatria360/features/notifications/presentation/notification_center_screen.dart';
import 'package:pediatria360/features/pending/data/pending_tracking_record.dart';
import 'package:pediatria360/features/finance/domain/finance_models.dart';
import 'package:pediatria360/features/inventory/domain/inventory_models.dart';
import 'package:pediatria360/features/pending/domain/pending_aggregator.dart';
import 'package:pediatria360/features/pending/domain/pending_item.dart';
import 'package:pediatria360/features/telemedicine/data/telemedicine_repository.dart';
import 'package:pediatria360/shared/domain/entities/clinical_record.dart';
import 'package:pediatria360/shared/domain/entities/encounter.dart';

void main() {
  final DateTime now = DateTime(2026, 3, 1, 12);

  group('PendingAggregator', () {
    test('builds draft and unread message items', () {
      final List<PendingItem> items = PendingAggregator.build(
        PendingAggregatorInput(
          now: now,
          patients: const <PendingPatientSnapshot>[],
          encounters: <Encounter>[
            Encounter(
              id: 'e1',
              patientId: 'p1',
              professionalId: 'pro1',
              professionalName: 'Dr',
              type: EncounterType.routine,
              status: EncounterStatus.draft,
              startedAt: now.subtract(const Duration(days: 1)),
              patientName: 'Ana',
            ),
          ],
          agenda: const <Appointment>[],
          notifications: <AppNotification>[
            AppNotification(
              id: 'n1',
              type: 'content',
              title: 'Aviso',
              body: 'Corpo',
              createdAt: now,
              read: false,
            ),
          ],
          unsignedDocuments: const <ClinicalDocument>[],
          pendingLabs: const <LabResult>[],
          vaccineOverdue: const <VaccineOverdueInput>[],
          trackingBySourceKey: const <String, PendingTrackingRecord>{},
        ),
      );

      expect(
        items.any((PendingItem i) => i.kind == PendingKind.draftEncounter),
        isTrue,
      );
      expect(
        items.any((PendingItem i) => i.kind == PendingKind.messageUnread),
        isTrue,
      );
    });

    test('merges resolved tracking', () {
      const String key = 'draft:e1';
      final List<PendingItem> items = PendingAggregator.build(
        PendingAggregatorInput(
          now: now,
          patients: const <PendingPatientSnapshot>[],
          encounters: <Encounter>[
            Encounter(
              id: 'e1',
              patientId: 'p1',
              professionalId: 'pro1',
              professionalName: 'Dr',
              type: EncounterType.routine,
              status: EncounterStatus.draft,
              startedAt: now,
            ),
          ],
          agenda: const <Appointment>[],
          notifications: const <AppNotification>[],
          unsignedDocuments: const <ClinicalDocument>[],
          pendingLabs: const <LabResult>[],
          vaccineOverdue: const <VaccineOverdueInput>[],
          trackingBySourceKey: <String, PendingTrackingRecord>{
            key: PendingTrackingRecord(
              id: key,
              professionalId: 'pro1',
              sourceKey: key,
              kind: 'draftEncounter',
              status: PendingWorkflowStatus.resolved,
              updatedAt: now,
              resolvedAt: now,
              resolvedBy: 'pro1',
            ),
          },
        ),
      );

      final PendingItem draft = items.firstWhere(
        (PendingItem i) => i.sourceKey == key,
      );
      expect(draft.workflowStatus, PendingWorkflowStatus.resolved);
      expect(draft.isActive, isFalse);
    });

    test('filters clinical and resolved', () {
      final List<PendingItem> items = <PendingItem>[
        PendingItem(
          sourceKey: 'a',
          kind: PendingKind.examPending,
          category: PendingCategory.clinical,
          title: 'Exame',
          subtitle: 'x',
          createdAt: now,
          workflowStatus: PendingWorkflowStatus.open,
        ),
        PendingItem(
          sourceKey: 'b',
          kind: PendingKind.paymentPending,
          category: PendingCategory.financial,
          title: 'Pag',
          subtitle: 'x',
          createdAt: now,
          workflowStatus: PendingWorkflowStatus.resolved,
        ),
      ];

      final List<PendingItem> clinical =
          PendingAggregator.filterByCenterFilter(
        items,
        PendingCenterFilter.clinical,
        now,
      );
      expect(clinical.length, 1);

      final List<PendingItem> resolved =
          PendingAggregator.filterByCenterFilter(
        items,
        PendingCenterFilter.resolved,
        now,
      );
      expect(resolved.length, 1);
    });

    test('links items to patient id', () {
      final List<PendingItem> items = <PendingItem>[
        PendingItem(
          sourceKey: 'exam:1',
          kind: PendingKind.examPending,
          category: PendingCategory.clinical,
          title: 'Exame',
          subtitle: 'x',
          createdAt: now,
          childId: 'child-1',
        ),
      ];
      final List<PendingItem> forPatient =
          PendingAggregator.forPatient(items, 'child-1');
      expect(forPatient.length, 1);
    });

    test('dashboard attention counts', () {
      final List<PendingItem> items = <PendingItem>[
        PendingItem(
          sourceKey: 'v1',
          kind: PendingKind.vaccineOverdue,
          category: PendingCategory.clinical,
          title: 'Vac',
          subtitle: '',
          createdAt: now,
        ),
        PendingItem(
          sourceKey: 'd1',
          kind: PendingKind.draftEncounter,
          category: PendingCategory.clinical,
          title: 'Rasc',
          subtitle: '',
          createdAt: now,
        ),
      ];
      final PendingAttentionCounts counts =
          PendingAggregator.attentionCounts(items);
      expect(counts.vaccineOverdue, 1);
      expect(counts.returnsAndDrafts, 1);
    });

    test('prefers finance receivable over appointment payment key', () {
      final List<PendingItem> items = PendingAggregator.build(
        PendingAggregatorInput(
          now: now,
          patients: const <PendingPatientSnapshot>[],
          encounters: const <Encounter>[],
          agenda: <Appointment>[
            Appointment(
              id: 'appt-1',
              patientId: 'p1',
              professionalId: 'pro1',
              professionalName: 'Dr',
              startsAt: now,
              durationMinutes: 30,
              status: AppointmentStatus.confirmed,
              createdAt: now,
              priceCents: 10000,
              paid: false,
            ),
          ],
          notifications: const <AppNotification>[],
          unsignedDocuments: const <ClinicalDocument>[],
          pendingLabs: const <LabResult>[],
          vaccineOverdue: const <VaccineOverdueInput>[],
          trackingBySourceKey: const <String, PendingTrackingRecord>{},
          openReceivables: <FinanceReceivable>[
            FinanceReceivable(
              id: 'appt_appt-1',
              ownerId: 'pro1',
              totalCents: 10000,
              paidCents: 0,
              status: ReceivableStatus.pending,
              dueAt: now,
              createdAt: now,
              appointmentId: 'appt-1',
              description: 'Consulta',
            ),
          ],
        ),
      );
      final List<String> paymentKeys = items
          .where((PendingItem i) => i.kind == PendingKind.paymentPending)
          .map((PendingItem i) => i.sourceKey)
          .toList(growable: false);
      expect(paymentKeys, contains('finance_recv:appt_appt-1'));
      expect(paymentKeys, isNot(contains('payment:appt-1')));
    });

    test('expired lot creates inventory pending', () {
      final List<PendingItem> items = PendingAggregator.build(
        PendingAggregatorInput(
          now: now,
          patients: const <PendingPatientSnapshot>[],
          encounters: const <Encounter>[],
          agenda: const <Appointment>[],
          notifications: const <AppNotification>[],
          unsignedDocuments: const <ClinicalDocument>[],
          pendingLabs: const <LabResult>[],
          vaccineOverdue: const <VaccineOverdueInput>[],
          trackingBySourceKey: const <String, PendingTrackingRecord>{},
          inventoryItems: <InventoryItem>[
            InventoryItem(
              id: 'vac1',
              name: 'BCG',
              code: 'BCG',
              category: InventoryCategory.vaccines,
              unit: InventoryUnit.vial,
              ownerId: 'o',
            ),
          ],
          inventoryLots: <InventoryLot>[
            InventoryLot(
              id: 'lot1',
              itemId: 'vac1',
              lotCode: 'L-OLD',
              expiresAt: now.subtract(const Duration(days: 2)),
              qty: 3,
              unitCostCents: 100,
              receivedAt: now.subtract(const Duration(days: 100)),
              ownerId: 'o',
            ),
          ],
        ),
      );
      expect(
        items.any((PendingItem i) => i.kind == PendingKind.lotExpired),
        isTrue,
      );
    });

    test('auth expiring creates billing pending', () {
      final List<PendingItem> items = PendingAggregator.build(
        PendingAggregatorInput(
          now: now,
          patients: const <PendingPatientSnapshot>[],
          encounters: const <Encounter>[],
          agenda: const <Appointment>[],
          notifications: const <AppNotification>[],
          unsignedDocuments: const <ClinicalDocument>[],
          pendingLabs: const <LabResult>[],
          vaccineOverdue: const <VaccineOverdueInput>[],
          trackingBySourceKey: const <String, PendingTrackingRecord>{},
          authorizations: <InsuranceAuthorization>[
            InsuranceAuthorization(
              id: 'auth1',
              ownerId: 'o',
              childId: 'child1',
              requestedAt: now.subtract(const Duration(days: 20)),
              status: AuthorizationStatus.authorized,
              validUntil: now.add(const Duration(days: 3)),
              authNumber: '123',
              procedureName: 'Sessao',
            ),
          ],
        ),
      );
      expect(
        items.any((PendingItem i) => i.kind == PendingKind.authExpiring),
        isTrue,
      );
    });
  });
}
