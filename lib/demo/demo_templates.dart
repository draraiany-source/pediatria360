import '../shared/clinical/clinical_documents.dart';
import '../shared/clinical/doc_templates.dart';
import '../shared/clinical/orientation_templates.dart';
import '../shared/clinical/rx_templates.dart';
import '../shared/clinical/template_library.dart';
import '../shared/wellchild/age_band.dart';
import 'demo_session.dart';

/// Abas da biblioteca de modelos.
enum TemplateView {
  mine('Meus modelos'),
  clinic('Da clínica'),
  examples('Exemplos'),
  archived('Arquivados');

  const TemplateView(this.label);

  final String label;
}

/// Linha da biblioteca, igual para os três tipos de modelo.
class TemplateEntry {
  const TemplateEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.summary,
    required this.org,
    required this.updatedAt,
    required this.author,
    this.version,
    this.isExample = false,
  });

  final String id;
  final DocKind kind;
  final String name;
  final String summary;
  final TemplateOrg org;
  final DateTime updatedAt;
  final String author;

  /// Versão do conteúdo; `null` nos modelos de orientação, que não guardam
  /// versões.
  final int? version;
  final bool isExample;
}

/// Modelos de documento da demonstração: atestado, declaração,
/// encaminhamento e exames ([DocTemplate]), orientações
/// ([OrientationTemplate]) e receitas ([RxTemplate]), com organização e
/// permissões em [TemplateLibrary].
class DemoTemplates {
  DemoTemplates(this._s);

  final DemoSession _s;

  TemplateLibrary get library => _s.templateLibrary;
  TemplateActor get actor => _s.templateActor;

  /// Profissional (os próprios e os da clínica) e gestão da clínica.
  bool get canOpen =>
      _s.isPediatrician || _s.profile == DemoProfile.administrador;

  bool get managesClinic => _s.profile == DemoProfile.administrador;

  bool canManage(String id) => library.canManage(id, actor);
  bool canUse(String id) => library.canUse(id, actor);

  // ------------------------------------------------ Lista

  List<TemplateEntry> get _visible => <TemplateEntry>[
    for (final DocTemplate t in _s.docTemplates)
      if (library.canSee(t.id, actor))
        TemplateEntry(
          id: t.id,
          kind: t.kind,
          name: t.name,
          summary: t.summary,
          org: library.orgOf(t.id)!,
          updatedAt: t.updatedAt,
          author: t.current.savedBy,
          version: t.current.number,
          isExample: t.isExample,
        ),
    for (final OrientationTemplate t in _s.orientationTemplates)
      if (library.canSee(t.id, actor))
        TemplateEntry(
          id: t.id,
          kind: DocKind.orientacoes,
          name: t.title,
          summary: _short(t.body),
          org: library.orgOf(t.id)!,
          updatedAt: t.updatedAt,
          author: t.author,
          isExample: t.isExample,
        ),
    for (final RxTemplate t in _s.rxTemplates)
      if (library.canSee(t.id, actor))
        TemplateEntry(
          id: t.id,
          kind: DocKind.receituario,
          name: t.name,
          summary: t.items.map((RxTemplateItem i) => i.drug).join(', '),
          org: library.orgOf(t.id)!,
          updatedAt: t.updatedAt,
          author: t.current.savedBy,
          version: t.current.number,
          isExample: t.isExample,
        ),
  ];

  static String _short(String s) {
    final String one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return one.length > 140 ? '${one.substring(0, 137)}...' : one;
  }

  bool _inView(TemplateEntry e, TemplateView v) {
    final TemplateOrg o = e.org;
    return switch (v) {
      TemplateView.archived => o.isArchived && canManage(e.id),
      _ when o.isArchived => false,
      TemplateView.mine =>
        managesClinic ? o.scope == TemplateScope.clinic : o.scope == TemplateScope.personal,
      TemplateView.clinic => o.scope == TemplateScope.clinic,
      TemplateView.examples => o.scope == TemplateScope.example,
    };
  }

  /// Abas disponíveis para quem está usando.
  List<TemplateView> get views => managesClinic
      ? const <TemplateView>[TemplateView.mine, TemplateView.archived]
      : TemplateView.values;

  String viewLabel(TemplateView v) =>
      managesClinic && v == TemplateView.mine ? 'Modelos da clínica' : v.label;

  List<TemplateEntry> entries({
    required TemplateView view,
    DocKind? kind,
    String query = '',
  }) {
    final String q = normalizeSearch(query);
    final List<TemplateEntry> out = <TemplateEntry>[
      for (final TemplateEntry e in _visible)
        if (_inView(e, view) &&
            (kind == null || e.kind == kind) &&
            (q.isEmpty ||
                q
                    .split(' ')
                    .where((String w) => w.isNotEmpty)
                    .every(
                      normalizeSearch(
                        '${e.name} ${e.summary} ${e.kind.label} ${e.org.folder}',
                      ).contains,
                    )))
          e,
    ];
    out.sort((TemplateEntry a, TemplateEntry b) {
      final int f = a.org.folder.compareTo(b.org.folder);
      if (f != 0) {
        if (a.org.folder.isEmpty) return 1;
        if (b.org.folder.isEmpty) return -1;
        return f;
      }
      return normalizeSearch(a.name).compareTo(normalizeSearch(b.name));
    });
    return out;
  }

  int count(TemplateView v) => _visible.where((TemplateEntry e) => _inView(e, v)).length;

  List<String> get folders => library.foldersFor(actor);

  // ------------------------------------------------ Modelos de documento

