import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/clinical_access.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../emr/presentation/screens/encounter_editor_screen.dart';
import '../../../emr/presentation/screens/patient_timeline_screen.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/telemedicine_screen.dart'
    show telemedicineRepositoryProvider;
import '../../domain/patient_360_timeline.dart';
import '../../../billing/domain/billing_access.dart';
import '../../../billing/domain/billing_models.dart';
import '../../../billing/presentation/providers/billing_providers.dart';
import '../../../finance/domain/finance_access.dart';
import '../../../finance/domain/finance_models.dart';
import '../../../finance/presentation/providers/finance_providers.dart';
import '../../../pending/domain/pending_item.dart';
import '../../../pending/presentation/pending_actions.dart';
import '../../../pending/presentation/providers/pending_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../../shared/domain/entities/commerce.dart';

final StreamProviderFamily<List<Appointment>, String>
    childAppointments360Provider =
    StreamProvider.family<List<Appointment>, String>((Ref ref, String childId) {
  return ref
      .watch(telemedicineRepositoryProvider)
      .watchChildAppointments(childId);
});

/// Hub Paciente 360 — resume dados reais e aponta para módulos existentes.
class Patient360Screen extends ConsumerStatefulWidget {
  const Patient360Screen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<Patient360Screen> createState() => _Patient360ScreenState();
}

