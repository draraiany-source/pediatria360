import 'dart:math' as math;

/// Calculadoras pediátricas.
///
/// ## O que existe aqui — e o que não existe, de propósito
///
/// Todas as calculadoras deste arquivo são **fórmulas publicadas e estáveis**:
/// Holliday-Segar, Mosteller, IMC, idade corrigida. São aritmética verificável,
/// não julgamento clínico, e estão cobertas por testes.
///
/// **Não há banco de doses de medicamentos aqui.** Uma tabela de mg/kg escrita
/// de memória é o tipo de erro que machuca criança: a diferença entre 10 e 100
/// mg/kg de paracetamol é a diferença entre analgesia e falência hepática.
///
/// O cálculo de dose existe ([DoseCalculator]), mas é um **motor genérico**: ele
/// recebe mg/kg, dose máxima e concentração de um protocolo cadastrado no
/// Firestore por um profissional identificado, e devolve a conta. O app faz a
/// aritmética; quem responde pela posologia é quem publicou o protocolo.
class PediatricCalculators {
  const PediatricCalculators._();

  /// Superfície corporal pela fórmula de Mosteller.
  ///
  /// `SC (m²) = √(altura_cm × peso_kg / 3600)`
  ///
  /// Escolhida entre as várias existentes por ser a mais simples de conferir
  /// à mão — num plantão, uma fórmula que o profissional consegue refazer de
  /// cabeça vale mais que uma marginalmente mais precisa que ele não consegue.
  static double bodySurfaceArea({
    required double weightKg,
    required double heightCm,
  }) {
    if (weightKg <= 0 || heightCm <= 0) return 0;
    return math.sqrt(heightCm * weightKg / 3600);
  }

  /// Índice de massa corporal.
  static double bmi({required double weightKg, required double heightCm}) {
    if (weightKg <= 0 || heightCm <= 0) return 0;
    final double heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// Necessidade hídrica de manutenção por Holliday-Segar.
  ///
  /// Devolve **as duas formas da regra**, calculadas de forma independente:
  ///
  /// - **Diária (100-50-20 mL/kg/dia)**: 100 nos primeiros 10 kg, 50 nos 10 kg
  ///   seguintes, 20 acima de 20 kg.
  /// - **Horária (4-2-1 mL/kg/h)**: 4 nos primeiros 10 kg, 2 nos 10 kg
  ///   seguintes, 1 acima de 20 kg.
  ///
  /// ## Por que as duas não batem exatamente
  ///
  /// A regra 4-2-1 é o **arredondamento** da diária: 100 mL/kg/dia dá 4,17
  /// mL/kg/h, não 4. Para 10 kg a diferença é 41,7 vs 40 mL/h — pequena, mas
  /// real. Derivar uma da outra faria o app contradizer o número que o
  /// profissional espera ver. Então calculamos as duas e mostramos as duas.
  static FluidRequirement maintenanceFluids(double weightKg) {
    if (weightKg <= 0) {
      return const FluidRequirement(
        perDayMl: 0,
        perHourMl: 0,
        perHourMl421: 0,
      );
    }

    final double perDay;
    if (weightKg <= 10) {
      perDay = weightKg * 100;
    } else if (weightKg <= 20) {
      perDay = 1000 + (weightKg - 10) * 50;
    } else {
      perDay = 1500 + (weightKg - 20) * 20;
    }

    final double perHour421;
    if (weightKg <= 10) {
      perHour421 = weightKg * 4;
    } else if (weightKg <= 20) {
      perHour421 = 40 + (weightKg - 10) * 2;
    } else {
      perHour421 = 60 + (weightKg - 20) * 1;
    }

    return FluidRequirement(
      perDayMl: perDay,
      perHourMl: perDay / 24,
      perHourMl421: perHour421,
    );
  }

  /// Déficit estimado na desidratação.
  ///
  /// `déficit (mL) = peso_kg × % desidratação × 10`
  ///
  /// O percentual é estimativa clínica (turgor, mucosas, perfusão), não medida
  /// — por isso o app pede que o profissional informe, em vez de deduzir.
  static double dehydrationDeficitMl({
    required double weightKg,
    required double percentage,
  }) {
    if (weightKg <= 0 || percentage <= 0) return 0;
    return weightKg * percentage * 10;
  }

  /// Idade corrigida para prematuros, em meses.
  ///
  /// Aplica-se até os 24 meses de idade cronológica.
  static int correctedAgeMonths({
    required int chronologicalMonths,
    required int gestationalWeeks,
  }) {
    if (gestationalWeeks >= 37 || chronologicalMonths > 24) {
      return chronologicalMonths;
    }
    final int weeksMissing = 40 - gestationalWeeks;
    final int corrected =
        chronologicalMonths - (weeksMissing / 4.345).round();
    return corrected < 0 ? 0 : corrected;
  }

  /// Peso estimado por idade, para emergência quando não há balança.
  ///
  /// Fórmula APLS: `peso (kg) = (idade_anos + 4) × 2`, válida de 1 a 10 anos.
  ///
  /// É uma estimativa grosseira, para uso quando pesar não é possível. Havendo
  /// balança, **sempre pese** — a tela deixa isso explícito.
  static double? estimatedWeightKg(int ageYears) {
    if (ageYears < 1 || ageYears > 10) return null;
    return (ageYears + 4) * 2;
  }

  /// Faixas de referência de frequência cardíaca e respiratória em repouso.
  ///
  /// São intervalos amplamente reproduzidos em referências pediátricas. Servem
  /// de orientação: choro, febre e dor alteram os dois de forma significativa.
  static VitalRanges vitalRanges(int ageMonths) {
    if (ageMonths < 1) {
      return const VitalRanges(
        heartRate: (100, 180),
        respiratoryRate: (30, 60),
        label: 'Recém-nascido',
      );
    }
    if (ageMonths < 12) {
      return const VitalRanges(
        heartRate: (100, 160),
        respiratoryRate: (25, 50),
        label: 'Lactente',
      );
    }
    if (ageMonths < 36) {
      return const VitalRanges(
        heartRate: (90, 150),
        respiratoryRate: (20, 40),
        label: '1 a 3 anos',
      );
    }
    if (ageMonths < 72) {
      return const VitalRanges(
        heartRate: (80, 140),
        respiratoryRate: (20, 30),
        label: '3 a 6 anos',
      );
    }
    if (ageMonths < 144) {
      return const VitalRanges(
        heartRate: (70, 120),
        respiratoryRate: (16, 26),
        label: '6 a 12 anos',
      );
    }
    return const VitalRanges(
      heartRate: (60, 100),
      respiratoryRate: (12, 20),
      label: 'Acima de 12 anos',
    );
  }
}

/// Necessidade hídrica calculada, nas duas formas da regra.
class FluidRequirement {
  const FluidRequirement({
    required this.perDayMl,
    required this.perHourMl,
    required this.perHourMl421,
  });

