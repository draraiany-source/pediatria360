/// Modelos de receita do profissional ("Meus modelos de receita").
///
/// Regras:
/// - o modelo guarda o esquema (medicamento, apresentação, mg/kg, via,
///   intervalo, duração, quantidade e orientações), nunca a dose calculada
///   para uma criança;
/// - usar o modelo gera um rascunho novo para o paciente atual: doses pelo
///   peso são refeitas com o peso dele, e a conta fica no item;
/// - todo item gerado exige conferência campo a campo antes da emissão;
/// - editar o modelo cria uma nova versão e não altera receitas já geradas,
///   que guardam cópia própria dos itens.
library;

import 'clinical_documents.dart';
import 'dose_calculator.dart';

enum RxDoseMode {
  weight('Pelo peso (mg/kg)'),
  fixed('Dose fixa'),
  atConsultation('Definir na consulta');

  const RxDoseMode(this.label);

  final String label;
}

class RxTemplateItem {
  const RxTemplateItem({
    required this.drug,
    required this.presentation,
    required this.mode,
    this.concentration = '',
    this.referenceId,
    this.presentationId,
    this.mgPerKg,
    this.fixedDose = '',
    this.fixedVolume = '',
    this.route = 'via oral',
    this.frequency = '',
    this.duration = '',
    this.quantity = '',
    this.notes = '',
  });

  final String drug;
  final String presentation;
  final String concentration;
  final RxDoseMode mode;

  /// Só em [RxDoseMode.weight].
  final String? referenceId;
  final String? presentationId;
  final double? mgPerKg;

  /// Só em [RxDoseMode.fixed]: dose que não depende do peso.
  final String fixedDose;
  final String fixedVolume;

  final String route;
  final String frequency;
  final String duration;
  final String quantity;
  final String notes;

  String doseSummary(List<DoseReference> references) => switch (mode) {
    RxDoseMode.weight =>
      '${formatDoseNumber(mgPerKg ?? 0)} '
          '${_ref(references, referenceId)?.basis.label ?? 'mg/kg'}, '
          'recalculada com o peso de cada paciente',
    RxDoseMode.fixed =>
      '$fixedDose${fixedVolume.trim().isEmpty ? '' : ' ($fixedVolume)'} '
          '(dose fixa)',
    RxDoseMode.atConsultation => 'Dose a definir na consulta',
  };

  List<String> problems(List<DoseReference> references) {
    final List<String> out = <String>[];
    if (drug.trim().isEmpty) out.add('informe o medicamento');
    if (presentation.trim().isEmpty) out.add('informe a apresentação');
    switch (mode) {
      case RxDoseMode.weight:
        final DoseReference? ref = _ref(references, referenceId);
        if (ref == null) {
          out.add('escolha a referência de dose');
        } else {
          if (!ref.isUsable) out.add('referência de dose não validada');
          if (_pres(ref, presentationId) == null) {
            out.add('escolha a apresentação da referência');
          }
        }
        if (mgPerKg == null || !mgPerKg!.isFinite || mgPerKg! <= 0) {
          out.add('informe a dose em mg/kg');
        }
      case RxDoseMode.fixed:
        if (fixedDose.trim().isEmpty) out.add('informe a dose fixa');
        if (frequency.trim().isEmpty) out.add('informe a frequência');
      case RxDoseMode.atConsultation:
        if (frequency.trim().isEmpty) out.add('informe a frequência');
    }
    if (duration.trim().isEmpty) out.add('informe a duração');
    return out;
  }
}

class RxTemplateVersion {
  const RxTemplateVersion({
    required this.number,
    required this.name,
    required this.items,
    required this.orientations,
    required this.savedAt,
    required this.savedBy,
    this.note,
  });

  final int number;
  final String name;
  final List<RxTemplateItem> items;
  final String orientations;
  final DateTime savedAt;
  final String savedBy;
  final String? note;
}

