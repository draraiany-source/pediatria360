/// Observações por paciente, com data, autor e visibilidade explícita.
///
/// - observação interna: só a equipe clínica vê;
/// - visível ao responsável: aparece na área da família;
/// - editar não apaga: cada versão fica guardada com autor e data;
/// - arquivar tira da lista, mas mantém o registro.
library;

enum NoteVisibility {
  interna(
    'Observação interna',
    'Só a equipe clínica vê. Não aparece para o responsável.',
  ),
  responsavel(
    'Visível ao responsável',
    'Aparece para o responsável na área da família.',
  );

  const NoteVisibility(this.label, this.help);

  final String label;
  final String help;
}

class NoteVersion {
  const NoteVersion({
    required this.at,
    required this.author,
    required this.text,
    required this.visibility,
    this.reason,
  });

  final DateTime at;
  final String author;
  final String text;
  final NoteVisibility visibility;

  /// Motivo informado ao mudar a visibilidade.
  final String? reason;
}

const int maxNoteLength = 2000;

String? validateNoteText(String text) {
  final String t = text.trim();
  if (t.isEmpty) return 'Escreva a observação.';
  if (t.length > maxNoteLength) return 'Use até 2.000 caracteres.';
  return null;
}

class PatientNote {
  PatientNote({
    required this.id,
    required this.patientId,
    required this.authorId,
    required this.author,
    required this.createdAt,
    required String text,
    required NoteVisibility visibility,
    this.consultationId,
  }) : versions = <NoteVersion>[
         NoteVersion(
           at: createdAt,
           author: author,
           text: text.trim(),
           visibility: visibility,
         ),
       ];

  final String id;
  final String patientId;

  /// Conta de quem escreveu (define a clínica que enxerga a nota interna).
  final String authorId;
  final String author;
  final DateTime createdAt;
  final String? consultationId;
  final List<NoteVersion> versions;
  DateTime? archivedAt;
  String? archivedBy;
  String? archiveReason;

  NoteVersion get current => versions.last;
  String get text => current.text;
  NoteVisibility get visibility => current.visibility;
  bool get edited => versions.length > 1;
  bool get archived => archivedAt != null;
  bool get visibleToGuardian =>
      !archived && visibility == NoteVisibility.responsavel;

  void edit({
    required String text,
    required NoteVisibility visibility,
    required String author,
    required DateTime at,
    String? reason,
  }) {
    if (archived) throw StateError('Observação arquivada não é editada.');
    final String? error = validateNoteText(text);
    if (error != null) throw StateError(error);
    final bool sameText = text.trim() == this.text;
    final bool sameVisibility = visibility == this.visibility;
    if (sameText && sameVisibility) throw StateError('Nada foi alterado.');
    if (!sameVisibility && (reason == null || reason.trim().isEmpty)) {
      throw StateError('Informe o motivo da mudança de visibilidade.');
    }
    versions.add(
      NoteVersion(
        at: at,
        author: author,
        text: text.trim(),
        visibility: visibility,
        reason: reason?.trim(),
      ),
    );
  }

  void archive({
    required String author,
    required DateTime at,
    required String reason,
  }) {
    if (archived) return;
    if (reason.trim().isEmpty) throw StateError('Informe o motivo.');
    archivedAt = at;
    archivedBy = author;
    archiveReason = reason.trim();
  }
}
