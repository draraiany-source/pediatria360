import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/flow_widgets.dart';

/// Abre a calculadora sobre o receituário e devolve o item conferido.
Future<RxItem?> openDoseCalculator(
  BuildContext context,
  DemoPatient patient, {
  String? contextNote,
}) =>
    Navigator.of(context).push<RxItem>(
      MaterialPageRoute<RxItem>(
        fullscreenDialog: true,
        builder: (BuildContext c) => Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Cancelar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(c).pop(),
            ),
            title: const Text('Calculadora de doses'),
          ),
          body: DoseCalculatorPanel(
            patient: patient,
            contextNote: contextNote,
            insertLabel: 'Inserir na receita',
            onInsert: (RxItem item) => Navigator.of(c).pop(item),
          ),
        ),
      ),
    );

/// Módulo "Calculadora": escolhe o paciente e leva o item para um
/// receituário novo, onde ainda passa por revisão antes da emissão.
class DemoCalculatorScreen extends StatelessWidget {
  const DemoCalculatorScreen({super.key, this.initialPatientId});

  final String? initialPatientId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Calculadora de doses'),
        automaticallyImplyLeading: false,
      ),
      body: DoseCalculatorPanel(
        patient: initialPatientId == null
            ? null
            : demoSession.patientById(initialPatientId!),
        insertLabel: 'Inserir em novo receituário',
        onInsert: (RxItem item) {},
        onInsertForPatient: (DemoPatient p, RxItem item) {
          final DateTime now = DateTime.now();
          final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
            id: demoSession.newDocumentId(),
            kind: DocKind.receituario,
            patientId: p.id,
            author: demoSession.currentAuthor,
            context: DemoClinicalSeed.contextFor(
              p,
              date: DateTime(now.year, now.month, now.day),
            ),
            now: now,
            items: <RxItem>[item],
          );
          demoSession.saveDocument(doc);
          showDemoSnack(
            context,
            'Item inserido em um receituário em rascunho. Revise antes de emitir.',
          );
          context.go('/pacientes/${p.id}/documentos/${doc.id}/editar');
        },
      ),
    );
  }
}

class DoseCalculatorPanel extends StatefulWidget {
  const DoseCalculatorPanel({
    required this.onInsert,
    required this.insertLabel,
    super.key,
    this.patient,
    this.onInsertForPatient,
    this.contextNote,
  });

  /// Origem do cálculo (ex.: decisão de suplementação), mostrada no topo.
  final String? contextNote;

  /// `null` mostra a escolha de paciente.
  final DemoPatient? patient;
  final ValueChanged<RxItem> onInsert;
  final void Function(DemoPatient patient, RxItem item)? onInsertForPatient;
  final String insertLabel;

  @override
  State<DoseCalculatorPanel> createState() => _DoseCalculatorPanelState();
}

class _DoseCalculatorPanelState extends State<DoseCalculatorPanel> {
  DemoPatient? _patient;
  DoseReference? _ref;
  DrugPresentation? _pres;
  final TextEditingController _mgPerKg = TextEditingController();
  final TextEditingController _route = TextEditingController(text: 'via oral');
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  bool _limit = false;
  bool _confirmResult = false;
  bool _confirmPresentation = false;
  final Set<DoseAlertKind> _acknowledged = <DoseAlertKind>{};

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  @override
  void dispose() {
    _mgPerKg.dispose();
    _route.dispose();
    _duration.dispose();
    _quantity.dispose();
    super.dispose();
  }

  /// Qualquer mudança de entrada invalida as conferências já feitas.
  void _changed(VoidCallback fn) => setState(() {
    fn();
    _confirmResult = false;
    _confirmPresentation = false;
    _acknowledged.clear();
  });

  double? get _mgPerKgValue {
    final String t = _mgPerKg.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return double.nan;
    return double.tryParse(t) ?? double.nan;
  }

