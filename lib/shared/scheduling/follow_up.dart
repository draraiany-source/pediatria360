/// Acompanhamento de pacientes: frequentes, inativos e com retorno próximo.
///
/// Regras puras (sem Flutter, sem Firebase) para a clínica configurar os
/// critérios e o painel mostrar a lista de cada indicador. O mesmo código
/// serve à demonstração e ao app real.
library;

enum FollowUpCategory {
  frequente('Frequentes'),
  inativo('Inativos'),
  retornoProximo('Retorno próximo');

  const FollowUpCategory(this.label);

  final String label;

  static FollowUpCategory? fromSlug(String? slug) {
    for (final FollowUpCategory c in values) {
      if (c.name == slug) return c;
    }
    return null;
  }
}

/// Critérios definidos pela clínica.
class FollowUpCriteria {
  const FollowUpCriteria({
    this.inactiveAfterMonths = 6,
    this.returnSoonDays = 15,
    this.frequentMinVisits = 3,
    this.frequentWindowMonths = 12,
  });

  /// Sem consulta há este número de meses (e sem consulta futura) = inativo.
  final int inactiveAfterMonths;

  /// Faltando até este número de dias para a data recomendada = retorno
  /// próximo. Retorno vencido e ainda não agendado também entra.
  final int returnSoonDays;

  /// Pelo menos este número de consultas no período = frequente.
  final int frequentMinVisits;

  /// Período padrão (meses) para contar as consultas.
  final int frequentWindowMonths;

  static const int maxInactiveMonths = 36;
  static const int maxReturnSoonDays = 90;
  static const int maxFrequentVisits = 20;
  static const int maxWindowMonths = 24;

  /// Mensagem para a clínica quando algum valor está fora da faixa.
  String? validate() {
    if (inactiveAfterMonths < 1 || inactiveAfterMonths > maxInactiveMonths) {
      return 'Inativo: use de 1 a $maxInactiveMonths meses sem consulta.';
    }
    if (returnSoonDays < 1 || returnSoonDays > maxReturnSoonDays) {
      return 'Retorno próximo: use de 1 a $maxReturnSoonDays dias.';
    }
    if (frequentMinVisits < 2 || frequentMinVisits > maxFrequentVisits) {
      return 'Frequente: use de 2 a $maxFrequentVisits consultas.';
    }
    if (frequentWindowMonths < 1 || frequentWindowMonths > maxWindowMonths) {
      return 'Período: use de 1 a $maxWindowMonths meses.';
    }
    return null;
  }

  FollowUpCriteria copyWith({
    int? inactiveAfterMonths,
    int? returnSoonDays,
    int? frequentMinVisits,
    int? frequentWindowMonths,
  }) => FollowUpCriteria(
    inactiveAfterMonths: inactiveAfterMonths ?? this.inactiveAfterMonths,
    returnSoonDays: returnSoonDays ?? this.returnSoonDays,
    frequentMinVisits: frequentMinVisits ?? this.frequentMinVisits,
    frequentWindowMonths: frequentWindowMonths ?? this.frequentWindowMonths,
  );

  String describe(FollowUpCategory c) => switch (c) {
    FollowUpCategory.frequente =>
      '$frequentMinVisits ou mais consultas no período',
    FollowUpCategory.inativo =>
      'Sem consulta há $inactiveAfterMonths '
          '${inactiveAfterMonths == 1 ? 'mês' : 'meses'} e sem consulta futura',
    FollowUpCategory.retornoProximo =>
      'Faltam até $returnSoonDays dias para o retorno recomendado '
          '(ou já venceu sem agendamento)',
  };

  @override
  bool operator ==(Object other) =>
      other is FollowUpCriteria &&
      other.inactiveAfterMonths == inactiveAfterMonths &&
      other.returnSoonDays == returnSoonDays &&
      other.frequentMinVisits == frequentMinVisits &&
      other.frequentWindowMonths == frequentWindowMonths;

  @override
  int get hashCode => Object.hash(
    inactiveAfterMonths,
    returnSoonDays,
    frequentMinVisits,
    frequentWindowMonths,
  );
}

/// Dados de um paciente, já filtrados por profissional/clínica.
class FollowUpInput {
  const FollowUpInput({
    required this.patientId,
    required this.visits,
    this.nextAppointment,
    this.recommendedReturn,
    this.contactAttempts = 0,
  });

  final String patientId;

  /// Consultas realizadas (datas). Canceladas e faltas não entram.
  final List<DateTime> visits;

  /// Próxima consulta marcada (não cancelada), se houver.
  final DateTime? nextAppointment;

  /// Data recomendada para retorno, registrada pelo profissional.
  final DateTime? recommendedReturn;

