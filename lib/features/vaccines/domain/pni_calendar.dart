import '../../../shared/domain/entities/vaccine.dart';

/// Calendário Nacional de Vacinação (PNI / Ministério da Saúde).
///
/// ## Verifique antes de publicar
///
/// O calendário do PNI é revisado periodicamente — em 2023, por exemplo, a
/// vacina de poliomielite oral (VOP) foi substituída pela inativada (VIP) em
/// todo o esquema. Confira a versão vigente em
/// gov.br/saude/pt-br/vacinacao/calendario antes de publicar o app, e ajuste
/// esta lista se necessário.
///
/// Estruturalmente, a lista é a única fonte do calendário: mudar aqui atualiza
/// a tela, os lembretes e o cálculo de atraso de uma vez só.
class PniCalendar {
  const PniCalendar._();

  /// Mesmo aviso do comentário acima, mas legível pelo código — para a tela
  /// poder mostrá-lo, não só quem lê o arquivo-fonte. O calendário de vacina
  /// já teve o mesmo problema que a curva de crescimento tinha: o aviso
  /// existia, mas só em comentário, invisível para quem usa o app de
  /// verdade.
  static const String warning =
      'Calendário de referência — confira a versão vigente em '
      'gov.br/saude/vacinacao/calendario antes de usar clinicamente.';

  static const List<VaccineDoseSchedule> schedule = <VaccineDoseSchedule>[
    // ------------------------------------------------------------ Ao nascer
    VaccineDoseSchedule(
      vaccineId: 'bcg',
      vaccineName: 'BCG',
      doseLabel: 'Dose única',
      doseIndex: 1,
      ageMonths: 0,
      protects: 'Formas graves de tuberculose',
      notes: 'Deixa a cicatriz característica no braço direito.',
    ),
    VaccineDoseSchedule(
      vaccineId: 'hepatite_b',
      vaccineName: 'Hepatite B',
      doseLabel: 'Ao nascer',
      doseIndex: 1,
      ageMonths: 0,
      protects: 'Hepatite B',
      notes: 'Idealmente nas primeiras 12 horas de vida.',
    ),

    // -------------------------------------------------------------- 2 meses
    VaccineDoseSchedule(
      vaccineId: 'penta',
      vaccineName: 'Pentavalente',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 2,
      protects: 'Difteria, tétano, coqueluche, hepatite B e Haemophilus '
          'influenzae B',
    ),
    VaccineDoseSchedule(
      vaccineId: 'vip',
      vaccineName: 'Poliomielite (VIP)',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 2,
      protects: 'Paralisia infantil',
    ),
    VaccineDoseSchedule(
      vaccineId: 'rotavirus',
      vaccineName: 'Rotavírus',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 2,
      protects: 'Diarreia por rotavírus',
      notes: 'Há limite de idade para a 1ª dose. Se atrasar, procure a '
          'unidade de saúde antes de aplicar.',
    ),
    VaccineDoseSchedule(
      vaccineId: 'pneumo10',
      vaccineName: 'Pneumocócica 10',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 2,
      protects: 'Pneumonia, otite e meningite por pneumococo',
    ),

    // -------------------------------------------------------------- 3 meses
    VaccineDoseSchedule(
      vaccineId: 'meningo_c',
      vaccineName: 'Meningocócica C',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 3,
      protects: 'Meningite meningocócica C',
    ),

    // -------------------------------------------------------------- 4 meses
    VaccineDoseSchedule(
      vaccineId: 'penta',
      vaccineName: 'Pentavalente',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 4,
      protects: 'Difteria, tétano, coqueluche, hepatite B e Hib',
    ),
    VaccineDoseSchedule(
      vaccineId: 'vip',
      vaccineName: 'Poliomielite (VIP)',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 4,
      protects: 'Paralisia infantil',
    ),
    VaccineDoseSchedule(
      vaccineId: 'rotavirus',
      vaccineName: 'Rotavírus',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 4,
      protects: 'Diarreia por rotavírus',
    ),
    VaccineDoseSchedule(
      vaccineId: 'pneumo10',
      vaccineName: 'Pneumocócica 10',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 4,
      protects: 'Pneumonia, otite e meningite por pneumococo',
    ),

    // -------------------------------------------------------------- 5 meses
    VaccineDoseSchedule(
      vaccineId: 'meningo_c',
      vaccineName: 'Meningocócica C',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 5,
      protects: 'Meningite meningocócica C',
    ),

    // -------------------------------------------------------------- 6 meses
    VaccineDoseSchedule(
      vaccineId: 'penta',
      vaccineName: 'Pentavalente',
      doseLabel: '3ª dose',
      doseIndex: 3,
      ageMonths: 6,
      protects: 'Difteria, tétano, coqueluche, hepatite B e Hib',
    ),
    VaccineDoseSchedule(
      vaccineId: 'vip',
      vaccineName: 'Poliomielite (VIP)',
      doseLabel: '3ª dose',
      doseIndex: 3,
      ageMonths: 6,
      protects: 'Paralisia infantil',
    ),
    VaccineDoseSchedule(
      vaccineId: 'influenza',
      vaccineName: 'Influenza (gripe)',
      doseLabel: 'Anual',
      doseIndex: 1,
      ageMonths: 6,
      protects: 'Gripe',
      notes: 'Repetir todo ano durante a campanha, dos 6 meses aos 5 anos.',
    ),

    // -------------------------------------------------------------- 9 meses
    VaccineDoseSchedule(
      vaccineId: 'febre_amarela',
      vaccineName: 'Febre amarela',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 9,
      protects: 'Febre amarela',
    ),

    // ------------------------------------------------------------- 12 meses
    VaccineDoseSchedule(
      vaccineId: 'triplice_viral',
      vaccineName: 'Tríplice viral',
      doseLabel: '1ª dose',
      doseIndex: 1,
      ageMonths: 12,
      protects: 'Sarampo, caxumba e rubéola',
    ),
    VaccineDoseSchedule(
      vaccineId: 'pneumo10',
      vaccineName: 'Pneumocócica 10',
      doseLabel: 'Reforço',
      doseIndex: 3,
      ageMonths: 12,
      protects: 'Pneumonia, otite e meningite por pneumococo',
    ),
    VaccineDoseSchedule(
      vaccineId: 'meningo_c',
      vaccineName: 'Meningocócica C',
      doseLabel: 'Reforço',
      doseIndex: 3,
      ageMonths: 12,
      protects: 'Meningite meningocócica C',
    ),

    // ------------------------------------------------------------- 15 meses
    VaccineDoseSchedule(
      vaccineId: 'dtp',
      vaccineName: 'DTP',
      doseLabel: '1º reforço',
      doseIndex: 1,
      ageMonths: 15,
      protects: 'Difteria, tétano e coqueluche',
    ),
    VaccineDoseSchedule(
      vaccineId: 'vopi',
      vaccineName: 'Poliomielite',
      doseLabel: '1º reforço',
      doseIndex: 4,
      ageMonths: 15,
      protects: 'Paralisia infantil',
    ),
    VaccineDoseSchedule(
      vaccineId: 'hepatite_a',
      vaccineName: 'Hepatite A',
      doseLabel: 'Dose única',
      doseIndex: 1,
      ageMonths: 15,
      protects: 'Hepatite A',
    ),
    VaccineDoseSchedule(
      vaccineId: 'tetra_viral',
      vaccineName: 'Tetra viral',
      doseLabel: 'Dose única',
      doseIndex: 1,
      ageMonths: 15,
      protects: 'Sarampo, caxumba, rubéola e catapora',
    ),

    // -------------------------------------------------------------- 4 anos
    VaccineDoseSchedule(
      vaccineId: 'dtp',
      vaccineName: 'DTP',
      doseLabel: '2º reforço',
      doseIndex: 2,
      ageMonths: 48,
      protects: 'Difteria, tétano e coqueluche',
    ),
    VaccineDoseSchedule(
      vaccineId: 'vopi',
      vaccineName: 'Poliomielite',
      doseLabel: '2º reforço',
      doseIndex: 5,
      ageMonths: 48,
      protects: 'Paralisia infantil',
    ),
    VaccineDoseSchedule(
      vaccineId: 'varicela',
      vaccineName: 'Varicela',
      doseLabel: '2ª dose',
      doseIndex: 2,
      ageMonths: 48,
      protects: 'Catapora',
    ),
    VaccineDoseSchedule(
      vaccineId: 'febre_amarela',
      vaccineName: 'Febre amarela',
      doseLabel: 'Reforço',
      doseIndex: 2,
      ageMonths: 48,
      protects: 'Febre amarela',
    ),

    // -------------------------------------------------------------- 9 anos
    VaccineDoseSchedule(
      vaccineId: 'hpv',
      vaccineName: 'HPV',
      doseLabel: 'Dose única',
      doseIndex: 1,
      ageMonths: 108,
      protects: 'Cânceres e verrugas causados pelo HPV',
      notes: 'Indicada dos 9 aos 14 anos.',
    ),

    // ------------------------------------------------------------- 11 anos
    VaccineDoseSchedule(
      vaccineId: 'meningo_acwy',
      vaccineName: 'Meningocócica ACWY',
      doseLabel: 'Reforço',
      doseIndex: 1,
      ageMonths: 132,
      protects: 'Meningite A, C, W e Y',
      notes: 'Indicada dos 11 aos 14 anos.',
    ),
  ];

