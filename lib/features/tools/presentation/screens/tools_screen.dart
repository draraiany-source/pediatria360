import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../domain/calculators.dart';

/// Ferramentas de cálculo.
///
/// Todas usam fórmulas publicadas e estáveis. Não há tabela de doses de
/// medicamentos aqui — ver a documentação em `calculators.dart` para o porquê.
class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _height = TextEditingController();

  Child? _child;
  double _dehydration = 5;

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    super.dispose();
  }

  double get _weightKg => Parsers.decimal(_weight.text) ?? 0;
  double get _heightCm => Parsers.decimal(_height.text) ?? 0;

  /// Preenche a partir da última medição registrada — evita redigitar o peso
  /// que o app já conhece.
  void _fillFromChild(Child child) {
    final List<dynamic> records =
        ref.read(growthProvider(child.id)).valueOrNull ?? const <dynamic>[];

    setState(() {
      _child = child;
      for (final dynamic record in records.reversed) {
        if (_weight.text.isEmpty && record.weightKg != null) {
          _weight.text =
              (record.weightKg as double).toString().replaceAll('.', ',');
        }
        if (_height.text.isEmpty && record.heightCm != null) {
          _height.text =
              (record.heightCm as double).toString().replaceAll('.', ',');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Child> children =
        ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final bool isProfessional =
        ref.watch(currentUserProvider)?.role.isProfessional ?? false;

    final bool hasWeight = _weightKg > 0;
    final bool hasBoth = hasWeight && _heightCm > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Ferramentas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          ContentBounds(
            maxWidth: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (children.isNotEmpty) ...<Widget>[
                  Text('Preencher a partir de', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        for (final Child child in children)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(child.firstName),
                              selected: _child?.id == child.id,
                              onSelected: (_) => _fillFromChild(child),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Peso',
                        controller: _weight,
                        hint: '12,5',
                        suffix: const Padding(
                          padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                          child: Text('kg'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: Masks.decimal,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        label: 'Altura',
                        controller: _height,
                        hint: '88',
                        suffix: const Padding(
                          padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                          child: Text('cm'),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: Masks.decimal,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (!hasWeight) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            Icons.calculate_outlined,
                            size: 36,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Informe o peso para calcular.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  const SectionHeader(
                    title: 'Hidratação',
                    eyebrow: 'Holliday-Segar',
                  ),
                  _FluidsCard(weightKg: _weightKg),
                  const SizedBox(height: AppSpacing.md),
                  _DehydrationCard(
                    weightKg: _weightKg,
                    percentage: _dehydration,
                    onChanged: (double v) =>
                        setState(() => _dehydration = v),
                  ),
                  if (hasBoth) ...<Widget>[
                    const SectionHeader(
                      title: 'Antropometria',
                      eyebrow: 'Cálculos',
                    ),
                    _ResultCard(
                      title: 'Superfície corporal',
                      subtitle: 'Fórmula de Mosteller',
                      value: Formatters.decimal(
                        PediatricCalculators.bodySurfaceArea(
                          weightKg: _weightKg,
                          heightCm: _heightCm,
                        ),
                        digits: 2,
                      ),
                      unit: 'm²',
                      color: AppColors.moduleGrowth,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ResultCard(
                      title: 'IMC',
                      subtitle: 'Interprete pela curva de IMC para idade',
                      value: Formatters.decimal(
                        PediatricCalculators.bmi(
                          weightKg: _weightKg,
                          heightCm: _heightCm,
                        ),
                        digits: 1,
                      ),
                      unit: 'kg/m²',
                      color: AppColors.moduleNutrition,
                    ),
                  ],
                  if (_child != null) ...<Widget>[
                    const SectionHeader(
                      title: 'Sinais vitais esperados',
                      eyebrow: 'Referência por idade',
                    ),
                    _VitalsCard(
                      ranges: PediatricCalculators.vitalRanges(
                        _child!.ageInMonths,
                      ),
                    ),
                  ],
                  if (isProfessional) ...<Widget>[
                    const SectionHeader(
                      title: 'Peso estimado',
                      eyebrow: 'Emergência',
                    ),
                    _EstimatedWeightCard(),
                    const SectionHeader(
                      title: 'Neonatologia',
                      eyebrow: 'Profissional',
                    ),
                    const _ApgarCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _GlucoseInfusionCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _UrineOutputCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _OsmolarityCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _GestationalAgeCard(),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Os cálculos usam fórmulas de referência e não substituem '
                    'avaliação clínica. Confira sempre o peso aferido antes de '
                    'qualquer conduta.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FluidsCard extends StatelessWidget {
  const _FluidsCard({required this.weightKg});

  final double weightKg;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final FluidRequirement fluids =
        PediatricCalculators.maintenanceFluids(weightKg);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Manutenção hídrica',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Por dia', style: theme.textTheme.bodySmall),
                      DataValue(
                        value: fluids.perDayMl.round().toString(),
                        unit: 'mL',
                        color: AppColors.vital,
                      ),
                      Text(
                        'regra 100-50-20',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Por hora', style: theme.textTheme.bodySmall),
                      DataValue(
                        value: Formatters.decimal(fluids.perHourMl421),
                        unit: 'mL/h',
                        color: AppColors.vital,
                      ),
                      Text('regra 4-2-1', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // As duas regras não são exatamente equivalentes. Esconder isso
            // faria o app parecer errado para quem confere a conta.
            Text(
              'A regra 4-2-1 é o arredondamento da diária. Dividir '
              '${fluids.perDayMl.round()} mL por 24 daria '
              '${Formatters.decimal(fluids.perHourMl)} mL/h — a pequena '
              'diferença é esperada.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DehydrationCard extends StatelessWidget {
  const _DehydrationCard({
    required this.weightKg,
    required this.percentage,
    required this.onChanged,
  });

  final double weightKg;
  final double percentage;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double deficit = PediatricCalculators.dehydrationDeficitMl(
      weightKg: weightKg,
      percentage: percentage,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Déficit por desidratação',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                DataValue(
                  value: deficit.round().toString(),
                  unit: 'mL',
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Slider(
                    value: percentage,
                    min: 1,
                    max: 15,
                    divisions: 14,
                    label: '${percentage.round()}%',
                    onChanged: onChanged,
                  ),
                ),
                Text(
                  '${percentage.round()}%',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            Text(
              'O percentual é estimativa clínica (turgor, mucosas, perfusão), '
              'não medida — por isso você informa, o app não deduz.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            DataValue(value: value, unit: unit, color: color),
          ],
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.ranges});

  final VitalRanges ranges;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppTag(label: ranges.label),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Freq. cardíaca',
                        style: theme.textTheme.bodySmall,
                      ),
                      DataValue(
                        value: '${ranges.heartRate.$1}–${ranges.heartRate.$2}',
                        unit: 'bpm',
                        size: 18,
                        color: AppColors.raspberry,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Freq. respiratória',
                        style: theme.textTheme.bodySmall,
                      ),
                      DataValue(
                        value: '${ranges.respiratoryRate.$1}–'
                            '${ranges.respiratoryRate.$2}',
                        unit: 'irpm',
                        size: 18,
                        color: AppColors.vital,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Valores em repouso. Choro, febre e dor elevam os dois de forma '
              'significativa.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimatedWeightCard extends StatefulWidget {
  @override
  State<_EstimatedWeightCard> createState() => _EstimatedWeightCardState();
}

class _EstimatedWeightCardState extends State<_EstimatedWeightCard> {
  int _age = 4;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? estimated = PediatricCalculators.estimatedWeightKg(_age);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Peso estimado (APLS)',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (estimated != null)
                  DataValue(
                    value: estimated.round().toString(),
                    unit: 'kg',
                    color: AppColors.emergency,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Slider(
                    value: _age.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_age anos',
                    onChanged: (double v) => setState(() => _age = v.round()),
                  ),
                ),
                Text('$_age anos', style: theme.textTheme.titleSmall),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdAll,
              ),
              child: Text(
                'Estimativa grosseira, para quando pesar não é possível. '
                'Havendo balança, sempre pese.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boletim de Apgar. Sem estado por ser inserido de cabeça pelo profissional
/// no momento do parto — cinco seletores de 0 a 2, resultado imediato.
class _ApgarCard extends StatefulWidget {
  const _ApgarCard();

  @override
  State<_ApgarCard> createState() => _ApgarCardState();
}

class _ApgarCardState extends State<_ApgarCard> {
  int _heartRate = 2;
  int _respiratoryEffort = 2;
  int _muscleTone = 2;
  int _reflexIrritability = 2;
  int _color = 2;

  ApgarScore get _score => ApgarScore(
        heartRate: _heartRate,
        respiratoryEffort: _respiratoryEffort,
        muscleTone: _muscleTone,
        reflexIrritability: _reflexIrritability,
        color: _color,
      );

  Widget _criterion(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 0, label: Text('0')),
              ButtonSegment<int>(value: 1, label: Text('1')),
              ButtonSegment<int>(value: 2, label: Text('2')),
            ],
            selected: <int>{value},
            showSelectedIcon: false,
            onSelectionChanged: (Set<int> v) => onChanged(v.first),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ApgarScore score = _score;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Boletim de Apgar', style: theme.textTheme.titleSmall),
                ),
                DataValue(
                  value: '${score.total}',
                  unit: '/10',
                  color: score.total >= 7
                      ? AppColors.success
                      : score.total >= 4
                          ? AppColors.warning
                          : AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _criterion('Freq. cardíaca', _heartRate,
                (int v) => setState(() => _heartRate = v)),
            _criterion('Esforço respiratório', _respiratoryEffort,
                (int v) => setState(() => _respiratoryEffort = v)),
            _criterion('Tônus muscular', _muscleTone,
                (int v) => setState(() => _muscleTone = v)),
            _criterion('Irritabilidade reflexa', _reflexIrritability,
                (int v) => setState(() => _reflexIrritability = v)),
            _criterion('Cor', _color, (int v) => setState(() => _color = v)),
            const SizedBox(height: AppSpacing.sm),
            AppTag(
              label: score.interpretation,
              color: score.total >= 7
                  ? AppColors.success
                  : score.total >= 4
                      ? AppColors.warning
                      : AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Aplique no 1º e no 5º minuto (10º se o 5º ficar abaixo de 7).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Taxa de infusão de glicose (TIG), em mg/kg/min.
class _GlucoseInfusionCard extends StatefulWidget {
  const _GlucoseInfusionCard();

  @override
  State<_GlucoseInfusionCard> createState() => _GlucoseInfusionCardState();
}

class _GlucoseInfusionCardState extends State<_GlucoseInfusionCard> {
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _concentration = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  @override
  void dispose() {
    _rate.dispose();
    _concentration.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? rate = Parsers.decimal(_rate.text);
    final double? conc = Parsers.decimal(_concentration.text);
    final double? weight = Parsers.decimal(_weight.text);

    final double? tig = (rate != null && conc != null &&
            weight != null && weight > 0)
        ? glucoseInfusionRateMgKgMin(
            infusionRateMlPerHour: rate,
            dextroseConcentrationPercent: conc,
            weightKg: weight,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Taxa de infusão de glicose', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'Vazão',
                    controller: _rate,
                    hint: '4',
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('mL/h'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Concentração',
                    controller: _concentration,
                    hint: '10',
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('%'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Peso',
              controller: _weight,
              hint: '1,2',
              suffix: const Padding(
                padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                child: Text('kg'),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: Masks.decimal,
              onChanged: (_) => setState(() {}),
            ),
            if (tig != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: DataValue(
                  value: Formatters.decimal(tig, digits: 2),
                  unit: 'mg/kg/min',
                  color: AppColors.vital,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Débito urinário, em mL/kg/h.
class _UrineOutputCard extends StatefulWidget {
  const _UrineOutputCard();

  @override
  State<_UrineOutputCard> createState() => _UrineOutputCardState();
}

class _UrineOutputCardState extends State<_UrineOutputCard> {
  final TextEditingController _volume = TextEditingController();
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _hours = TextEditingController();

  @override
  void dispose() {
    _volume.dispose();
    _weight.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? volume = Parsers.decimal(_volume.text);
    final double? weight = Parsers.decimal(_weight.text);
    final double? hours = Parsers.decimal(_hours.text);

    final UrineOutput? output =
        (volume != null && weight != null && weight > 0 &&
                hours != null && hours > 0)
            ? urineOutput(volumeMl: volume, weightKg: weight, hours: hours)
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Débito urinário', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'Volume',
                    controller: _volume,
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('mL'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Peso',
                    controller: _weight,
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('kg'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Horas',
                    controller: _hours,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (output != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  DataValue(
                    value: Formatters.decimal(output.rate, digits: 2),
                    unit: 'mL/kg/h',
                    color: output.isOliguric
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                  if (output.isOliguric) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    const AppTag(label: 'Oligúria', color: AppColors.danger),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Osmolaridade sérica calculada, a partir de ureia (não BUN).
class _OsmolarityCard extends StatefulWidget {
  const _OsmolarityCard();

  @override
  State<_OsmolarityCard> createState() => _OsmolarityCardState();
}

class _OsmolarityCardState extends State<_OsmolarityCard> {
  final TextEditingController _sodium = TextEditingController();
  final TextEditingController _glucose = TextEditingController();
  final TextEditingController _urea = TextEditingController();

  @override
  void dispose() {
    _sodium.dispose();
    _glucose.dispose();
    _urea.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? na = Parsers.decimal(_sodium.text);
    final double? glicose = Parsers.decimal(_glucose.text);
    final double? ureia = Parsers.decimal(_urea.text);

    final double? osm = (na != null && glicose != null && ureia != null)
        ? calculatedSerumOsmolarity(
            sodiumMEqL: na,
            glucoseMgDl: glicose,
            ureaMgDl: ureia,
          )
        : null;

    final bool outOfRange = osm != null &&
        (osm < normalSerumOsmolarityRange.$1 ||
            osm > normalSerumOsmolarityRange.$2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Osmolaridade calculada', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    label: 'Sódio',
                    controller: _sodium,
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('mEq/L'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Glicose',
                    controller: _glucose,
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('mg/dL'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Ureia',
                    controller: _urea,
                    helper: 'não BUN',
                    suffix: const Padding(
                      padding: EdgeInsets.all(AppSpacing.fieldSuffix),
                      child: Text('mg/dL'),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Masks.decimal,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (osm != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  DataValue(
                    value: Formatters.decimal(osm, digits: 1),
                    unit: 'mOsm/L',
                    color: outOfRange ? AppColors.warning : AppColors.success,
                  ),
                  if (outOfRange) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    const AppTag(label: 'Fora da faixa', color: AppColors.warning),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Faixa normal: ${normalSerumOsmolarityRange.$1.toInt()}–'
                '${normalSerumOsmolarityRange.$2.toInt()} mOsm/L. '
                'Informe ureia do laboratório — não converta para BUN.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Idade gestacional pela DUM.
class _GestationalAgeCard extends StatefulWidget {
  const _GestationalAgeCard();

  @override
  State<_GestationalAgeCard> createState() => _GestationalAgeCardState();
}

class _GestationalAgeCardState extends State<_GestationalAgeCard> {
  DateTime? _lmp;

  Future<void> _pick() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lmp ?? now.subtract(const Duration(days: 200)),
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Data da última menstruação',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _lmp = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final GestationalAge? ga = _lmp == null
        ? null
        : gestationalAgeFromLmp(lastMenstrualPeriod: _lmp!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Idade gestacional (DUM)', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pick,
              borderRadius: AppRadius.mdAll,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Última menstruação',
                  prefixIcon: Icon(Icons.event_outlined, size: 20),
                ),
                child: Text(
                  _lmp == null ? 'Selecionar' : Formatters.date(_lmp!),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            if (ga != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Column(
                  children: <Widget>[
                    Text(ga.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    AppTag(label: ga.classification),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
