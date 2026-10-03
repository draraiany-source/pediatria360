/// Modelos de exemplo de orientação (sono seguro, rotina e puericultura) e
/// de evolução de puericultura.
///
/// São pontos de partida para a demonstração, escritos sem copiar material
/// de terceiros. Trazem trechos "[a definir: ...]" que o profissional
/// precisa completar: a emissão fica bloqueada enquanto houver colchetes.
/// Conteúdo pendente de validação clínica antes de qualquer uso real.
library;

import '../clinical/orientation_templates.dart';
import 'age_band.dart';
import 'well_child_templates.dart';
import 'well_child_visit.dart';

const String kSafeSleepNotice =
    'Ruído branco, aplicativos ou aparelhos para ninar não substituem as '
    'orientações de sono seguro.';

String _safeInfant(String extra) =>
    'Orientações de sono seguro para {{crianca}} ({{idade}}), conversadas '
    'com {{responsavel}} em {{data}}.\n\n'
    '1. Coloque {{crianca}} para dormir sempre de barriga para cima, também '
    'nos cochilos.\n'
    '2. Use berço ou moisés próprio, com colchão firme, do tamanho certo e '
    'lençol bem preso.\n'
    '3. Deixe o berço vazio: sem travesseiro, protetor lateral, cobertor '
    'solto, bichos de pelúcia ou outros objetos.\n'
    '4. Não deixe {{crianca}} dormir em sofá, poltrona, almofada ou '
    'bebê-conforto fora do carro.\n'
    '5. Evite agasalhar demais, não cubra a cabeça e mantenha a casa sem '
    'fumaça de cigarro.\n'
    '$extra\n'
    '7. $kSafeSleepNotice';

List<OrientationTemplate> guidanceExamples({
  required String author,
  required DateTime now,
}) {
  OrientationTemplate t(
    String id,
    String title,
    OrientationTopic topic,
    ChildAgeBand? band,
    String body,
    int daysAgo,
  ) => OrientationTemplate(
    id: id,
    title: 'Modelo de exemplo: $title',
    body: body,
    author: author,
    updatedAt: now.subtract(Duration(days: daysAgo)),
    isExample: true,
    topic: topic,
    band: band,
  );

  return <OrientationTemplate>[
    t(
      'os0',
      'sono seguro (0 a 3 meses)',
      OrientationTopic.sonoSeguro,
      ChildAgeBand.ate3m,
      _safeInfant(
        '6. [a definir: orientação do serviço sobre quarto compartilhado, '
        'cama compartilhada e chupeta]',
      ),
      30,
    ),
    t(
      'os1',
      'sono seguro (4 a 11 meses)',
      OrientationTopic.sonoSeguro,
      ChildAgeBand.de4a11m,
      _safeInfant(
        '6. [a definir: orientação do serviço para quando {{crianca}} já '
        'rola sozinha e sobre o ajuste da altura do colchão]',
      ),
      30,
    ),
    t(
      'os2',
      'sono seguro (1 a 2 anos)',
      OrientationTopic.sonoSeguro,
      ChildAgeBand.de1a2a,
      'Orientações de sono seguro para {{crianca}} ({{idade}}), conversadas '
          'com {{responsavel}} em {{data}}.\n\n'
          '1. Mantenha o berço ou a cama sem objetos que sirvam de degrau.\n'
          '2. Deixe cordões de cortina, fios e tomadas longe do alcance.\n'
          '3. [a definir: orientação do serviço sobre a passagem do berço '
          'para a cama e sobre travesseiro e cobertor]\n'
          '4. $kSafeSleepNotice',
      30,
    ),
    t(
      'or0',
      'rotina e sono (0 a 3 meses)',
      OrientationTopic.rotina,
      ChildAgeBand.ate3m,
      'Rotina de {{crianca}} ({{idade}}), combinada com {{responsavel}} em '
          '{{data}}.\n\n'
          '1. Nos primeiros meses o sono ainda não tem horário fixo.\n'
          '2. De dia, ambiente claro e com os sons da casa; à noite, luz '
          'baixa e pouca conversa nas mamadas.\n'
          '3. [a definir: total de sono esperado para a faixa, conforme a '
          'referência adotada pelo serviço]\n'
          '4. Registre no diário do app os horários de sono, cochilos e '
          'despertares para conversarmos na próxima consulta.',
      25,
    ),
    t(
      'or1',
      'rotina e sono (4 a 11 meses)',
      OrientationTopic.rotina,
      ChildAgeBand.de4a11m,
      'Rotina de {{crianca}} ({{idade}}), combinada com {{responsavel}} em '
          '{{data}}.\n\n'
          '1. Procure horários parecidos todos os dias para dormir e '
          'acordar.\n'
          '2. Faça um ritual curto antes de dormir, sempre na mesma ordem '
          '(por exemplo: banho, troca, canção).\n'
          '3. Coloque {{crianca}} no berço sonolenta, ainda acordada.\n'
          '4. [a definir: número de cochilos e total de sono para a faixa, '
          'conforme a referência adotada pelo serviço]\n'
          '5. Registre no diário do app o sono noturno, os cochilos e os '
          'despertares.',
      25,
    ),
    t(
      'or2',
      'rotina e sono (1 a 2 anos)',
      OrientationTopic.rotina,
      ChildAgeBand.de1a2a,
      'Rotina de {{crianca}} ({{idade}}), combinada com {{responsavel}} em '
          '{{data}}.\n\n'
          '1. Mantenha horário regular para dormir, também nos fins de '
          'semana.\n'
          '2. Ritual curto antes de dormir, com luz baixa e sem telas.\n'
          '3. [a definir: cochilos e total de sono para a faixa, e tempo sem '
          'telas antes de dormir, conforme a referência adotada]\n'
          '4. Registre no diário do app os despertares da noite.',
      25,
    ),
    t(
      'or3',
      'rotina e sono (3 a 5 anos)',
      OrientationTopic.rotina,
      ChildAgeBand.de3a5a,
      'Rotina de {{crianca}} ({{idade}}), combinada com {{responsavel}} em '
          '{{data}}.\n\n'
          '1. Horário regular para dormir e acordar.\n'
          '2. Telas fora do quarto; brincadeiras calmas antes de dormir.\n'
          '3. Atividade física e brincadeiras ao ar livre durante o dia.\n'
          '4. [a definir: total de sono para a faixa, conforme a referência '
          'adotada pelo serviço]',
      25,
    ),
    t(
      'or4',
      'rotina e sono (6 anos ou mais)',
      OrientationTopic.rotina,
      ChildAgeBand.de6a,
      'Rotina de {{crianca}} ({{idade}}), combinada com {{responsavel}} em '
          '{{data}}.\n\n'
          '1. Horário regular para dormir, inclusive nos fins de semana.\n'
          '2. Celular, tablet e TV fora do quarto à noite.\n'
          '3. [a definir: total de sono para a faixa e orientação sobre '
          'cafeína, conforme a referência adotada pelo serviço]',
      25,
    ),
    t(
      'op1',
      'consulta de puericultura',
      OrientationTopic.puericultura,
      null,
      'Orientações da consulta de puericultura de {{crianca}} ({{idade}}) '
          'em {{data}}, para {{responsavel}}.\n\n'
          '1. Alimentação: [a definir]\n'
          '2. Sono: [a definir]\n'
          '3. Vacinas: leve a carteira de vacinação em todas as consultas.\n'
          '4. Próxima consulta: [a definir]\n'
          '5. Procure atendimento antes da data combinada se houver piora ou '
          'qualquer preocupação.',
      15,
    ),
  ];
}