class RxTemplate {
  const RxTemplate({
    required this.id,
    required this.versions,
    this.isExample = false,
  });

  final String id;
  final List<RxTemplateVersion> versions;

  /// Modelo de exemplo, com medicamentos fictícios.
  final bool isExample;

  RxTemplateVersion get current => versions.last;
  String get name => current.name;
  List<RxTemplateItem> get items => current.items;
  String get orientations => current.orientations;
  DateTime get createdAt => versions.first.savedAt;
  DateTime get updatedAt => current.savedAt;

  /// Como a receita gerada identifica a origem.
  String get originLabel => 'Modelo "$name" · v${current.number}';

  static RxTemplate create({
    required String id,
    required String name,
    required List<RxTemplateItem> items,
    required String author,
    required DateTime now,
    String orientations = '',
    String? note,
    bool isExample = false,
  }) => RxTemplate(
    id: id,
    isExample: isExample,
    versions: <RxTemplateVersion>[
      RxTemplateVersion(
        number: 1,
        name: name.trim(),
        items: List<RxTemplateItem>.unmodifiable(items),
        orientations: orientations.trim(),
        savedAt: now,
        savedBy: author,
        note: note,
      ),
    ],
  );

  List<String> problems(List<DoseReference> references) => <String>[
    if (name.trim().isEmpty) 'Dê um nome ao modelo',
    if (items.isEmpty) 'Inclua ao menos um item',
    for (int i = 0; i < items.length; i++)
      if (items[i].problems(references).isNotEmpty)
        'Item ${i + 1}: ${items[i].problems(references).join(', ')}',
  ];

  /// Nova versão; as anteriores e as receitas já geradas ficam como estão.
  RxTemplate edit({
    required String name,
    required List<RxTemplateItem> items,
    required String orientations,
    required String author,
    required DateTime now,
    String? note,
  }) => RxTemplate(
    id: id,
    isExample: isExample,
    versions: <RxTemplateVersion>[
      ...versions,
      RxTemplateVersion(
        number: current.number + 1,
        name: name.trim(),
        items: List<RxTemplateItem>.unmodifiable(items),
        orientations: orientations.trim(),
        savedAt: now,
        savedBy: author,
        note: (note ?? '').trim().isEmpty
            ? 'Edição a partir da v${current.number}'
            : note!.trim(),
      ),
    ],
  );

  RxTemplate duplicate({
    required String id,
    required String author,
    required DateTime now,
    String? name,
  }) => RxTemplate.create(
    id: id,
    name: name ?? 'Cópia de ${this.name}',
    items: items,
    orientations: orientations,
    author: author,
    now: now,
    note: 'Cópia de "${this.name}" (v${current.number})',
  );

  bool matches(String query) {
    final String q = normalizeSearch(query);
    if (q.isEmpty) return true;
    final String hay = normalizeSearch(
      <String>[
        name,
        orientations,
        for (final RxTemplateItem it in items) '${it.drug} ${it.presentation}',
      ].join(' '),
    );
    return q.split(' ').where((String w) => w.isNotEmpty).every(hay.contains);
  }
}

