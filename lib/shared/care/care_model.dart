/// Cuidado multidisciplinar: equipe vinculada à criança, registros de cada
/// profissional, resumos compartilhados por escolha do autor, plano
/// terapêutico conjunto, comunicação da equipe e trilha de acesso.
///
/// O registro completo de um atendimento é do profissional que o produziu.
/// Os demais só recebem o que o autor escolheu compartilhar (resumo) ou o que
/// ele concedeu com justificativa. Vínculo com a criança e pertencer à mesma
/// clínica não abrem nada sozinhos.
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
  privado('Privado: autor e acessos concedidos'),
  familia('Liberado para a família');

  const CareVisibility(this.label);

  final String label;
}

/// Partes de um registro. Só o conteúdo clínico pode ser escolhido para um
/// resumo ou visto por quem recebeu acesso concedido.
enum CareSectionKind {
  clinica('Conteúdo clínico', shareable: true),
  anotacaoPrivada('Anotação privada'),
  transcricao('Transcrição'),
  conversa('Conversa registrada');

  const CareSectionKind(this.label, {this.shareable = false});

  final String label;
  final bool shareable;
}

class CareSection {
  const CareSection({
    required this.id,
    required this.kind,
    required this.label,
    required this.text,
  });

  final String id;
  final CareSectionKind kind;
  final String label;
  final String text;
}

/// Seção informada ao criar um registro; o identificador é dado pelo store.
typedef CareSectionInput = ({CareSectionKind kind, String label, String text});

/// Informação que pode entrar num resumo, com a parte do registro de onde
/// veio.
class CareShareItem {
  const CareShareItem({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
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
  avaliacaoFuncional('Avaliação funcional e medidas'),
  exerciciosCasa('Exercícios e atividades para casa'),
  orientacaoFamilia('Orientações aos responsáveis'),
  liberarFamilia('Liberar conteúdo para a família'),
  compartilharResumo('Compartilhar resumo escolhido com a equipe'),
  concederAcesso('Conceder acesso justificado ao registro completo'),
  planoCompartilhado('Contribuir com o plano terapêutico conjunto'),
  encaminhar('Encaminhamento interno'),
  solicitarParecer('Solicitar parecer'),
  mensagemEquipe('Mensagens da equipe'),
  rascunhoIa('Sugestão da IA sobre o que já foi compartilhado (com revisão)');

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
    required this.createdAt,
    this.visibility = CareVisibility.privado,
    this.sessionNumber,
    this.measure,
    List<CareSection>? sections,
  }) : sections = sections ?? <CareSection>[];

  static const String bodyItemId = 'registro';
  static const String measureItemId = 'medida';

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

  /// Partes do registro. Anotação privada, transcrição e conversa ficam só
  /// com o autor.
  final List<CareSection> sections;
  final List<CareRevision> revisions = <CareRevision>[];

  /// De onde veio a informação: especialidade, autor e data.
  String get origin => '${specialty.area} - $authorName';

  /// O que o autor pode escolher para um resumo.
  List<CareShareItem> get shareableItems => <CareShareItem>[
    CareShareItem(id: bodyItemId, label: kind.label, text: body),
    if (measure != null)
      CareShareItem(id: measureItemId, label: 'Medida', text: measure!),
    for (final CareSection s in sections)
      if (s.kind.shareable) CareShareItem(id: s.id, label: s.label, text: s.text),
  ];

  List<CareSection> get lockedSections => <CareSection>[
    for (final CareSection s in sections)
      if (!s.kind.shareable) s,
  ];
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

/// Acesso ao registro completo concedido pelo autor a um profissional da
/// equipe, com justificativa. Não inclui as seções privadas.
class CareRecordGrant {
  CareRecordGrant({
    required this.id,
    required this.recordId,
    required this.childId,
    required this.granteeId,
    required this.granteeName,
    required this.granteeSpecialty,
    required this.justification,
    required this.grantedAt,
    required this.grantedBy,
  });

  static const int minJustification = 15;

  final String id;
  final String recordId;
  final String childId;
  final String granteeId;
  final String granteeName;
  final CareSpecialty granteeSpecialty;
  final String justification;
  final DateTime grantedAt;
  final String grantedBy;
  DateTime? revokedAt;
  String? revokedBy;
  String? revokeReason;

  bool get active => revokedAt == null;
}

enum CareSummaryStatus {
  publicado('Compartilhado'),
  encerrado('Acesso encerrado');

  const CareSummaryStatus(this.label);

  final String label;
}

enum CareAudience {
  selecionados('Profissionais escolhidos'),
  equipe('Equipe de cuidado autorizada');

  const CareAudience(this.label);

  final String label;
}

/// Cada publicação, atualização ou encerramento gera uma versão.
class CareSummaryVersion {
  const CareSummaryVersion({
    required this.version,
    required this.at,
    required this.actorName,
    required this.status,
    required this.audience,
    required this.recipientNames,
    required this.items,
    required this.attachmentNames,
    required this.note,
    this.reason,
    this.aiAssisted = false,
  });

  final int version;
  final DateTime at;
  final String actorName;
  final CareSummaryStatus status;
  final CareAudience audience;
  final List<String> recipientNames;
  final List<CareShareItem> items;
  final List<String> attachmentNames;
  final String note;
  final String? reason;
  final bool aiAssisted;
}

class CareSummaryAccess {
  const CareSummaryAccess({
    required this.at,
    required this.actorId,
    required this.actorName,
    required this.version,
  });

