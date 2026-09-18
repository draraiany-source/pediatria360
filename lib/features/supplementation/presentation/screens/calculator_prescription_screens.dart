import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/supplement_calculator.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/supplement_prescription.dart';
import '../providers/supplement_providers.dart';
import '../widgets/supplement_widgets.dart';

class SupplementCalculatorScreen extends ConsumerStatefulWidget {
  const SupplementCalculatorScreen({this.micronutrientId, this.childId, super.key});

  final String? micronutrientId;
  final String? childId;

  @override
  ConsumerState<SupplementCalculatorScreen> createState() =>
      _SupplementCalculatorScreenState();
}

class _SupplementCalculatorScreenState
    extends ConsumerState<SupplementCalculatorScreen> {
  late String _microId;
  final TextEditingController _ageY = TextEditingController();
  final TextEditingController _ageM = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _sex = TextEditingController();
  final TextEditingController _ga = TextEditingController();
  final TextEditingController _dx = TextEditingController();
  final TextEditingController _lab = TextEditingController();
  final TextEditingController _presentation = TextEditingController();
  bool _preterm = false;
  SupplementGoal _goal = SupplementGoal.prophylaxis;
  String _examId = '';
  SupplementCalculatorSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    _microId = widget.micronutrientId ?? kMicronutrientCatalog.first.id;
  }

  @override
  void dispose() {
    _ageY.dispose();
    _ageM.dispose();
    _weight.dispose();
    _sex.dispose();
    _ga.dispose();
    _dx.dispose();
    _lab.dispose();
    _presentation.dispose();
    super.dispose();
  }

  void _calculate() {
    final SupplementCalculatorSuggestion s =
        ref.read(supplementCalculatorProvider).suggest(
              SupplementCalculatorInput(
                micronutrientId: _microId,
                ageYears: int.tryParse(_ageY.text.trim()),
                ageMonths: int.tryParse(_ageM.text.trim()),
                weightKg: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
                sex: _sex.text.trim(),
                preterm: _preterm,
                gestationalAgeWeeks: int.tryParse(_ga.text.trim()),
                diagnosis: _dx.text.trim(),
                goal: _goal,
                relatedExamId: _examId,
                labResultText: _lab.text.trim(),
                presentation: _presentation.text.trim(),
              ),
            );
    setState(() => _suggestion = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Calculadora de suplementacao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _microId,
            items: kMicronutrientCatalog
                .map(
                  (MicronutrientProfile m) => DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(m.name),
                  ),
                )
                .toList(),
            onChanged: (String? v) {
              if (v != null) setState(() => _microId = v);
            },
            decoration: const InputDecoration(labelText: 'Micronutriente'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _ageY,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Idade (anos)'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _ageM,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Idade (meses)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Peso (kg)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _sex,
            decoration: const InputDecoration(labelText: 'Sexo'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prematuridade'),
            value: _preterm,
            onChanged: (bool v) => setState(() => _preterm = v),
          ),
          if (_preterm)
            TextField(
              controller: _ga,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Idade gestacional ao nascimento (semanas)',
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _dx,
            decoration: const InputDecoration(labelText: 'Diagnostico / contexto'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<SupplementGoal>(
            value: _goal,
            items: SupplementGoal.values
                .map(
                  (SupplementGoal g) => DropdownMenuItem<SupplementGoal>(
                    value: g,
                    child: Text(g.label),
                  ),
                )
                .toList(),
            onChanged: (SupplementGoal? v) {
              if (v != null) setState(() => _goal = v);
            },
            decoration: const InputDecoration(labelText: 'Objetivo'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _examId.isEmpty ? null : _examId,
            items: kLabExamCatalog
                .map(
                  (LabExamDefinition e) => DropdownMenuItem<String>(
                    value: e.id,
                    child: Text(e.name),
                  ),
                )
                .toList(),
            onChanged: (String? v) => setState(() => _examId = v ?? ''),
            decoration: const InputDecoration(labelText: 'Exame relacionado'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _lab,
            decoration: const InputDecoration(labelText: 'Resultado laboratorial'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _presentation,
            decoration: const InputDecoration(labelText: 'Apresentacao disponivel'),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Gerar sugestao para conferencia',
            onPressed: _calculate,
          ),
          if (_suggestion != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            const BrandSectionHeader(title: 'Resultado (nao prescrito)'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_suggestion!.doseLine),
                  Text(_suggestion!.perKgLine),
                  Text(_suggestion!.dailyLine),
                  Text(_suggestion!.frequencyLine),
                  Text(_suggestion!.durationLine),
                  Text(_suggestion!.maxLine),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _suggestion!.summary,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ..._suggestion!.safetyAlerts.map(
                    (String a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(child: Text(a)),
                        ],
                      ),
                    ),
                  ),
                  if (_suggestion!.requiresLabFollowUp)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Controle laboratorial: revisar necessidade clinicamente.'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () {
                final String q =
                    'micronutrientId=$_microId&suggestion=1';
                context.push('${Routes.supplementPrescriptionPath}?$q');
              },
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Revisar e gerar prescricao'),
            ),
          ],
        ],
      ),
    );
  }
}

class SupplementPrescriptionScreen extends ConsumerStatefulWidget {
  const SupplementPrescriptionScreen({
    this.micronutrientId,
    this.childId,
    this.prescriptionId,
    super.key,
  });

  final String? micronutrientId;
  final String? childId;
  final String? prescriptionId;