List<WellChildTemplate> wellChildTemplateExamples({
  required String author,
  required DateTime now,
}) => <WellChildTemplate>[
  WellChildTemplate(
    id: 'wt1',
    name: 'Puericultura 4 a 11 meses (exemplo)',
    band: ChildAgeBand.de4a11m,
    author: author,
    updatedAt: now.subtract(const Duration(days: 40)),
    isExample: true,
    fields: const <WellChildSection, String>{
      WellChildSection.historia:
          '{{responsavel}} relata [preencher: intercorrências desde a última consulta].',
      WellChildSection.alimentacao:
          '[preencher: aleitamento, alimentos introduzidos e aceitação]',
      WellChildSection.sono: '[preencher: local, rotina e despertares]',
      WellChildSection.eliminacoes: '[preencher]',
      WellChildSection.vacinacao: 'Carteira conferida: [preencher]',
      WellChildSection.exameFisico: '[preencher]',
      WellChildSection.desenvolvimento:
          'Marcos registrados na lista da consulta. [preencher]',
      WellChildSection.plano:
          'Retorno em [a definir]. Orientações entregues por escrito.',
    },
    guidance: 'Sono seguro e rotina: [a definir].',
  ),
  WellChildTemplate(
    id: 'wt2',
    name: 'Puericultura 1 a 2 anos (exemplo)',
    band: ChildAgeBand.de1a2a,
    author: author,
    updatedAt: now.subtract(const Duration(days: 20)),
    isExample: true,
    fields: const <WellChildSection, String>{
      WellChildSection.historia:
          '{{responsavel}} relata [preencher: intercorrências desde a última consulta].',
      WellChildSection.alimentacao:
          '[preencher: refeições da família, leite, aceitação]',
      WellChildSection.sono: '[preencher: horários, cochilos e despertares]',
      WellChildSection.eliminacoes: '[preencher]',
      WellChildSection.vacinacao: 'Carteira conferida: [preencher]',
      WellChildSection.exameFisico: '[preencher]',
      WellChildSection.desenvolvimento:
          'Marcos registrados na lista da consulta. [preencher]',
      WellChildSection.plano:
          'Retorno em [a definir]. Orientações entregues por escrito.',
    },
    guidance: 'Rotina de sono, telas e alimentação: [a definir].',
  ),
];