  /// Doses previstas até uma idade, ordenadas cronologicamente.
  static List<VaccineDoseSchedule> upTo(int ageMonths) => schedule
      .where((VaccineDoseSchedule d) => d.ageMonths <= ageMonths)
      .toList(growable: false)
    ..sort(
      (VaccineDoseSchedule a, VaccineDoseSchedule b) =>
          a.ageMonths.compareTo(b.ageMonths),
    );

  /// Agrupa o calendário por idade — é assim que a caderneta é lida.
  static Map<int, List<VaccineDoseSchedule>> groupedByAge() {
    final Map<int, List<VaccineDoseSchedule>> grouped =
        <int, List<VaccineDoseSchedule>>{};
    for (final VaccineDoseSchedule dose in schedule) {
      grouped.putIfAbsent(dose.ageMonths, () => <VaccineDoseSchedule>[]).add(dose);
    }
    return grouped;
  }

  static VaccineDoseSchedule? find(String vaccineId, int doseIndex) {
    for (final VaccineDoseSchedule dose in schedule) {
      if (dose.vaccineId == vaccineId && dose.doseIndex == doseIndex) {
        return dose;
      }
    }
    return null;
  }

  /// Data prevista de uma dose para uma criança.
  ///
  /// Prematuros seguem a **idade cronológica** no calendário vacinal — ao
  /// contrário das curvas de crescimento, que usam idade corrigida. Vacinar
  /// pela idade corrigida atrasaria a proteção justamente em quem tem mais
  /// risco de infecção grave.
  static DateTime dueDateFor(DateTime birthDate, VaccineDoseSchedule dose) =>
      DateTime(
        birthDate.year,
        birthDate.month + dose.ageMonths,
        birthDate.day,
      );
}
