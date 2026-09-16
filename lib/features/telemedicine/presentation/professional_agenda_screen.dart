import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/clinical_ui.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinical_record.dart';
import '../../../shared/domain/entities/encounter.dart';
import '../../../shared/domain/entities/pre_visit_questionnaire.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../emr/presentation/screens/encounter_editor_screen.dart';
import '../../emr/presentation/screens/patient_timeline_screen.dart'
    show encounterRepositoryProvider;
import '../data/telemedicine_repository.dart';
import 'telemedicine_screen.dart' show myAgendaProvider, myAvailabilityProvider, telemedicineRepositoryProvider;

/// Agenda do profissional.
///
/// ## O que "Iniciar atendimento" faz, e por que é diferente por tipo
///
/// Para consulta **presencial**, iniciar atendimento não depende de vídeo
/// nenhum — cria (ou retoma, se já existir rascunho) um [Encounter] e abre
/// o editor do prontuário. É a mesma chamada que `PatientTimelineScreen` já
/// fazia, só que partindo da agenda em vez da lista de pacientes — usa
/// `appointment.childId`, não `appointment.patientId` (que aqui é o
/// responsável que agendou, não quem é atendido).
///
/// Para **teleconsulta**, iniciar atendimento entra na sala de vídeo, que
/// está desativada por flag até existir provedor contratado — o botão
/// mostra isso claramente, não finge que vai funcionar.
class ProfessionalAgendaScreen extends ConsumerStatefulWidget {
  const ProfessionalAgendaScreen({super.key});

  @override
  ConsumerState<ProfessionalAgendaScreen> createState() =>
      _ProfessionalAgendaScreenState();
}

enum _AgendaRange { today, week }

class _ProfessionalAgendaScreenState
    extends ConsumerState<ProfessionalAgendaScreen> {
  _AgendaRange _range = _AgendaRange.today;
  bool _busy = false;

  List<Appointment> _filtered(List<Appointment> all) {
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime rangeEnd = _range == _AgendaRange.today
        ? todayStart.add(const Duration(days: 1))
        : todayStart.add(const Duration(days: 7));

    final List<Appointment> list = all
        .where(
          (Appointment a) =>
              a.startsAt.isAfter(todayStart) && a.startsAt.isBefore(rangeEnd),
        )
        .toList()
      ..sort((Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  Future<void> _confirm(Appointment a) async {
    setState(() => _busy = true);
    final Result<void> result =
        await ref.read(telemedicineRepositoryProvider).confirm(a.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (_) {},
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _cancel(Appointment a) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar esta consulta?'),
        content: Text(
          '${a.childName ?? 'Paciente'}, '
          '${_timeLabel(a.startsAt)}. Isto avisa o responsável.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar consulta'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;

    setState(() => _busy = true);
    final Result<void> result =
        await ref.read(telemedicineRepositoryProvider).cancel(a.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (_) {},
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Future<void> _startEncounter(Appointment a) async {
    if (a.type == AppointmentType.teleconsulta) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Videochamada indisponível nesta versão — sem provedor de '
            'vídeo contratado ainda.',
          ),
        ),
      );
      return;
    }

    if (a.childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Esta consulta não tem uma criança vinculada — não é possível '
            'abrir o prontuário a partir dela.',
          ),
        ),
      );
      return;
    }

    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    // Retoma rascunho aberto em vez de criar um segundo registro para a
    // mesma consulta — mesmo padrão de PatientTimelineScreen._startEncounter.
    final Encounter? existing = (await ref
            .read(encounterRepositoryProvider)
            .openDraft(patientId: a.childId!, professionalId: uid))
        .valueOrNull;

    if (!mounted) return;

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
              patientId: a.childId!,
              professionalId: uid,
              professionalName: ref.read(currentUserProvider)?.name ?? '',
              professionalCrm: ref.read(currentUserProvider)?.crm,
              patientName: a.childName,
              type: EncounterType.routine,
              appointmentId: a.id,
            );

    if (!mounted) return;

    created.fold(
      (Encounter e) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EncounterEditorScreen(encounterId: e.id),
        ),
      ),
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Appointment>> agenda = ref.watch(myAgendaProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Agenda',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.lightBackground,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.brand),
                tooltip: 'Voltar',
              )
            : null,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: () => _openAvailabilitySheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillAll,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Novo atendimento'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SegmentedButton<_AgendaRange>(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return isDark
                        ? AppColors.darkInkMuted
                        : theme.colorScheme.onSurfaceVariant;
                  },
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.brand;
                    }
                    return isDark
                        ? AppColors.darkSurfaceAlt
                        : theme.colorScheme.surfaceContainerHighest;
                  },
                ),
              ),
              segments: const <ButtonSegment<_AgendaRange>>[
                ButtonSegment<_AgendaRange>(
                  value: _AgendaRange.today,
                  label: Text('Hoje'),
                ),
                ButtonSegment<_AgendaRange>(
                  value: _AgendaRange.week,
                  label: Text('7 dias'),
                ),
              ],
              selected: <_AgendaRange>{_range},
              onSelectionChanged: (Set<_AgendaRange> s) =>
                  setState(() => _range = s.first),
            ),
          ),
        ),
      ),
      body: agenda.when(
        loading: () => const SkeletonList(itemCount: 4, itemHeight: 88),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Não conseguimos carregar essas informações',
          message: 'Tente novamente em alguns instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(myAgendaProvider),
        ),
        data: (List<Appointment> all) {
          final List<Appointment> list = _filtered(all);
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.event_available_outlined,
              title: _range == _AgendaRange.today
                  ? 'Nenhuma consulta hoje'
                  : 'Nenhuma consulta nos próximos 7 dias',
              message:
                  'Quando houver atendimentos agendados, eles aparecem aqui '
                  'com horário e paciente.',
              actionLabel: 'Novo atendimento',
              onAction: () => _openAvailabilitySheet(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) =>
                _AppointmentCard(
              appointment: list[i],
              busy: _busy,
              onConfirm: () => _confirm(list[i]),
              onCancel: () => _cancel(list[i]),
              onStart: () => _startEncounter(list[i]),
            ),
          );
        },
      ),
    );
  }

  void _openAvailabilitySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => const _AvailabilitySheet(),
    );
  }
}