  final DateTime at;
  final String actorId;
  final String actorName;
  final int version;
}

/// Resumo de um atendimento para a equipe, separado do registro completo.
/// Guarda cópia só do que o autor escolheu.
class CareSummary {
  CareSummary({
    required this.id,
    required this.recordId,
    required this.childId,
    required this.clinicId,
    required this.authorId,
    required this.authorName,
    required this.specialty,
    required this.recordTitle,
    required this.createdAt,
  });

  final String id;
  final String recordId;
  final String childId;
  final String clinicId;
  final String authorId;
  final String authorName;
  final CareSpecialty specialty;
  final String recordTitle;
  final DateTime createdAt;

  CareSummaryStatus status = CareSummaryStatus.publicado;
  CareAudience audience = CareAudience.selecionados;
  List<String> recipientIds = <String>[];
  Map<String, String> recipientNames = <String, String>{};
  List<CareShareItem> items = <CareShareItem>[];
  List<String> attachmentIds = <String>[];
  String note = '';
  int version = 0;
  DateTime? updatedAt;
  bool aiAssisted = false;
  String? reviewedBy;
  final List<CareSummaryVersion> versions = <CareSummaryVersion>[];
  final List<CareSummaryAccess> accessLog = <CareSummaryAccess>[];

  bool get published => status == CareSummaryStatus.publicado;

  String get recipientsLabel => audience == CareAudience.equipe
      ? '${audience.label}: ${recipientNames.values.join(', ')}'
      : recipientNames.values.join(', ');
}

/// Escolhas do autor antes de compartilhar. Tudo começa vazio: nenhuma
/// informação, nenhum anexo e nenhum destinatário.
class CareSummaryDraft {
  CareSummaryDraft({required this.recordId});

  final String recordId;
  final Set<String> itemIds = <String>{};
  final Set<String> attachmentIds = <String>{};
  CareAudience? audience;
  final Set<String> recipientIds = <String>{};
  String note = '';

  /// Texto da observação sugerido pela IA; exige revisão de quem publica.
  bool aiAssisted = false;
  bool aiReviewed = false;
}

/// O que será enviado, para quem e em que versão.
class CareSummaryPreview {
  const CareSummaryPreview({
    required this.recordId,
    required this.recordTitle,
    required this.items,
    required this.attachments,
    required this.recipients,
    required this.audience,
    required this.note,
    required this.version,
    required this.aiAssisted,
  });

  final String recordId;
  final String recordTitle;
  final List<CareShareItem> items;
  final List<CareAttachment> attachments;
  final List<CareLink> recipients;
  final CareAudience audience;
  final String note;
  final int version;
  final bool aiAssisted;

  bool get isUpdate => version > 1;
}

// --------------------------------------------- Plano terapêutico conjunto

enum CareGoalStatus {
  emAndamento('Em andamento'),
  atingido('Atingido'),
  revisar('Revisar');

  const CareGoalStatus(this.label);

  final String label;
}

enum CareContributionKind {
  acao('Ação'),
  informacao('Informação compartilhada');

  const CareContributionKind(this.label);

  final String label;
}

/// Contribuição escrita para o plano: o profissional decide o que entra; o
/// registro completo não é anexado.
class CarePlanContribution {
  const CarePlanContribution({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.specialty,
    required this.kind,
    required this.text,
    required this.at,
  });

  final String id;
  final String authorId;
  final String authorName;
  final CareSpecialty specialty;
  final CareContributionKind kind;
  final String text;
  final DateTime at;
}

class CareReassessment {
  const CareReassessment({
    required this.at,
    required this.actorName,
    required this.status,
    required this.note,
    required this.nextReassessAt,
  });

  final DateTime at;
  final String actorName;
  final CareGoalStatus status;
  final String note;
  final DateTime nextReassessAt;
}

class CarePlanGoal {
  CarePlanGoal({
    required this.id,
    required this.objective,
    required this.responsibleId,
    required this.responsibleName,
    required this.responsibleSpecialty,
    required this.dueDate,
    required this.reassessAt,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String objective;
  final String responsibleId;
  final String responsibleName;
  final CareSpecialty responsibleSpecialty;
  final DateTime dueDate;
  DateTime reassessAt;
  CareGoalStatus status = CareGoalStatus.emAndamento;
  final String createdBy;
  final DateTime createdAt;
  final List<CarePlanContribution> contributions = <CarePlanContribution>[];
  final List<CareReassessment> reassessments = <CareReassessment>[];

  List<CarePlanContribution> get actions => <CarePlanContribution>[
    for (final CarePlanContribution c in contributions)
      if (c.kind == CareContributionKind.acao) c,
  ];

  List<CarePlanContribution> get shared => <CarePlanContribution>[
    for (final CarePlanContribution c in contributions)
      if (c.kind == CareContributionKind.informacao) c,
  ];
}

class CarePlanChange {
  const CarePlanChange({
    required this.at,
    required this.actorName,
    required this.specialty,
    required this.description,
  });

  final DateTime at;
  final String actorName;
  final CareSpecialty specialty;
  final String description;
}

/// Plano terapêutico conjunto da equipe de uma clínica para a criança.
class CarePlan {
  CarePlan({required this.childId, required this.clinicId});

  final String childId;
  final String clinicId;
  final List<CarePlanGoal> goals = <CarePlanGoal>[];
  final List<CarePlanChange> history = <CarePlanChange>[];
}

// ------------------------------------------------------------ Comunicação

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
