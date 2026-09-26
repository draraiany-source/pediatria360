import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../../security/domain/permission_matrix.dart';
import '../../../security/presentation/providers/security_providers.dart';
import '../widgets/clinical_assist_sheet.dart';
import 'document_editor_screen.dart';
import 'patient_timeline_screen.dart';
import 'visit_summary_editor_screen.dart';

final StreamProviderFamily<Encounter?, String> encounterProvider =
    StreamProvider.family<Encounter?, String>(
  (Ref ref, String encounterId) =>
      ref.watch(encounterRepositoryProvider).watchEncounter(encounterId),
);

/// Editor de atendimento.
///
/// ## Salvamento automático, não botão "salvar"
///
/// O médico digita a anamnese, examina a criança, volta e digita o exame. Um
/// botão "salvar" nesse fluxo perde conteúdo quando a consulta é interrompida —
/// e consulta pediátrica é interrompida o tempo todo.
///
/// O rascunho grava sozinho 2 segundos após a última tecla. Só a **assinatura**
/// é ação explícita, porque é ela que torna o registro imutável.
class EncounterEditorScreen extends ConsumerStatefulWidget {
  const EncounterEditorScreen({required this.encounterId, super.key});

  final String encounterId;

  @override
  ConsumerState<EncounterEditorScreen> createState() =>
      _EncounterEditorScreenState();
}