  /// Volume diário pela regra 100-50-20.
  final double perDayMl;

  /// Volume horário derivado do diário (`perDayMl / 24`).
  final double perHourMl;

  /// Volume horário pela regra 4-2-1, calculado direto. Difere levemente de
  /// [perHourMl] porque 4-2-1 é a versão arredondada.
  final double perHourMl421;
}

/// Faixas de sinais vitais por idade.
class VitalRanges {
  const VitalRanges({
    required this.heartRate,
    required this.respiratoryRate,
    required this.label,
  });

  final (int, int) heartRate;
  final (int, int) respiratoryRate;
  final String label;
}

/// Parâmetros de posologia, vindos de um protocolo cadastrado.
///
/// Nenhum valor default: se o protocolo não trouxer o mg/kg, não há cálculo.
/// Um default aqui viraria, na prática, uma recomendação clínica sem autor.
class DoseProtocol {
  const DoseProtocol({
    required this.drugName,
    required this.mgPerKg,
    required this.timesPerDay,
    required this.source,
    this.maxSingleDoseMg,
    this.maxDailyDoseMg,
    this.concentrationMgPerMl,
    this.minAgeMonths,
    this.notes,
  });

  final String drugName;

  /// Dose por quilo, por administração.
  final double mgPerKg;

  final int timesPerDay;

  /// Quem publicou e revisou a posologia. Exibido junto ao resultado.
  final String source;

  final double? maxSingleDoseMg;
  final double? maxDailyDoseMg;

  /// Concentração da apresentação (ex.: 200 mg/mL). Sem ela, o app mostra a
  /// dose em mg e não converte para mL.
  final double? concentrationMgPerMl;

  final int? minAgeMonths;
  final String? notes;
}

/// Resultado de um cálculo de dose.
class DoseResult {
  const DoseResult({
    required this.protocol,
    required this.weightKg,
    required this.singleDoseMg,
    required this.dailyDoseMg,
    this.singleDoseMl,
    this.cappedBySingleMax = false,
    this.cappedByDailyMax = false,
    this.belowMinimumAge = false,
  });

  final DoseProtocol protocol;
  final double weightKg;
  final double singleDoseMg;
  final double dailyDoseMg;
  final double? singleDoseMl;

