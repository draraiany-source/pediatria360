/// Leitura do texto livre da conversa de agendamento: sinais de possível
/// urgência, período do dia, dias da semana e opções mencionadas.
///
/// A detecção de urgência só serve para orientar a procurar atendimento
/// imediato. Não avalia gravidade nem sugere diagnóstico.
library;

import 'slots.dart';

/// Minúsculas e sem acentos, para comparar o que a família digitou.
String normalizeText(String s) {
  const String from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const String to = 'aaaaaeeeeiiiiooooouuuucn';
  final StringBuffer b = StringBuffer();
  for (final int rune in s.toLowerCase().runes) {
    final String ch = String.fromCharCode(rune);
    final int i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Frases que indicam que a criança pode precisar de atendimento imediato.
const List<String> urgencySignals = <String>[
  'nao respira',
  'nao esta respirando',
  'dificuldade para respirar',
  'dificuldade de respirar',
  'falta de ar',
  'respirando mal',
  'cansaco para respirar',
  'chiado forte',
  'labios roxos',
  'boca roxa',
  'ficou roxo',
  'ficou roxa',
  'convuls',
  'crise convulsiva',
  'desmai',
  'desacordad',
  'inconsciente',
  'nao acorda',
  'muito mole',
  'sangramento',
  'sangrando muito',
  'vomitando sangue',
  'engoliu',
  'ingeriu',
  'intoxica',
  'envenen',
  'bateu a cabeca',
  'caiu de cabeca',
  'queimadura',
  'rigidez na nuca',
  'manchas roxas',
  'sem urinar',
  'nao faz xixi',
];

class UrgencyCheck {
  const UrgencyCheck(this.matched);

  final List<String> matched;

  bool get urgent => matched.isNotEmpty;
}

/// Procura sinais de alerta. [ageInMonths] < 3 com febre também conta.
UrgencyCheck checkUrgency(String text, {int? ageInMonths}) {
  final String t = normalizeText(text);
  final List<String> hits = <String>[
    for (final String s in urgencySignals)
      if (t.contains(s)) s,
  ];
  if (ageInMonths != null && ageInMonths < 3 && t.contains('febre')) {
    hits.add('febre em bebê com menos de 3 meses');
  }
  return UrgencyCheck(hits);
}

/// Orientação fixa: não interpreta sintomas nem sugere conduta clínica.
const String urgencyGuidance =
    'Pelo que você descreveu, a criança pode precisar de atendimento '
    'imediato. Procure agora um pronto-socorro ou ligue 192 (SAMU). '
    'Este assistente não faz avaliação médica nem diagnóstico e não '
    'substitui o atendimento de urgência.';

enum AssistantIntent { agendar, remarcar, cancelar, recepcao }

AssistantIntent? detectIntent(String text) {
  final String t = normalizeText(text);
  if (RegExp(r'recepcao|atendente|humano|pessoa|secretaria').hasMatch(t)) {
    return AssistantIntent.recepcao;
  }
  if (RegExp(r'remarc|reagend|trocar (o )?horario|mudar (o )?horario')
      .hasMatch(t)) {
    return AssistantIntent.remarcar;
  }
  if (RegExp(r'cancel|desmarc').hasMatch(t)) return AssistantIntent.cancelar;
  if (RegExp(r'marc|agend|consulta|horario').hasMatch(t)) {
    return AssistantIntent.agendar;
  }
  return null;
}

DayPart? detectDayPart(String text) {
  final String t = normalizeText(text);
  final bool morning = t.contains('manha') || t.contains('cedo');
  final bool afternoon = t.contains('tarde');
  if (morning && !afternoon) return DayPart.manha;
  if (afternoon && !morning) return DayPart.tarde;
  if (RegExp(r'qualquer|tanto faz|indiferente|sem preferencia').hasMatch(t) ||
      (morning && afternoon)) {
    return DayPart.qualquer;
  }
  return null;
}

const Map<String, int> _weekdayWords = <String, int>{
  'segunda': DateTime.monday,
  'terca': DateTime.tuesday,
  'quarta': DateTime.wednesday,
  'quinta': DateTime.thursday,
  'sexta': DateTime.friday,
  'sabado': DateTime.saturday,
};

Set<int> detectWeekdays(String text) {
  final String t = normalizeText(text);
  return <int>{
    for (final MapEntry<String, int> e in _weekdayWords.entries)
      if (t.contains(e.key)) e.value,
  };
}

/// "Próxima semana" começa na segunda seguinte.
bool mentionsNextWeek(String text) =>
    RegExp(r'proxima semana|semana que vem').hasMatch(normalizeText(text));

VisitType? detectVisitType(String text) {
  final String t = normalizeText(text);
  if (t.contains('retorno') || t.contains('revisao')) return VisitType.retorno;
  if (RegExp(r'puericultura|rotina|check.?up|acompanhamento').hasMatch(t)) {
    return VisitType.puericultura;
  }
  if (t.contains('primeira')) return VisitType.primeiraConsulta;
  return null;
}

/// `true` = teleconsulta, `false` = presencial, `null` = não disse.
bool? detectTele(String text) {
  final String t = normalizeText(text);
  if (RegExp(r'tele|online|video|a distancia|remot').hasMatch(t)) return true;
  if (RegExp(r'presencial|consultorio|pessoalmente|na clinica').hasMatch(t)) {
    return false;
  }
  return null;
}

bool isAffirmative(String text) => RegExp(
  r'^(sim|pode|confirm|isso|ok|certo|claro|quero|pode ser)',
).hasMatch(normalizeText(text));

bool isNegative(String text) =>
    RegExp(r'^(nao|negativo|melhor nao|manter)').hasMatch(normalizeText(text));

const Set<String> _stopWords = <String>{
  'dra',
  'exemplo',
  'consulta',
  'com',
  'por',
  'para',
};

/// Opção cujo rótulo (ou a primeira/última palavra) aparece no texto.
String? matchOption(String text, List<String> options) {
  final String t = normalizeText(text);
  if (t.isEmpty) return null;
  for (final String o in options) {
    if (normalizeText(o) == t) return o;
  }
  for (final String o in options) {
    final String n = normalizeText(o);
    if (t.contains(n) || (n.contains(t) && t.length >= 3)) return o;
  }
  for (final String o in options) {
    final List<String> words = normalizeText(o)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(' ')
        .where((String w) => w.length >= 3 && !_stopWords.contains(w))
        .toList();
    for (final String w in <String>{
      if (words.isNotEmpty) words.first,
      if (words.length > 1) words.last,
    }) {
      if (RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(t)) return o;
    }
  }
  return null;
}
