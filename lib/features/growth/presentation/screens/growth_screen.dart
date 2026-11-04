import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/growth_record.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../domain/who_reference.dart';
import '../widgets/growth_chart.dart';

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({required this.childId, super.key});

  final String childId;

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  GrowthIndicator _indicator = GrowthIndicator.weightForAge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Child? child = ref.watch(childProvider(widget.childId)).valueOrNull;
    final AsyncValue<List<GrowthRecord>> records =
        ref.watch(growthProvider(widget.childId));
    final AsyncValue<WhoReference> who = ref.watch(whoReferenceProvider);
    final List<GrowthAssessment> assessments =
        ref.watch(latestAssessmentsProvider(widget.childId));

    if (child == null) {
      return const Scaffold(body: LoadingState());
    }

    // Perímetro cefálico some do seletor depois dos 3 anos: deixa de compor o
    // acompanhamento de rotina e um seletor inútil só atrapalha.
    final List<GrowthIndicator> available = GrowthIndicator.values
        .where((GrowthIndicator i) => child.ageInMonths <= i.maxAgeMonths)
        .toList(growable: false);

    if (!available.contains(_indicator) && available.isNotEmpty) {
      _indicator = available.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Crescimento · ${child.firstName}'),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, child),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova medição'),
      ),
      body: Column(
        children: <Widget>[
          if (who.valueOrNull?.warning != null) DataWarningBanner(text: who.valueOrNull!.warning!),
          Expanded(
            child: records.when(
        loading: () => const SkeletonList(itemCount: 4, itemHeight: 64),
        error: (Object e, StackTrace s) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Não foi possível carregar',
          message: 'Tente novamente em instantes.',
          actionLabel: 'Recarregar',
          onAction: () => ref.invalidate(growthProvider(widget.childId)),
        ),
        data: (List<GrowthRecord> list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.show_chart_rounded,
              title: 'Sem medições ainda',
              message: 'Registre peso e altura para ver a curva de '
                  '${child.firstName} comparada à referência da OMS.',
              actionLabel: 'Registrar medição',
              onAction: () => _openForm(context, child),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            children: <Widget>[
              ContentBounds(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (assessments.isNotEmpty) ...<Widget>[
                      _AssessmentRow(assessments: assessments),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: <Widget>[
                          for (final GrowthIndicator i in available)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(i.shortLabel),
                                selected: _indicator == i,
                                onSelected: (_) =>
                                    setState(() => _indicator = i),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SurfaceCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: who.when(
                          loading: () => const AspectRatio(
                            aspectRatio: 1.35,
                            child: LoadingState(),
                          ),
                          error: (Object e, StackTrace s) => const AspectRatio(
                            aspectRatio: 1.35,
                            child: EmptyState(
                              icon: Icons.insert_chart_outlined,
                              title: 'Referência indisponível',
                              message: 'Não foi possível carregar a tabela '
                                  'da OMS.',
                            ),
                          ),
                          data: (WhoReference reference) => Column(
                            children: <Widget>[
                              GrowthChart(
                                indicator: _indicator,
                                child: child,
                                records: list,
                                reference: reference,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const GrowthChartLegend(),
                            ],
                          ),
                        ),
                    ),
                    const SectionHeader(
                      title: 'Histórico',
                      eyebrow: 'Medições',
                    ),
                  ],
                ),
              ),
              for (final GrowthRecord record in list.reversed)
                ContentBounds(
                  child: _RecordTile(
                    record: record,
                    child: child,
                    onEdit: () => _openForm(context, child, record: record),
                    onDelete: () => _confirmDelete(context, record),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              ContentBounds(
                child: Text(
                  'A avaliação segue os padrões de crescimento da OMS. Um '
                  'ponto fora da faixa não é diagnóstico: o que o pediatra '
                  'observa é a trajetória ao longo do tempo.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    Child child, {
    GrowthRecord? record,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: GrowthFormSheet(childId: child.id, record: record),
        ),
      );

  Future<void> _confirmDelete(BuildContext context, GrowthRecord record) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Excluir medição?'),
        content: Text(
          'A medição de ${Formatters.date(record.measuredAt)} será removida.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (ok ?? false) {
      await ref.read(childrenControllerProvider.notifier).deleteGrowth(
            childId: widget.childId,
            recordId: record.id,
          );
    }
  }
}

/// Faixa horizontal com o resultado de cada indicador.
class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessments});

  final List<GrowthAssessment> assessments;

  Color _colorFor(GrowthClassification c) => switch (c) {
        GrowthClassification.severelyLow ||
        GrowthClassification.severelyHigh =>
          AppColors.danger,
        GrowthClassification.low || GrowthClassification.high =>
          AppColors.warning,
        GrowthClassification.attention => AppColors.honey,
        GrowthClassification.adequate => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final GrowthAssessment a in assessments)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: SizedBox(
                width: 172,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          a.indicator.shortLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        DataValue(
                          value: Formatters.decimal(a.value),
                          unit: a.indicator.unit,
                          size: 20,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTag(
                          label: a.classification.labelFor(a.indicator),
                          color: _colorFor(a.classification),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Percentil ${a.percentile.round()}  ·  '
                          'z ${a.zScore >= 0 ? '+' : ''}'
                          '${a.zScore.toStringAsFixed(1)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final GrowthRecord record;
  final Child child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<String> parts = <String>[
      if (record.weightKg != null)
        '${Formatters.decimal(record.weightKg!, digits: 2)} kg',
      if (record.heightCm != null)
        '${Formatters.decimal(record.heightCm!)} cm',
      if (record.headCircumferenceCm != null)
        'PC ${Formatters.decimal(record.headCircumferenceCm!)} cm',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          title: Row(
            children: <Widget>[
              Text(
                Formatters.date(record.measuredAt),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Formatters.pediatricAge(child.birthDate, at: record.measuredAt),
                style: theme.textTheme.bodySmall,
              ),
              if (record.pendingSync) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              parts.isEmpty ? 'Sem valores' : parts.join('   ·   '),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (String value) =>
                value == 'editar' ? onEdit() : onDelete(),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'editar',
                child: Text('Editar'),
              ),
              const PopupMenuItem<String>(
                value: 'excluir',
                child: Text('Excluir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulário de medição, aberto como bottom sheet.
class GrowthFormSheet extends ConsumerStatefulWidget {
  const GrowthFormSheet({required this.childId, this.record, super.key});

  final String childId;
  final GrowthRecord? record;

  @override
  ConsumerState<GrowthFormSheet> createState() => _GrowthFormSheetState();
}

class _GrowthFormSheetState extends ConsumerState<GrowthFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _height;
  late final TextEditingController _head;
  late final TextEditingController _note;
  late DateTime _measuredAt;

  @override
  void initState() {
    super.initState();
    final GrowthRecord? r = widget.record;
    _weight = TextEditingController(
      text: r?.weightKg?.toString().replaceAll('.', ',') ?? '',
    );
    _height = TextEditingController(
      text: r?.heightCm?.toString().replaceAll('.', ',') ?? '',
    );
    _head = TextEditingController(
      text: r?.headCircumferenceCm?.toString().replaceAll('.', ',') ?? '',
    );
    _note = TextEditingController(text: r?.note ?? '');
    _measuredAt = r?.measuredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    _head.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime(DateTime.now().year - 25),
      lastDate: DateTime.now(),
      helpText: 'Data da medição',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _measuredAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final double? weight = Parsers.decimal(_weight.text);
    final double? height = Parsers.decimal(_height.text);
    final double? head = Parsers.decimal(_head.text);

    if (weight == null && height == null && head == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha pelo menos uma medida.')),
      );
      return;
    }

    final GrowthRecord record = GrowthRecord(
      id: widget.record?.id ?? '',
      childId: widget.childId,
      measuredAt: _measuredAt,
      updatedAt: DateTime.now(),
      weightKg: weight,
      heightCm: height,
      headCircumferenceCm: head,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    final GrowthRecord? saved = await ref
        .read(childrenControllerProvider.notifier)
        .saveGrowth(record);

    if (!mounted) return;
    if (saved != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildActionState action = ref.watch(childrenControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.record == null ? 'Nova medição' : 'Editar medição',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                onTap: _pickDate,
                borderRadius: AppRadius.mdAll,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data da medição',
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  child: Text(
                    Formatters.date(_measuredAt),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Peso',
                controller: _weight,
                hint: '9,6',
                suffix: const Padding(
                  padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                  child: Text('kg'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: Masks.decimal,
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? null : Validators.weightKg(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Altura ou comprimento',
                controller: _height,
                hint: '75,7',
                suffix: const Padding(
                  padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                  child: Text('cm'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: Masks.decimal,
                validator: (String? v) =>
                    (v == null || v.isEmpty) ? null : Validators.heightCm(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Perímetro cefálico',
                controller: _head,
                hint: '46,1',
                helper: 'Acompanhado até os 3 anos.',
                suffix: const Padding(
                  padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                  child: Text('cm'),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: Masks.decimal,
                validator: Validators.headCircumferenceCm,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Observação',
                controller: _note,
                hint: 'Consulta de rotina',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Salvar',
                isLoading: action.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