  DocTemplate? docTemplate(String id) {
    for (final DocTemplate t in _s.docTemplates) {
      if (t.id == id) return library.canSee(id, actor) ? t : null;
    }
    return null;
  }

  int _scopeRank(String id) => switch (library.orgOf(id)?.scope) {
    TemplateScope.personal => 0,
    TemplateScope.clinic => 1,
    _ => 2,
  };

  /// Modelos que podem ser aplicados a um documento do tipo: os próprios,
  /// depois os da clínica e os exemplos.
  List<DocTemplate> usableFor(DocKind kind) =>
      _s.docTemplates
          .where((DocTemplate t) => t.kind == kind && canUse(t.id))
          .toList()
        ..sort((DocTemplate a, DocTemplate b) {
          final int r = _scopeRank(a.id).compareTo(_scopeRank(b.id));
          return r != 0 ? r : normalizeSearch(a.name).compareTo(normalizeSearch(b.name));
        });

  DocTemplate createDocTemplate({
    required DocKind kind,
    required String name,
    required Map<String, String> fields,
    String folder = '',
    String? note,
  }) {
    final DocTemplate t = DocTemplate.create(
      id: _s.newId('mt'),
      kind: kind,
      name: name,
      fields: fields,
      author: actor.name,
      now: DateTime.now(),
      note: note,
    );
    library.registerNew(t.id, actor, folder: folder);
    _s.docTemplates = <DocTemplate>[t, ..._s.docTemplates];
    _s.changed();
    return t;
  }

  DocTemplate reviseDocTemplate(
    String id, {
    required String name,
    required Map<String, String> fields,
    String? note,
  }) {
    library.requireManage(id, actor);
    final DocTemplate cur = docTemplate(id)!;
    final DocTemplate next = cur.edit(
      name: name,
      fields: fields,
      author: actor.name,
      now: DateTime.now(),
      note: note,
    );
    _s.docTemplates = <DocTemplate>[
      for (final DocTemplate t in _s.docTemplates) t.id == id ? next : t,
    ];
    _s.changed();
    return next;
  }

  // ------------------------------------------------ Orientações

  OrientationTemplate? orientation(String id) {
    for (final OrientationTemplate t in _s.orientationTemplates) {
      if (t.id == id) return library.canSee(id, actor) ? t : null;
    }
    return null;
  }

  OrientationTemplate createOrientation({
    required String title,
    required String body,
    OrientationTopic topic = OrientationTopic.geral,
    ChildAgeBand? band,
    String folder = '',
  }) {
    final String id = _s.newId('t');
    final TemplateOrg org = library.registerNew(id, actor, folder: folder);
    final OrientationTemplate t = OrientationTemplate(
      id: id,
      title: title.trim(),
      body: body.trim(),
      author: actor.name,
      updatedAt: DateTime.now(),
      topic: topic,
      band: band,
      ownerId: org.ownerId,
    );
    _s.orientationTemplates = <OrientationTemplate>[
      t,
      ..._s.orientationTemplates,
    ];
    _s.changed();
    return t;
  }

  OrientationTemplate reviseOrientation(
    String id, {
    required String title,
    required String body,
    required OrientationTopic topic,
    required ChildAgeBand? band,
  }) {
    library.requireManage(id, actor);
    final OrientationTemplate next = orientation(id)!.revise(
      title: title,
      body: body,
      topic: topic,
      band: band,
      author: actor.name,
      now: DateTime.now(),
    );
    _s.orientationTemplates = <OrientationTemplate>[
      for (final OrientationTemplate t in _s.orientationTemplates)
        t.id == id ? next : t,
    ];
    _s.changed();
    return next;
  }

  // ------------------------------------------------ Organização

  /// Cópia independente; quem não organiza o original recebe cópia pessoal.
  /// Devolve o id da cópia.
  String duplicate(String id) {
    final DateTime now = DateTime.now();
    final DocTemplate? d = docTemplate(id);
    if (d != null) {
      final DocTemplate copy = d.duplicate(
        id: _s.newId('mt'),
        author: actor.name,
        now: now,
      );
      library.registerCopy(
        sourceId: id,
        newId: copy.id,
        sourceName: d.name,
        actor: actor,
      );
      _s.docTemplates = <DocTemplate>[copy, ..._s.docTemplates];
      _s.changed();
      return copy.id;
    }
    final OrientationTemplate? o = orientation(id);
    if (o != null) {
      final String newId = _s.newId('t');
      final TemplateOrg org = library.registerCopy(
        sourceId: id,
        newId: newId,
        sourceName: o.title,
        actor: actor,
      );
      _s.orientationTemplates = <OrientationTemplate>[
        o.duplicate(
          id: newId,
          ownerId: org.ownerId,
          author: actor.name,
          now: now,
        ),
        ..._s.orientationTemplates,
      ];
      _s.changed();
      return newId;
    }
    final RxTemplate? r = _s.rxTemplateVisible(id);
    if (r != null) {
      final RxTemplate copy = r.duplicate(
        id: _s.newRxTemplateId(),
        author: actor.name,
        now: now,
      );
      library.registerCopy(
        sourceId: id,
        newId: copy.id,
        sourceName: r.name,
        actor: actor,
      );
      _s.saveRxTemplate(copy);
      return copy.id;
    }
    throw const TemplateAccessException('Modelo não disponível nesta conta.');
  }

  void archive(String id) {
    library.archive(id, actor, DateTime.now());
    _s.changed();
  }

  void restore(String id) {
    library.restore(id, actor);
    _s.changed();
  }

  void moveTo(String id, String folder) {
    library.moveTo(id, actor, folder);
    _s.changed();
  }
}
