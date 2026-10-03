/// Cuidado multidisciplinar: equipe vinculada à criança, registros por
/// especialidade, plano compartilhado, comunicação da equipe e trilha de
/// acesso.
///
/// O acesso nasce do vínculo de cada profissional com a criança (autorizado
/// pela família) e da especialidade registrada nesse vínculo. Pertencer à
/// mesma clínica não dá acesso a nada.
library;

enum CareSpecialty {
  pediatria('Pediatria', 'Pediatra', 'CRM', active: true),
  psicologia('Psicologia', 'Psicólogo(a)', 'CRP', active: true),
  fisioterapia('Fisioterapia', 'Fisioterapeuta', 'CREFITO', active: true),
  fonoaudiologia('Fonoaudiologia', 'Fonoaudiólogo(a)', 'CRFa'),
  terapiaOcupacional(
    'Terapia ocupacional',
    'Terapeuta ocupacional',
    'CREFITO',
  ),
  nutricao('Nutrição', 'Nutricionista', 'CRN');

  const CareSpecialty(
    this.area,
    this.profession,
    this.council, {
    this.active = false,
  });

  /// Nome da área na ficha da criança.
  final String area;
  final String profession;

  /// Conselho do registro profissional.
  final String council;

  /// Especialidades com área própria na ficha. As demais já têm perfil e
  /// permissões, mas a área de registros ainda não foi construída.
  final bool active;

  static CareSpecialty? fromText(String? text) {
    final String t = (text ?? '').trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final CareSpecialty s in CareSpecialty.values) {
      if (s.name.toLowerCase() == t ||
          s.area.toLowerCase() == t ||
          s.profession.toLowerCase() == t) {
        return s;
      }
    }
    if (t.startsWith('pediatr')) return CareSpecialty.pediatria;
    if (t.startsWith('psic')) return CareSpecialty.psicologia;
    if (t.startsWith('fisio')) return CareSpecialty.fisioterapia;
    if (t.startsWith('fono')) return CareSpecialty.fonoaudiologia;
    if (t.contains('ocupacional')) return CareSpecialty.terapiaOcupacional;
    if (t.startsWith('nutri')) return CareSpecialty.nutricao;
    return null;
  }
}

enum CareRecordKind {
  resumoEquipe('Resumo para a equipe'),
  avaliacao('Avaliação'),
  sessao('Evolução da sessão'),
  planoTerapeutico('Plano terapêutico'),
  avaliacaoFuncional('Avaliação funcional'),
  objetivos('Objetivos'),
  planoSessoes('Plano de sessões'),
  intervencao('Intervenções realizadas'),
  evolucao('Evolução'),
  medida('Medida de acompanhamento'),
  orientacao('Orientação aos responsáveis'),
  atividadeCasa('Atividade ou exercício para casa');

  const CareRecordKind(this.label);

  final String label;

  /// Só orientações e atividades para casa podem ser liberadas à família.
  bool get canGoToFamily =>
      this == CareRecordKind.orientacao || this == CareRecordKind.atividadeCasa;
}

enum CareVisibility {
  reservado('Reservado ao profissional responsável'),
  equipe('Equipe do cuidado'),
  familia('Liberado para a família');

  const CareVisibility(this.label);

  final String label;
}

/// Documentos que cada especialidade pode preparar.
enum CareDocKind {
  atestadoMedico('Atestado médico'),
  receituario('Receituário'),
  solicitacaoExames('Solicitação de exames'),
  declaracaoComparecimento('Declaração de comparecimento'),
  encaminhamento('Encaminhamento'),
  orientacoes('Orientações aos responsáveis'),
  relatorioPsicologico('Relatório psicológico'),
  relatorioFisioterapeutico('Relatório fisioterapêutico'),
  planoExerciciosCasa('Plano de exercícios para casa');

  const CareDocKind(this.label);

  final String label;
}

/// Ações sujeitas à especialidade. A matriz de permissões é gerada daqui.
enum CareAction {
  prescrever('Prescrever medicamentos e calcular doses'),
  solicitarExames('Solicitar exames laboratoriais'),
  atestadoMedico('Emitir atestado médico'),
  avaliacaoPsicologica('Avaliação e evolução psicológica'),
  registroReservado('Registro reservado'),
  avaliacaoFuncional('Avaliação funcional e medidas'),
  exerciciosCasa('Exercícios e atividades para casa'),
  orientacaoFamilia('Orientações aos responsáveis'),
  liberarFamilia('Liberar conteúdo para a família'),
  planoCompartilhado('Editar o plano compartilhado'),
  encaminhar('Encaminhamento interno'),
  solicitarParecer('Solicitar parecer'),
  mensagemEquipe('Mensagens da equipe'),
  rascunhoIa('Rascunho de resumo pela IA (com revisão)');

