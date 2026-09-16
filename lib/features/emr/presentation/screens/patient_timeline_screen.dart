import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../../shared/domain/entities/vaccine.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../../vaccines/domain/pni_calendar.dart';
import '../../data/encounter_repository.dart';
import 'document_viewer_screen.dart';
import 'encounter_editor_screen.dart';
import 'patient_summary_formatting.dart';
import '../widgets/patient_chart_widgets.dart';
import '../../../children/presentation/screens/child_form_screen.dart';
import '../../../../core/widgets/brand_ui.dart';

final Provider<EncounterRepository> encounterRepositoryProvider =
    Provider<EncounterRepository>(
  (Ref ref) => EncounterRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final StreamProviderFamily<List<Encounter>, String> patientEncountersProvider =
    StreamProvider.family<List<Encounter>, String>(
  (Ref ref, String patientId) => ref
      .watch(encounterRepositoryProvider)
      .watchPatientEncounters(patientId),
);

final StreamProviderFamily<List<ClinicalDocument>, String>
    patientDocumentsProvider =
    StreamProvider.family<List<ClinicalDocument>, String>(
  (Ref ref, String patientId) => ref
      .watch(encounterRepositoryProvider)
      .watchPatientDocuments(patientId),
);

final StreamProviderFamily<List<LabResult>, String> patientLabsProvider =
    StreamProvider.family<List<LabResult>, String>(
  (Ref ref, String patientId) =>
      ref.watch(encounterRepositoryProvider).watchLabResults(patientId),
);

/// Filtro da linha do tempo — `null` significa "todos os tipos". Um
/// provider simples em vez de converter a tela inteira para stateful só
/// por causa de um valor de seleção.
final StateProvider<_EventKind?> timelineFilterProvider =
    StateProvider<_EventKind?>((Ref ref) => null);

/// Um evento na linha do tempo, vindo de qualquer das três fontes.
class _TimelineEvent {
  const _TimelineEvent({
    required this.at,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.encounter,
    this.document,
    this.labs,
    this.flagged = false,
  });

  final DateTime at;
  final _EventKind kind;
  final String title;
  final String subtitle;
  final Encounter? encounter;
  final ClinicalDocument? document;
  final List<LabResult>? labs;

  /// Merece atenção visual: atendimento retificado, documento cancelado,
  /// exame fora da faixa.
  final bool flagged;
}

enum _EventKind { encounter, document, labs, growth, vaccine }

/// Linha do tempo do paciente.
///
/// ## Por que três fontes num fluxo único
///
/// Atendimentos, documentos e exames aparecem entrelaçados em ordem
/// cronológica. Separá-los em abas obrigaria o médico a reconstruir mentalmente
/// a sequência — "a receita saiu antes ou depois do hemograma?" — que é
/// justamente a pergunta que a leitura do prontuário precisa responder.
///
/// Exames do mesmo dia são agrupados em um evento: um hemograma são quinze
/// analitos, e quinze linhas soterrariam o resto.
class PatientTimelineScreen extends ConsumerWidget {
  const PatientTimelineScreen({
    required this.patientId,
    this.patientName,
    super.key,
  });

  final String patientId;
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Encounter>> encounters =
        ref.watch(patientEncountersProvider(patientId));
    final AsyncValue<List<ClinicalDocument>> documents =
        ref.watch(patientDocumentsProvider(patientId));
    final AsyncValue<List<LabResult>> labs =
        ref.watch(patientLabsProvider(patientId));
    final AsyncValue<List<GrowthRecord>> growth =
        ref.watch(growthProvider(patientId));
    final AsyncValue<List<VaccineDose>> vaccines =
        ref.watch(vaccineDosesProvider(patientId));
    final Child? child = ref.watch(childProvider(patientId)).valueOrNull;
    final VaccineSummary vaccineSummary =
        ref.watch(vaccineSummaryProvider(patientId));

    final bool isProfessional =
        ref.watch(currentUserProvider)?.canPrescribe ?? false;

    final List<_TimelineEvent> allEvents = _buildTimeline(
      encounters.valueOrNull ?? const <Encounter>[],
      documents.valueOrNull ?? const <ClinicalDocument>[],
      labs.valueOrNull ?? const <LabResult>[],
      growth.valueOrNull ?? const <GrowthRecord>[],
      vaccines.valueOrNull ?? const <VaccineDose>[],
    );

    final _EventKind? filter = ref.watch(timelineFilterProvider);
    final List<_TimelineEvent> events = filter == null
        ? allEvents
        : allEvents.where((_TimelineEvent e) => e.kind == filter).toList();

    final bool loading = encounters.isLoading && allEvents.isEmpty;
    // `encounters` já é o stream que `loading` trata como autoritativo —
    // mesma escolha aqui: um erro nele não deveria virar silenciosamente
    // "prontuário vazio". Os outros 4 streams (documentos/exames/
    // crescimento/vacina) já caem em lista vazia via `valueOrNull ?? []`
    // se falharem sozinhos — perda de uma faixa da timeline, não a tela
    // inteira mentindo que não há nada.
    final bool hasError = encounters.hasError;

    return DefaultTabController(
      length: 10,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: AppColors.lightBackground,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Prontuário 360',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                patientName ?? child?.name ?? 'Acompanhe o histórico do paciente',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
              ),
            ],
          ),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.brand),
            tooltip: 'Voltar',
          ),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.navy,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const BoxDecoration(
              color: AppColors.brand,
              borderRadius: AppRadius.pillAll,
            ),
            tabs: const <Widget>[
              Tab(text: 'Resumo'),
              Tab(text: 'Prontuário'),
              Tab(text: 'Evoluções'),
              Tab(text: 'Prescrições'),
              Tab(text: 'Exames'),
              Tab(text: 'Vacinas'),
              Tab(text: 'Crescimento'),
              Tab(text: 'Desenvolvimento'),
              Tab(text: 'Documentos'),
              Tab(text: 'Telemedicina'),
            ],
          ),
        ),
        floatingActionButton: isProfessional
            ? FloatingActionButton.extended(
                onPressed: () => _startEncounter(context, ref),
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova evolução'),
              )
            : null,
        body: hasError
            ? ErrorState(
                failure: ErrorMapper.map(
                  encounters.error!,
                  encounters.stackTrace ?? StackTrace.empty,
                ),
                onRetry: () =>
                    ref.invalidate(patientEncountersProvider(patientId)),
              )
            : loading
                ? const SkeletonList(itemCount: 5, itemHeight: 88)
                : TabBarView(
                    children: <Widget>[
                      _ChartSummaryTab(
                        patientId: patientId,
                        patientName: patientName,
                        child: child,
                        isProfessional: isProfessional,
                        growth: growth.valueOrNull ?? const <GrowthRecord>[],
                        vaccineSummary: vaccineSummary,
                        encounters:
                            encounters.valueOrNull ?? const <Encounter>[],
                        labs: labs.valueOrNull ?? const <LabResult>[],
                        documents: documents.valueOrNull ??
                            const <ClinicalDocument>[],
                        onStartEncounter: () => _startEncounter(context, ref),
                      ),
                      _ChartTimelinePane(
                        patientId: patientId,
                        allEvents: allEvents,
                        events: events,
                        filter: filter,
                        isProfessional: isProfessional,
                        onStartEncounter: () => _startEncounter(context, ref),
                      ),
                      _EvolutionsTab(
                        patientId: patientId,
                        encounters:
                            encounters.valueOrNull ?? const <Encounter>[],
                        isProfessional: isProfessional,
                        onStartEncounter: () => _startEncounter(context, ref),
                      ),
                      _ChartFilteredList(
                        patientId: patientId,
                        events: allEvents
                            .where(
                              (_TimelineEvent e) =>
                                  e.kind == _EventKind.document &&
                                  e.document?.type ==
                                      ClinicalDocumentType.prescription,
                            )
                            .toList(growable: false),
                        emptyTitle: 'Sem prescrições',
                        emptyMessage:
                            'Receitas emitidas ficam nesta aba.',
                      ),
                      _ChartFilteredList(
                        patientId: patientId,
                        events: allEvents
                            .where(
                              (_TimelineEvent e) => e.kind == _EventKind.labs,
                            )
                            .toList(growable: false),
                        emptyTitle: 'Sem exames',
                        emptyMessage:
                            'Resultados laboratoriais aparecerão aqui.',
                      ),
                      ChartModuleLinkCard(
                        title: 'Caderneta de vacinas',
                        message: vaccineSummary.total == 0
                            ? 'Abra o módulo de vacinas para gerar ou '
                                'consultar o calendário deste paciente.'
                            : '${vaccineSummary.applied} aplicadas · '
                                '${vaccineSummary.overdue} em atraso · '
                                '${vaccineSummary.upcoming} próximas.',
                        icon: Icons.vaccines_outlined,
                        color: AppColors.moduleVaccines,
                        actionLabel: 'Abrir vacinas',
                        onAction: () => context.push(Routes.vaccines(patientId)),
                      ),
                      ChartModuleLinkCard(
                        title: 'Crescimento e curvas',
                        message:
                            'Acompanhe peso, altura, IMC e perímetro cefálico '
                            'com referências da OMS.',
                        icon: Icons.show_chart_rounded,
                        color: AppColors.moduleGrowth,
                        actionLabel: 'Abrir crescimento',
                        onAction: () => context.push(Routes.growth(patientId)),
                      ),
                      const ChartModuleLinkCard(
                        title: 'Desenvolvimento',
                        message:
                            'Marcos motores e rastreios comportamentais '
                            'estarão disponíveis na próxima etapa do produto. '
                            'Por enquanto, registre na anamnese da consulta.',
                        icon: Icons.child_care_outlined,
                        color: AppColors.teal,
                      ),
                      _ChartFilteredList(
                        patientId: patientId,
                        events: allEvents
                            .where(
                              (_TimelineEvent e) =>
                                  e.kind == _EventKind.document,
                            )
                            .toList(growable: false),
                        emptyTitle: 'Sem documentos',
                        emptyMessage:
                            'Atestados, encaminhamentos e relatórios '
                            'aparecem aqui.',
                      ),
                      ChartModuleLinkCard(
                        title: 'Telemedicina',
                        message:
                            'Agende ou acompanhe teleconsultas vinculadas '
                            'a este paciente.',
                        icon: Icons.videocam_outlined,
                        color: AppColors.moduleTelemedicine,
                        actionLabel: 'Abrir telemedicina',
                        onAction: () => context.push(Routes.telemedicinePath),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _startEncounter(BuildContext context, WidgetRef ref) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    // Retoma rascunho aberto em vez de criar um segundo registro para a mesma
    // consulta — o médico pode ter saído da tela e voltado.
    final Encounter? existing = (await ref
            .read(encounterRepositoryProvider)
            .openDraft(patientId: patientId, professionalId: uid))
        .valueOrNull;

    if (!context.mounted) return;

    if (existing != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EncounterEditorScreen(encounterId: existing.id),
        ),
      );
      return;
    }

    final Result<Encounter> created =
        await ref.read(encounterRepositoryProvider).create(
              patientId: patientId,
              professionalId: uid,
              professionalName: ref.read(currentUserProvider)?.name ?? '',
              professionalCrm: ref.read(currentUserProvider)?.crm,
              patientName: patientName,
              type: EncounterType.routine,
            );

    if (!context.mounted) return;

    created.fold(
      (Encounter e) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EncounterEditorScreen(encounterId: e.id),
        ),
      ),
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  /// Funde as três fontes em ordem cronológica decrescente.
  static List<_TimelineEvent> _buildTimeline(
    List<Encounter> encounters,
    List<ClinicalDocument> documents,
    List<LabResult> labs,
    List<GrowthRecord> growthRecords,
    List<VaccineDose> vaccineDoses,
  ) {
    final List<_TimelineEvent> events = <_TimelineEvent>[];

    for (final Encounter e in encounters) {
      final Diagnosis? dx = e.primaryDiagnosis;
      events.add(
        _TimelineEvent(
          at: e.startedAt,
          kind: _EventKind.encounter,
          title: e.type.label,
          subtitle: dx == null
              ? (e.anamnesis.chiefComplaint.isEmpty
                  ? 'Sem diagnóstico registrado'
                  : e.anamnesis.chiefComplaint)
              : '${dx.code} — ${dx.description}',
          encounter: e,
          flagged: e.amendsEncounterId != null,
        ),
      );
    }

    for (final ClinicalDocument d in documents) {
      events.add(
        _TimelineEvent(
          at: d.issuedAt,
          kind: _EventKind.document,
          title: d.type.label,
          subtitle: d.type == ClinicalDocumentType.prescription
              ? d.items
                  .map((PrescriptionItem i) => i.drug)
                  .take(3)
                  .join(', ')
              : d.content.length > 80
                  ? '${d.content.substring(0, 80)}...'
                  : d.content,
          document: d,
          flagged: d.cancelled,
        ),
      );
    }

    // Exames do mesmo dia viram um evento só — quinze linhas de hemograma
    // soterrariam o restante da linha do tempo.
    final Map<String, List<LabResult>> labsByDay = <String, List<LabResult>>{};
    for (final LabResult l in labs) {
      final String key = '${l.collectedAt.year}-${l.collectedAt.month}-'
          '${l.collectedAt.day}';
      labsByDay.putIfAbsent(key, () => <LabResult>[]).add(l);
    }

    for (final List<LabResult> group in labsByDay.values) {
      final int outOfRange =
          group.where((LabResult l) => l.isOutOfRange).length;

      events.add(
        _TimelineEvent(
          at: group.first.collectedAt,
          kind: _EventKind.labs,
          title: group.length == 1
              ? group.first.analyte
              : '${group.length} exames laboratoriais',
          subtitle: outOfRange == 0
              ? 'Todos dentro da faixa de referência'
              : '$outOfRange ${outOfRange == 1 ? 'valor fora' : 'valores fora'} '
                  'da faixa',
          labs: group,
          flagged: outOfRange > 0,
        ),
      );
    }

    for (final GrowthRecord g in growthRecords) {
      final List<String> parts = <String>[
        if (g.weightKg != null) '${Formatters.decimal(g.weightKg!)} kg',
        if (g.heightCm != null) '${Formatters.decimal(g.heightCm!)} cm',
        if (g.headCircumferenceCm != null)
          'PC ${Formatters.decimal(g.headCircumferenceCm!)} cm',
      ];
      events.add(
        _TimelineEvent(
          at: g.measuredAt,
          kind: _EventKind.growth,
          title: 'Medição de crescimento',
          subtitle: parts.isEmpty ? 'Registro sem valores' : parts.join(' · '),
        ),
      );
    }

    // Só dose já aplicada é "algo que aconteceu" — dose futura/pendente é
    // agenda, não histórico, e não deveria aparecer numa linha do tempo.
    for (final VaccineDose v in vaccineDoses) {
      if (v.appliedAt == null) continue;

      final VaccineDoseSchedule? schedule =
          PniCalendar.find(v.vaccineId, v.doseIndex);

      events.add(
        _TimelineEvent(
          at: v.appliedAt!,
          kind: _EventKind.vaccine,
          title: schedule?.vaccineName ?? 'Vacina',
          subtitle: schedule?.doseLabel ?? 'Dose ${v.doseIndex + 1}',
        ),
      );
    }

    events.sort((_TimelineEvent a, _TimelineEvent b) => b.at.compareTo(a.at));
    return events;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.isLast,
    required this.patientId,
  });

  final _TimelineEvent event;
  final bool isLast;
  final String patientId;

  IconData get _icon => switch (event.kind) {
        _EventKind.encounter => Icons.medical_information_outlined,
        _EventKind.document => Icons.description_outlined,
        _EventKind.labs => Icons.science_outlined,
        _EventKind.growth => Icons.show_chart_rounded,
        _EventKind.vaccine => Icons.vaccines_outlined,
      };

  Color _color(ThemeData theme) {
    if (event.flagged) return AppColors.warning;
    return switch (event.kind) {
      _EventKind.encounter => AppColors.petrol,
      _EventKind.document => AppColors.raspberry,
      _EventKind.labs => AppColors.vital,
      _EventKind.growth => AppColors.moduleGrowth,
      _EventKind.vaccine => AppColors.moduleVaccines,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _color(theme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Trilho vertical: dá a sensação de continuidade que uma lista
          // solta não dá.
          Column(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Card(
                child: InkWell(
                  onTap: () => _open(context),
                  borderRadius: AppRadius.lgAll,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                event.title,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Text(
                              '${event.at.hour.toString().padLeft(2, '0')}:'
                              '${event.at.minute.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          event.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            if (event.encounter != null) ...<Widget>[
                              AppTag(
                                label: event.encounter!.status.label,
                                color: event.encounter!.isSigned
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              AppTag(label: event.encounter!.professionalName),
                            ],
                            if (event.document != null) ...<Widget>[
                              if (event.document!.cancelled)
                                const AppTag(
                                  label: 'Cancelado',
                                  color: AppColors.danger,
                                )
                              else if (event.document!.isExpired)
                                const AppTag(
                                  label: 'Vencido',
                                  color: AppColors.inkMuted,
                                )
                              else
                                const AppTag(
                                  label: 'Válido',
                                  color: AppColors.success,
                                ),
                            ],
                            if (event.flagged &&
                                event.kind == _EventKind.encounter)
                              const AppTag(
                                label: 'Retificação',
                                color: AppColors.warning,
                                icon: Icons.edit_note_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    if (event.encounter != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              EncounterEditorScreen(encounterId: event.encounter!.id),
        ),
      );
      return;
    }

    if (event.document != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentViewerScreen(document: event.document!),
        ),
      );
      return;
    }

    if (event.labs != null) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => _LabSheet(results: event.labs!),
      );
      return;
    }

    if (event.kind == _EventKind.growth) {
      context.push(Routes.growth(patientId));
      return;
    }

    if (event.kind == _EventKind.vaccine) {
      context.push(Routes.vaccines(patientId));
      return;
    }
  }
}

