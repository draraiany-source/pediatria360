import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/clinical_access.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../emr/presentation/screens/professional_patients_screen.dart';
import '../../domain/main_menu.dart';
import '../providers/selected_patient_provider.dart';

/// Abre um módulo clínico do menu: escolhe (ou confirma) o paciente em foco
/// e segue para a tela do módulo.
class PatientModuleScreen extends ConsumerStatefulWidget {
  const PatientModuleScreen({required this.moduleSlug, super.key});

  final String moduleSlug;

  @override
  ConsumerState<PatientModuleScreen> createState() =>
      _PatientModuleScreenState();
}

class _PatientModuleScreenState extends ConsumerState<PatientModuleScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(MainMenuModule module, PatientSummary patient) async {
    final SelectedPatient? current = ref.read(selectedPatientProvider);
    final SelectedPatient next = SelectedPatient(
      childId: patient.childId,
      name: patient.name,
      birthDate: patient.birthDate,
    );
    if (current != null && current.childId != next.childId) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) =>
            _SwitchPatientDialog(from: current, to: next),
      );
      if (confirmed != true || !mounted) return;
    }
    ref.read(selectedPatientProvider.notifier).state = next;
    if (!mounted) return;
    unawaited(context.push(module.patientRoute(next.childId)));
  }

  @override
  Widget build(BuildContext context) {
    final MainMenuModule? module = MainMenuModule.fromSlug(widget.moduleSlug);
    if (module == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Módulo não encontrado',
          message: 'Escolha um item do menu para continuar.',
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final SelectedPatient? selected = ref.watch(selectedPatientProvider);
    final AsyncValue<List<PatientSummary>> patients =
        ref.watch(professionalPatientsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentBounds(
        maxWidth: 960,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _Breadcrumb(module: module),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      module.label,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'O paciente escolhido fica em foco nos módulos clínicos '
                      'até você trocá-lo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (module.provisionalNotice != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: DataWarningBanner(text: module.provisionalNotice!),
                ),
              ),
            if (selected != null)
              SliverToBoxAdapter(
                child: _SelectedPatientCard(
                  patient: selected,
                  moduleLabel: module.label,
                  onOpen: () =>
                      context.push(module.patientRoute(selected.childId)),
                  onClear: () =>
                      ref.read(selectedPatientProvider.notifier).state = null,
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: TextField(
                  key: const Key('patient-module-search'),
                  controller: _search,
                  onChanged: (String v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: selected == null
                        ? 'Buscar paciente pelo nome'
                        : 'Trocar paciente: buscar pelo nome',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.lgAll,
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ),
            ),
            ...patients.when(
              loading: () => const <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingState(label: 'Carregando pacientes...'),
                ),
              ],
              error: (Object e, StackTrace s) => <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Não conseguimos carregar os pacientes',
                    message: clinicalLoadErrorMessage(e),
                    actionLabel: 'Tentar de novo',
                    onAction: () =>
                        ref.invalidate(professionalPatientsProvider),
                  ),
                ),
              ],
              data: (List<PatientSummary> all) {
                final List<PatientSummary> list = all
                    .where(
                      (PatientSummary p) =>
                          _query.isEmpty ||
                          p.name.toLowerCase().contains(_query),
                    )
                    .toList();
                if (all.isEmpty) {
                  return <Widget>[
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Nenhum paciente ainda',
                        message: 'Os pacientes aparecem aqui depois do '
                            'primeiro atendimento registrado por você.',
                        actionLabel: 'Ver agenda',
                        onAction: () => context.go(Routes.agendaPath),
                      ),
                    ),
                  ];
                }
                if (list.isEmpty) {
                  return const <Widget>[
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nenhum paciente com esse nome',
                        message: 'Confira a grafia ou busque pelo sobrenome.',
                      ),
                    ),
                  ];
                }
                return <Widget>[
                  SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final PatientSummary p = list[i];
                      return _PatientTile(
                        patient: p,
                        selected: selected?.childId == p.childId,
                        onTap: () => _choose(module, p),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xxl),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.module});

  final MainMenuModule module;

  @override
  Widget build(BuildContext context) {
    final TextStyle? muted = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.inkMuted);
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.navy,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Semantics(
            label: 'Você está em: Início, ${module.label}, selecionar paciente',
            child: ExcludeSemantics(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  InkWell(
                    onTap: () => context.go(Routes.homePath),
                    child: Text('Início', style: muted),
                  ),
                  Text('  ›  ', style: muted),
                  Text(module.label, style: muted),
                  Text('  ›  ', style: muted),
                  Text(
                    'Selecionar paciente',
                    style: muted?.copyWith(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedPatientCard extends StatelessWidget {
  const _SelectedPatientCard({
    required this.patient,
    required this.moduleLabel,
    required this.onOpen,
    required this.onClear,
  });

  final SelectedPatient patient;
  final String moduleLabel;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      color: AppColors.softLilac,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Icon(Icons.person_pin_rounded, color: AppColors.brand),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Paciente em foco',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  patient.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  patient.birthDate == null
                      ? 'Data de nascimento não informada'
                      : 'Nascimento: ${formatBirthDate(patient.birthDate!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const Key('patient-module-open'),
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('Abrir $moduleLabel'),
          ),
          TextButton(onPressed: onClear, child: const Text('Limpar seleção')),
        ],
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient,
    required this.selected,
    required this.onTap,
  });

  final PatientSummary patient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> details = <String>[
      if (patient.birthDate != null)
        'Nasc. ${formatBirthDate(patient.birthDate!)}',
      if (patient.ageLabel.isNotEmpty) patient.ageLabel,
      if (patient.lastEncounterAt != null)
        'Último atendimento ${formatBirthDate(patient.lastEncounterAt!)}',
    ];
    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.softLilac : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: AppColors.avatarFor(patient.name),
            foregroundColor: Colors.white,
            child: Text(patient.initials),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  patient.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (selected)
            const StatusChip(label: 'Em foco')
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

/// Confirma a identidade antes de trocar o paciente em foco.
class _SwitchPatientDialog extends StatelessWidget {
  const _SwitchPatientDialog({required this.from, required this.to});

  final SelectedPatient from;
  final SelectedPatient to;

  String _describe(SelectedPatient p) => p.birthDate == null
      ? p.name
      : '${p.name} (nasc. ${formatBirthDate(p.birthDate!)})';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trocar o paciente em foco?'),
      content: Text(
        'Sai: ${_describe(from)}\n'
        'Entra: ${_describe(to)}\n\n'
        'Confira nome e data de nascimento antes de registrar qualquer dado.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('patient-switch-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmar troca'),
        ),
      ],
    );
  }
}

String formatBirthDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