class _EncounterEditorScreenState
    extends ConsumerState<EncounterEditorScreen> {
  // Anamnese
  final TextEditingController _complaint = TextEditingController();
  final TextEditingController _hpi = TextEditingController();
  final TextEditingController _past = TextEditingController();
  final TextEditingController _family = TextEditingController();
  final TextEditingController _gestation = TextEditingController();
  final TextEditingController _birth = TextEditingController();
  final TextEditingController _feeding = TextEditingController();
  final TextEditingController _sleep = TextEditingController();
  final TextEditingController _elimination = TextEditingController();
  final TextEditingController _development = TextEditingController();
  final TextEditingController _immunization = TextEditingController();
  final TextEditingController _allergies = TextEditingController();
  final TextEditingController _medications = TextEditingController();

  // Sinais vitais
  final TextEditingController _temp = TextEditingController();
  final TextEditingController _hr = TextEditingController();
  final TextEditingController _rr = TextEditingController();
  final TextEditingController _spo2 = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _head = TextEditingController();
  final TextEditingController _sbp = TextEditingController();
  final TextEditingController _dbp = TextEditingController();
  final TextEditingController _pain = TextEditingController();

  // Avaliação e conduta
  final TextEditingController _assessment = TextEditingController();
  final TextEditingController _plan = TextEditingController();
  final TextEditingController _guidance = TextEditingController();
  final TextEditingController _returnPlan = TextEditingController();

  final Map<ExamSystem, TextEditingController> _exam =
      <ExamSystem, TextEditingController>{
    for (final ExamSystem s in ExamSystem.values) s: TextEditingController(),
  };
  final Set<ExamSystem> _examined = <ExamSystem>{};

  List<Diagnosis> _diagnoses = <Diagnosis>[];

  Timer? _autosave;
  bool _hydrated = false;
  bool _chartOpenLogged = false;
  bool _saving = false;
  DateTime? _savedAt;

  static const Duration _autosaveDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    for (final TextEditingController c in _allControllers) {
      c.addListener(_scheduleSave);
    }
  }

  List<TextEditingController> get _allControllers => <TextEditingController>[
        _complaint,
        _hpi,
        _past,
        _family,
        _gestation,
        _birth,
        _feeding,
        _sleep,
        _elimination,
        _development,
        _immunization,
        _allergies,
        _medications,
        _temp,
        _hr,
        _rr,
        _spo2,
        _weight,
        _height,
        _head,
        _sbp,
        _dbp,
        _pain,
        _assessment,
        _plan,
        _guidance,
        _returnPlan,
        ..._exam.values,
      ];

  static const String _guidanceMarker = '\n\n--- Orientações ---\n';
  static const String _returnMarker = '\n\n--- Retorno ---\n';

  String _composePlan() {
    final String base = _plan.text.trim();
    final String guidance = _guidance.text.trim();
    final String ret = _returnPlan.text.trim();
    final StringBuffer buffer = StringBuffer(base);
    if (guidance.isNotEmpty) {
      buffer.write('$_guidanceMarker$guidance');
    }
    if (ret.isNotEmpty) {
      buffer.write('$_returnMarker$ret');
    }
    return buffer.toString();
  }

  void _splitPlan(String raw) {
    String plan = raw;
    String guidance = '';
    String ret = '';
    final int g = plan.indexOf(_guidanceMarker);
    final int r = plan.indexOf(_returnMarker);
    if (g >= 0 && (r < 0 || g < r)) {
      guidance = plan.substring(g + _guidanceMarker.length);
      plan = plan.substring(0, g);
      final int r2 = guidance.indexOf(_returnMarker);
      if (r2 >= 0) {
        ret = guidance.substring(r2 + _returnMarker.length);
        guidance = guidance.substring(0, r2);
      }
    } else if (r >= 0) {
      ret = plan.substring(r + _returnMarker.length);
      plan = plan.substring(0, r);
    }
    _plan.text = plan.trim();
    _guidance.text = guidance.trim();
    _returnPlan.text = ret.trim();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    // Grava o que estiver pendente ao sair — sem isso, os últimos 2 segundos
    // de digitação se perdem ao fechar a tela.
    unawaited(_save(disposing: true));
    for (final TextEditingController c in _allControllers) {
      c
        ..removeListener(_scheduleSave)
        ..dispose();
    }
    super.dispose();
  }

  void _scheduleSave() {
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, _save);
  }

  void _maybeLogChartOpened(Encounter e) {
    if (_chartOpenLogged || !e.isSigned) return;
    _chartOpenLogged = true;
    unawaited(
      ref.read(auditLogServiceProvider).log(
            user: ref.read(currentUserProvider),
            membership: ref.read(activeClinicMembershipProvider),
            action: 'chartOpened',
            module: PermissionModule.chart,
            entityType: 'encounter',
            entityId: e.id,
          ),
    );
  }

  void _hydrate(Encounter e) {
    if (_hydrated) return;
    _hydrated = true;
    _maybeLogChartOpened(e);

    _complaint.text = e.anamnesis.chiefComplaint;
    _hpi.text = e.anamnesis.historyOfPresentIllness;
    _past.text = e.anamnesis.pastMedicalHistory;
    _family.text = e.anamnesis.familyHistory;
    _gestation.text = e.anamnesis.gestationalHistory;
    _birth.text = e.anamnesis.birthHistory;
    _feeding.text = e.anamnesis.feedingHistory;
    _sleep.text = e.anamnesis.sleepHistory;
    _elimination.text = e.anamnesis.eliminationHistory;
    _development.text = e.anamnesis.developmentHistory;
    _immunization.text = e.anamnesis.immunizationStatus;
    _allergies.text = e.anamnesis.allergies.join(', ');
    _medications.text = e.anamnesis.currentMedications.join(', ');

    _temp.text = _num(e.vitals.temperatureC);
    _hr.text = e.vitals.heartRate?.toString() ?? '';
    _rr.text = e.vitals.respiratoryRate?.toString() ?? '';
    _spo2.text = e.vitals.oxygenSaturation?.toString() ?? '';
    _weight.text = _num(e.vitals.weightKg);
    _height.text = _num(e.vitals.heightCm);
    _head.text = _num(e.vitals.headCircumferenceCm);
    _sbp.text = e.vitals.systolicBp?.toString() ?? '';
    _dbp.text = e.vitals.diastolicBp?.toString() ?? '';
    _pain.text = e.vitals.painScore?.toString() ?? '';

    _assessment.text = e.assessment;
    _splitPlan(e.plan);

    for (final ExamSystem s in ExamSystem.values) {
      final String? finding = e.exam.findings[s.name];
      if (finding != null) _exam[s]!.text = finding;
      if (e.exam.systemsExamined.contains(s.name)) _examined.add(s);
    }

    _diagnoses = List<Diagnosis>.of(e.diagnoses);
  }

  static String _num(double? v) =>
      v == null ? '' : v.toString().replaceAll('.', ',');

  /// Com [disposing], grava sem tocar no estado do widget (ja em descarte).
  Future<void> _save({bool disposing = false}) async {
    if (_saving || (!disposing && !mounted)) return;

    final Encounter? current =
        ref.read(encounterProvider(widget.encounterId)).valueOrNull;
    if (current == null || !current.isEditable) return;

    if (!disposing) setState(() => _saving = true);

    final Result<void> result =
        await ref.read(encounterRepositoryProvider).updateDraft(
              encounterId: widget.encounterId,
              anamnesis: Anamnesis(
                chiefComplaint: _complaint.text.trim(),
                historyOfPresentIllness: _hpi.text.trim(),
                pastMedicalHistory: _past.text.trim(),
                gestationalHistory: _gestation.text.trim(),
                birthHistory: _birth.text.trim(),
                developmentHistory: _development.text.trim(),
                feedingHistory: _feeding.text.trim(),
                sleepHistory: _sleep.text.trim(),
                eliminationHistory: _elimination.text.trim(),
                immunizationStatus: _immunization.text.trim(),
                allergies: _splitList(_allergies.text),
                currentMedications: _splitList(_medications.text),
                familyHistory: _family.text.trim(),
              ),
              vitals: VitalSigns(
                temperatureC: Parsers.decimal(_temp.text),
                heartRate: int.tryParse(_hr.text.trim()),
                respiratoryRate: int.tryParse(_rr.text.trim()),
                oxygenSaturation: int.tryParse(_spo2.text.trim()),
                weightKg: Parsers.decimal(_weight.text),
                heightCm: Parsers.decimal(_height.text),
                headCircumferenceCm: Parsers.decimal(_head.text),
                systolicBp: int.tryParse(_sbp.text.trim()),
                diastolicBp: int.tryParse(_dbp.text.trim()),
                painScore: int.tryParse(_pain.text.trim()),
              ),
              exam: PhysicalExam(
                findings: <String, String>{
                  for (final MapEntry<ExamSystem, TextEditingController> e
                      in _exam.entries)
                    if (e.value.text.trim().isNotEmpty)
                      e.key.name: e.value.text.trim(),
                },
                systemsExamined:
                    _examined.map((ExamSystem s) => s.name).toSet(),
              ),
              diagnoses: _diagnoses,
              assessment: _assessment.text.trim(),
              plan: _composePlan(),
            );

    if (disposing || !mounted) return;

    setState(() {
      _saving = false;
      if (result.isSuccess) _savedAt = DateTime.now();
    });
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);

  /// Marca o aparelho como examinado e preenche o texto de normalidade.
  ///
  /// Registrar o normal importa tanto quanto o alterado: campo em branco não
  /// distingue "estava normal" de "não foi examinado".
  void _markNormal(ExamSystem system) {
    setState(() {
      _examined.add(system);
      if (_exam[system]!.text.trim().isEmpty) {
        _exam[system]!.text = system.normalFinding;
      }
    });
    _scheduleSave();
  }

  Future<void> _sign(Encounter encounter) async {
    // Grava o pendente antes de validar — assinar um estado desatualizado
    // gravaria hash de um conteúdo diferente do que está na tela.
    _autosave?.cancel();
    await _save();

    if (!mounted) return;

    final Encounter? fresh =
        ref.read(encounterProvider(widget.encounterId)).valueOrNull;
    final List<String> missing = fresh?.missingForSignature ?? <String>[];

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Faltam: ${missing.join(', ')}.')),
        );
      return;
    }

    final PhysicalExam exam = fresh?.exam ?? const PhysicalExam();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Assinar atendimento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Depois de assinado, o registro não pode ser editado. '
              'Correções geram uma retificação vinculada, e o original '
              'continua legível.',
            ),
            if (exam.notExamined.length > 4) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                '${exam.notExamined.length} aparelhos não foram registrados '
                'no exame físico.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Assinar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) return;

    final Result<String> result =
        await ref.read(encounterRepositoryProvider).sign(widget.encounterId);

    if (!mounted) return;

    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atendimento assinado.')),
      ),
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<Encounter?> async =
        ref.watch(encounterProvider(widget.encounterId));
    final Encounter? encounter = async.valueOrNull;

    if (encounter == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.popOrHome(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Voltar',
          ),
        ),
        body: async.isLoading
            ? const LoadingState()
            : const EmptyState(
                icon: Icons.folder_off_outlined,
                title: 'Atendimento não encontrado',
                message: 'Ele pode ter sido removido.',
              ),
      );
    }

    _hydrate(encounter);
    final bool locked = !encounter.isEditable;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(encounter.type.label, style: theme.textTheme.titleSmall),
            Text(
              locked
                  ? 'Assinado em ${Formatters.dateTime(encounter.signedAt!)}'
                  : _savedAt == null
                      ? 'Rascunho'
                      : 'Salvo às '
                          '${_savedAt!.hour.toString().padLeft(2, '0')}:'
                          '${_savedAt!.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => _openAssistant(encounter),
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Assistente clínico',
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: locked
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => VisitSummaryEditorScreen(
                        encounterId: encounter.id,
                        patientId: encounter.patientId,
                        professionalId: encounter.professionalId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.summarize_outlined, size: 18),
                  label: const Text('Resumo para a família'),
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppButton(
                  label: 'Assinar atendimento',
                  icon: Icons.verified_outlined,
                  onPressed: () => _sign(encounter),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          ContentBounds(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (locked) _SignedBanner(encounter: encounter),
                if (encounter.amendsEncounterId != null)
                  _AmendmentBanner(reason: encounter.amendmentReason),

                const SectionHeader(title: 'Anamnese', eyebrow: 'História'),
                _Field(
                  label: 'Queixa principal',
                  controller: _complaint,
                  enabled: !locked,
                  hint: 'Nas palavras de quem trouxe a criança',
                  required: true,
                ),
                _Field(
                  label: 'História da doença atual (HDA)',
                  controller: _hpi,
                  enabled: !locked,
                  lines: 5,
                ),
                _Field(
                  label: 'Antecedentes pessoais',
                  controller: _past,
                  enabled: !locked,
                  lines: 3,
                ),
                _Field(
                  label: 'Antecedentes familiares',
                  controller: _family,
                  enabled: !locked,
                  lines: 2,
                ),
                _Field(
                  label: 'Gestação',
                  controller: _gestation,
                  enabled: !locked,
                  lines: 2,
                  hint: 'Pré-natal, intercorrências, medicações',
                ),
                _Field(
                  label: 'Parto',
                  controller: _birth,
                  enabled: !locked,
                  lines: 2,
                  hint: 'Tipo de parto, Apgar, peso ao nascer',
                ),
                _Field(
                  label: 'Alimentação',
                  controller: _feeding,
                  enabled: !locked,
                  lines: 2,
                ),
                _Field(
                  label: 'Sono',
                  controller: _sleep,
                  enabled: !locked,
                  lines: 2,
                ),
                _Field(
                  label: 'Eliminações',
                  controller: _elimination,
                  enabled: !locked,
                  lines: 2,
                ),
                _Field(
                  label: 'Desenvolvimento',
                  controller: _development,
                  enabled: !locked,
                  lines: 2,
                  hint: 'Marcos neuropsicomotores',
                ),
                _Field(
                  label: 'Vacinação',
                  controller: _immunization,
                  enabled: !locked,
                  lines: 2,
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Field(
                        label: 'Alergias',
                        controller: _allergies,
                        enabled: !locked,
                        hint: 'Separe por vírgula',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _Field(
                        label: 'Medicações em uso',
                        controller: _medications,
                        enabled: !locked,
                        hint: 'Separe por vírgula',
                      ),
                    ),
                  ],
                ),

                const SectionHeader(
                  title: 'Sinais vitais',
                  eyebrow: 'Aferição',
                ),
                _VitalsGrid(
                  temp: _temp,
                  hr: _hr,
                  rr: _rr,
                  spo2: _spo2,
                  weight: _weight,
                  height: _height,
                  head: _head,
                  sbp: _sbp,
                  dbp: _dbp,
                  pain: _pain,
                  enabled: !locked,
                  ageMonths: encounter.patientAgeMonthsAtEncounter,
                ),

                const SectionHeader(
                  title: 'Exame físico',
                  eyebrow: 'Aparelhos',
                ),
                for (final ExamSystem system in ExamSystem.values)
                  _ExamField(
                    system: system,
                    controller: _exam[system]!,
                    examined: _examined.contains(system),
                    enabled: !locked,
                    onMarkNormal: () => _markNormal(system),
                    onToggle: (bool v) {
                      setState(() {
                        if (v) {
                          _examined.add(system);
                        } else {
                          _examined.remove(system);
                        }
                      });
                      _scheduleSave();
                    },
                  ),

                SectionHeader(
                  title: 'Diagnósticos',
                  eyebrow: 'CID',
                  actionLabel: locked ? null : 'Adicionar',
                  onAction: locked ? null : _addDiagnosis,
                ),
                if (_diagnoses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    child: Text(
                      'Nenhum diagnóstico registrado.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                else
                  for (int i = 0; i < _diagnoses.length; i++)
                    _DiagnosisTile(
                      diagnosis: _diagnoses[i],
                      enabled: !locked,
                      onRemove: () {
                        setState(() => _diagnoses.removeAt(i));
                        _scheduleSave();
                      },
                    ),

                const SectionHeader(
                  title: 'Avaliação e conduta',
                  eyebrow: 'Raciocínio',
                ),
                _Field(
                  label: 'Avaliação / hipóteses',
                  controller: _assessment,
                  enabled: !locked,
                  hint: 'Correlação entre achados e hipóteses',
                  lines: 4,
                ),
                _Field(
                  label: 'Conduta',
                  controller: _plan,
                  enabled: !locked,
                  lines: 4,
                  required: true,
                ),
                _Field(
                  label: 'Orientações',
                  controller: _guidance,
                  enabled: !locked,
                  lines: 3,
                  hint: 'Orientações para a família',
                ),
                _Field(
                  label: 'Retorno',
                  controller: _returnPlan,
                  enabled: !locked,
                  lines: 2,
                  hint: 'Quando retornar e sinais de alerta',
                ),

                if (locked) ...<Widget>[
                  const SectionHeader(
                    title: 'Documentos',
                    eyebrow: 'Emissão',
                  ),
                  _DocumentActions(encounter: encounter),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Abre o assistente clínico.
  ///
  /// Grava o pendente antes: o assistente lê o prontuário no servidor, e ler
  /// um estado defasado produziria um texto que ignora o que acabou de ser
  /// digitado.
  Future<void> _openAssistant(Encounter encounter) async {
    _autosave?.cancel();
    await _save();

    if (!mounted) return;

    final List<Encounter> previous =
        ref.read(patientEncountersProvider(encounter.patientId)).valueOrNull ??
            const <Encounter>[];

    final bool hasHistory = previous
        .where((Encounter e) => e.id != encounter.id && e.isSigned)
        .isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => ClinicalAssistSheet(
        encounter: encounter,
        hasHistory: hasHistory,
        // Depois de assinado o campo é somente leitura, então não faz sentido
        // oferecer inserção.
        onInsertToAssessment: encounter.isEditable
            ? (String text) => _appendTo(_assessment, text)
            : null,
        onInsertToPlan: encounter.isEditable
            ? (String text) => _appendTo(_plan, text)
            : null,
      ),
    );
  }

  /// Acrescenta ao final do campo, preservando o que o médico já escreveu.
  ///
  /// Substituir apagaria observação clínica — o assistente soma, não troca.
  void _appendTo(TextEditingController controller, String text) {
    final String existing = controller.text.trimRight();
    controller.text =
        existing.isEmpty ? text : '$existing\n\n$text';
    _scheduleSave();
  }

  Future<void> _addDiagnosis() async {
    final Diagnosis? added = await showModalBottomSheet<Diagnosis>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _DiagnosisSheet(),
      ),
    );

    if (added != null) {
      setState(() => _diagnoses.add(added));
      _scheduleSave();
    }
  }
}

class _SignedBanner extends StatelessWidget {
  const _SignedBanner({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Registro assinado e selado',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  'Correções geram retificação vinculada. O original continua '
                  'legível no prontuário.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmendmentBanner extends StatelessWidget {
  const _AmendmentBanner({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Retificação', style: theme.textTheme.titleSmall),
          if (reason != null)
            Text(reason!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.hint,
    this.lines = 1,
    this.required = false,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final String? hint;
  final int lines;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: AppTextField(
          label: required ? '$label *' : label,
          controller: controller,
          enabled: enabled,
          hint: hint,
          maxLines: lines,
          textCapitalization: TextCapitalization.sentences,
        ),
      );
}

/// Sinais vitais com faixa esperada para a idade ao lado.
class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({
    required this.temp,
    required this.hr,
    required this.rr,
    required this.spo2,
    required this.weight,
    required this.height,
    required this.head,
    required this.sbp,
    required this.dbp,
    required this.pain,
    required this.enabled,
    this.ageMonths,
  });

  final TextEditingController temp;
  final TextEditingController hr;
  final TextEditingController rr;
  final TextEditingController spo2;
  final TextEditingController weight;
  final TextEditingController height;
  final TextEditingController head;
  final TextEditingController sbp;
  final TextEditingController dbp;
  final TextEditingController pain;
  final bool enabled;
  final int? ageMonths;

  @override
  Widget build(BuildContext context) {
    // A faixa esperada aparece como texto de apoio, não como validação: uma
    // criança febril tem taquicardia esperada, e bloquear o campo seria
    // impedir o registro de um achado real.
    String? hrHelper;
    String? rrHelper;

    if (ageMonths != null) {
      final ({(int, int) hr, (int, int) rr}) ranges = _ranges(ageMonths!);
      hrHelper = 'Esperado ${ranges.hr.$1}–${ranges.hr.$2} bpm';
      rrHelper = 'Esperado ${ranges.rr.$1}–${ranges.rr.$2} irpm';
    }

    Widget field(
      String label,
      TextEditingController c,
      String unit, {
      String? helper,
      bool decimal = false,
    }) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppTextField(
              label: label,
              controller: c,
              enabled: enabled,
              helper: helper,
              suffix: Padding(
                padding: const EdgeInsets.all(AppSpacing.fieldSuffix),
                child: Text(unit),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: decimal ? Masks.decimal : Masks.digitsOnly,
            ),
          ),
        );

    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            field('Temperatura', temp, '°C', decimal: true),
            const SizedBox(width: AppSpacing.md),
            field('SpO₂', spo2, '%'),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            field('Freq. cardíaca', hr, 'bpm', helper: hrHelper),
            const SizedBox(width: AppSpacing.md),
            field('Freq. respiratória', rr, 'irpm', helper: rrHelper),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            field('Peso', weight, 'kg', decimal: true),
            const SizedBox(width: AppSpacing.md),
            field('Altura', height, 'cm', decimal: true),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            field('Perímetro cefálico', head, 'cm', decimal: true),
            const SizedBox(width: AppSpacing.md),
            field('Dor (0–10)', pain, ''),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            field('PA sistólica', sbp, 'mmHg'),
            const SizedBox(width: AppSpacing.md),
            field('PA diastólica', dbp, 'mmHg'),
          ],
        ),
      ],
    );
  }

  static ({(int, int) hr, (int, int) rr}) _ranges(int months) {
    if (months < 1) return (hr: (100, 180), rr: (30, 60));
    if (months < 12) return (hr: (100, 160), rr: (25, 50));
    if (months < 36) return (hr: (90, 150), rr: (20, 40));
    if (months < 72) return (hr: (80, 140), rr: (20, 30));
    if (months < 144) return (hr: (70, 120), rr: (16, 26));
    return (hr: (60, 100), rr: (12, 20));
  }
}