  String? get _mgPerKgError {
    final String t = _mgPerKg.text.trim();
    if (t.isEmpty) return 'Informe a dose em ${_ref?.basis.label ?? 'mg/kg'}.';
    final double? v = double.tryParse(t.replaceAll(',', '.'));
    if (v == null) return 'Use só números (ex.: 15 ou 12,5).';
    if (v <= 0) return 'A dose precisa ser maior que zero.';
    return null;
  }

  DoseCalculation _calc(DateTime now) => PediatricDoseCalculator.calculate(
    reference: _ref,
    presentation: _pres,
    patient: DosePatientData(
      name: _patient?.name,
      weightKg: _patient?.weightKg,
      weighedAt: _patient?.weighedAt,
      birthDate: _patient?.birthDate,
      allergies: _patient?.allergies ?? const <String>[],
    ),
    now: now,
    mgPerKgOverride: _ref == null ? null : _mgPerKgValue,
    limitToMax: _limit,
  );

  List<String> _insertBlockers(DoseCalculation c) => <String>[
    if (_patient == null) 'Selecione o paciente.',
    if (c.isBlocked) 'Cálculo bloqueado.',
    if (c.hasCritical) 'Há alerta crítico.',
    if (c.alerts.any(
      (DoseAlert a) => !a.isCritical && !_acknowledged.contains(a.kind),
    ))
      'Marque ciência dos alertas.',
    if (!c.isBlocked && !_confirmResult) 'Confirme o resultado.',
    if (!c.isBlocked && !_confirmPresentation) 'Confirme a apresentação.',
    if (_duration.text.trim().isEmpty) 'Informe a duração do tratamento.',
  ];