/// Painel de resultados laboratoriais.
///
/// Mostra valor, unidade e faixa de referência. Sinaliza o que está fora —
/// e **não diz o que isso significa**. Comparar número com faixa é aritmética;
/// interpretar é ato médico.
class _LabSheet extends StatelessWidget {
  const _LabSheet({required this.results});

  final List<LabResult> results;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Resultados de ${Formatters.date(results.first.collectedAt)}',
              style: theme.textTheme.headlineSmall,
            ),
            if (results.first.laboratory != null)
              Text(
                results.first.laboratory!,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final LabResult r = results[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                r.analyte,
                                style: theme.textTheme.bodyMedium,
                              ),
                              if (r.referenceLabel != null)
                                Text(
                                  'Referência ${r.referenceLabel}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        DataValue(
                          value: r.displayValue,
                          size: 15,
                          color: r.isOutOfRange ? AppColors.warning : null,
                        ),
                        if (r.deviation != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            r.deviation == 'acima'
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'A sinalização compara o valor com a faixa de referência para a '
              'idade. A interpretação é do médico.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Aba Resumo do prontuário premium.
class _ChartSummaryTab extends StatelessWidget {
  const _ChartSummaryTab({
    required this.patientId,
    required this.patientName,
    required this.child,
    required this.isProfessional,
    required this.growth,
    required this.vaccineSummary,
    required this.encounters,
    required this.labs,
    required this.documents,
    required this.onStartEncounter,
  });

  final String patientId;
  final String? patientName;
  final Child? child;
  final bool isProfessional;
  final List<GrowthRecord> growth;
  final VaccineSummary vaccineSummary;
  final List<Encounter> encounters;
  final List<LabResult> labs;
  final List<ClinicalDocument> documents;
  final VoidCallback onStartEncounter;

  @override
  Widget build(BuildContext context) {
    final GrowthRecord? latestGrowth = growth.isEmpty
        ? null
        : growth.reduce(
            (GrowthRecord a, GrowthRecord b) =>
                a.measuredAt.isAfter(b.measuredAt) ? a : b,
          );

    final DateTime? birthFromEncounters = () {
      for (final Encounter e in encounters) {
        if (e.patientBirthDate != null) return e.patientBirthDate;
      }
      return null;
    }();

    final List<String> allergiesFromEncounters = encounters.isEmpty
        ? const <String>[]
        : encounters.first.anamnesis.allergies;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        96,
      ),
      children: <Widget>[
        ContentBounds(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PatientChartHeader(
                patientId: patientId,
                displayName: patientName ?? child?.name ?? 'Paciente',
                child: child,
                birthDate: birthFromEncounters,
                allergies: allergiesFromEncounters,
                overdueVaccines: vaccineSummary.overdue,
                onEditProfile: child == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChildFormScreen(childId: child!.id),
                          ),
                        ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Resumo clínico',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              ClinicalSummaryGrid(
                latestGrowth: latestGrowth,
                encounters: encounters,
                labs: labs,
                vaccineSummary: vaccineSummary,
                childId: child?.id ?? patientId,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Indicadores do prontuário',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final int cols = c.maxWidth > 520 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.4,
                    children: <Widget>[
                      StatTile(
                        label: 'Consultas',
                        value: '${encounters.length}',
                        icon: Icons.medical_information_outlined,
                      ),
                      StatTile(
                        label: 'Documentos',
                        value: '${documents.length}',
                        icon: Icons.description_outlined,
                        color: AppColors.raspberry,
                      ),
                      StatTile(
                        label: 'Exames',
                        value: '${labs.length}',
                        icon: Icons.science_outlined,
                        color: AppColors.vital,
                      ),
                      StatTile(
                        label: 'Vacinas OK',
                        value: '${vaccineSummary.applied}',
                        icon: Icons.vaccines_outlined,
                        color: AppColors.success,
                      ),
                    ],
                  );
                },
              ),
              if (isProfessional && child != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                _PatientSummaryCard(
                  child: child!,
                  latestGrowth: latestGrowth,
                  vaccineSummary: vaccineSummary,
                  encounters: encounters,
                  labs: labs,
                  documents: documents,
                ),
              ],
              if (encounters.isEmpty && isProfessional) ...<Widget>[
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Iniciar primeiro atendimento',
                  icon: Icons.add_rounded,
                  onPressed: onStartEncounter,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Aba de evoluções clínicas (atendimentos) com cópia da última evolução.
class _EvolutionsTab extends ConsumerWidget {
  const _EvolutionsTab({
    required this.patientId,
    required this.encounters,
    required this.isProfessional,
    required this.onStartEncounter,
  });

  final String patientId;
  final List<Encounter> encounters;
  final bool isProfessional;
  final VoidCallback onStartEncounter;

  Future<void> _copyPrevious(BuildContext context, WidgetRef ref) async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final List<Encounter> signed = encounters
        .where((Encounter e) => e.isSigned)
        .toList(growable: false)
      ..sort((Encounter a, Encounter b) => b.startedAt.compareTo(a.startedAt));

    if (signed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não há evolução assinada para copiar.'),
        ),
      );
      return;
    }

    final Encounter source = signed.first;
    final Result<Encounter> created =
        await ref.read(encounterRepositoryProvider).create(
              patientId: patientId,
              professionalId: uid,
              professionalName: ref.read(currentUserProvider)?.name ?? '',
              professionalCrm: ref.read(currentUserProvider)?.crm,
              patientName: source.patientName,
              patientBirthDate: source.patientBirthDate,
              type: EncounterType.followUp,
            );

    if (!context.mounted) return;

    await created.fold(
      (Encounter draft) async {
        await ref.read(encounterRepositoryProvider).updateDraft(
              encounterId: draft.id,
              anamnesis: source.anamnesis,
              vitals: source.vitals,
              exam: source.exam,
              diagnoses: source.diagnoses,
              assessment: source.assessment,
              plan: source.plan,
            );
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EncounterEditorScreen(encounterId: draft.id),
          ),
        );
      },
      (Failure failure) async {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (encounters.isEmpty) {
      return EmptyState(
        icon: Icons.notes_outlined,
        title: 'Nenhuma evolução',
        message: isProfessional
            ? 'Registre a primeira evolução clínica deste paciente.'
            : 'As evoluções aparecem após as consultas.',
        actionLabel: isProfessional ? 'Nova evolução' : null,
        onAction: isProfessional ? onStartEncounter : null,
      );
    }

    final List<Encounter> ordered = List<Encounter>.of(encounters)
      ..sort((Encounter a, Encounter b) => b.startedAt.compareTo(a.startedAt));

    return Column(
      children: <Widget>[
        if (isProfessional)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onStartEncounter,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Nova evolução'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPrevious(context, ref),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copiar anterior'),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: ordered.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final Encounter e = ordered[index];
              return ContentBounds(
                maxWidth: 760,
                child: AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          EncounterEditorScreen(encounterId: e.id),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Icon(
                          e.status == EncounterStatus.draft
                              ? Icons.edit_note_rounded
                              : Icons.verified_outlined,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              e.type.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              e.anamnesis.chiefComplaint.isEmpty
                                  ? e.status.label
                                  : e.anamnesis.chiefComplaint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.date(e.startedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChartTimelinePane extends ConsumerWidget {
  const _ChartTimelinePane({
    required this.patientId,
    required this.allEvents,
    required this.events,
    required this.filter,
    required this.isProfessional,
    required this.onStartEncounter,
  });

  final String patientId;
  final List<_TimelineEvent> allEvents;
  final List<_TimelineEvent> events;
  final _EventKind? filter;
  final bool isProfessional;
  final VoidCallback onStartEncounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    if (allEvents.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Prontuário vazio',
        message: isProfessional
            ? 'Nenhum atendimento registrado ainda.'
            : 'Os atendimentos aparecem após a primeira consulta.',
        actionLabel: isProfessional ? 'Iniciar atendimento' : null,
        onAction: isProfessional ? onStartEncounter : null,
      );
    }

    return Column(
      children: <Widget>[
        _TimelineFilterBar(current: filter),
        Expanded(
          child: events.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nada com este filtro',
                  message: 'Este paciente não tem evento deste tipo.',
                  actionLabel: 'Mostrar todos',
                  onAction: () =>
                      ref.read(timelineFilterProvider.notifier).state = null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: events.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _TimelineEvent event = events[index];
                    final bool isFirstOfDay = index == 0 ||
                        !PatientTimelineScreen._sameDay(
                          events[index - 1].at,
                          event.at,
                        );

                    return ContentBounds(
                      maxWidth: 760,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (isFirstOfDay)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                Formatters.dateLong(event.at),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          _TimelineTile(
                            event: event,
                            isLast: index == events.length - 1,
                            patientId: patientId,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChartFilteredList extends StatelessWidget {
  const _ChartFilteredList({
    required this.patientId,
    required this.events,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String patientId;
  final List<_TimelineEvent> events;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        96,
      ),
      itemCount: events.length,
      itemBuilder: (BuildContext context, int index) {
        final _TimelineEvent event = events[index];
        return ContentBounds(
          maxWidth: 760,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(event.title, style: theme.textTheme.titleSmall),
                subtitle: Text(event.subtitle),
                trailing: Text(
                  Formatters.date(event.at),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Filtro por tipo de evento — chips de seleção única. "Todos" preserva o
/// padrão intercalado cronológico (ver docstring de [PatientTimelineScreen]
/// sobre por que os tipos vêm misturados por padrão); os outros restringem
/// a visão sem trocar a estrutura por abas.
class _TimelineFilterBar extends ConsumerWidget {
  const _TimelineFilterBar({required this.current});

  final _EventKind? current;

  static const List<(String, _EventKind?, IconData)> _options =
      <(String, _EventKind?, IconData)>[
    ('Todos', null, Icons.all_inclusive_rounded),
    ('Consultas', _EventKind.encounter, Icons.medical_information_outlined),
    ('Crescimento', _EventKind.growth, Icons.show_chart_rounded),
    ('Vacinas', _EventKind.vaccine, Icons.vaccines_outlined),
    ('Exames', _EventKind.labs, Icons.science_outlined),
    ('Documentos', _EventKind.document, Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final (String label, _EventKind? kind, IconData icon) =
              _options[i];
          final bool selected = current == kind;

          return FilterChip(
            selected: selected,
            avatar: Icon(icon, size: 16),
            label: Text(label),
            onSelected: (_) =>
                ref.read(timelineFilterProvider.notifier).state = kind,
          );
        },
      ),
    );
  }
}

/// Resumo compacto do paciente, no topo do prontuário — só para o
/// profissional. Reúne o que o médico precisa saber antes de ler a linha
/// do tempo inteira: quem é, alergia, e o último número de cada
/// acompanhamento numérico (peso/altura, vacinação).
///
/// ## Por que o alerta de alergia é a parte que mais importa aqui
///
/// Antes desta tela, a alergia só aparecia como banner na tela do
/// responsável — o profissional via só o campo de texto vazio da anamnese
/// desta consulta, sem nenhum aviso vindo do cadastro da criança. Um
/// profissional prescrevendo sem ver a alergia registrada é exatamente o
/// tipo de lacuna de segurança que motivou este bloco existir.
///
/// ## O que fica de fora, por não existir ainda
///
/// Desenvolvimento (nenhum acompanhamento estruturado existe no projeto
/// ainda) e "medicamentos em uso" como lista persistente (só existe por
/// consulta, dentro da anamnese — não há campo de uso contínuo no
/// cadastro da criança). Nenhum dos dois foi inventado para preencher o
/// espaço.
class _PatientSummaryCard extends StatelessWidget {
  const _PatientSummaryCard({
    required this.child,
    required this.latestGrowth,
    required this.vaccineSummary,
    required this.encounters,
    required this.labs,
    required this.documents,
  });

  final Child child;
  final GrowthRecord? latestGrowth;
  final VaccineSummary vaccineSummary;
  final List<Encounter> encounters;
  final List<LabResult> labs;
  final List<ClinicalDocument> documents;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasAlert = child.allergies.isNotEmpty || child.conditions.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: ContentBounds(
        maxWidth: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.avatarFor(child.id),
                      backgroundImage: child.photoUrl != null
                          ? NetworkImage(child.photoUrl!)
                          : null,
                      child: child.photoUrl == null
                          ? Text(
                              child.initials,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(child.name, style: theme.textTheme.titleMedium),
                          Text(
                            '${Formatters.pediatricAge(child.birthDate)} · '
                            '${child.sex.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Responsável: ${child.guardianName ?? 'Sem registro'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasAlert) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.danger,
                    text: <String>[
                      if (child.allergies.isNotEmpty)
                        'Alergias: ${child.allergies.join(', ')}',
                      if (child.conditions.isNotEmpty)
                        'Condições: ${child.conditions.join(', ')}',
                    ].join(' · '),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.show_chart_rounded,
                        color: AppColors.moduleGrowth,
                        label: 'Crescimento',
                        value: formatGrowthSummary(latestGrowth),
                        onTap: () => context.push(Routes.growth(child.id)),
                      ),
                    ),
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.vaccines_outlined,
                        color: vaccineSummary.overdue > 0
                            ? AppColors.danger
                            : AppColors.moduleVaccines,
                        label: 'Vacinação',
                        value: vaccineSummary.total == 0
                            ? 'Sem calendário'
                            : vaccineSummary.overdue > 0
                                ? '${vaccineSummary.overdue} em atraso'
                                : '${vaccineSummary.applied}/${vaccineSummary.total} em dia',
                        onTap: () => context.push(Routes.vaccines(child.id)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SummaryStat(
                  icon: Icons.medical_information_outlined,
                  color: AppColors.petrol,
                  label: 'Consultas',
                  value: formatConsultationsSummary(encounters),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.science_outlined,
                        color: AppColors.moduleExams,
                        label: 'Exames',
                        value: formatLabsSummary(labs),
                      ),
                    ),
                    Expanded(
                      child: _SummaryStat(
                        icon: Icons.description_outlined,
                        color: AppColors.raspberry,
                        label: 'Documentos',
                        value: formatDocumentsSummary(documents),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: content,
      ),
    );
  }
}