  /// `true` quando o teto do adulto foi atingido — acontece em adolescentes,
  /// e precisa ficar visível para não parecer erro de conta.
  final bool cappedBySingleMax;
  final bool cappedByDailyMax;

  /// `true` quando a criança é mais nova que o mínimo do protocolo.
  final bool belowMinimumAge;

  bool get hasWarning =>
      cappedBySingleMax || cappedByDailyMax || belowMinimumAge;
}

/// Motor de cálculo de dose.
///
/// Faz aritmética sobre parâmetros que **vêm de fora**. Não conhece nenhum
/// medicamento e não tem tabela embutida.
class DoseCalculator {
  const DoseCalculator._();

  static DoseResult calculate({
    required DoseProtocol protocol,
    required double weightKg,
    int? ageMonths,
  }) {
    if (weightKg <= 0) {
      return DoseResult(
        protocol: protocol,
        weightKg: weightKg,
        singleDoseMg: 0,
        dailyDoseMg: 0,
      );
    }

    double single = protocol.mgPerKg * weightKg;
    bool cappedSingle = false;
    bool cappedDaily = false;

    if (protocol.maxSingleDoseMg != null &&
        single > protocol.maxSingleDoseMg!) {
      single = protocol.maxSingleDoseMg!;
      cappedSingle = true;
    }

    double daily = single * protocol.timesPerDay;

    if (protocol.maxDailyDoseMg != null && daily > protocol.maxDailyDoseMg!) {
      daily = protocol.maxDailyDoseMg!;
      cappedDaily = true;
      // Recalcula a dose unitária para respeitar o teto diário: mantém o
      // número de tomadas e reduz cada uma, em vez de mandar suspender.
      single = daily / protocol.timesPerDay;
    }

    final double? volumeMl = protocol.concentrationMgPerMl == null ||
            protocol.concentrationMgPerMl! <= 0
        ? null
        : single / protocol.concentrationMgPerMl!;

    return DoseResult(
      protocol: protocol,
      weightKg: weightKg,
      singleDoseMg: single,
      dailyDoseMg: daily,
      singleDoseMl: volumeMl,
      cappedBySingleMax: cappedSingle,
      cappedByDailyMax: cappedDaily,
      belowMinimumAge: protocol.minAgeMonths != null &&
          ageMonths != null &&
          ageMonths < protocol.minAgeMonths!,
    );
  }
}

// =============================================================================
// Escalas e cálculos adicionais
//
// ## Por que Glasgow pediátrico e PEWS não estão aqui
//
// Diferente de Apgar (uma única definição universal) ou das fórmulas abaixo
// (aritmética direta, sem variação), **não existe uma única PEWS**. Há a
// versão de Brighton, a Bedside PEWS, a do Royal College e outras, com pontos
// de corte e critérios diferentes entre si — usar qualquer uma como "a" PEWS
// seria apresentar uma escolha institucional como se fosse padrão único.
// Glasgow pediátrico tem o mesmo problema nas faixas etárias mais novas: a
// escala adaptada para lactente varia conforme a fonte.
//
// Implementar uma versão fixa aqui seria inventar autoridade que a escala não
// tem. Se a clínica que for usar esta plataforma adotar uma versão
// específica, ela deve ser cadastrada como protocolo (Módulo 4), com a fonte
// citada — não como calculadora embutida.
// =============================================================================

/// Boletim de Apgar.
///
/// Único critério de pontuação — sem variantes entre serviços — por isso é
/// seguro implementar diretamente. Cada item vale 0, 1 ou 2; o resultado é a
/// soma, aplicada no 1º e no 5º minuto (e no 10º se o 5º ficar abaixo de 7).
class ApgarScore {
  const ApgarScore({
    required this.heartRate,
    required this.respiratoryEffort,
    required this.muscleTone,
    required this.reflexIrritability,
    required this.color,
  })  : assert(heartRate >= 0 && heartRate <= 2),
        assert(respiratoryEffort >= 0 && respiratoryEffort <= 2),
        assert(muscleTone >= 0 && muscleTone <= 2),
        assert(reflexIrritability >= 0 && reflexIrritability <= 2),
        assert(color >= 0 && color <= 2);

  /// 0 ausente · 1 abaixo de 100 · 2 acima de 100.
  final int heartRate;

  /// 0 ausente · 1 fraco/irregular · 2 choro forte.
  final int respiratoryEffort;

  /// 0 flácido · 1 alguma flexão · 2 movimento ativo.
  final int muscleTone;

  /// 0 sem resposta · 1 careta · 2 choro/espirro/tosse.
  final int reflexIrritability;

  /// 0 cianótico/pálido · 1 corpo rosado, extremidades cianóticas · 2 rosado.
  final int color;