class _ExamField extends StatelessWidget {
  const _ExamField({
    required this.system,
    required this.controller,
    required this.examined,
    required this.enabled,
    required this.onMarkNormal,
    required this.onToggle,
  });

  final ExamSystem system;
  final TextEditingController controller;
  final bool examined;
  final bool enabled;
  final VoidCallback onMarkNormal;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Checkbox(
                    value: examined,
                    onChanged: enabled ? (bool? v) => onToggle(v ?? false) : null,
                  ),
                  Expanded(
                    child: Text(
                      system.label,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (enabled)
                    TextButton(
                      onPressed: onMarkNormal,
                      child: const Text('Normal'),
                    ),
                ],
              ),
              if (examined || controller.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: AppTextField(
                    label: 'Achados',
                    controller: controller,
                    enabled: enabled,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosisTile extends StatelessWidget {
  const _DiagnosisTile({
    required this.diagnosis,
    required this.enabled,
    required this.onRemove,
  });

  final Diagnosis diagnosis;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          title: Text(
            diagnosis.description,
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                AppTag(label: diagnosis.code),
                AppTag(label: diagnosis.type.label),
                AppTag(
                  label: diagnosis.certainty.label,
                  color: diagnosis.certainty == DiagnosisCertainty.confirmed
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
          ),
          trailing: enabled
              ? IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remover',
                )
              : null,
        ),
      ),
    );
  }
}

