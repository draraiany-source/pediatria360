import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../shared/domain/entities/clinical_record.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../tools/domain/calculators.dart';
import '../services/clinical_pdf_service.dart';
import 'patient_timeline_screen.dart';

/// Emissão de documentos clínicos.
///
/// ## Um editor, seis documentos
///
/// Receita tem estrutura própria — itens, posologia, quantidade. Os outros
/// cinco são texto corrido sobre um modelo. Manter telas separadas para cada um
/// multiplicaria código quase idêntico; a diferença real é só o corpo.
///
/// ## Por que o texto vem preenchido e editável
///
/// Um campo em branco obriga o médico a escrever a mesma frase pela milésima
/// vez. Um texto travado o obriga a aceitar redação que não é dele. O modelo
/// preenche e ele ajusta — e quem responde pelo conteúdo continua sendo ele.
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({
    required this.encounter,
    required this.type,
    super.key,
  });

  final Encounter encounter;
  final ClinicalDocumentType type;

  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState
    extends ConsumerState<DocumentEditorScreen> {
  final TextEditingController _content = TextEditingController();
  final List<_ItemDraft> _items = <_ItemDraft>[];

  // Campos que alimentam os modelos.
  int _certificateDays = 1;
  bool _includeCid = true;
  final TextEditingController _specialty = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _exams = TextEditingController();

  bool _issuing = false;

  bool get _isPrescription =>
      widget.type == ClinicalDocumentType.prescription;

  @override
  void initState() {
    super.initState();
    if (_isPrescription) {
      _items.add(_ItemDraft.empty());
    } else {
      _content.text = _initialTemplate();
    }
  }

  @override
  void dispose() {
    _content.dispose();
    _specialty.dispose();
    _reason.dispose();
    _exams.dispose();
    for (final _ItemDraft i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  String get _patientName => widget.encounter.patientName ?? 'o paciente';

  String? get _primaryCid {
    final Diagnosis? dx = widget.encounter.primaryDiagnosis;
    if (dx == null || dx.code.isEmpty) return null;
    return '${dx.code} — ${dx.description}';
  }

  String _initialTemplate() => switch (widget.type) {
        ClinicalDocumentType.certificate => DocumentTemplates.certificate(
            patientName: _patientName,
            days: _certificateDays,
            cid: _includeCid ? _primaryCid : null,
          ),
        ClinicalDocumentType.referral => DocumentTemplates.referral(
            patientName: _patientName,
            specialty: '[especialidade]',
            reason: widget.encounter.assessment.isEmpty
                ? '[motivo]'
                : widget.encounter.assessment,
            cid: _primaryCid,
          ),
        ClinicalDocumentType.examRequest => DocumentTemplates.examRequest(
            patientName: _patientName,
            exams: const <String>['[exame]'],
            clinicalIndication: widget.encounter.assessment.isEmpty
                ? null
                : widget.encounter.assessment,
          ),
        ClinicalDocumentType.dischargeSummary =>
          DocumentTemplates.dischargeSummary(
            patientName: _patientName,
            admission: widget.encounter.startedAt,
            discharge: DateTime.now(),
            diagnosis: _primaryCid ?? '[diagnóstico]',
            course: '[evolução]',
            medications: '[medicações]',
            followUp: '[orientações e retorno]',
          ),
        ClinicalDocumentType.report =>
          'Relatório médico referente ao atendimento de $_patientName em '
              '${Formatters.date(widget.encounter.startedAt)}.\n\n'
              '${widget.encounter.assessment}\n\n'
              '${widget.encounter.plan}',
        ClinicalDocumentType.prescription => '',
      };

  /// Reconstrói o texto quando um parâmetro do modelo muda.
  ///
  /// Só sobrescreve se o médico ainda não editou — perder texto digitado por
  /// causa de um toque num seletor seria inaceitável.
  void _refreshTemplate({required String previousTemplate}) {
    if (_content.text.trim() == previousTemplate.trim()) {
      _content.text = _initialTemplate();
    }
  }

  Future<void> _issue() async {
    final String content = _isPrescription
        ? _content.text.trim()
        : _content.text.trim();

    if (!_isPrescription && content.length < 10) {
      _snack('O documento está vazio.');
      return;
    }

    final List<PrescriptionItem> items = _items
        .where((_ItemDraft i) => i.drug.text.trim().isNotEmpty)
        .map((_ItemDraft i) => i.toItem())
        .toList(growable: false);

    if (_isPrescription && items.isEmpty) {
      _snack('Adicione ao menos um medicamento.');
      return;
    }

    setState(() => _issuing = true);

    final Result<ClinicalDocument> result =
        await ref.read(encounterRepositoryProvider).issueDocument(
              encounterId: widget.encounter.id,
              type: widget.type,
              content: content,
              items: items,
            );

    if (!mounted) return;
    setState(() => _issuing = false);

    result.fold(
      (ClinicalDocument document) async {
        _snack('${widget.type.label} emitido.');
        await ClinicalPdfService.printDocument(
          document: document,
          clinicName: 'Pediatria 360',
        );
        if (mounted) Navigator.of(context).pop();
      },
      (Failure failure) => _snack(failure.message, error: true),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.label),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancelar',
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppButton(
            label: 'Emitir e imprimir',
            icon: Icons.print_outlined,
            isLoading: _issuing,
            onPressed: _issue,
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
                _PatientCard(encounter: widget.encounter),
                const SizedBox(height: AppSpacing.lg),

                if (_isPrescription) ..._prescriptionFields(theme),
                if (widget.type == ClinicalDocumentType.certificate)
                  ..._certificateFields(theme),
                if (widget.type == ClinicalDocumentType.referral)
                  ..._referralFields(),
                if (widget.type == ClinicalDocumentType.examRequest)
                  ..._examFields(),

                if (!_isPrescription) ...<Widget>[
                  const SectionHeader(title: 'Texto do documento'),
                  AppTextField(
                    label: 'Conteúdo',
                    controller: _content,
                    maxLines: 14,
                    textCapitalization: TextCapitalization.sentences,
                    helper: 'Revise antes de emitir — o conteúdo é seu.',
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),
                _SignatureNotice(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Receita

  List<Widget> _prescriptionFields(ThemeData theme) => <Widget>[
        SectionHeader(
          title: 'Medicamentos',
          eyebrow: '${_items.length} ${_items.length == 1 ? 'item' : 'itens'}',
          actionLabel: 'Adicionar',
          onAction: () => setState(() => _items.add(_ItemDraft.empty())),
        ),
        for (int i = 0; i < _items.length; i++)
          _PrescriptionItemCard(
            key: ValueKey<_ItemDraft>(_items[i]),
            draft: _items[i],
            index: i + 1,
            weightKg: widget.encounter.vitals.weightKg,
            ageMonths: widget.encounter.patientAgeMonthsAtEncounter,
            onChanged: () => setState(() {}),
            onRemove: _items.length == 1
                ? null
                : () => setState(() => _items.removeAt(i).dispose()),
          ),
        const SectionHeader(title: 'Orientações', eyebrow: 'Opcional'),
        AppTextField(
          label: 'Orientações gerais',
          controller: _content,
          maxLines: 4,
          hint: 'Retornar se febre persistir por mais de 3 dias...',
          textCapitalization: TextCapitalization.sentences,
        ),
      ];

  // ------------------------------------------------------------ Atestado

  List<Widget> _certificateFields(ThemeData theme) => <Widget>[
        const SectionHeader(title: 'Afastamento'),
        Row(
          children: <Widget>[
            Text('Dias', style: theme.textTheme.bodyMedium),
            Expanded(
              child: Slider(
                value: _certificateDays.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '$_certificateDays',
                onChanged: (double v) {
                  final String previous = _initialTemplate();
                  setState(() => _certificateDays = v.round());
                  _refreshTemplate(previousTemplate: previous);
                },
              ),
            ),
            Text('$_certificateDays', style: theme.textTheme.titleSmall),
          ],
        ),
        // O CFM garante ao paciente o direito de pedir atestado sem CID.
        // Deixar isso como escolha explícita no momento da emissão evita que
        // o diagnóstico chegue à escola ou ao empregador por descuido.
        SwitchListTile(
          value: _includeCid,
          onChanged: _primaryCid == null
              ? null
              : (bool v) {
                  final String previous = _initialTemplate();
                  setState(() => _includeCid = v);
                  _refreshTemplate(previousTemplate: previous);
                },
          title: const Text('Incluir CID'),
          subtitle: Text(
            _primaryCid == null
                ? 'Nenhum diagnóstico registrado no atendimento'
                : 'O responsável pode pedir a supressão do CID',
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ];

  // ------------------------------------------------------ Encaminhamento

  List<Widget> _referralFields() => <Widget>[
        const SectionHeader(title: 'Destino'),
        AppTextField(
          label: 'Especialidade',
          controller: _specialty,
          hint: 'Neuropediatria',
          textCapitalization: TextCapitalization.words,
          onChanged: (String v) {
            _content.text = DocumentTemplates.referral(
              patientName: _patientName,
              specialty: v.isEmpty ? '[especialidade]' : v,
              reason: _reason.text.isEmpty
                  ? (widget.encounter.assessment.isEmpty
                      ? '[motivo]'
                      : widget.encounter.assessment)
                  : _reason.text,
              cid: _primaryCid,
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Motivo',
          controller: _reason,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (String v) {
            _content.text = DocumentTemplates.referral(
              patientName: _patientName,
              specialty:
                  _specialty.text.isEmpty ? '[especialidade]' : _specialty.text,
              reason: v.isEmpty ? '[motivo]' : v,
              cid: _primaryCid,
            );
          },
        ),
      ];

  // ------------------------------------------------------------- Exames

  List<Widget> _examFields() => <Widget>[
        const SectionHeader(title: 'Exames solicitados'),
        AppTextField(
          label: 'Um por linha',
          controller: _exams,
          maxLines: 6,
          hint: 'Hemograma completo\nPCR\nUrina tipo I',
          onChanged: (String v) {
            final List<String> list = v
                .split('\n')
                .map((String s) => s.trim())
                .where((String s) => s.isNotEmpty)
                .toList(growable: false);

            _content.text = DocumentTemplates.examRequest(
              patientName: _patientName,
              exams: list.isEmpty ? const <String>['[exame]'] : list,
              clinicalIndication: widget.encounter.assessment.isEmpty
                  ? null
                  : widget.encounter.assessment,
            );
          },
        ),
      ];
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.encounter});

  final Encounter encounter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? months = encounter.patientAgeMonthsAtEncounter;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  encounter.patientName ?? 'Paciente',
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  <String>[
                    if (months != null) '$months meses',
                    if (encounter.vitals.weightKg != null)
                      '${Formatters.decimal(encounter.vitals.weightKg!, digits: 2)} kg',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (encounter.anamnesis.allergies.isNotEmpty)
            AppTag(
              label: 'Alergias: ${encounter.anamnesis.allergies.join(', ')}',
              color: AppColors.danger,
              icon: Icons.warning_amber_rounded,
            ),
        ],
      ),
    );
  }
}

/// Rascunho editável de um item da receita.
class _ItemDraft {
  _ItemDraft({
    required this.drug,
    required this.presentation,
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.instructions,
    required this.quantity,
    required this.mgPerKg,
    required this.maxSingleDoseMg,
    required this.maxDailyDoseMg,
    required this.timesPerDay,
  });

  factory _ItemDraft.empty() => _ItemDraft(
        drug: TextEditingController(),
        presentation: TextEditingController(),
        dose: TextEditingController(),
        frequency: TextEditingController(),
        duration: TextEditingController(),
        instructions: TextEditingController(),
        quantity: TextEditingController(),
        mgPerKg: TextEditingController(),
        maxSingleDoseMg: TextEditingController(),
        maxDailyDoseMg: TextEditingController(),
        timesPerDay: TextEditingController(),
      );

  final TextEditingController drug;
  final TextEditingController presentation;
  final TextEditingController dose;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController instructions;
  final TextEditingController quantity;
  final TextEditingController mgPerKg;
  final TextEditingController maxSingleDoseMg;
  final TextEditingController maxDailyDoseMg;
  final TextEditingController timesPerDay;

  String route = 'Via oral';
  bool controlled = false;

  PrescriptionItem toItem() => PrescriptionItem(
        drug: drug.text.trim(),
        presentation: presentation.text.trim(),
        dose: dose.text.trim(),
        route: route,
        frequency: frequency.text.trim(),
        duration: duration.text.trim(),
        instructions:
            instructions.text.trim().isEmpty ? null : instructions.text.trim(),
        quantity: quantity.text.trim().isEmpty ? null : quantity.text.trim(),
        mgPerKg: Parsers.decimal(mgPerKg.text),
        isControlled: controlled,
      );

  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      drug, presentation, dose, frequency, duration,
      instructions, quantity, mgPerKg,
      maxSingleDoseMg, maxDailyDoseMg, timesPerDay,
    ]) {
      c.dispose();
    }
  }
}

class _PrescriptionItemCard extends StatefulWidget {
  const _PrescriptionItemCard({
    required this.draft,
    required this.index,
    required this.onChanged,
    this.weightKg,
    this.ageMonths,
    this.onRemove,
    super.key,
  });

  final _ItemDraft draft;
  final int index;
  final VoidCallback onChanged;
  final double? weightKg;
  final int? ageMonths;
  final VoidCallback? onRemove;

  @override
  State<_PrescriptionItemCard> createState() => _PrescriptionItemCardState();
}

class _PrescriptionItemCardState extends State<_PrescriptionItemCard> {
  static const List<String> _routes = <String>[
    'Via oral',
    'Via retal',
    'Via nasal',
    'Via inalatória',
    'Via tópica',
    'Via oftálmica',
    'Via otológica',
    'Intramuscular',
    'Endovenosa',
    'Subcutânea',
  ];

  static const List<String> _frequencies = <String>[
    'a cada 4 horas',
    'a cada 6 horas',
    'a cada 8 horas',
    'a cada 12 horas',
    'a cada 24 horas',
    '1 vez ao dia',
    '2 vezes ao dia',
    '3 vezes ao dia',
    'se necessário',
  ];

  /// Conferência por peso, usando o motor de [DoseCalculator].
  ///
  /// A conta usa o mg/kg e os tetos **que o prescritor digitou**, com o peso
  /// registrado no atendimento. A plataforma não sugere dose — faz a
  /// aritmética que o médico faria à mão, e avisa quando o resultado bate no
  /// teto que ele mesmo definiu.
  ///
  /// A versão anterior desta tela multiplicava inline e ignorava os tetos:
  /// uma dose acima do máximo diário passava sem aviso.
  DoseResult? get _doseCheck {
    final double? perKg = Parsers.decimal(widget.draft.mgPerKg.text);
    if (perKg == null || perKg <= 0 || widget.weightKg == null) return null;

    final int times = int.tryParse(widget.draft.timesPerDay.text.trim()) ??
        _timesFromFrequency(widget.draft.frequency.text);

    return DoseCalculator.calculate(
      protocol: DoseProtocol(
        drugName: widget.draft.drug.text.trim(),
        mgPerKg: perKg,
        timesPerDay: times,
        source: 'informado pelo prescritor',
        maxSingleDoseMg: Parsers.decimal(widget.draft.maxSingleDoseMg.text),
        maxDailyDoseMg: Parsers.decimal(widget.draft.maxDailyDoseMg.text),
      ),
      weightKg: widget.weightKg!,
      ageMonths: widget.ageMonths,
    );
  }

  /// Deduz o número de tomadas a partir da frequência escolhida.
  ///
  /// Evita pedir a mesma informação duas vezes: quem selecionou "a cada 8
  /// horas" já disse que são 3 ao dia.
  static int _timesFromFrequency(String frequency) {
    final String f = frequency.toLowerCase();
    if (f.contains('4 horas')) return 6;
    if (f.contains('6 horas')) return 4;
    if (f.contains('8 horas')) return 3;
    if (f.contains('12 horas')) return 2;
    if (f.contains('24 horas') || f.contains('1 vez')) return 1;
    if (f.contains('2 vezes')) return 2;
    if (f.contains('3 vezes')) return 3;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(
            color: widget.draft.controlled
                ? AppColors.danger.withValues(alpha: 0.5)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('${widget.index}', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  if (widget.onRemove != null)
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: 'Remover',
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              AppTextField(
                label: 'Medicamento',
                controller: widget.draft.drug,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => widget.onChanged(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Apresentação',
                controller: widget.draft.presentation,
                hint: 'Suspensão 100 mg/mL',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: 'Dose',
                      controller: widget.draft.dose,
                      hint: '5 mL',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: widget.draft.route,
                      decoration: const InputDecoration(labelText: 'Via'),
                      items: _routes
                          .map(
                            (String r) => DropdownMenuItem<String>(
                              value: r,
                              child: Text(r, style: theme.textTheme.bodySmall),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) => setState(
                        () => widget.draft.route = v ?? widget.draft.route,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _frequencies.contains(widget.draft.frequency.text)
                          ? widget.draft.frequency.text
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'Frequência'),
                      items: _frequencies
                          .map(
                            (String f) => DropdownMenuItem<String>(
                              value: f,
                              child: Text(f, style: theme.textTheme.bodySmall),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) =>
                          setState(() => widget.draft.frequency.text = v ?? ''),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Duração',
                      controller: widget.draft.duration,
                      hint: 'por 7 dias',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 120,
                    child: AppTextField(
                      label: 'mg/kg',
                      controller: widget.draft.mgPerKg,
                      hint: '15',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: Masks.decimal,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Quantidade',
                      controller: widget.draft.quantity,
                      hint: '1 frasco',
                    ),
                  ),
                ],
              ),
              if (widget.draft.mgPerKg.text.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppTextField(
                        label: 'Máx. por dose',
                        controller: widget.draft.maxSingleDoseMg,
                        hint: 'mg',
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
                        label: 'Máx. por dia',
                        controller: widget.draft.maxDailyDoseMg,
                        hint: 'mg',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: Masks.decimal,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
              if (_doseCheck != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                _DoseCheckBox(result: _doseCheck!),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Instruções',
                controller: widget.draft.instructions,
                hint: 'Agitar antes de usar. Administrar após as refeições.',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Controle especial muda o modelo do receituário impresso.
              CheckboxListTile(
                value: widget.draft.controlled,
                onChanged: (bool? v) => setState(() {
                  widget.draft.controlled = v ?? false;
                  widget.onChanged();
                }),
                title: const Text('Medicamento de controle especial'),
                subtitle: const Text('Altera o modelo do receituário'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso sobre a natureza da assinatura.
///
/// Enquanto não houver certificado ICP-Brasil, o médico precisa saber que o
/// documento vale como registro selado pela plataforma, não como documento
/// com assinatura digital juridicamente plena.
class _SignatureNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sobre a assinatura deste documento',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'O documento é selado pela plataforma, com hash de '
                  'integridade e código de conferência. Isso não substitui '
                  'assinatura digital ICP-Brasil, exigida pelo CFM para '
                  'validade jurídica plena de receita e atestado.',
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

/// Resultado da conferência de dose.
///
/// Mostra a conta e, quando o resultado bate num teto que o prescritor
/// definiu, diz qual — em vez de exibir um número menor que o esperado sem
/// explicação, o que pareceria erro de cálculo.
class _DoseCheckBox extends StatelessWidget {
  const _DoseCheckBox({required this.result});

  final DoseResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color =
        result.hasWarning ? AppColors.warning : AppColors.vital;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: result.hasWarning
                ? Border.all(color: color.withValues(alpha: 0.4))
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    result.hasWarning
                        ? Icons.warning_amber_rounded
                        : Icons.calculate_outlined,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${Formatters.decimal(result.protocol.mgPerKg)} mg/kg × '
                      '${Formatters.decimal(result.weightKg, digits: 2)} kg = '
                      '${Formatters.decimal(result.singleDoseMg, digits: 1)} mg '
                      'por dose',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${result.protocol.timesPerDay}× ao dia = '
                '${Formatters.decimal(result.dailyDoseMg, digits: 1)} mg/dia',
                style: theme.textTheme.bodySmall,
              ),
              if (result.singleDoseMl != null)
                Text(
                  '≈ ${Formatters.decimal(result.singleDoseMl!, digits: 2)} mL '
                  'por dose',
                  style: theme.textTheme.bodySmall,
                ),

              // Sem estas linhas, o prescritor veria um número menor que o
              // esperado e acharia que a conta está errada.
              if (result.cappedBySingleMax) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Limitado ao máximo por dose que você informou.',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
              if (result.cappedByDailyMax) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Limitado ao máximo diário. A dose unitária foi reduzida '
                  'para manter as ${result.protocol.timesPerDay} tomadas.',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
              if (result.belowMinimumAge) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Paciente abaixo da idade mínima informada.',
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Conferência com os valores que você informou. A escolha da dose '
            'é sua.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