  final int contactAttempts;
}

class FollowUpStatus {
  const FollowUpStatus({
    required this.patientId,
    required this.categories,
    required this.visitsInPeriod,
    required this.contactAttempts,
    this.lastVisit,
    this.nextAppointment,
    this.recommendedReturn,
    this.daysToReturn,
    this.inactiveButScheduled = false,
  });

  final String patientId;
  final Set<FollowUpCategory> categories;
  final int visitsInPeriod;
  final int contactAttempts;
  final DateTime? lastVisit;
  final DateTime? nextAppointment;
  final DateTime? recommendedReturn;

  /// Dias até o retorno recomendado (negativo = vencido).
  final int? daysToReturn;

  /// Passou do prazo de inatividade, mas já tem consulta futura marcada —
  /// por isso NÃO é classificado como inativo.
  final bool inactiveButScheduled;

  bool isIn(FollowUpCategory c) => categories.contains(c);

  /// Retorno recomendado já coberto por uma consulta marcada.
  bool get returnBooked => recommendedReturn != null && nextAppointment != null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Subtrai meses de calendário, ajustando o dia ao fim do mês se preciso.
DateTime subtractMonths(DateTime d, int months) {
  final int totalMonths = d.year * 12 + (d.month - 1) - months;
  final int year = totalMonths ~/ 12;
  final int month = totalMonths % 12 + 1;
  final int lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

/// Classifica um paciente. [periodMonths] é o período do filtro do painel
/// (quando nulo, usa o período padrão dos critérios).
FollowUpStatus classifyFollowUp(
  FollowUpInput input,
  FollowUpCriteria criteria, {
  required DateTime now,
  int? periodMonths,
}) {
  final DateTime today = _dateOnly(now);
  final List<DateTime> past =
      input.visits.where((DateTime v) => !v.isAfter(now)).toList()
        ..sort((DateTime a, DateTime b) => b.compareTo(a));
  final DateTime? last = past.isEmpty ? null : past.first;

  final DateTime periodStart = subtractMonths(
    today,
    periodMonths ?? criteria.frequentWindowMonths,
  );
  final int inPeriod = past
      .where((DateTime v) => !_dateOnly(v).isBefore(periodStart))
      .length;

  // Consulta de hoje ainda não concluída conta como marcada, mesmo depois
  // do horário: a criança está sendo atendida ou atrasou.
  final DateTime? next =
      input.nextAppointment != null &&
          !_dateOnly(input.nextAppointment!).isBefore(today)
      ? input.nextAppointment
      : null;

  final Set<FollowUpCategory> cats = <FollowUpCategory>{};
  if (inPeriod >= criteria.frequentMinVisits) {
    cats.add(FollowUpCategory.frequente);
  }

  bool suppressed = false;
  if (last != null) {
    final DateTime limit = subtractMonths(today, criteria.inactiveAfterMonths);
    if (_dateOnly(last).isBefore(limit) ||
        _dateOnly(last).isAtSameMomentAs(limit)) {
      if (next == null) {
        cats.add(FollowUpCategory.inativo);
      } else {
        suppressed = true;
      }
    }
  }

  int? days;
  if (input.recommendedReturn != null) {
    days = _dateOnly(input.recommendedReturn!).difference(today).inDays;
    final bool soon = days >= 0 && days <= criteria.returnSoonDays;
    final bool overdueUnbooked = days < 0 && next == null;
    if (soon || overdueUnbooked) cats.add(FollowUpCategory.retornoProximo);
  }

  return FollowUpStatus(
    patientId: input.patientId,
    categories: cats,
    visitsInPeriod: inPeriod,
    contactAttempts: input.contactAttempts,
    lastVisit: last,
    nextAppointment: next,
    recommendedReturn: input.recommendedReturn,
    daysToReturn: days,
    inactiveButScheduled: suppressed,
  );
}

/// Contagem por indicador para o painel.
Map<FollowUpCategory, int> countFollowUp(Iterable<FollowUpStatus> list) =>
    <FollowUpCategory, int>{
      for (final FollowUpCategory c in FollowUpCategory.values)
        c: list.where((FollowUpStatus s) => s.isIn(c)).length,
    };

/// Texto curto do retorno para a lista.
String returnLabel(FollowUpStatus s) {
  final int? d = s.daysToReturn;
  if (d == null) return 'Sem retorno recomendado';
  if (d < 0) return 'Retorno vencido há ${-d} ${d == -1 ? 'dia' : 'dias'}';
  if (d == 0) return 'Retorno recomendado para hoje';
  return 'Retorno em $d ${d == 1 ? 'dia' : 'dias'}';
}