  const CareAction(this.label);

  final String label;
}

enum CareActorRole {
  profissional('Profissional de saúde'),
  familia('Família / responsável'),
  recepcao('Recepção'),
  financeiro('Financeiro'),
  gestaoClinica('Gestão da clínica'),
  adminPlataforma('Administração da plataforma');

  const CareActorRole(this.label);

  final String label;
}

/// Quem está agindo. A especialidade que vale para a criança é a do vínculo,
/// não a declarada aqui.
class CareActor {
  const CareActor({
    required this.id,
    required this.name,
    required this.role,
    this.specialty,
    this.clinicId,
    this.guardianOf = const <String>{},
  });

  final String id;
  final String name;
  final CareActorRole role;
  final CareSpecialty? specialty;
  final String? clinicId;

  /// Crianças pelas quais o responsável responde.
  final Set<String> guardianOf;

  bool get isProfessional => role == CareActorRole.profissional;
  bool get isFamily => role == CareActorRole.familia;
}

/// Vínculo de um profissional com uma criança. Nasce pendente (por
/// encaminhamento aceito ou designação da clínica) e só vale depois que a
/// família autoriza. Encerrar o vínculo encerra o acesso.
class CareLink {
  CareLink({
    required this.id,
    required this.childId,
    required this.professionalId,
    required this.professionalName,
    required this.specialty,
    required this.clinicId,
    required this.clinicName,
    required this.since,
    required this.reason,
    required this.requestedBy,
    this.registry = '',
    this.authorizedAt,
    this.authorizedBy,
  });

  final String id;
  final String childId;
  final String professionalId;
  final String professionalName;
  final CareSpecialty specialty;
  final String clinicId;
  final String clinicName;
  final DateTime since;

  /// Motivo do encaminhamento.
  final String reason;
  final String requestedBy;
  final String registry;

  DateTime? authorizedAt;
  String? authorizedBy;
  DateTime? endedAt;
  String? endedBy;
  String? endReason;

  bool get pending => authorizedAt == null && endedAt == null;
  bool get active => authorizedAt != null && endedAt == null;

  String get statusLabel => endedAt != null
      ? 'Vínculo encerrado'
      : authorizedAt == null
      ? 'Aguardando autorização da família'
      : 'Vínculo ativo';
}

class CareRevision {
  const CareRevision({
    required this.at,
    required this.actorName,
    required this.note,
    required this.previousBody,
  });

  final DateTime at;
  final String actorName;
  final String note;
  final String previousBody;
}

class CareRecord {
  CareRecord({
    required this.id,
    required this.childId,
    required this.clinicId,
    required this.authorId,
    required this.authorName,
    required this.specialty,
    required this.kind,
    required this.title,
    required this.body,
    required this.visibility,
    required this.createdAt,
    this.sessionNumber,
    this.measure,
    this.sourceId,
    this.fromAi = false,
    this.reviewedBy,
  });

  final String id;
  final String childId;

  /// Clínica em que o registro foi feito. A equipe de outra clínica não o vê.
  final String clinicId;
  final String authorId;
  final String authorName;
  final CareSpecialty specialty;
  final CareRecordKind kind;
  String title;
  String body;
  CareVisibility visibility;
  final DateTime createdAt;
  DateTime? updatedAt;
  DateTime? releasedAt;
  final int? sessionNumber;
  String? measure;

  /// Resumo compartilhado de um registro reservado: aponta para ele.
  final String? sourceId;

  /// Texto preparado pela IA e revisado por [reviewedBy] antes de salvar.
  final bool fromAi;
  final String? reviewedBy;
  final List<CareRevision> revisions = <CareRevision>[];

  /// De onde veio a informação: especialidade, autor e data.
  String get origin => '${specialty.area} - $authorName';
}

class CareAttachment {
  const CareAttachment({
    required this.id,
    required this.recordId,
    required this.fileName,
    required this.addedBy,
    required this.at,
  });

