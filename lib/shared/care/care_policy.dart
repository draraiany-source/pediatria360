import 'care_model.dart';

/// Regras de acesso do cuidado multidisciplinar. As mesmas regras estão em
/// `firestore.rules` (coleção `care_teams`) e em `storage.rules` (`care/`).
class CarePolicy {
  const CarePolicy._();

  static const Set<CareAction> _sharing = <CareAction>{
    CareAction.orientacaoFamilia,
    CareAction.liberarFamilia,
    CareAction.compartilharResumo,
    CareAction.concederAcesso,
    CareAction.planoCompartilhado,
    CareAction.encaminhar,
    CareAction.solicitarParecer,
    CareAction.mensagemEquipe,
  };

  static Set<CareAction> actionsFor(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => const <CareAction>{
      CareAction.prescrever,
      CareAction.solicitarExames,
      CareAction.atestadoMedico,
      ..._sharing,
      CareAction.rascunhoIa,
    },
    CareSpecialty.psicologia => const <CareAction>{
      CareAction.avaliacaoPsicologica,
      ..._sharing,
      CareAction.rascunhoIa,
    },
    CareSpecialty.fisioterapia => const <CareAction>{
      CareAction.avaliacaoFuncional,
      CareAction.exerciciosCasa,
      ..._sharing,
      CareAction.rascunhoIa,
    },
    CareSpecialty.fonoaudiologia ||
    CareSpecialty.terapiaOcupacional => const <CareAction>{
      CareAction.avaliacaoFuncional,
      CareAction.exerciciosCasa,
      ..._sharing,
    },
    CareSpecialty.nutricao => _sharing,
  };

  static Set<CareRecordKind> kindsFor(CareSpecialty s) => switch (s) {
    CareSpecialty.pediatria => const <CareRecordKind>{
      CareRecordKind.avaliacao,
      CareRecordKind.evolucao,
      CareRecordKind.objetivos,
      CareRecordKind.orientacao,
    },
    CareSpecialty.psicologia => const <CareRecordKind>{
      CareRecordKind.avaliacao,
      CareRecordKind.sessao,
      CareRecordKind.planoTerapeutico,
      CareRecordKind.objetivos,
      CareRecordKind.orientacao,
    },
    CareSpecialty.fisioterapia => const <CareRecordKind>{
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
      CareRecordKind.avaliacao,
      CareRecordKind.objetivos,
      CareRecordKind.evolucao,
      CareRecordKind.atividadeCasa,
      CareRecordKind.orientacao,
    },
    CareSpecialty.nutricao => const <CareRecordKind>{
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

  /// Concessão ativa do registro para o profissional, valendo só enquanto
  /// ele tem vínculo ativo na clínica do registro.
  static CareRecordGrant? activeGrant(
    CareActor actor,
    CareRecord record,
    Iterable<CareLink> links,
    Iterable<CareRecordGrant> grants,
  ) {
    final CareLink? link = activeLink(links, actor, record.childId);
    if (link == null || link.clinicId != record.clinicId) return null;
    for (final CareRecordGrant g in grants) {
      if (g.recordId == record.id && g.granteeId == actor.id && g.active) {
        return g;
      }
    }
    return null;
  }

  /// Leitura do registro completo.
  ///
  /// - o autor sempre lê o que escreveu (guarda do prontuário), mesmo sem
  ///   vínculo;
  /// - outro profissional só com acesso concedido e vínculo ativo na mesma
  ///   clínica, e mesmo assim sem as seções privadas;
  /// - o responsável só o que foi liberado para a família.
  static bool canRead(
    CareActor actor,
    CareRecord record,
    Iterable<CareLink> links,
    Iterable<CareRecordGrant> grants,
  ) {
    if (actor.isProfessional) {
      if (record.authorId == actor.id) return true;
      return activeGrant(actor, record, links, grants) != null;
    }
    if (actor.isFamily) {
      return actor.guardianOf.contains(record.childId) &&
          record.visibility == CareVisibility.familia &&
          record.releasedAt != null;
    }
    return false;
  }

  /// Leitura de um resumo: o autor sempre; destinatário só enquanto o resumo
  /// está publicado e ele tem vínculo ativo na mesma clínica.
  static bool canReadSummary(
    CareActor actor,
    CareSummary summary,
    Iterable<CareLink> links,
  ) {
    if (!actor.isProfessional) return false;
    if (summary.authorId == actor.id) return true;
    final CareLink? link = activeLink(links, actor, summary.childId);
    return summary.published &&
        link != null &&
        link.clinicId == summary.clinicId &&
        summary.recipientIds.contains(actor.id);
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
    if (visibility == CareVisibility.familia && !kind.canGoToFamily) {
      return 'Só orientações e atividades para casa vão para a família.';
    }
    return null;
  }
}
