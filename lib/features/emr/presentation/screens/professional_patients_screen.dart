import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/config/dev_mode.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/clinical_access.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import 'patient_timeline_screen.dart';

/// Um paciente na visão do profissional.
///
/// Não é a entidade `Child` do responsável: aqui interessa o vínculo com o
/// atendimento — quando foi visto pela última vez, qual o diagnóstico, se há
/// rascunho aberto.
class PatientSummary {
  const PatientSummary({
    required this.patientId,
    required this.childId,
    required this.name,
    this.birthDate,
    this.lastEncounterAt,
    this.lastDiagnosis,
    this.hasOpenDraft = false,
    this.encounterCount = 0,
    this.allergies = const <String>[],
  });

  /// Uid do responsável — é a chave do prontuário.
  final String patientId;

  final String childId;
  final String name;
  final DateTime? birthDate;
  final DateTime? lastEncounterAt;
  final String? lastDiagnosis;

  /// Há atendimento em rascunho deste profissional para este paciente.
  final bool hasOpenDraft;

  final int encounterCount;
  final List<String> allergies;

  int? get ageMonths {
    if (birthDate == null) return null;
    final DateTime now = DateTime.now();
    int months =
        (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
    if (now.day < birthDate!.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  String get ageLabel {
    final int? m = ageMonths;
    if (m == null) return '';
    if (m < 24) return '$m ${m == 1 ? 'mês' : 'meses'}';
    final int years = m ~/ 12;
    return '$years ${years == 1 ? 'ano' : 'anos'}';
  }

  /// Iniciais para o avatar.
  String get initials {
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Pacientes que o profissional já atendeu.
///
/// ## Por que derivar dos atendimentos e não de uma lista própria
///
/// Manter uma collection `professional_patients` exigiria sincronizar dois
/// lugares e conviver com divergência. Os atendimentos já são a fonte de
/// verdade do vínculo: quem eu atendi é quem tem atendimento meu.
final StreamProvider<List<PatientSummary>> professionalPatientsProvider =
    StreamProvider<List<PatientSummary>>((Ref ref) {
  if (DevMode.isEnabled &&
      ref.watch(firebaseAuthProvider).currentUser == null) {
    return Stream<List<PatientSummary>>.error(
      const PermissionFailure(
        'Modo demonstração: entre com conta profissional verificada '
        'para ver pacientes reais.',
      ),
    );
  }
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<PatientSummary>>.value(const <PatientSummary>[]);
  }

  return ref
      .watch(encounterRepositoryProvider)
      .watchProfessionalEncounters(uid)
      .map((List<Encounter> encounters) {
    final Map<String, List<Encounter>> byPatient =
        <String, List<Encounter>>{};

    for (final Encounter e in encounters) {
      byPatient.putIfAbsent(e.patientId, () => <Encounter>[]).add(e);
    }

    final List<PatientSummary> patients = <PatientSummary>[];

    for (final MapEntry<String, List<Encounter>> entry in byPatient.entries) {
      final List<Encounter> list = entry.value
        ..sort((Encounter a, Encounter b) =>
            b.startedAt.compareTo(a.startedAt));

      final Encounter latest = list.first;

      // O nome mais recente prevalece: o cadastro pode ter sido corrigido.
      String? name;
      DateTime? birth;
      for (final Encounter e in list) {
        name ??= e.patientName;
        birth ??= e.patientBirthDate;
        if (name != null && birth != null) break;
      }

      patients.add(
        PatientSummary(
          patientId: entry.key,
          childId: entry.key,
          name: name ?? 'Paciente sem nome',
          birthDate: birth,
          lastEncounterAt: latest.startedAt,
          lastDiagnosis: latest.primaryDiagnosis?.description,
          hasOpenDraft:
              list.any((Encounter e) => e.status == EncounterStatus.draft),
          encounterCount: list.length,
          allergies: latest.anamnesis.allergies,
        ),
      );
    }

    patients.sort((PatientSummary a, PatientSummary b) =>
        (b.lastEncounterAt ?? DateTime(0))
            .compareTo(a.lastEncounterAt ?? DateTime(0)));

    return patients;
  });
});

/// Filtro ativo da lista.
enum PatientFilter {
  all,
  openDrafts,
  recent;

  String get label => switch (this) {
        PatientFilter.all => 'Todos',
        PatientFilter.openDrafts => 'Pendentes',
        PatientFilter.recent => 'Em acompanhamento',
      };
}

/// Lista de pacientes do profissional.
///
/// É a porta de entrada do prontuário: daqui se chega à linha do tempo e, dela,
/// ao atendimento.
class ProfessionalPatientsScreen extends ConsumerStatefulWidget {
  const ProfessionalPatientsScreen({super.key});

  @override
  ConsumerState<ProfessionalPatientsScreen> createState() =>
      _ProfessionalPatientsScreenState();
}

class _ProfessionalPatientsScreenState
    extends ConsumerState<ProfessionalPatientsScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  PatientFilter _filter = PatientFilter.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => setState(() => _query = value.trim()),
    );
  }

  /// Busca sem acento e sem caixa — quem digita "jose" precisa achar "José".
  List<PatientSummary> _apply(List<PatientSummary> all) {
    final DateTime cutoff =
        DateTime.now().subtract(const Duration(days: 30));

    Iterable<PatientSummary> result = all;

    result = switch (_filter) {
      PatientFilter.all => result,
      PatientFilter.openDrafts =>
        result.where((PatientSummary p) => p.hasOpenDraft),
      PatientFilter.recent => result.where((PatientSummary p) =>
          p.lastEncounterAt != null && p.lastEncounterAt!.isAfter(cutoff)),
    };

    if (_query.length >= 2) {
      final String needle = _normalize(_query);
      result = result.where(
        (PatientSummary p) => _normalize(p.name).contains(needle),
      );
    }

    return result.toList(growable: false);
  }

  static String _normalize(String input) {
    const Map<String, String> accents = <String, String>{
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final StringBuffer buffer = StringBuffer();
    for (final String c in input.toLowerCase().split('')) {
      buffer.write(accents[c] ?? c);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PatientSummary>> async =
        ref.watch(professionalPatientsProvider);

    final bool verified =
        ref.watch(currentUserProvider)?.canPrescribe ?? false;

    if (!verified) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pacientes'),
          leading: IconButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(Routes.homePath),
            icon: const AppIcon(
              asset: AppIcons.back,
              size: 22,
              fallback: Icons.arrow_back_rounded,
            ),
            tooltip: 'Voltar',
          ),
        ),
        body: const EmptyState(
          icon: Icons.gpp_maybe_outlined,
          title: 'Registro não verificado',
          message: 'O prontuário é liberado após a equipe conferir seu '
              'registro profissional. Você recebe um aviso quando isso '
              'acontecer.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: PrimaryButton(
          label: '+ Novo paciente',
          icon: Icons.add_rounded,
          asset: AppIcons.newPatient,
          onPressed: () async {
            final bool ok = await ensureClinicalAccessBeforeForm(
              context,
              ref,
              actionLabel: 'cadastrar paciente',
            );
            if (ok && context.mounted) await _newPatientSheet(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                children: <Widget>[
                  AppHeader(
                    notificationCount: ref.watch(unreadCountProvider),
                  ),
                  ScreenTitleBlock(
                    title: 'Pacientes',
                    subtitle: 'Gerencie e acompanhe seus pacientes.',
                    trailing: TextButton.icon(
                      onPressed: () {},
                      icon: const AppIcon(
                        asset: AppIcons.filter,
                        size: 18,
                        fallback: Icons.tune_rounded,
                        color: AppColors.brand,
                      ),
                      label: const Text('Filtros'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        backgroundColor: AppColors.softBlue,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillAll,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SearchBar(
                    controller: _search,
                    hintText: 'Buscar por nome ou responsável...',
                    leading: const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.md),
                      child: AppIcon(
                        asset: AppIcons.search,
                        size: 20,
                        fallback: Icons.search_rounded,
                      ),
                    ),
                    trailing: <Widget>[
                      if (_search.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: 'Limpar busca',
                        ),
                    ],
                    onChanged: _onSearch,
                    elevation: const WidgetStatePropertyAll<double>(0),
                    backgroundColor: const WidgetStatePropertyAll<Color>(
                      Colors.white,
                    ),
                    side: const WidgetStatePropertyAll<BorderSide>(
                      BorderSide(color: AppColors.line),
                    ),
                    shape: const WidgetStatePropertyAll<OutlinedBorder>(
                      RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        FilterChipPill(
                          label: PatientFilter.all.label,
                          icon: Icons.groups_rounded,
                          asset: AppIcons.patients,
                          selected: _filter == PatientFilter.all,
                          onTap: () =>
                              setState(() => _filter = PatientFilter.all),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilterChipPill(
                          label: PatientFilter.recent.label,
                          icon: Icons.child_care_rounded,
                          asset: AppIcons.child,
                          selected: _filter == PatientFilter.recent,
                          unselectedBg: AppColors.softLilac,
                          unselectedFg: const Color(0xFF7C6CF0),
                          selectedColor: const Color(0xFF7C6CF0),
                          onTap: () =>
                              setState(() => _filter = PatientFilter.recent),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilterChipPill(
                          label: PatientFilter.openDrafts.label,
                          icon: Icons.edit_calendar_outlined,
                          asset: AppIcons.schedule,
                          selected: _filter == PatientFilter.openDrafts,
                          unselectedBg: AppColors.softTeal,
                          unselectedFg: AppColors.tealDeep,
                          selectedColor: AppColors.teal,
                          onTap: () => setState(
                            () => _filter = PatientFilter.openDrafts,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const SkeletonList(itemCount: 6, itemHeight: 88),
                error: (Object e, StackTrace s) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Não conseguimos carregar essas informações',
                  message: clinicalLoadErrorMessage(e),
                  actionLabel: DevMode.isEnabled &&
                          ref.read(firebaseAuthProvider).currentUser == null
                      ? 'Entrar'
                      : 'Recarregar',
                  onAction: () async {
                    if (DevMode.isEnabled &&
                        ref.read(firebaseAuthProvider).currentUser == null) {
                      DevMode.requireRealAuth = true;
                      await ref.read(authRepositoryProvider).signOut();
                      ref.invalidate(authStateProvider);
                      if (context.mounted) context.go(Routes.loginPath);
                      return;
                    }
                    ref.invalidate(professionalPatientsProvider);
                  },
                ),
                data: (List<PatientSummary> all) {
                  final List<PatientSummary> patients = _apply(all);

                  if (all.isEmpty) {
                    return EmptyState(
                      icon: Icons.people_outline_rounded,
                      asset: AppIcons.patients,
                      title: 'Nenhum paciente ainda',
                      message:
                          'Os pacientes aparecem aqui depois do primeiro '
                          'atendimento registrado.',
                      actionLabel: 'Cadastrar paciente',
                      onAction: () async {
                        final bool ok = await ensureClinicalAccessBeforeForm(
                          context,
                          ref,
                          actionLabel: 'cadastrar paciente',
                        );
                        if (ok && context.mounted) {
                          await _newPatientSheet(context);
                        }
                      },
                    );
                  }

                  if (patients.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Nada encontrado',
                      message: _query.isNotEmpty
                          ? 'Nenhum paciente com "$_query".'
                          : 'Nenhum paciente neste filtro.',
                      actionLabel: 'Limpar filtros',
                      onAction: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _filter = PatientFilter.all;
                        });
                      },
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      108,
                    ),
                    itemCount: patients.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) =>
                        ContentBounds(
                      maxWidth: 760,
                      child: _PatientCard(patient: patients[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cadastro rápido de paciente, para quem chega sem conta no app.
  ///
  /// O prontuário é indexado pelo uid do responsável. Quando a família ainda
  /// não tem conta, criamos um identificador provisório — o vínculo é feito
  /// depois, quando o responsável se cadastrar com o mesmo e-mail.
  Future<void> _newPatientSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const _NewPatientSheet(),
        ),
      );
}

class _PatientCard extends ConsumerWidget {
  const _PatientCard({required this.patient});

  final PatientSummary patient;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String statusLabel = patient.hasOpenDraft
        ? 'Consulta pendente'
        : (patient.lastEncounterAt != null
            ? 'Acompanhamento'
            : 'Próxima consulta');

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PatientTimelineScreen(
            patientId: patient.patientId,
            patientName: patient.name,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          PersonAvatar(
            name: patient.name,
            seed: patient.patientId,
            radius: 28,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  patient.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (patient.ageLabel.isNotEmpty)
                  Text(
                    patient.ageLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                Text(
                  patient.lastDiagnosis != null
                      ? 'Responsável / última nota: ${patient.lastDiagnosis}'
                      : 'Responsável: cadastro vinculado',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusChip.fromStatusLabel(statusLabel),
                const SizedBox(height: 4),
                Text(
                  patient.hasOpenDraft
                      ? 'Retorno: atendimento em rascunho'
                      : (patient.lastEncounterAt != null
                          ? 'Última consulta: ${Formatters.date(patient.lastEncounterAt!)}'
                          : 'Próximo retorno: a agendar'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                if (patient.allergies.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Alergias: ${patient.allergies.take(2).join(', ')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.inkMuted.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

/// Cadastro rápido no consultório.
class _NewPatientSheet extends ConsumerStatefulWidget {
  const _NewPatientSheet();

  @override
  ConsumerState<_NewPatientSheet> createState() => _NewPatientSheetState();
}

class _NewPatientSheetState extends ConsumerState<_NewPatientSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _guardianEmail = TextEditingController();

  DateTime? _birthDate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _guardianEmail.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: now,
      helpText: 'Data de nascimento',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de nascimento.')),
      );
      return;
    }

    setState(() => _saving = true);

    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    // Identificador provisório do paciente. Quando o responsável criar conta
    // com este e-mail, uma Function faz o vínculo e migra o prontuário.
    final String provisionalId =
        'pending_${_guardianEmail.text.trim().toLowerCase().hashCode.abs()}';

    final Result<Encounter> created =
        await ref.read(encounterRepositoryProvider).create(
              patientId: provisionalId,
              professionalId: uid,
              professionalName: ref.read(currentUserProvider)?.name ?? '',
              professionalCrm: ref.read(currentUserProvider)?.crm,
              patientName: _name.text.trim(),
              patientBirthDate: _birthDate,
              type: EncounterType.routine,
              clinicId: ref.read(activeClinicIdProvider).valueOrNull,
            );

    if (!mounted) return;
    setState(() => _saving = false);

    created.fold(
      (Encounter e) {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientTimelineScreen(
              patientId: provisionalId,
              patientName: _name.text.trim(),
            ),
          ),
        );
      },
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Novo paciente', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Nome da criança',
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
            const SizedBox(height: AppSpacing.lg),
            InkWell(
              onTap: _pickBirthDate,
              borderRadius: AppRadius.mdAll,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data de nascimento',
                  prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                  helperText: _birthDate == null
                      ? null
                      : Formatters.pediatricAge(_birthDate!),
                ),
                child: Text(
                  _birthDate == null
                      ? 'Selecionar'
                      : Formatters.date(_birthDate!),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'E-mail do responsável',
              controller: _guardianEmail,
              keyboardType: TextInputType.emailAddress,
              helper: 'Usado para vincular o prontuário quando a família '
                  'criar conta no aplicativo.',
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Cadastrar e iniciar atendimento',
              isLoading: _saving,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'O prontuário fica vinculado à conta do responsável. Enquanto '
              'ela não existir, o registro segue acessível a você.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
