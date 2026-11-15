/// Motor deterministico da Tia Cris — sem diagnostico e sem inventar dados.
enum TiaCrisIntent {
  greeting,
  hoursFaq,
  bookingHelp,
  rescheduleHelp,
  cancelHelp,
  kidsHelp,
  handoffHuman,
  whatsappStatus,
  refuseClinical,
  unknown,
}

class TiaCrisReply {
  const TiaCrisReply({
    required this.intent,
    required this.text,
    this.suggestHandoff = false,
    this.suggestAgenda = false,
    this.suggestKids = false,
    this.suggestWhatsApp = false,
  });

  final TiaCrisIntent intent;
  final String text;
  final bool suggestHandoff;
  final bool suggestAgenda;
  final bool suggestKids;
  final bool suggestWhatsApp;
}

class TiaCrisEngine {
  const TiaCrisEngine();

  TiaCrisReply reply(String raw) {
    final String q = raw.trim().toLowerCase();
    if (q.isEmpty) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.unknown,
        text: 'Pode escrever sua duvida administrativa? '
            'Nao consigo ver prontuario nem receitas.',
      );
    }

    if (_hasAny(q, <String>['dor', 'febre', 'diagn', 'receita', 'exame', 'cid', 'remedio', 'dose'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.refuseClinical,
        text: 'Nao posso orientar sobre saude, diagnostico ou medicamentos. '
            'Vou encaminhar voce para a equipe humana da clinica.',
        suggestHandoff: true,
      );
    }

    if (_hasAny(q, <String>['ola', 'oi', 'bom dia', 'boa tarde', 'boa noite'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.greeting,
        text: 'Ola! Sou a Tia Cris, recepcionista virtual. '
            'Posso ajudar com agenda, confirmacao e encaminhamento. '
            'Nao acesso prontuario.',
      );
    }

    if (_hasAny(q, <String>['horario', 'abre', 'funcionamento', 'expediente'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.hoursFaq,
        text: 'Os horarios oficiais sao os cadastrados na agenda da clinica. '
            'Posso abrir a agenda real para consultar vagas — '
            'nao invento horarios.',
        suggestAgenda: true,
      );
    }

    if (_hasAny(q, <String>['remarcar', 'reagend'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.rescheduleHelp,
        text: 'Para remarcar, uso o fluxo oficial de reagendamento da clinica '
            '(com validacao de conflito no servidor). '
            'Posso abrir a agenda ou chamar a recepcao humana.',
        suggestAgenda: true,
        suggestHandoff: true,
      );
    }

    if (_hasAny(q, <String>['cancel'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.cancelHelp,
        text: 'Cancelamentos autorizados passam pelo status oficial da consulta. '
            'Abra a agenda ou peça a recepcao humana para concluir.',
        suggestAgenda: true,
        suggestHandoff: true,
      );
    }

    if (_hasAny(q, <String>['agend', 'marcar', 'consulta', 'vaga', 'horario livre'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.bookingHelp,
        text: 'Consigo orientar o agendamento usando a agenda real da clinica. '
            'Com a flag de booking ligada, a reserva passa pelas Functions '
            'getScheduleSlots/scheduleAppointment — sem inventar vagas.',
        suggestAgenda: true,
      );
    }

    if (_hasAny(q, <String>['jogo', 'kids', 'brincar', 'crianca na sala'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.kidsHelp,
        text: 'O Espaco Kids e para a sala de espera: jogos educativos, '
            'sem prontuario. Posso abrir o Espaco Kids se estiver liberado.',
        suggestKids: true,
      );
    }

    if (_hasAny(q, <String>['whatsapp', 'mensagem', 'lembrete'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.whatsappStatus,
        text: 'Lembretes por WhatsApp so saem com consentimento e canal '
            'oficial configurado. Posso mostrar o status real do canal — '
            'nunca marco mensagem como enviada sem o provedor confirmar.',
        suggestWhatsApp: true,
        suggestHandoff: true,
      );
    }

    if (_hasAny(q, <String>['humano', 'pessoa', 'recepcao', 'atendente'])) {
      return const TiaCrisReply(
        intent: TiaCrisIntent.handoffHuman,
        text: 'Claro — vou encaminhar para a recepcao humana.',
        suggestHandoff: true,
        suggestAgenda: true,
      );
    }

    return const TiaCrisReply(
      intent: TiaCrisIntent.unknown,
      text: 'Nao tenho essa informacao cadastrada. '
          'Prefiro encaminhar para a equipe humana a inventar uma resposta.',
      suggestHandoff: true,
    );
  }

  static bool _hasAny(String q, List<String> keys) {
    for (final String k in keys) {
      if (q.contains(k)) {
        return true;
      }
    }
    return false;
  }
}