String normalizeSearch(String s) {
  const String from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const String to = 'aaaaaeeeeiiiiooooouuuucn';
  final StringBuffer b = StringBuffer();
  for (final String ch in s.toLowerCase().trim().split('')) {
    final int i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// Receita em rascunho gerada de um modelo para um paciente.
class RxTemplateDraft {
  const RxTemplateDraft({
    required this.items,
    required this.orientations,
    required this.notices,
  });

  final List<RxItem> items;
  final String orientations;

  /// O que aconteceu com cada item, para mostrar ao prescritor.
  final List<String> notices;
}

class RxTemplates {
  const RxTemplates._();

  static const String _child = '{{crianca}}';
  static const String _guardian = '{{responsavel}}';

  /// Transforma uma receita em modelo. Doses calculadas não são copiadas:
  /// itens pelo peso guardam só o mg/kg, e os demais ficam com a dose a
  /// definir na consulta.
  static RxTemplate fromPrescription({
    required String id,
    required String name,
    required List<RxItem> items,
    required String orientations,
    required String author,
    required DateTime now,
    required DocContext context,
    required List<DoseReference> references,
  }) {
    final String g = (context.guardianName ?? '').trim();
    final List<(String, String)> names = <(String, String)>[
      (context.patientName, _child),
      if (g.isNotEmpty) (g, _guardian),
    ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
    String generalize(String t) {
      String out = t;
      for (final (String name, String marker) in names) {
        out = out.replaceAll(name, marker);
      }
      return out;
    }

    return RxTemplate.create(
      id: id,
      name: name,
      author: author,
      now: now,
      orientations: generalize(orientations),
      note: 'Criado a partir de uma receita; doses não copiadas',
      items: <RxTemplateItem>[
        for (final RxItem it in items)
          it.weightDosing != null
              ? RxTemplateItem(
                  drug: it.drug,
                  presentation: it.presentation,
                  concentration: it.concentration,
                  mode: RxDoseMode.weight,
                  referenceId: it.weightDosing!.referenceId,
                  presentationId: it.weightDosing!.presentationId,
                  mgPerKg: it.weightDosing!.mgPerKg,
                  route: it.route,
                  frequency:
                      _ref(
                        references,
                        it.weightDosing!.referenceId,
                      )?.intervalLabel ??
                      it.frequency,
                  duration: it.duration,
                  quantity: it.quantity,
                  notes: generalize(it.notes),
                )
              : RxTemplateItem(
                  drug: it.drug,
                  presentation: it.presentation,
                  concentration: it.concentration,
                  mode: RxDoseMode.atConsultation,
                  route: it.route,
                  frequency: it.frequency,
                  duration: it.duration,
                  quantity: it.quantity,
                  notes: generalize(it.notes),
                ),
      ],
    );
  }

  /// Gera os itens do rascunho para o paciente atual.
  static RxTemplateDraft instantiate(
    RxTemplate template, {
    required DocContext context,
    required List<DoseReference> references,
    required DateTime now,
  }) {
    final DosePatientData patient = DosePatientData(
      name: context.patientName,
      weightKg: context.weightKg,
      weighedAt: context.weighedAt,
      birthDate: context.patientBirthDate,
      allergies: context.allergies,
    );
    String personalize(String t) => t
        .replaceAll(_child, context.patientName)
        .replaceAll(_guardian, context.guardianName ?? 'responsável');

    final List<RxItem> items = <RxItem>[];
    final List<String> notices = <String>[];
    for (int i = 0; i < template.items.length; i++) {
      final RxTemplateItem t = template.items[i];
      final String n = 'Item ${i + 1} (${t.drug})';
      final RxItem base = RxItem(
        drug: t.drug,
        presentation: t.presentation,
        concentration: t.concentration,
        dose: t.mode == RxDoseMode.fixed ? t.fixedDose : '',
        volume: t.mode == RxDoseMode.fixed ? t.fixedVolume : '',
        route: t.route,
        frequency: t.frequency,
        duration: t.duration,
        quantity: t.quantity,
        notes: personalize(t.notes),
        origin: template.originLabel,
        needsCheck: true,
      );
      switch (t.mode) {
        case RxDoseMode.weight:
          final RxItem it = recalculate(
            base.copyWith(
              weightDosing: RxWeightDosing(
                referenceId: t.referenceId ?? '',
                presentationId: t.presentationId ?? '',
                mgPerKg: t.mgPerKg ?? 0,
              ),
            ),
            patient: patient,
            references: references,
            now: now,
          );
          items.add(it);
          notices.add(
            it.blockers.isEmpty
                ? '$n: dose recalculada com ${formatDoseNumber(context.weightKg!)} kg '
                      'de ${context.patientName}.'
                : '$n: dose não calculada. ${it.blockers.join(' ')}',
          );
        case RxDoseMode.fixed:
          items.add(_withAllergy(base, context.allergies));
          notices.add(
            '$n: dose fixa do modelo (não depende do peso). Confira.',
          );
        case RxDoseMode.atConsultation:
          items.add(_withAllergy(base, context.allergies));
          notices.add('$n: escreva a dose para ${context.patientName}.');
      }
    }
    return RxTemplateDraft(
      items: items,
      orientations: personalize(template.orientations),
      notices: notices,
    );
  }

  /// Refaz a conta de um item pelo peso com os dados atuais do paciente.
  /// A conferência feita antes deixa de valer.
  static RxItem recalculate(
    RxItem item, {
    required DosePatientData patient,
    required List<DoseReference> references,
    required DateTime now,
  }) {
    final RxWeightDosing spec = item.weightDosing!;
    final DoseReference? ref = _ref(references, spec.referenceId);
    final DrugPresentation? pres = ref == null
        ? null
        : _pres(ref, spec.presentationId);
    final DoseCalculation c = PediatricDoseCalculator.calculate(
      reference: ref,
      presentation: pres,
      patient: patient,
      now: now,
      mgPerKgOverride: spec.mgPerKg,
      limitToMax: spec.limitToMax,
    );
    final RxWeightDosing used = RxWeightDosing(
      referenceId: spec.referenceId,
      presentationId: spec.presentationId,
      mgPerKg: spec.mgPerKg,
      limitToMax: spec.limitToMax,
      weightKg: patient.weightKg,
      weighedAt: patient.weighedAt,
    );
    final RxItem common = item.copyWith(
      drug: ref?.drugName ?? item.drug,
      presentation: pres?.label ?? item.presentation,
      concentration: pres?.concentrationLabel ?? item.concentration,
      frequency: ref?.intervalLabel ?? item.frequency,
      weightDosing: used,
      checked: const <RxCheck>{},
    );
    if (!c.canInsert) {
      return common.copyWith(
        dose: '',
        volume: '',
        clearCalculation: true,
        alerts: const <String>[],
        blockers: <String>[
          ...c.blockers,
          for (final DoseAlert a in c.alerts)
            if (a.isCritical) a.message,
        ],
      );
    }
    return common.copyWith(
      dose: c.perAdministrationLabel,
      volume: c.mlPerDose != null
          ? '${formatDoseNumber(c.mlPerDose!, decimals: 1)} mL por dose'
          : 'não se aplica (${pres!.unitName})',
      calculation: <String>[
        ...c.steps,
        'Peso de ${patient.name ?? 'paciente'}: ${formatDoseNumber(c.weightKg!)} kg '
            'em ${formatDocDate(c.weighedAt!)}; referência: ${ref!.source} '
            '(revisão ${formatDocDate(ref.reviewedAt!)}).',
      ].join('\n'),
      alerts: <String>[
        for (final DoseAlert a in c.alerts)
          if (!a.isCritical) a.message,
      ],
      blockers: const <String>[],
    );
  }

  static RxItem _withAllergy(RxItem it, List<String> allergies) {
    final String drug = it.drug.toLowerCase().trim();
    final List<String> hits = <String>[
      for (final String a in allergies)
        if (a.trim().isNotEmpty &&
            drug.isNotEmpty &&
            (a.toLowerCase().contains(drug) ||
                drug.contains(a.toLowerCase().trim())))
          'Alergia registrada: "$a".',
    ];
    return hits.isEmpty ? it : it.copyWith(alerts: <String>[...hits]);
  }
}

DoseReference? _ref(List<DoseReference> refs, String? id) {
  for (final DoseReference r in refs) {
    if (r.id == id) return r;
  }
  return null;
}

DrugPresentation? _pres(DoseReference ref, String? id) {
  for (final DrugPresentation p in ref.presentations) {
    if (p.id == id) return p;
  }
  return null;
}