/// Entrada de diagnóstico.
///
/// ## Estado real, não aspiracional
///
/// Isto é só um campo de texto livre — não existe busca, nem tabela CID
/// carregada, nem validação de código. O comentário anterior descrevia uma
/// busca que nunca foi implementada, o que é pior que não ter comentário
/// nenhum: alguém lendo o código acreditaria que a funcionalidade existe.
///
/// Não construí a busca porque não tenho uma base oficial/licenciada de
/// CID-10 para popular — inventar uma lista incompleta seria pior que não
/// ter busca nenhuma. O aviso na tela, logo abaixo do título, é a parte
/// que efetivamente chega ao médico usando isto, não só ao próximo
/// programador lendo o arquivo.
class _DiagnosisSheet extends StatefulWidget {
  const _DiagnosisSheet();

  @override
  State<_DiagnosisSheet> createState() => _DiagnosisSheetState();
}

class _DiagnosisSheetState extends State<_DiagnosisSheet> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _description = TextEditingController();

  DiagnosisType _type = DiagnosisType.primary;
  DiagnosisCertainty _certainty = DiagnosisCertainty.suspected;

  @override
  void dispose() {
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

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
            Text('Adicionar diagnóstico', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Código digitado manualmente — busca por base oficial de CID-10 '
              'ainda não disponível.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 110,
                  child: AppTextField(
                    label: 'CID',
                    controller: _code,
                    hint: 'J06',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Descrição',
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Tipo', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DiagnosisType>(
              segments: DiagnosisType.values
                  .map(
                    (DiagnosisType t) => ButtonSegment<DiagnosisType>(
                      value: t,
                      label: Text(t.label),
                    ),
                  )
                  .toList(),
              selected: <DiagnosisType>{_type},
              onSelectionChanged: (Set<DiagnosisType> v) =>
                  setState(() => _type = v.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Certeza', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DiagnosisCertainty>(
              segments: DiagnosisCertainty.values
                  .map(
                    (DiagnosisCertainty c) =>
                        ButtonSegment<DiagnosisCertainty>(
                      value: c,
                      label: Text(c.label),
                    ),
                  )
                  .toList(),
              selected: <DiagnosisCertainty>{_certainty},
              onSelectionChanged: (Set<DiagnosisCertainty> v) =>
                  setState(() => _certainty = v.first),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Registrar suspeita como confirmação carimba a criança com um '
              'diagnóstico que ela pode nunca ter tido.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Adicionar',
              onPressed: () {
                if (_description.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  Diagnosis(
                    code: _code.text.trim().toUpperCase(),
                    description: _description.text.trim(),
                    type: _type,
                    certainty: _certainty,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Emissão de documentos, disponível só após a assinatura.
class _DocumentActions extends ConsumerWidget {
  const _DocumentActions({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: <Widget>[
          for (final ClinicalDocumentType type in ClinicalDocumentType.values)
            ListTile(
              leading: Icon(_iconFor(type)),
              title: Text(type.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DocumentEditorScreen(
                    encounter: encounter,
                    type: type,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(ClinicalDocumentType type) => switch (type) {
        ClinicalDocumentType.prescription => Icons.medication_outlined,
        ClinicalDocumentType.certificate => Icons.description_outlined,
        ClinicalDocumentType.referral => Icons.send_outlined,
        ClinicalDocumentType.report => Icons.article_outlined,
        ClinicalDocumentType.dischargeSummary =>
          Icons.assignment_turned_in_outlined,
        ClinicalDocumentType.examRequest => Icons.science_outlined,
      };
}