  final String id;
  final String recordId;
  final String fileName;
  final String addedBy;
  final DateTime at;
}

class CarePlanGoal {
  const CarePlanGoal({
    required this.text,
    required this.specialty,
    required this.ownerName,
  });

  final String text;
  final CareSpecialty specialty;
  final String ownerName;
}

class CarePlanVersion {
  const CarePlanVersion({
    required this.at,
    required this.actorName,
    required this.specialty,
    required this.text,
  });

  final DateTime at;
  final String actorName;
  final CareSpecialty specialty;
  final String text;
}

/// Plano combinado pela equipe da clínica para a criança.
class CarePlan {
  CarePlan({
    required this.childId,
    required this.clinicId,
    required this.text,
    required this.updatedAt,
    required this.updatedBy,
    required this.updatedBySpecialty,
    List<CarePlanGoal>? goals,
  }) : goals = goals ?? <CarePlanGoal>[];

  final String childId;
  final String clinicId;
  String text;
  DateTime updatedAt;
  String updatedBy;
  CareSpecialty updatedBySpecialty;
  final List<CarePlanGoal> goals;
  final List<CarePlanVersion> history = <CarePlanVersion>[];
}

enum CareMessageKind {
  encaminhamento('Encaminhamento interno'),
  parecer('Solicitação de parecer'),
  mensagem('Mensagem');

  const CareMessageKind(this.label);

  final String label;
}

enum CareMessageStatus {
  aberto('Em aberto'),
  respondido('Respondido'),
  aceito('Aceito'),
  recusado('Recusado');

  const CareMessageStatus(this.label);

  final String label;
}

class CareMessageEvent {
  const CareMessageEvent({
    required this.at,
    required this.actorName,
    required this.status,
  });

  final DateTime at;
  final String actorName;
  final CareMessageStatus status;
}

class CareMessage {
  CareMessage({
    required this.id,
    required this.childId,
    required this.clinicId,
    required this.kind,
    required this.authorId,
    required this.authorName,
    required this.authorSpecialty,
    required this.subject,
    required this.body,
    required this.at,
    this.toSpecialty,
    this.toProfessionalId,
    this.replyTo,
  });

  final String id;
  final String childId;
  final String clinicId;
  final CareMessageKind kind;
  final String authorId;
  final String authorName;
  final CareSpecialty authorSpecialty;
  final String subject;
  final String body;
  final DateTime at;
  final CareSpecialty? toSpecialty;
  final String? toProfessionalId;

  /// Resposta a outra mensagem do mesmo assunto.
  final String? replyTo;
  CareMessageStatus status = CareMessageStatus.aberto;
  final List<CareMessageEvent> events = <CareMessageEvent>[];
}

enum CareDocStatus {
  draft('Rascunho'),
  reviewed('Revisado'),
  issued('Emitido');

  const CareDocStatus(this.label);

  final String label;
}

class CareDocument {
  CareDocument({
    required this.id,
    required this.childId,
    required this.clinicId,
    required this.kind,
    required this.authorId,
    required this.authorName,
    required this.authorRegistry,
    required this.specialty,
    required this.title,
    required this.body,
    required this.createdAt,
    this.templateId,
  });

  final String id;
  final String childId;
  final String clinicId;
  final CareDocKind kind;
  final String authorId;
  final String authorName;
  final String authorRegistry;
  final CareSpecialty specialty;
  String title;
  String body;
  final DateTime createdAt;
  final String? templateId;
  CareDocStatus status = CareDocStatus.draft;
  DateTime? issuedAt;
  DateTime? releasedAt;
}

/// Modelo de documento pessoal de um profissional.
class CareTemplate {
  CareTemplate({
    required this.id,
    required this.ownerId,
    required this.specialty,
    required this.kind,
    required this.title,
    required this.body,
  });

  final String id;
  final String ownerId;
  final CareSpecialty specialty;
  final CareDocKind kind;
  String title;
  String body;
}

class CareAuditEntry {
  const CareAuditEntry({
    required this.at,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.target,
    required this.childId,
    required this.allowed,
    this.clinicId,
  });

  final DateTime at;
  final String actorId;
  final String actorName;
  final String action;
  final String target;
  final String childId;
  final bool allowed;
  final String? clinicId;
}

class CareAccessDenied implements Exception {
  const CareAccessDenied(this.message);

  final String message;

  @override
  String toString() => message;
}