String _timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
    required this.onStart,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onStart;

  Color _statusColor(ColorScheme scheme) => switch (appointment.status) {
        AppointmentStatus.requested => AppColors.warning,
        AppointmentStatus.confirmed => AppColors.success,
        AppointmentStatus.inProgress => AppColors.brand,
        AppointmentStatus.completed => scheme.onSurfaceVariant,
        AppointmentStatus.cancelled => AppColors.danger,
        AppointmentStatus.noShow => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isActive = appointment.status == AppointmentStatus.requested ||
        appointment.status == AppointmentStatus.confirmed;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _timeLabel(appointment.startsAt),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${appointment.durationMinutes} min',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              AppTag(label: appointment.type.label, color: AppColors.brand),
              const SizedBox(width: AppSpacing.xs),
              AppTag(
                label: appointment.status.label,
                color: _statusColor(theme.colorScheme),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            appointment.childName ?? 'Paciente não identificado',
            style: theme.textTheme.titleSmall,
          ),
          if (appointment.reason != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(appointment.reason!, style: theme.textTheme.bodySmall),
          ],
          if (isActive) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _PreVisitIndicator(appointmentId: appointment.id),
          ],
          if (isActive) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (appointment.status == AppointmentStatus.requested)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        side: BorderSide(
                          color: AppColors.brand.withValues(alpha: 0.45),
                        ),
                      ),
                      onPressed: busy ? null : onConfirm,
                      child: const Text('Confirmar'),
                    ),
                  ),
                if (appointment.status == AppointmentStatus.requested)
                  const SizedBox(width: AppSpacing.sm),
                if (appointment.status == AppointmentStatus.confirmed)
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : onStart,
                      child: const Text('Iniciar atendimento'),
                    ),
                  ),
                if (appointment.status == AppointmentStatus.confirmed)
                  const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancelar consulta',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Indicador de pré-consulta preenchida — some sozinho quando a família não