  @override
  ConsumerState<SupplementPrescriptionScreen> createState() =>
      _SupplementPrescriptionScreenState();
}

class _SupplementPrescriptionScreenState
    extends ConsumerState<SupplementPrescriptionScreen> {
  late final TextEditingController _child;
  late final TextEditingController _product;
  late final TextEditingController _active;
  late final TextEditingController _presentation;
  late final TextEditingController _concentration;
  late final TextEditingController _dose;
  late final TextEditingController _unit;
  late final TextEditingController _frequency;
  late final TextEditingController _route;
  late final TextEditingController _duration;
  late final TextEditingController _qty;
  late final TextEditingController _instructions;
  String _microId = '';
  bool _saving = false;
  SupplementPrescription? _saved;

  @override
  void initState() {
    super.initState();
    _microId = widget.micronutrientId ?? '';
    final MicronutrientProfile? m = micronutrientById(_microId);
    _child = TextEditingController(text: widget.childId ?? '');
    _product = TextEditingController(text: m?.name ?? '');
    _active = TextEditingController(text: m?.name ?? '');
    _presentation = TextEditingController();
    _concentration = TextEditingController();
    _dose = TextEditingController();
    _unit = TextEditingController();
    _frequency = TextEditingController();
    _route = TextEditingController(text: 'oral');
    _duration = TextEditingController();
    _qty = TextEditingController();
    _instructions = TextEditingController(
      text: 'Conferir dose e duracao antes de dispensar. $kSupplementContentPending',
    );
  }

  @override
  void dispose() {
    _child.dispose();
    _product.dispose();
    _active.dispose();
    _presentation.dispose();
    _concentration.dispose();
    _dose.dispose();
    _unit.dispose();
    _frequency.dispose();
    _route.dispose();
    _duration.dispose();
    _qty.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final String childId = _child.text.trim();
    if (childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o paciente.')),
      );
      return;
    }
    setState(() => _saving = true);
    final Result<SupplementPrescription> res =
        await ref.read(supplementRepositoryProvider).savePrescription(
              SupplementPrescription(
                id: _saved?.id ?? '',
                childId: childId,
                professionalId: uid,
                createdAt: _saved?.createdAt ?? DateTime.now(),
                micronutrientId: _microId,
                productName: _product.text.trim(),
                activeIngredient: _active.text.trim(),
                presentation: _presentation.text.trim(),
                concentration: _concentration.text.trim(),
                doseText: _dose.text.trim(),
                unit: _unit.text.trim(),
                frequency: _frequency.text.trim(),
                route: _route.text.trim(),
                duration: _duration.text.trim(),
                quantity: _qty.text.trim(),
                instructions: _instructions.text.trim(),
                status: SupplementRxStatus.draft,
                calculatorSuggestion: kSupplementContentPending,
              ),
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = res.valueOrNull ?? _saved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.isSuccess ? 'Rascunho salvo.' : 'Falha ao salvar.'),
      ),
    );
  }

  Future<void> _confirm() async {
    final SupplementPrescription? draft = _saved;
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (draft == null || uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salve o rascunho antes de confirmar.')),
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Confirmar prescricao'),
        content: const Text(
          'Confirma que revisou dose, apresentacao e orientacoes? '
          'A responsabilidade clinica e do profissional assistente.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    final Result<SupplementPrescription> res =
        await ref.read(supplementRepositoryProvider).confirmPrescription(
              rx: draft,
              confirmedBy: uid,
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = res.valueOrNull ?? _saved;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.isSuccess ? 'Prescricao confirmada.' : 'Falha na confirmacao.',
        ),
      ),
    );
    if (res.isSuccess && mounted) {
      await context.push(Routes.supplementPrescriptionView(res.valueOrNull!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Gerador de prescricao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _child, decoration: const InputDecoration(labelText: 'ID do paciente')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _product, decoration: const InputDecoration(labelText: 'Nome do suplemento')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _active, decoration: const InputDecoration(labelText: 'Principio ativo')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _presentation, decoration: const InputDecoration(labelText: 'Apresentacao')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _concentration, decoration: const InputDecoration(labelText: 'Concentracao')),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: TextField(controller: _dose, decoration: const InputDecoration(labelText: 'Dose'))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unidade'))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _frequency, decoration: const InputDecoration(labelText: 'Frequencia')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _route, decoration: const InputDecoration(labelText: 'Via')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _duration, decoration: const InputDecoration(labelText: 'Duracao')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _qty, decoration: const InputDecoration(labelText: 'Quantidade')),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _instructions,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Orientacoes'),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Salvar rascunho',
            isLoading: _saving,
            onPressed: _saving ? null : _saveDraft,
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _saving ? null : _confirm,
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Confirmar e finalizar'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'PDF / impressao / compartilhar: disponiveis apos confirmacao na tela de visualizacao.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class SupplementPrescriptionViewScreen extends ConsumerWidget {
  const SupplementPrescriptionViewScreen({required this.prescriptionId, super.key});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Prescricao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: 'Imprimir / PDF (estrutura)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Exportacao PDF preparada — integrar gerador no proximo ciclo.'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Compartilhar',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Compartilhamento preparado para integracao.')),
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ID: $prescriptionId', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Visualizacao da prescricao confirmada. Duplicar/renovar: use o gerador com os mesmos campos.',
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: () => context.push(Routes.supplementPrescriptionPath),
                  child: const Text('Nova / duplicar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
