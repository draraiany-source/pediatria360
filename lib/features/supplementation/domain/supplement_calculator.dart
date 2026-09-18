import 'supplement_catalog.dart';

/// Entrada da calculadora ? NAO aplica formulas clinicas numericas.
/// Devolve sugestao textual para CONFERENCIA medica.
enum SupplementGoal {
  prophylaxis,
  treatment,
  maintenance;

  String get label => switch (this) {
        SupplementGoal.prophylaxis => 'Profilaxia',
        SupplementGoal.treatment => 'Tratamento',
        SupplementGoal.maintenance => 'Manutencao',
      };
}

class SupplementCalculatorInput {
  const SupplementCalculatorInput({
    required this.micronutrientId,
    this.ageYears,
    this.ageMonths,
    this.weightKg,
    this.sex = '',
    this.preterm = false,
    this.gestationalAgeWeeks,
    this.diagnosis = '',
    this.goal = SupplementGoal.prophylaxis,
    this.relatedExamId = '',
    this.labResultText = '',
    this.presentation = '',
  });

  final String micronutrientId;
  final int? ageYears;
  final int? ageMonths;
  final double? weightKg;
  final String sex;
  final bool preterm;
  final int? gestationalAgeWeeks;
  final String diagnosis;
  final SupplementGoal goal;
  final String relatedExamId;
  final String labResultText;
  final String presentation;
}

class SupplementCalculatorSuggestion {
  const SupplementCalculatorSuggestion({
    required this.summary,
    required this.safetyAlerts,
    required this.requiresLabFollowUp,
    this.doseLine = kSupplementContentPending,
    this.perKgLine = kSupplementContentPending,
    this.dailyLine = kSupplementContentPending,
    this.frequencyLine = kSupplementContentPending,
    this.durationLine = kSupplementContentPending,
    this.maxLine = kSupplementContentPending,
  });

  final String summary;
  final List<String> safetyAlerts;
  final bool requiresLabFollowUp;
  final String doseLine;
  final String perKgLine;
  final String dailyLine;
  final String frequencyLine;
  final String durationLine;
  final String maxLine;
}

/// Motor sem doses: monta checklist de revisao a partir dos dados informados.
class SupplementCalculatorEngine {
  const SupplementCalculatorEngine();

  SupplementCalculatorSuggestion suggest(SupplementCalculatorInput input) {
    final String name =
        micronutrientById(input.micronutrientId)?.name ?? input.micronutrientId;
    final List<String> alerts = <String>[
      kSupplementClinicalDisclaimer,
      'Nenhuma dose automatica foi aplicada. Preencha e confirme com base em fonte validada.',
      if (input.weightKg == null) 'Peso nao informado ? necessario para dose por kg.',
      if (input.ageMonths == null && input.ageYears == null)
        'Idade nao informada ? revisar faixa etaria antes de qualquer esquema.',
      if (input.preterm)
        'Prematuridade marcada ? revisar conduta especifica com protocolo validado.',
    ];

    final StringBuffer summary = StringBuffer()
      ..writeln('SUGESTAO PARA CONFERENCIA ? $name')
      ..writeln('Objetivo: ${input.goal.label}')
      ..writeln(
        'Idade: ${input.ageYears ?? '-'} a / ${input.ageMonths ?? '-'} m',
      )
      ..writeln('Peso: ${input.weightKg ?? '-'} kg | Sexo: ${input.sex.isEmpty ? '-' : input.sex}')
      ..writeln('Prematuro: ${input.preterm ? 'sim' : 'nao'}'
          '${input.gestationalAgeWeeks == null ? '' : ' (IG ${input.gestationalAgeWeeks} sem)'}')
      ..writeln('Diagnostico informado: ${input.diagnosis.isEmpty ? 'Nao informado' : input.diagnosis}')
      ..writeln('Exame: ${input.relatedExamId.isEmpty ? 'Nao informado' : input.relatedExamId}')
      ..writeln('Resultado: ${input.labResultText.isEmpty ? 'Nao informado' : input.labResultText}')
      ..writeln('Apresentacao: ${input.presentation.isEmpty ? 'Nao informado' : input.presentation}')
      ..writeln()
      ..writeln(kSupplementContentPending);

    return SupplementCalculatorSuggestion(
      summary: summary.toString(),
      safetyAlerts: alerts,
      requiresLabFollowUp: true,
    );
  }
}
