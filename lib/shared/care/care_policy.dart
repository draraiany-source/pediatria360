import 'care_model.dart';

/// Regras de acesso do cuidado multidisciplinar. As mesmas regras estão em
/// `firestore.rules` (coleção `care_teams`) e em `storage.rules` (`care/`).
class CarePolicy {
  const CarePolicy._();

  static Set<CareAction> actionsFor(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => const <CareAction>{
      CareAction.prescrever,
      CareAction.solicitarExames,
      CareAction.atestadoMedico,
      CareAction.orientacaoFamilia,
      CareAction.liberarFamilia,
      CareAction.planoCompartilhado,
      CareAction.encaminhar,
      CareAction.solicitarParecer,
      CareAction.mensagemEquipe,
      CareAction.rascunhoIa,
    },
    CareSpecialty.psicologia => const <CareAction>{
      CareAction.avaliacaoPsicologica,
      CareAction.registroReservado,
      CareAction.orientacaoFamilia,
      CareAction.liberarFamilia,
      CareAction.planoCompartilhado,
      CareAction.encaminhar,
      CareAction.solicitarParecer,
      CareAction.mensagemEquipe,
      CareAction.rascunhoIa,
    },
    CareSpecialty.fisioterapia => const <CareAction>{
      CareAction.avaliacaoFuncional,
      CareAction.exerciciosCasa,
      CareAction.orientacaoFamilia,
      CareAction.liberarFamilia,
      CareAction.planoCompartilhado,
      CareAction.encaminhar,
      CareAction.solicitarParecer,
      CareAction.mensagemEquipe,
      CareAction.rascunhoIa,
    },
    CareSpecialty.fonoaudiologia ||
    CareSpecialty.terapiaOcupacional => const <CareAction>{
      CareAction.avaliacaoFuncional,
      CareAction.exerciciosCasa,
      CareAction.orientacaoFamilia,
      CareAction.liberarFamilia,
      CareAction.planoCompartilhado,
      CareAction.encaminhar,
      CareAction.solicitarParecer,
      CareAction.mensagemEquipe,
    },
    CareSpecialty.nutricao => const <CareAction>{
      CareAction.orientacaoFamilia,
      CareAction.liberarFamilia,
      CareAction.planoCompartilhado,
      CareAction.encaminhar,
      CareAction.solicitarParecer,
      CareAction.mensagemEquipe,
    },
  };

  static Set<CareRecordKind> kindsFor(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => const <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.avaliacao,
      CareRecordKind.evolucao,
      CareRecordKind.objetivos,
      CareRecordKind.orientacao,
    },
    CareSpecialty.psicologia => const <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.avaliacao,
      CareRecordKind.sessao,
      CareRecordKind.planoTerapeutico,
      CareRecordKind.objetivos,
      CareRecordKind.orientacao,
    },
    CareSpecialty.fisioterapia => const <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.avaliacaoFuncional,
      CareRecordKind.objetivos,
      CareRecordKind.planoSessoes,
      CareRecordKind.intervencao,
      CareRecordKind.evolucao,
      CareRecordKind.medida,
      CareRecordKind.atividadeCasa,
      CareRecordKind.orientacao,
    },
    CareSpecialty.fonoaudiologia ||
    CareSpecialty.terapiaOcupacional => const <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.avaliacao,
      CareRecordKind.objetivos,
      CareRecordKind.evolucao,
      CareRecordKind.atividadeCasa,
      CareRecordKind.orientacao,
    },
    CareSpecialty.nutricao => const <CareRecordKind>{
      CareRecordKind.resumoEquipe,
      CareRecordKind.avaliacao,
      CareRecordKind.objetivos,
      CareRecordKind.evolucao,
      CareRecordKind.orientacao,
    },
  };

  static Set<CareDocKind> docsFor(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => const <CareDocKind>{
      CareDocKind.atestadoMedico,
      CareDocKind.receituario,
      CareDocKind.solicitacaoExames,
      CareDocKind.declaracaoComparecimento,
      CareDocKind.encaminhamento,
      CareDocKind.orientacoes,
    },
    CareSpecialty.psicologia => const <CareDocKind>{
      CareDocKind.declaracaoComparecimento,
      CareDocKind.relatorioPsicologico,
      CareDocKind.encaminhamento,
      CareDocKind.orientacoes,
    },
    CareSpecialty.fisioterapia => const <CareDocKind>{
      CareDocKind.declaracaoComparecimento,
      CareDocKind.relatorioFisioterapeutico,
      CareDocKind.planoExerciciosCasa,
      CareDocKind.encaminhamento,
      CareDocKind.orientacoes,
    },
    CareSpecialty.fonoaudiologia ||
    CareSpecialty.terapiaOcupacional ||
    CareSpecialty.nutricao => const <CareDocKind>{
      CareDocKind.declaracaoComparecimento,
      CareDocKind.encaminhamento,
      CareDocKind.orientacoes,
    },
  };

  /// Registro reservado: hoje só a psicologia.
  static bool canReserve(CareSpecialty s) =>
      actionsFor(s).contains(CareAction.registroReservado);

  static bool allows(CareSpecialty s, CareAction a) =>
      actionsFor(s).contains(a);

  /// Vínculo ativo do profissional com a criança, se houver.
  static CareLink? activeLink(
    Iterable<CareLink> links,
    CareActor actor,
    String childId,
  ) {
    if (!actor.isProfessional) return null;
    for (final CareLink l in links) {
      if (l.childId == childId && l.professionalId == actor.id && l.active) {
        return l;
      }
    }
    return null;
  }

  /// Leitura de um registro.
  ///
  /// - o autor sempre lê o que escreveu (guarda legal), mesmo sem vínculo;
  /// - reservado: só o autor;
  /// - equipe: profissional com vínculo ativo na mesma clínica do registro;
  /// - família: o responsável da criança, quando liberado.
  static bool canRead(
    CareActor actor,
    CareRecord record,
    Iterable<CareLink> links,
  ) {
    if (actor.isProfessional) {
      if (record.authorId == actor.id) return true;
      if (record.visibility == CareVisibility.reservado) return false;
      final CareLink? link = activeLink(links, actor, record.childId);
      return link != null && link.clinicId == record.clinicId;
    }
    if (actor.isFamily) {
      return actor.guardianOf.contains(record.childId) &&
          record.visibility == CareVisibility.familia &&
          record.releasedAt != null;
    }
    return false;
  }

  /// Motivo da recusa de um novo registro, ou `null` se permitido.
  static String? denyCreate({
    required CareLink? link,
    required CareRecordKind kind,
    required CareVisibility visibility,
  }) {
    if (link == null) {
      return 'Sem vínculo ativo com a criança: registro não permitido.';
    }
    if (!kindsFor(link.specialty).contains(kind)) {
      return '${kind.label} não é registro da ${link.specialty.area}.';
    }
    if (visibility == CareVisibility.reservado &&
        !canReserve(link.specialty)) {
      return 'Registro reservado não disponível para '
          '${link.specialty.area}.';
    }
    if (visibility == CareVisibility.familia && !kind.canGoToFamily) {
      return 'Só orientações e atividades para casa vão para a família.';
    }
    return null;
  }
}