  void _insert(DoseCalculation c) {
    final DoseReference ref = c.reference!;
    final DrugPresentation pres = c.presentation!;
    final RxItem item = RxItem(
      drug: ref.drugName,
      presentation: pres.label,
      dose: c.perAdministrationLabel,
      route: _route.text.trim(),
      frequency: ref.intervalLabel,
      duration: _duration.text.trim(),
      quantity: _quantity.text.trim(),
      calculation: <String>[
        ...c.steps,
        'Peso ${formatDoseNumber(c.weightKg!)} kg em ${formatDocDate(c.weighedAt!)}; '
            'referência: ${ref.source} (revisão ${formatDocDate(ref.reviewedAt!)}).',
      ].join('\n'),
    );
    if (widget.onInsertForPatient != null) {
      widget.onInsertForPatient!(_patient!, item);
    } else {
      widget.onInsert(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DoseCalculation calc = _calc(now);
    final TextTheme t = Theme.of(context).textTheme;
    final List<String> blockers = _insertBlockers(calc);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        DemoContent(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const DemoNotice(
                icon: Icons.science_outlined,
                color: AppColors.warning,
                text:
                    'Medicamentos e referências FICTÍCIOS, criados só para '
                    'testar as contas. A calculadora confere aritmética sobre '
                    'uma referência validada; não sugere tratamento nem gera '
                    'prescrição sozinha.',
              ),
              if (widget.contextNote != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                DemoNotice(
                  icon: Icons.link_rounded,
                  text: widget.contextNote!,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (widget.patient == null)
                Semantics(
                  container: true,
                  child: DropdownButtonFormField<String>(
                    initialValue: _patient?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Paciente *'),
                    items: <DropdownMenuItem<String>>[
                      for (final DemoPatient p in demoSession.visiblePatients)
                        DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (String? id) => _changed(
                      () => _patient = id == null
                          ? null
                          : demoSession.patientById(id),
                    ),
                  ),
                ),
              if (_patient != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                DemoPatientStrip(patient: _patient!, now: now),
                const SizedBox(height: AppSpacing.xs),
                _PatientFacts(patient: _patient!, now: now),
              ],
              const DemoSectionTitle('Medicamento e referência'),
              Semantics(
                container: true,
                child: DropdownButtonFormField<String>(
                  initialValue: _ref?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Medicamento *'),
                  items: <DropdownMenuItem<String>>[
                    for (final DoseReference r in demoSession.doseReferences)
                      DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(
                          r.isUsable
                              ? r.drugName
                              : '${r.drugName} (não validada)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (String? id) => _changed(() {
                    _ref = demoSession.doseReferences.firstWhere(
                      (DoseReference r) => r.id == id,
                    );
                    _pres = null;
                    _mgPerKg.text = formatDoseNumber(_ref!.mgPerKg);
                  }),
                ),
              ),
              if (_ref != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _ReferenceCard(reference: _ref!),
                const DemoSectionTitle('Dose e apresentação'),
                TextField(
                  key: const ValueKey<String>('mgkg'),
                  controller: _mgPerKg,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _changed(() {}),
                  decoration: InputDecoration(
                    labelText: 'Dose prescrita *',
                    suffixText: _ref!.basis.label,
                    helperText: _ref!.minMgPerKg == null
                        ? null
                        : 'Faixa configurada: ${formatDoseNumber(_ref!.minMgPerKg!)} a '
                              '${formatDoseNumber(_ref!.maxMgPerKg!)} ${_ref!.basis.label}',
                    errorText: _mgPerKgError,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  container: true,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>('pres-${_ref!.id}'),
                    initialValue: _pres?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Apresentação *',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final DrugPresentation p in _ref!.presentations)
                        DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            p.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (String? id) => _changed(
                      () => _pres = _ref!.presentations.firstWhere(
                        (DrugPresentation p) => p.id == id,
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  value: _limit,
                  onChanged: (bool? v) => _changed(() => _limit = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Limitar à dose máxima da referência'),
                  subtitle: const Text(
                    'Sem esta opção, dose acima do máximo impede a inserção.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              if (calc.isBlocked)
                _BlockedCard(blockers: calc.blockers)
              else ...<Widget>[
                _ResultCard(calc: calc),
                if (calc.alerts.isNotEmpty) ...<Widget>[
                  const DemoSectionTitle('Alertas'),
                  for (final DoseAlert a in calc.alerts)
                    _AlertTile(
                      alert: a,
                      acknowledged: _acknowledged.contains(a.kind),
                      onAcknowledge: (bool v) => setState(
                        () => v
                            ? _acknowledged.add(a.kind)
                            : _acknowledged.remove(a.kind),
                      ),
                    ),
                ],
                const DemoSectionTitle('Para a receita'),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: <Widget>[
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _route,
                        decoration: const InputDecoration(labelText: 'Via'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        key: const ValueKey<String>('duracao'),
                        controller: _duration,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Duração *',
                          hintText: 'ex.: 5 dias',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _quantity,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade',
                          hintText: 'ex.: 1 frasco',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                CheckboxListTile(
                  key: const ValueKey<String>('confirm-result'),
                  value: _confirmResult,
                  onChanged: calc.canInsert
                      ? (bool? v) => setState(() => _confirmResult = v ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Conferi o resultado: ${calc.perAdministrationLabel}, '
                    '${calc.reference!.intervalLabel}.',
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey<String>('confirm-presentation'),
                  value: _confirmPresentation,
                  onChanged: calc.canInsert
                      ? (bool? v) =>
                            setState(() => _confirmPresentation = v ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Conferi a apresentação: ${calc.presentation!.displayName}.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: blockers.isEmpty ? () => _insert(calc) : null,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(widget.insertLabel),
              ),
              if (blockers.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Para inserir: ${blockers.join(' ')}',
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientFacts extends StatelessWidget {
  const _PatientFacts({required this.patient, required this.now});

  final DemoPatient patient;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final TextStyle? s = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      spacing: AppSpacing.md,
      children: <Widget>[
        Text('Nascimento: ${formatDocDate(patient.birthDate)}', style: s),
        Text(
          patient.weighedAt == null
              ? 'Pesagem: não registrada'
              : 'Pesagem: ${formatDocDate(patient.weighedAt!)} '
                    '(há ${now.difference(patient.weighedAt!).inDays} dias)',
          style: s,
        ),
        Text(
          'Alergias: ${patient.allergies.isEmpty ? 'nenhuma registrada' : patient.allergies.join(', ')}',
          style: s,
        ),
      ],
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.reference});

  final DoseReference reference;

  @override
  Widget build(BuildContext context) {
    final DoseReference r = reference;
    final TextTheme t = Theme.of(context).textTheme;
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$k: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Referência cadastrada', style: t.titleSmall),
              ),
              ClinicalBadge(
                label: r.isUsable ? 'Validada (teste)' : 'Não validada',
                color: r.isUsable ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          row('Indicação', r.indication),
          row(
            'Dose de referência',
            '${formatDoseNumber(r.mgPerKg)} ${r.basis.label}, ${r.dosesPerDay}x/dia (${r.intervalLabel})',
          ),
          if (r.minMgPerKg != null)
            row(
              'Faixa configurada',
              '${formatDoseNumber(r.minMgPerKg!)} a ${formatDoseNumber(r.maxMgPerKg!)} ${r.basis.label}',
            ),
          row(
            'Dose máxima',
            <String>[
              if (r.maxSingleDoseMg != null)
                '${formatDoseNumber(r.maxSingleDoseMg!)} mg por dose',
              if (r.maxDailyDoseMg != null)
                '${formatDoseNumber(r.maxDailyDoseMg!)} mg/dia',
            ].join(' e ').ifEmpty('não configurada'),
          ),
          if (r.minAgeMonths != null)
            row('Idade mínima', formatAgeMonths(r.minAgeMonths!)),
          row('Fonte', r.source.ifEmpty('não informada')),
          row(
            'Revisão',
            r.reviewedAt == null
                ? 'sem revisão'
                : '${formatDocDate(r.reviewedAt!)} por ${r.reviewedBy ?? '-'}',
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.blockers});

  final List<String> blockers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.inkMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.block_rounded, color: AppColors.navy),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Cálculo bloqueado',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final String b in blockers) Text('• $b'),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.calc});

  final DoseCalculation calc;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DoseCalculation c = calc;
    final String main = c.mlPerDose != null
        ? '${formatDoseNumber(c.mlPerDose!, decimals: 1)} mL por dose'
        : '${formatDoseNumber(c.unitsPerDose!)} ${c.presentation!.unitName}(s) por dose';
    Widget fact(String k, String v) => SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(k, style: t.labelMedium),
          Text(v, style: t.titleSmall?.copyWith(color: AppColors.navy)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.brand, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resultado',
            style: t.labelLarge?.copyWith(color: AppColors.inkMuted),
          ),
          Text(
            main,
            key: const ValueKey<String>('dose-main'),
            style: t.headlineMedium?.copyWith(color: AppColors.navy),
          ),
          if (c.limitedToMax)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: ClinicalBadge(
                label: 'Limitado à dose máxima',
                color: AppColors.warning,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              fact(
                'Dose por administração',
                '${formatDoseNumber(c.mgPerDose!)} mg',
              ),
              fact('Dose diária', '${formatDoseNumber(c.mgPerDay!)} mg/dia'),
              fact('Intervalo', c.reference!.intervalLabel),
              fact(
                'Base',
                '${formatDoseNumber(c.mgPerKgUsed!)} ${c.reference!.basis.label}',
              ),
              fact('Peso usado', '${formatDoseNumber(c.weightKg!)} kg'),
              fact('Concentração', c.presentation!.concentrationLabel),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Text('Conta utilizada', style: t.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (int i = 0; i < c.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${i + 1}. ${c.steps[i]}',
                style: t.bodyMedium?.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.acknowledged,
    required this.onAcknowledge,
  });

  final DoseAlert alert;
  final bool acknowledged;
  final ValueChanged<bool> onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final bool critical = alert.isCritical;
    final Color c = critical ? AppColors.danger : AppColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                critical
                    ? Icons.dangerous_outlined
                    : Icons.warning_amber_rounded,
                color: c,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${critical ? 'Impede a inserção' : 'Atenção'}: ${alert.message}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (!critical)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: acknowledged,
                onChanged: (bool? v) => onAcknowledge(v ?? false),
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('Estou ciente e mantenho a conduta'),
              ),
            ),
        ],
      ),
    );
  }
}