  int get total =>
      heartRate + respiratoryEffort + muscleTone + reflexIrritability + color;

  /// Faixa de leitura corrente — não é diagnóstico, é a interpretação
  /// convencional do número.
  String get interpretation {
    if (total >= 7) return 'Normal';
    if (total >= 4) return 'Moderadamente deprimido';
    return 'Gravemente deprimido';
  }
}

/// Taxa de infusão de glicose (TIG), em mg/kg/min.
///
/// `TIG = (mL/h × concentração% × 10) / (60 × peso_kg)`
///
/// Deduzida de: mL/h × (%/100) = g/h de glicose; × 1000 = mg/h; / 60 = mg/min;
/// / peso = mg/kg/min. Verificada com caso de referência antes de entrar no
/// código: RN de 1 kg em SG 10% a 4 mL/h resulta 6,67 mg/kg/min, dentro da
/// faixa inicial neonatal usual.
double glucoseInfusionRateMgKgMin({
  required double infusionRateMlPerHour,
  required double dextroseConcentrationPercent,
  required double weightKg,
}) {
  if (weightKg <= 0 || infusionRateMlPerHour < 0) return 0;
  return (infusionRateMlPerHour * dextroseConcentrationPercent * 10) /
      (60 * weightKg);
}

/// Osmolaridade sérica calculada, em mOsm/L.
///
/// `Osm = 2×Na + Glicose(mg/dL)/18 + Ureia(mg/dL)/6`
///
/// ## Sobre o terceiro termo — ureia, não BUN
///
/// A fórmula clássica usa BUN (nitrogênio ureico), em mg/dL, dividido por 2,8.
/// Laboratório brasileiro relata **ureia** (não BUN), e usar o divisor errado
/// com a unidade errada é o tipo de erro de conversão que se propaga sem
/// nenhum aviso.
///
/// Como ureia (MW 60) carrega 28/60 de nitrogênio, ureia/6 e BUN/2,8 dão
/// exatamente o mesmo resultado em mmol/L — confirmado numericamente antes de
/// implementar. Por isso a função pede ureia, do jeito que o laboratório
/// brasileiro relata, sem exigir conversão manual de quem usa.
double calculatedSerumOsmolarity({
  required double sodiumMEqL,
  required double glucoseMgDl,
  required double ureaMgDl,
}) =>
    2 * sodiumMEqL + glucoseMgDl / 18 + ureaMgDl / 6;

/// Faixa de referência da osmolaridade sérica normal, em mOsm/L.
const (double, double) normalSerumOsmolarityRange = (275, 295);

/// Débito urinário, em mL/kg/h.
class UrineOutput {
  const UrineOutput({required this.rate});

  final double rate;

  /// Ponto de corte convencional de oligúria. Difere por faixa etária na
  /// literatura; este é o valor mais citado para uso geral pediátrico — a
  /// tela deve permitir ajuste quando a clínica adotar critério diferente.
  static const double oliguriaThreshold = 1.0;

  bool get isOliguric => rate < oliguriaThreshold;
}

/// Calcula o débito urinário a partir do volume coletado.
UrineOutput urineOutput({
  required double volumeMl,
  required double weightKg,
  required double hours,
}) {
  if (weightKg <= 0 || hours <= 0) return const UrineOutput(rate: 0);
  return UrineOutput(rate: volumeMl / weightKg / hours);
}

/// Idade gestacional a partir da data da última menstruação (DUM).
class GestationalAge {
  const GestationalAge({required this.weeks, required this.days});

  final int weeks;
  final int days;

  String get label => '$weeks semanas e $days dias';

  /// Classificação por idade gestacional ao nascer (OMS).
  String get classification {
    final int totalWeeks = weeks;
    if (totalWeeks < 28) return 'Prematuridade extrema';
    if (totalWeeks < 32) return 'Prematuridade grave';
    if (totalWeeks < 34) return 'Prematuridade moderada';
    if (totalWeeks < 37) return 'Prematuridade tardia';
    if (totalWeeks < 42) return 'A termo';
    return 'Pós-termo';
  }
}

/// Calcula a idade gestacional pela DUM, na data informada.
///
/// Cálculo obstétrico padrão: dias corridos entre a DUM e a data de
/// referência, divididos em semanas completas e dias restantes.
GestationalAge gestationalAgeFromLmp({
  required DateTime lastMenstrualPeriod,
  DateTime? at,
}) {
  final DateTime reference = at ?? DateTime.now();
  final int days = reference.difference(lastMenstrualPeriod).inDays;
  if (days < 0) return const GestationalAge(weeks: 0, days: 0);
  return GestationalAge(weeks: days ~/ 7, days: days % 7);
}