class _Patient360ScreenState extends ConsumerState<Patient360Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _ageLabel(DateTime? birth) {
    if (birth == null) return '';
    final DateTime now = DateTime.now();
    int months =
        (now.year - birth.year) * 12 + (now.month - birth.month);
    if (now.day < birth.day) months -= 1;
    if (months < 0) months = 0;
    if (months < 24) return '$months ${months == 1 ? 'mês' : 'meses'}';
    final int years = months ~/ 12;
    return '$years ${years == 1 ? 'ano' : 'anos'}';
  }

  @override
  Widget build(BuildContext context) {
    final String id = widget.childId;
    final AsyncValue<List<Encounter>> encountersAsync =
        ref.watch(patientEncountersProvider(id));
    final AsyncValue<List<ClinicalDocument>> docsAsync =
        ref.watch(patientDocumentsProvider(id));
    final AsyncValue<List<LabResult>> labsAsync =
        ref.watch(patientLabsProvider(id));
    final AsyncValue<List<Appointment>> apptsAsync =
        ref.watch(childAppointments360Provider(id));

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Paciente 360'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.inkMuted,
          tabs: const <Widget>[
            Tab(text: 'Resumo'),
            Tab(text: 'Timeline'),
            Tab(text: 'Módulos'),
          ],
        ),
      ),
      body: encountersAsync.when(
        loading: () => const SkeletonList(itemCount: 5, itemHeight: 72),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(clinicalLoadErrorMessage(e)),
          onRetry: () {
            ref.invalidate(patientEncountersProvider(id));
            ref.invalidate(patientDocumentsProvider(id));
            ref.invalidate(patientLabsProvider(id));
            ref.invalidate(childAppointments360Provider(id));
          },
        ),
        data: (List<Encounter> encounters) {
          final List<ClinicalDocument> docs =
              docsAsync.valueOrNull ?? const <ClinicalDocument>[];
          final List<LabResult> labs =
              labsAsync.valueOrNull ?? const <LabResult>[];
          final List<Appointment> appts =
              apptsAsync.valueOrNull ?? const <Appointment>[];

          final Encounter? latest =
              encounters.isEmpty ? null : (List<Encounter>.from(encounters)
                ..sort((Encounter a, Encounter b) =>
                    b.startedAt.compareTo(a.startedAt))).first;

          final String name = latest?.patientName?.isNotEmpty == true
              ? latest!.patientName!
              : 'Paciente';
          final List<String> allergies =
              latest?.anamnesis.allergies ?? const <String>[];
          final List<String> meds =
              latest?.anamnesis.currentMedications ?? const <String>[];
          final bool hasDraft = encounters
              .any((Encounter e) => e.status == EncounterStatus.draft);
          final Appointment? nextAppt = appts
              .where(
                (Appointment a) =>
                    a.startsAt.isAfter(DateTime.now()) &&
                    a.status != AppointmentStatus.cancelled &&
                    a.status != AppointmentStatus.noShow,
              )
              .fold<Appointment?>(
                null,
                (Appointment? best, Appointment a) =>
                    best == null || a.startsAt.isBefore(best.startsAt)
                        ? a
                        : best,
              );

          final List<Patient360Event> timeline = buildPatient360Timeline(
            encounters: encounters,
            appointments: appts,
            documents: docs,
            labs: labs,
          );

          return Column(
            children: <Widget>[
              _Header(
                name: name,
                ageLabel: _ageLabel(latest?.patientBirthDate),
                childId: id,
                allergies: allergies,
                hasDraft: hasDraft,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: <Widget>[
                    _SummaryTab(
                      childId: id,
                      latest: latest,
                      nextAppt: nextAppt,
                      allergies: allergies,
                      meds: meds,
                      encounterCount: encounters.length,
                      docCount: docs.length,
                      labCount: labs.length,
                      onOpenProntuario: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PatientTimelineScreen(
                              patientId: id,
                              patientName: name,
                            ),
                          ),
                        );
                      },
                    ),
                    _TimelineTab(
                      events: timeline,
                      apptsLoading: apptsAsync.isLoading,
                      docsLoading: docsAsync.isLoading,
                      labsLoading: labsAsync.isLoading,
                      onOpenProntuario: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PatientTimelineScreen(
                              patientId: id,
                              patientName: name,
                            ),
                          ),
                        );
                      },
                      onOpenEncounter: (String encounterId) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                EncounterEditorScreen(encounterId: encounterId),
                          ),
                        );
                      },
                    ),
                    _ModulesTab(childId: id),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.ageLabel,
    required this.childId,
    required this.allergies,
    required this.hasDraft,
  });

  final String name;
  final String ageLabel;
  final String childId;
  final List<String> allergies;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.softTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    color: AppColors.tealDeep,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        [
                          if (ageLabel.isNotEmpty) ageLabel,
                          'ID ${childId.length > 12 ? '${childId.substring(0, 12)}…' : childId}',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (allergies.isNotEmpty || hasDraft) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  if (hasDraft)
                    Chip(
                      label: const Text('Rascunho aberto'),
                      backgroundColor: AppColors.honey.withValues(alpha: 0.2),
                      labelStyle: theme.textTheme.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  ...allergies.take(4).map(
                        (String a) => Chip(
                          avatar: const Icon(Icons.warning_amber_rounded,
                              size: 14, color: AppColors.danger),
                          label: Text(a),
                          backgroundColor:
                              AppColors.danger.withValues(alpha: 0.08),
                          labelStyle: theme.textTheme.labelSmall,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({
    required this.childId,
    required this.latest,
    required this.nextAppt,
    required this.allergies,
    required this.meds,
    required this.encounterCount,
    required this.docCount,
    required this.labCount,
    required this.onOpenProntuario,
  });

  final String childId;
  final Encounter? latest;
  final Appointment? nextAppt;
  final List<String> allergies;
  final List<String> meds;
  final int encounterCount;
  final int docCount;
  final int labCount;
  final VoidCallback onOpenProntuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateFormat fmt = DateFormat('dd/MM/yyyy HH:mm');
    final ThemeData theme = Theme.of(context);
    final List<PendingItem> pending =
        ref.watch(patientPendingItemsProvider(childId)).valueOrNull ??
            const <PendingItem>[];
    final PendingItem? recommended =
        ref.watch(patientRecommendedActionProvider(childId)).valueOrNull;
    final List<PendingItem> clinical = pending
        .where(
          (PendingItem i) =>
              i.category == PendingCategory.clinical && i.isActive,
        )
        .toList(growable: false);
    final List<PendingItem> admin = pending
        .where(
          (PendingItem i) =>
              i.category == PendingCategory.administrative && i.isActive,
        )
        .toList(growable: false);
    final List<PendingItem> financial = pending
        .where(
          (PendingItem i) =>
              i.category == PendingCategory.financial && i.isActive,
        )
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MiniKpi(
                label: 'Atendimentos',
                value: '$encounterCount',
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniKpi(
                label: 'Documentos',
                value: '$docCount',
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniKpi(
                label: 'Exames',
                value: '$labCount',
                color: AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Última consulta',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (latest == null)
                Text(
                  'Nenhum atendimento registrado ainda.',
                  style: theme.textTheme.bodySmall,
                )
              else ...<Widget>[
                Text(fmt.format(latest!.startedAt)),
                Text(
                  '${latest!.professionalName} · ${latest!.type.label} · '
                  '${latest!.status.label}',
                ),
                if (latest!.primaryDiagnosis != null)
                  Text('Dx: ${latest!.primaryDiagnosis!.description}'),
                if (latest!.vitals.weightKg != null ||
                    latest!.vitals.heightCm != null)
                  Text(
                    [
                      if (latest!.vitals.weightKg != null)
                        'Peso ${latest!.vitals.weightKg} kg',
                      if (latest!.vitals.heightCm != null)
                        'Altura ${latest!.vitals.heightCm} cm',
                    ].join(' · '),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Próximo retorno / agenda',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                nextAppt == null
                    ? 'Nenhum agendamento futuro.'
                    : '${fmt.format(nextAppt!.startsAt)} · '
                        '${nextAppt!.type.label} · ${nextAppt!.professionalName}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _PatientFinanceSummary(childId: childId),
        _PatientBillingSummary(childId: childId),
        if (allergies.isNotEmpty || meds.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Alertas clínicos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                if (allergies.isNotEmpty)
                  Text('Alergias: ${allergies.join(', ')}'),
                if (meds.isNotEmpty)
                  Text('Medicações: ${meds.join(', ')}'),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Pendências',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Clínicas: ${clinical.length} · '
                'Administrativas: ${admin.length} · '
                'Financeiras: ${financial.length}',
                style: theme.textTheme.bodySmall,
              ),
              if (recommended != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Próxima ação recomendada',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(recommended.title),
                Text(
                  recommended.subtitle,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonal(
                  onPressed: () => runPendingAction(
                    context,
                    ref,
                    recommended,
                    recommended.primaryAction,
                  ),
                  child: const Text('Executar ação'),
                ),
              ],
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Nenhuma pendência ativa para este paciente.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onOpenProntuario,
          icon: const AppIcon(
            asset: AppIcons.medicalRecord,
            size: 18,
            fallback: Icons.folder_shared_outlined,
          ),
          label: const Text('Abrir prontuário completo'),
        ),
      ],
    );
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.events,
    required this.apptsLoading,
    required this.docsLoading,
    required this.labsLoading,
    required this.onOpenProntuario,
    required this.onOpenEncounter,
  });

  final List<Patient360Event> events;
  final bool apptsLoading;
  final bool docsLoading;
  final bool labsLoading;
  final VoidCallback onOpenProntuario;
  final void Function(String encounterId) onOpenEncounter;

  IconData _icon(Patient360EventKind k) => switch (k) {
        Patient360EventKind.encounter => Icons.medical_services_outlined,
        Patient360EventKind.appointment => Icons.event_outlined,
        Patient360EventKind.document => Icons.description_outlined,
        Patient360EventKind.lab => Icons.science_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final DateFormat fmt = DateFormat('dd/MM/yyyy HH:mm');
    final bool loadingExtras = apptsLoading || docsLoading || labsLoading;

    if (events.isEmpty && !loadingExtras) {
      return EmptyState(
        title: 'Timeline vazia',
        message:
            'Atendimentos, agendamentos, documentos e exames deste paciente '
            'aparecem aqui em ordem cronológica.',
        icon: Icons.timeline_outlined,
        actionLabel: 'Abrir prontuário',
        onAction: onOpenProntuario,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: events.length + (loadingExtras ? 1 : 0) + 1,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (BuildContext context, int i) {
        if (loadingExtras && i == 0) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final int offset = loadingExtras ? 1 : 0;
        if (i == events.length + offset) {
          return TextButton(
            onPressed: onOpenProntuario,
            child: const Text('Ver linha do tempo completa do prontuário'),
          );
        }
        final Patient360Event e = events[i - offset];
        return AppCard(
          color: Colors.white,
          onTap: e.encounterId != null
              ? () => onOpenEncounter(e.encounterId!)
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _icon(e.kind),
                color: e.flagged ? AppColors.danger : AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      e.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    Text(
                      e.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      fmt.format(e.at),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModulesTab extends StatelessWidget {
  const _ModulesTab({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const BrandSectionHeader(title: 'Acompanhar'),
        QuickAccessCard(
          label: 'Prontuário / pacientes',
          subtitle: 'Linha do tempo e atendimentos',
          icon: Icons.folder_shared_outlined,
          asset: AppIcons.medicalRecord,
          color: AppColors.brand,
          wide: true,
          onTap: () => context.go(Routes.patientsPath),
        ),
        const SizedBox(height: AppSpacing.sm),
        QuickAccessCard(
          label: 'Crescimento',
          subtitle: 'Peso, altura e curvas',
          icon: Icons.show_chart_rounded,
          asset: AppIcons.growth,
          color: AppColors.teal,
          wide: true,
          onTap: () => context.push(Routes.growth(childId)),
        ),
        const SizedBox(height: AppSpacing.sm),
        QuickAccessCard(
          label: 'Vacinas',
          subtitle: 'Calendário e doses',
          icon: Icons.vaccines_outlined,
          asset: AppIcons.vaccines,
          color: AppColors.raspberry,
          wide: true,
          onTap: () => context.push(Routes.vaccines(childId)),
        ),
        const SizedBox(height: AppSpacing.sm),
        QuickAccessCard(
          label: 'Consulta com IA',
          subtitle: 'Iniciar gravação assistida',
          icon: Icons.mic_rounded,
          asset: AppIcons.microphone,
          color: AppColors.navy,
          wide: true,
          onTap: () => context.push(
            '${Routes.clinicVoicePath}?childId=$childId',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        QuickAccessCard(
          label: 'Suplementação',
          subtitle: 'Exames, calculadora e acompanhamento',
          icon: Icons.science_outlined,
          color: AppColors.tealDeep,
          wide: true,
          onTap: () => context.push(
            Routes.supplementWithChild(Routes.supplementPath, childId),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        QuickAccessCard(
          label: 'Recepção',
          subtitle: 'Fila e check-in do dia',
          icon: Icons.how_to_reg_rounded,
          asset: AppIcons.waitingQueue,
          color: AppColors.honey,
          wide: true,
          onTap: () => context.push(Routes.clinicReceptionPath),
        ),
      ],
    );
  }
}

class _PatientFinanceSummary extends ConsumerWidget {
  const _PatientFinanceSummary({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canSee = FinanceAccess.canViewPatientFinance(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!canSee) return const SizedBox.shrink();

    final AsyncValue<List<FinanceReceivable>> recvAsync =
        ref.watch(patientFinanceReceivablesProvider(childId));
    final AsyncValue<List<FinanceReceipt>> receiptsAsync =
        ref.watch(financeReceiptsProvider);

    return recvAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<FinanceReceivable> recv) {
        final DateTime now = DateTime.now();
        int openBalance = 0;
        for (final FinanceReceivable r in recv) {
          if (r.effectiveStatus(now).isOpen) openBalance += r.openCents;
        }
        final List<FinanceReceivable> recent = recv.toList(growable: false)
          ..sort(
            (FinanceReceivable a, FinanceReceivable b) =>
                b.createdAt.compareTo(a.createdAt),
          );
        final List<FinanceReceipt> receipts =
            receiptsAsync.valueOrNull ?? const <FinanceReceipt>[];
        final List<FinanceReceipt> patientReceipts = receipts
            .where((FinanceReceipt r) => r.patientId == childId)
            .take(3)
            .toList(growable: false);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Financeiro',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.push(Routes.financePath),
                      child: const Text('Ver modulo'),
                    ),
                  ],
                ),
                Text('Saldo em aberto: ${formatCents(openBalance)}'),
                if (recent.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ultimas cobrancas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  ...recent.take(3).map(
                        (FinanceReceivable r) => Text(
                          '${r.description} · ${formatCents(r.totalCents)} · '
                          '${r.effectiveStatus(now).label}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                ],
                if (patientReceipts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Recibos recentes',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  ...patientReceipts.map(
                    (FinanceReceipt r) => Text(
                      '${formatCents(r.amountCents)} · ${r.method.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatientBillingSummary extends ConsumerWidget {
  const _PatientBillingSummary({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canSee = BillingAccess.canViewPatientBilling(
      user: ref.watch(currentUserProvider),
      clinicMembership: ref.watch(activeClinicMembershipProvider),
    );
    if (!canSee) return const SizedBox.shrink();

    final AsyncValue<List<PatientInsurance>> insAsync =
        ref.watch(childBillingInsuranceProvider(childId));
    final List<InsuranceAuthorization> auths =
        ref.watch(billingAuthorizationsProvider).valueOrNull ??
            const <InsuranceAuthorization>[];
    final List<BillingGuide> guides =
        ref.watch(billingGuidesProvider).valueOrNull ?? const <BillingGuide>[];
    final List<BillingGlosa> glosas =
        ref.watch(billingGlosasProvider).valueOrNull ?? const <BillingGlosa>[];

    final List<InsuranceAuthorization> patientAuths = auths
        .where((InsuranceAuthorization a) => a.childId == childId)
        .take(3)
        .toList(growable: false);
    final List<BillingGuide> patientGuides = guides
        .where((BillingGuide g) => g.childId == childId)
        .take(3)
        .toList(growable: false);
    final List<BillingGlosa> patientGlosas = glosas
        .where((BillingGlosa g) => g.childId == childId)
        .take(2)
        .toList(growable: false);

    return insAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<PatientInsurance> ins) {
        if (ins.isEmpty &&
            patientAuths.isEmpty &&
            patientGuides.isEmpty &&
            patientGlosas.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Convenio / faturamento',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                    ),
                    TextButton(
                      onPressed: () => context.push(
                        '${Routes.billingPatientInsurancePath}?childId=$childId',
                      ),
                      child: const Text('Ver modulo'),
                    ),
                  ],
                ),
                if (ins.isNotEmpty)
                  Text(
                    'Plano: ${ins.first.coverageType.label}'
                    '${ins.first.cardNumber.isNotEmpty ? ' · ${ins.first.cardNumber}' : ''}'
                    '${ins.first.validUntil != null ? ' · val. ${ins.first.validUntil!.toLocal().toString().split(' ').first}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (patientAuths.isNotEmpty)
                  Text(
                    'Autorizacoes: ${patientAuths.length} recente(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (patientGuides.isNotEmpty)
                  Text(
                    'Guias: ${patientGuides.length} recente(s)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (patientGlosas.isNotEmpty)
                  Text(
                    'Glosas abertas: ${patientGlosas.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