/// preencheu nada, sem espaço reservado vazio no cartão.
class _PreVisitIndicator extends ConsumerWidget {
  const _PreVisitIndicator({required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PreVisitQuestionnaire?> q = ref.watch(
      _preVisitQuestionnaireProvider(appointmentId),
    );
    final PreVisitQuestionnaire? questionnaire = q.valueOrNull;

    if (questionnaire == null || !questionnaire.hasContent) {
      return const SizedBox.shrink();
    }

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PreVisitDetailSheet(questionnaire: questionnaire),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: <Widget>[
            const Icon(Icons.assignment_outlined, size: 16, color: AppColors.brand),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Pré-consulta preenchida pelo responsável',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.brand),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}

final StreamProviderFamily<PreVisitQuestionnaire?, String>
    _preVisitQuestionnaireProvider =
    StreamProvider.family<PreVisitQuestionnaire?, String>(
  (Ref ref, String appointmentId) => ref
      .watch(telemedicineRepositoryProvider)
      .watchPreVisitQuestionnaire(appointmentId),
);

/// Conteúdo completo da pré-consulta — rótulo obrigatório no topo, para
/// nunca ser confundido com anamnese ou qualquer registro clínico.
class _PreVisitDetailSheet extends StatelessWidget {
  const _PreVisitDetailSheet({required this.questionnaire});

  final PreVisitQuestionnaire questionnaire;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final PreVisitQuestionnaire q = questionnaire;

    Widget row(String label, String? value) {
      if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // O rótulo que a Fase 2 exige explicitamente — não é
              // decoração, é o que impede confundir isto com anamnese.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  'INFORMAÇÕES FORNECIDAS PELO RESPONSÁVEL',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.brand, letterSpacing: 0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              row('Motivo da consulta', q.reason),
              row('Sintomas', q.symptoms.isEmpty ? null : q.symptoms.join(', ')),
              if (q.symptomsStartedAt != null)
                row('Início dos sintomas', Formatters.date(q.symptomsStartedAt!)),
              if (q.hasFever)
                row(
                  'Febre',
                  q.feverTemperatureC == null
                      ? 'Sim'
                      : 'Sim, até ${Formatters.decimal(q.feverTemperatureC!)}°C',
                ),
              row('Alimentação', q.feedingNotes),
              row('Sono', q.sleepNotes),
              row('Eliminações', q.eliminationNotes),
              row(
                'Medicamentos em uso',
                q.currentMedications.isEmpty ? null : q.currentMedications.join(', '),
              ),
              row('Alergias', q.allergies.isEmpty ? null : q.allergies.join(', ')),
              row('Observações', q.additionalNotes),
              Text(
                'Enviado em ${Formatters.dateTime(q.submittedAt)}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Painel de edição de disponibilidade semanal.
///
/// Grade simples: para cada dia, uma lista de horários de início como
/// texto (`09:00`, `09:30`...) — o mesmo formato que `getAvailability`
/// já lê no servidor. Não tenta ser um editor visual de calendário; é
/// funcional, não é o polimento final.
class _AvailabilitySheet extends ConsumerStatefulWidget {
  const _AvailabilitySheet();

  @override
  ConsumerState<_AvailabilitySheet> createState() =>
      _AvailabilitySheetState();
}

class _AvailabilitySheetState extends ConsumerState<_AvailabilitySheet> {
  static const List<String> _weekdayLabels = <String>[
    'Domingo',
    'Segunda',
    'Terça',
    'Quarta',
    'Quinta',
    'Sexta',
    'Sábado',
  ];

  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
    for (int i = 0; i < 7; i++) '$i': TextEditingController(),
  };
  final TextEditingController _duration =
      TextEditingController(text: '30');

  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    _duration.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, List<String>> availability) {
    if (_hydrated) return;
    _hydrated = true;
    for (final MapEntry<String, List<String>> entry in availability.entries) {
      _controllers[entry.key]?.text = entry.value.join(', ');
    }
  }

  Future<void> _save() async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    final Map<String, List<String>> availability = <String, List<String>>{
      for (final MapEntry<String, TextEditingController> entry
          in _controllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty)
              .toList(),
    };

    setState(() => _saving = true);
    final Result<void> result = await ref
        .read(telemedicineRepositoryProvider)
        .setWeeklyAvailability(
          uid: uid,
          availability: availability,
          consultationMinutes: int.tryParse(_duration.text) ?? 30,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) {
        ref.invalidate(myAvailabilityProvider);
        Navigator.of(context).pop();
      },
      (Failure f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, List<String>>> availability =
        ref.watch(myAvailabilityProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Disponibilidade semanal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Horários de início, separados por vírgula. Ex.: 09:00, 09:30, 10:00',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            availability.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, StackTrace s) =>
                  const Text('Não foi possível carregar.'),
              data: (Map<String, List<String>> value) {
                _hydrate(value);
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < 7; i++)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppTextField(
                          label: _weekdayLabels[i],
                          controller: _controllers['$i']!,
                          hint: 'Ex.: 09:00, 09:30',
                        ),
                      ),
                  ],
                );
              },
            ),
            AppTextField(
              label: 'Duração da consulta (minutos)',
              controller: _duration,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Salvar disponibilidade',
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
