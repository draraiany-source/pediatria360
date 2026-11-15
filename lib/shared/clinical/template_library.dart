/// Organização e permissões dos modelos de documento (atestado, declaração,
/// encaminhamento, exames, orientações e receita).
///
/// Regras:
/// - modelo pessoal: só o dono vê, edita, organiza e arquiva;
/// - modelo da clínica: todos os profissionais da clínica veem e usam; só a
///   gestão da clínica edita, organiza e arquiva;
/// - exemplo do sistema: todos veem, ninguém edita; serve de ponto de partida;
/// - duplicar sempre gera uma cópia independente: mudar o original depois não
///   altera a cópia, e vice-versa;
/// - arquivar tira o modelo das listas de uso sem apagar; pode ser restaurado.
library;

enum TemplateScope {
  personal('Meu modelo'),
  clinic('Modelo da clínica'),
  example('Exemplo a revisar');

  const TemplateScope(this.label);

  final String label;
}

/// Quem está agindo sobre a biblioteca.
class TemplateActor {
  const TemplateActor({
    required this.accountId,
    required this.name,
    this.clinicId,
    this.managesClinic = false,
  });

  final String accountId;
  final String name;

  /// Clínica a que a conta pertence; `null` = sem clínica.
  final String? clinicId;

  /// Gestão da clínica: cria e mantém os modelos compartilhados.
  final bool managesClinic;
}

class TemplateOrg {
  const TemplateOrg({
    required this.id,
    required this.scope,
    required this.ownerId,
    this.folder = '',
    this.archivedAt,
    this.archivedBy,
    this.copiedFrom,
  });

  final String id;
  final TemplateScope scope;

  /// Conta (pessoal) ou clínica (compartilhado). Vazio nos exemplos.
  final String ownerId;

  /// Pasta para organizar; vazio = sem pasta.
  final String folder;
  final DateTime? archivedAt;
  final String? archivedBy;

  /// Origem da cópia, para o histórico ("Cópia de ...").
  final String? copiedFrom;

  bool get isArchived => archivedAt != null;

  TemplateOrg copyWith({
    String? folder,
    DateTime? archivedAt,
    String? archivedBy,
    bool clearArchive = false,
  }) => TemplateOrg(
    id: id,
    scope: scope,
    ownerId: ownerId,
    folder: folder ?? this.folder,
    archivedAt: clearArchive ? null : archivedAt ?? this.archivedAt,
    archivedBy: clearArchive ? null : archivedBy ?? this.archivedBy,
    copiedFrom: copiedFrom,
  );
}

class TemplateAccessException implements Exception {
  const TemplateAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Registro de organização dos modelos, independente do conteúdo.
class TemplateLibrary {
  final Map<String, TemplateOrg> _org = <String, TemplateOrg>{};

  Iterable<TemplateOrg> get all => _org.values;

  TemplateOrg? orgOf(String id) => _org[id];

  void register(TemplateOrg org) => _org[org.id] = org;

  void remove(String id) => _org.remove(id);

  bool canSee(String id, TemplateActor a) {
    final TemplateOrg? o = _org[id];
    if (o == null) return false;
    return switch (o.scope) {
      TemplateScope.personal => o.ownerId == a.accountId,
      TemplateScope.clinic => a.clinicId != null && o.ownerId == a.clinicId,
      TemplateScope.example => true,
    };
  }

  /// Editar o conteúdo, renomear, mover de pasta e arquivar.
  bool canManage(String id, TemplateActor a) {
    final TemplateOrg? o = _org[id];
    if (o == null) return false;
    return switch (o.scope) {
      TemplateScope.personal => o.ownerId == a.accountId,
      TemplateScope.clinic =>
        a.managesClinic && a.clinicId != null && o.ownerId == a.clinicId,
      TemplateScope.example => false,
    };
  }

  /// Usar em um documento: visível e não arquivado.
  bool canUse(String id, TemplateActor a) =>
      canSee(id, a) && !(_org[id]?.isArchived ?? true);

  /// Escopo das cópias e dos modelos novos de quem age.
  TemplateScope scopeForNew(TemplateActor a) =>
      a.managesClinic ? TemplateScope.clinic : TemplateScope.personal;

  String ownerForNew(TemplateActor a) => a.managesClinic
      ? (a.clinicId ??
            (throw const TemplateAccessException(
              'Conta de gestão sem clínica vinculada.',
            )))
      : a.accountId;

  /// Registra um modelo novo de quem age.
  TemplateOrg registerNew(String id, TemplateActor a, {String folder = ''}) {
    final TemplateOrg o = TemplateOrg(
      id: id,
      scope: scopeForNew(a),
      ownerId: ownerForNew(a),
      folder: normalizeFolder(folder),
    );
    register(o);
    return o;
  }

  /// Registra a cópia de [sourceId]. Quem só pode ver o original (modelo da
  /// clínica ou exemplo) recebe uma cópia pessoal.
  TemplateOrg registerCopy({
    required String sourceId,
    required String newId,
    required String sourceName,
    required TemplateActor actor,
  }) {
    if (!canSee(sourceId, actor)) {
      throw const TemplateAccessException('Modelo não disponível nesta conta.');
    }
    final TemplateOrg src = _org[sourceId]!;
    final TemplateOrg o = TemplateOrg(
      id: newId,
      scope: scopeForNew(actor),
      ownerId: ownerForNew(actor),
      folder: canManage(sourceId, actor) ? src.folder : '',
      copiedFrom: '${src.scope.label}: $sourceName',
    );
    register(o);
    return o;
  }

  void _requireManage(String id, TemplateActor a) {
    if (!canManage(id, a)) {
      final TemplateOrg? o = _org[id];
      throw TemplateAccessException(switch (o?.scope) {
        TemplateScope.clinic =>
          'Modelos da clínica só são alterados pela gestão da clínica. '
              'Duplique para ter uma cópia sua.',
        TemplateScope.example =>
          'Exemplos não são alterados. Duplique para ter uma cópia sua.',
        _ => 'Este modelo não pertence a esta conta.',
      });
    }
  }

  void requireManage(String id, TemplateActor a) => _requireManage(id, a);

  void archive(String id, TemplateActor a, DateTime now) {
    _requireManage(id, a);
    _org[id] = _org[id]!.copyWith(archivedAt: now, archivedBy: a.name);
  }

  void restore(String id, TemplateActor a) {
    _requireManage(id, a);
    _org[id] = _org[id]!.copyWith(clearArchive: true);
  }

  void moveTo(String id, TemplateActor a, String folder) {
    _requireManage(id, a);
    _org[id] = _org[id]!.copyWith(folder: normalizeFolder(folder));
  }

  /// Pastas em uso pelos modelos que [a] organiza, em ordem alfabética.
  List<String> foldersFor(TemplateActor a) {
    final Set<String> out = <String>{
      for (final TemplateOrg o in _org.values)
        if (o.folder.isNotEmpty && canManage(o.id, a)) o.folder,
    };
    return out.toList()..sort();
  }

  static String normalizeFolder(String f) =>
      f.trim().replaceAll(RegExp(r'\s+'), ' ');
}
