import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
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


  // Comparar avaliacoes (ids de registros reais).
  String? _compareFromId;
  String? _compareToId;

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

    final List<GrowthIndicator> available = GrowthIndicator.values
        .where((GrowthIndicator i) => child.ageInMonths <= i.maxAgeMonths)
        .toList(growable: false);

    if (!available.contains(_indicator) && available.isNotEmpty) {
      _indicator = available.first;
    }

    final GrowthAssessment? currentAssessment = assessments
        .cast<GrowthAssessment?>()
        .firstWhere(
          (GrowthAssessment? a) => a?.indicator == _indicator,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Crescimento — Registros e Evolucao'),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: Column(
        children: <Widget>[
          if (who.valueOrNull?.warning != null)
            DataWarningBanner(text: who.valueOrNull!.warning!),
          Expanded(
            child: records.when(
              loading: () => const SkeletonList(itemCount: 4, itemHeight: 64),
              error: (Object e, StackTrace s) => EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Nao foi possivel carregar',
                message: 'Tente novamente em instantes.',
                actionLabel: 'Recarregar',
                onAction: () => ref.invalidate(growthProvider(widget.childId)),
              ),
              data: (List<GrowthRecord> list) {
                return LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final bool wide = c.maxWidth >= 980;
                    final Widget header = _PatientHeader(
                      child: child,
                      onSwitch: () => context.push(
                        Routes.patientModule('crescimento'),
                      ),
                    );
                    final Widget table = _MeasuresPanel(
                      child: child,
                      records: list,
                      indicator: _indicator,
                      available: available,
                      onSelectIndicator: (GrowthIndicator i) =>
                          setState(() => _indicator = i),
                      onAdd: () => _openForm(context, child),
                      onEdit: (GrowthRecord r) =>
                          _openForm(context, child, record: r),
                      onDelete: (GrowthRecord r) =>
                          _confirmDelete(context, r),
                    );
                    final Widget chart = _ChartPanel(
                      child: child,
                      records: list,
                      indicator: _indicator,
                      available: available,
                      who: who,
                      assessment: currentAssessment,
                      onSelectIndicator: (GrowthIndicator i) =>
                          setState(() => _indicator = i),
                      compareFromId: _compareFromId,
                      compareToId: _compareToId,
                      onCompareFrom: (String? id) =>
                          setState(() => _compareFromId = id),
                      onCompareTo: (String? id) =>
                          setState(() => _compareToId = id),
                    );
                    final Widget footer = _GrowthFooter(
                      onImport: () => _toast(
                        'Importacao de medidas chega quando houver '
                        'integracao com a fonte clinica.',
                      ),
                      onHistory: () => _toast(
                        'O historico de alteracoes usa as medicoes '
                        'listadas na tabela.',
                      ),
                      onExport: () => _toast(
                        'Exportacao da tabela ainda nao esta disponivel '
                        'nesta versao.',
                      ),
                      onPrint: () => _toast(
                        'Use a captura do grafico do sistema ou aguarde '
                        'a impressao dedicada.',
                      ),
                    );

                    if (wide) {
                      return ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: <Widget>[
                          Text(
                            'Registre as medidas por data e acompanhe a evolucao.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          header,
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 5, child: table),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(flex: 4, child: chart),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          footer,
                        ],
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        header,
                        const SizedBox(height: AppSpacing.md),
                        table,
                        const SizedBox(height: AppSpacing.md),
                        chart,
                        const SizedBox(height: AppSpacing.lg),
                        footer,
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

/// Formulário de medição, aberto como bottom sheet.

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.child, required this.onSwitch});
  final Child child;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.xlAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: AppColors.brandIndicator,
              child: Text(
                child.initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    Formatters.pediatricAge(child.birthDate),
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onSwitch,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Trocar paciente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasuresPanel extends StatelessWidget {
  const _MeasuresPanel({
    required this.child,
    required this.records,
    required this.indicator,
    required this.available,
    required this.onSelectIndicator,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final Child child;
  final List<GrowthRecord> records;
  final GrowthIndicator indicator;
  final List<GrowthIndicator> available;
  final ValueChanged<GrowthIndicator> onSelectIndicator;
  final VoidCallback onAdd;
  final ValueChanged<GrowthRecord> onEdit;
  final ValueChanged<GrowthRecord> onDelete;

  String _tabLabel(GrowthIndicator i) => switch (i) {
        GrowthIndicator.weightForAge => 'Peso',
        GrowthIndicator.heightForAge => 'Estatura',
        GrowthIndicator.bmiForAge => 'IMC',
        GrowthIndicator.headForAge => 'Perimetro cefalico',
      };

  @override
  Widget build(BuildContext context) {
    final List<GrowthRecord> sorted = List<GrowthRecord>.from(records)
      ..sort((GrowthRecord a, GrowthRecord b) =>
          b.measuredAt.compareTo(a.measuredAt));

    return Material(
      color: Colors.white,
      borderRadius: AppRadius.xlAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final GrowthIndicator i in available)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_tabLabel(i)),
                        selected: indicator == i,
                        onSelected: (_) => onSelectIndicator(i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Tabela de medidas',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Nenhuma medicao salva. Adicione uma avaliacao com dados reais.',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 52,
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Data')),
                    DataColumn(label: Text('Idade')),
                    DataColumn(label: Text('Peso (kg)')),
                    DataColumn(label: Text('Estatura (cm)')),
                    DataColumn(label: Text('PC (cm)')),
                    DataColumn(label: Text('IMC')),
                    DataColumn(label: Text('Acoes')),
                  ],
                  rows: <DataRow>[
                    for (final GrowthRecord r in sorted)
                      DataRow(
                        cells: <DataCell>[
                          DataCell(Text(Formatters.date(r.measuredAt))),
                          DataCell(Text(
                            Formatters.pediatricAge(
                              child.birthDate,
                              at: r.measuredAt,
                            ),
                          )),
                          DataCell(Text(
                            r.weightKg == null
                                ? '—'
                                : Formatters.decimal(r.weightKg!, digits: 2),
                          )),
                          DataCell(Text(
                            r.heightCm == null
                                ? '—'
                                : Formatters.decimal(r.heightCm!),
                          )),
                          DataCell(Text(
                            r.headCircumferenceCm == null
                                ? '—'
                                : Formatters.decimal(r.headCircumferenceCm!),
                          )),
                          DataCell(Text(
                            r.bmi == null
                                ? '—'
                                : Formatters.decimal(r.bmi!, digits: 1),
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Editar',
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => onEdit(r),
                                ),
                                IconButton(
                                  tooltip: 'Excluir',
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () => onDelete(r),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Idade e IMC calculados apos preencher os dados necessarios.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar avaliacao'),
                ),
                OutlinedButton(
                  onPressed: onAdd,
                  child: const Text('Salvar medidas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.child,
    required this.records,
    required this.indicator,
    required this.available,
    required this.who,
    required this.assessment,
    required this.onSelectIndicator,
    required this.compareFromId,
    required this.compareToId,
    required this.onCompareFrom,
    required this.onCompareTo,
  });

  final Child child;
  final List<GrowthRecord> records;
  final GrowthIndicator indicator;
  final List<GrowthIndicator> available;
  final AsyncValue<WhoReference> who;
  final GrowthAssessment? assessment;
  final ValueChanged<GrowthIndicator> onSelectIndicator;
  final String? compareFromId;
  final String? compareToId;
  final ValueChanged<String?> onCompareFrom;
  final ValueChanged<String?> onCompareTo;

  @override
  Widget build(BuildContext context) {
    final List<GrowthRecord> sorted = List<GrowthRecord>.from(records)
      ..sort((GrowthRecord a, GrowthRecord b) =>
          a.measuredAt.compareTo(b.measuredAt));

    return Column(
      children: <Widget>[
        Material(
          color: Colors.white,
          borderRadius: AppRadius.xlAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Evolucao no grafico',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<GrowthIndicator>(
                        initialValue: available.contains(indicator)
                            ? indicator
                            : (available.isEmpty ? null : available.first),
                        decoration: const InputDecoration(
                          labelText: 'Indicador',
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<GrowthIndicator>>[
                          for (final GrowthIndicator i in available)
                            DropdownMenuItem<GrowthIndicator>(
                              value: i,
                              child: Text(i.shortLabel),
                            ),
                        ],
                        onChanged: (GrowthIndicator? v) {
                          if (v != null) onSelectIndicator(v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Referencia',
                          isDense: true,
                        ),
                        child: Text('Curvas OMS'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                who.when(
                  loading: () => const AspectRatio(
                    aspectRatio: 1.35,
                    child: LoadingState(),
                  ),
                  error: (Object e, StackTrace s) => const AspectRatio(
                    aspectRatio: 1.35,
                    child: EmptyState(
                      icon: Icons.insert_chart_outlined,
                      title: 'Referencia indisponivel',
                      message: 'Nao foi possivel carregar a tabela da OMS.',
                    ),
                  ),
                  data: (WhoReference reference) {
                    if (records.isEmpty) {
                      return const AspectRatio(
                        aspectRatio: 1.35,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'As medidas salvas aparecerao aqui. '
                              'Selecione a referencia oficial (OMS) para '
                              'visualizar a curva.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.inkMuted),
                            ),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: <Widget>[
                        GrowthChart(
                          indicator: indicator,
                          child: child,
                          records: records,
                          reference: reference,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const GrowthChartLegend(),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        assessment == null
                            ? 'Percentil —'
                            : 'Percentil ${assessment!.percentile.round()}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        assessment == null
                            ? 'Escore Z —'
                            : 'Escore Z ${assessment!.zScore >= 0 ? '+' : ''}'
                                '${assessment!.zScore.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Material(
          color: Colors.white,
          borderRadius: AppRadius.xlAll,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Comparar avaliacoes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: compareFromId,
                  decoration: const InputDecoration(
                    labelText: 'Avaliacao inicial',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final GrowthRecord r in sorted)
                      DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(Formatters.date(r.measuredAt)),
                      ),
                  ],
                  onChanged: sorted.isEmpty ? null : onCompareFrom,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: compareToId,
                  decoration: const InputDecoration(
                    labelText: 'Avaliacao final',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final GrowthRecord r in sorted)
                      DropdownMenuItem<String>(
                        value: r.id,
                        child: Text(Formatters.date(r.measuredAt)),
                      ),
                  ],
                  onChanged: sorted.isEmpty ? null : onCompareTo,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () {
                    final GrowthRecord? a = sorted
                        .cast<GrowthRecord?>()
                        .firstWhere(
                          (GrowthRecord? r) => r?.id == compareFromId,
                          orElse: () => null,
                        );
                    final GrowthRecord? b = sorted
                        .cast<GrowthRecord?>()
                        .firstWhere(
                          (GrowthRecord? r) => r?.id == compareToId,
                          orElse: () => null,
                        );
                    if (a == null || b == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione duas avaliacoes salvas.'),
                        ),
                      );
                      return;
                    }
                    final StringBuffer buf = StringBuffer()
                      ..writeln(
                        '${Formatters.date(a.measuredAt)} → '
                        '${Formatters.date(b.measuredAt)}',
                      );
                    if (a.weightKg != null && b.weightKg != null) {
                      buf.writeln(
                        'Peso: ${Formatters.decimal(a.weightKg!, digits: 2)} → '
                        '${Formatters.decimal(b.weightKg!, digits: 2)} kg '
                        '(Δ ${(b.weightKg! - a.weightKg!).toStringAsFixed(2)})',
                      );
                    }
                    if (a.heightCm != null && b.heightCm != null) {
                      buf.writeln(
                        'Estatura: ${Formatters.decimal(a.heightCm!)} → '
                        '${Formatters.decimal(b.heightCm!)} cm '
                        '(Δ ${(b.heightCm! - a.heightCm!).toStringAsFixed(1)})',
                      );
                    }
                    if (a.bmi != null && b.bmi != null) {
                      buf.writeln(
                        'IMC: ${Formatters.decimal(a.bmi!, digits: 1)} → '
                        '${Formatters.decimal(b.bmi!, digits: 1)}',
                      );
                    }
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        title: const Text('Comparacao'),
                        content: Text(buf.toString()),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Fechar'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Comparar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GrowthFooter extends StatelessWidget {
  const _GrowthFooter({
    required this.onImport,
    required this.onHistory,
    required this.onExport,
    required this.onPrint,
  });

  final VoidCallback onImport;
  final VoidCallback onHistory;
  final VoidCallback onExport;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: AppColors.softLilac,
          borderRadius: AppRadius.xlAll,
          child: const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                Text('1. Registrar medidas',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('2. Validar e salvar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('3. Visualizar evolucao',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Importar medidas'),
            ),
            OutlinedButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Historico de alteracoes'),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar tabela'),
            ),
            OutlinedButton.icon(
              onPressed: onPrint,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir grafico'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'A avaliacao segue os padroes de crescimento da OMS. Um ponto '
          'fora da faixa nao e diagnostico: o pediatra observa a trajetoria.',
          style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}


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
