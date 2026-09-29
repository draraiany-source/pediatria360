import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/patient_notes.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_workspace.dart';
import '../widgets/demo_widgets.dart';

String _stamp(DateTime d) => '${demoDate(d)} às ${demoTime(d)}';

class NoteVisibilityTag extends StatelessWidget {
  const NoteVisibilityTag({required this.visibility, super.key});

  final NoteVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final bool internal = visibility == NoteVisibility.interna;
    final Color color = internal ? AppColors.navy : AppColors.success;
    return Semantics(
      label: visibility.label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.pillAll,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              internal ? Icons.lock_outline_rounded : Icons.visibility_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              visibility.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Observações clínicas da criança. O profissional escreve, edita (com
/// versões) e arquiva; o responsável só lê as marcadas como visíveis.
class DemoPatientNotesScreen extends StatefulWidget {
  const DemoPatientNotesScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<DemoPatientNotesScreen> createState() => _DemoPatientNotesScreenState();
}

class _DemoPatientNotesScreenState extends State<DemoPatientNotesScreen> {
  bool _showArchived = false;

  Future<void> _openEditor({PatientNote? note}) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _NoteDialog(patientId: widget.patientId, note: note),
    );
    if ((saved ?? false) && mounted) {
      showDemoSnack(
        context,
        note == null ? 'Observação salva.' : 'Observação atualizada.',
      );
    }
  }

  Future<void> _archive(PatientNote n) async {
    final TextEditingController reason = TextEditingController();
    String? error;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          title: const Text('Arquivar observação'),
          content: TextField(
            controller: reason,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Motivo do arquivamento',
              errorText: error,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  demoSession.workspace.archiveNote(n.id, reason.text);
                  Navigator.of(context).pop(true);
                } on StateError catch (e) {
                  setLocal(() => error = e.message);
                }
              },
              child: const Text('Arquivar'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if ((ok ?? false) && mounted) {
      showDemoSnack(context, 'Observação arquivada (continua no registro).');
    }
  }

  void _versions(PatientNote n) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Versões da observação'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final (int i, NoteVersion v) in n.versions.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Versão ${i + 1}: ${v.text}'),
                  subtitle: Text(
                    <String>[
                      '${_stamp(v.at)} - ${v.author}',
                      v.visibility.label,
                      if (v.reason != null && v.reason!.isNotEmpty)
                        'Motivo: ${v.reason}',
                    ].join('\n'),
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        final DemoWorkspace ws = demoSession.workspace;
        final bool family = demoSession.profile == DemoProfile.responsavel;
        final String title = family ? 'Recados da equipe' : 'Observações';
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message: 'Volte para a lista de pacientes.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final List<PatientNote> active = ws.notesFor(p.id);
        final List<PatientNote> archived = ws.canWriteNotes
            ? ws.notesFor(p.id, archived: true)
            : const <PatientNote>[];
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.go('/pacientes/${p.id}'),
            ),
            title: Text('$title - ${p.name}'),
          ),
          floatingActionButton: ws.canWriteNotes
              ? FloatingActionButton.extended(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Nova observação'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            children: <Widget>[
              DemoContent(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (family)
                      const DemoNotice(
                        icon: Icons.mark_email_read_outlined,
                        text:
                            'Aqui aparecem só os recados que a equipe marcou '
                            'como visíveis para você.',
                      )
                    else
                      const DemoNotice(
                        icon: Icons.shield_outlined,
                        text:
                            'Observação interna: só a equipe clínica vê. '
                            'Visível ao responsável: aparece na área da '
                            'família. Editar guarda a versão anterior; '
                            'arquivar mantém o registro.',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    if (active.isEmpty)
                      DemoNotice(
                        text: family
                            ? 'Nenhum recado da equipe por enquanto.'
                            : 'Nenhuma observação registrada.',
                      ),
                    for (final PatientNote n in active)
                      _NoteCard(
                        note: n,
                        family: family,
                        onEdit: ws.canWriteNotes
                            ? () => _openEditor(note: n)
                            : null,
                        onArchive: ws.canWriteNotes ? () => _archive(n) : null,
                        onVersions: family ? null : () => _versions(n),
                      ),
                    if (archived.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showArchived = !_showArchived),
                        icon: Icon(
                          _showArchived
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                        ),
                        label: Text('Arquivadas (${archived.length})'),
                      ),
                      if (_showArchived)
                        for (final PatientNote n in archived)
                          _NoteCard(
                            note: n,
                            family: false,
                            onVersions: () => _versions(n),
                          ),
                    ],
                    if (!family) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      TextButton.icon(
                        onPressed: () => context.go(
                          '/pacientes/${p.id}/historico/alteracoes',
                        ),
                        icon: const Icon(Icons.manage_history_rounded),
                        label: const Text('Registro de alterações'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.family,
    this.onEdit,
    this.onArchive,
    this.onVersions,
  });

  final PatientNote note;
  final bool family;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onVersions;

  @override
  Widget build(BuildContext context) {
    final PatientNote n = note;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!family)
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  NoteVisibilityTag(visibility: n.visibility),
                  if (n.archived)
                    const DemoTag('Arquivada', color: AppColors.inkMuted),
                ],
              ),
            if (!family) const SizedBox(height: AppSpacing.sm),
            Text(n.text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              <String>[
                '${_stamp(n.createdAt)} - ${n.author}',
                if (n.edited)
                  'Editada em ${_stamp(n.current.at)} por ${n.current.author}',
                if (n.archived)
                  'Arquivada em ${_stamp(n.archivedAt!)} por '
                      '${n.archivedBy}: ${n.archiveReason}',
                if (n.consultationId != null && !family)
                  'Vinculada à consulta de '
                      '${_consultationDate(n.consultationId!)}',
              ].join('\n'),
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            if (onEdit != null || onArchive != null || onVersions != null)
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  if (onEdit != null && !n.archived)
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  if (onVersions != null)
                    TextButton.icon(
                      onPressed: onVersions,
                      icon: const Icon(Icons.history_rounded),
                      label: Text('Versões (${n.versions.length})'),
                    ),
                  if (onArchive != null && !n.archived)
                    TextButton.icon(
                      onPressed: onArchive,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Arquivar'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _consultationDate(String id) {
    final DateTime? d = demoSession.consultationById(id)?.startedAt;
    return d == null ? '-' : demoDate(d);
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.patientId, this.note});

  final String patientId;
  final PatientNote? note;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note?.text ?? '',
  );
  final TextEditingController _reason = TextEditingController();
  late NoteVisibility _visibility =
      widget.note?.visibility ?? NoteVisibility.interna;
  String? _error;

  bool get _visibilityChanged =>
      widget.note != null && widget.note!.visibility != _visibility;

  @override
  void dispose() {
    _text.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final DemoWorkspace ws = demoSession.workspace;
    try {
      if (widget.note == null) {
        ws.addNote(widget.patientId, _text.text, _visibility);
      } else {
        ws.editNote(
          widget.note!.id,
          text: _text.text,
          visibility: _visibility,
          reason: _visibilityChanged ? _reason.text : null,
        );
      }
      Navigator.of(context).pop(true);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.note == null ? 'Nova observação' : 'Editar observação',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                maxLength: maxNoteLength,
                decoration: const InputDecoration(labelText: 'Observação'),
              ),
              Text(
                'Quem pode ver',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<NoteVisibility>(
                segments: <ButtonSegment<NoteVisibility>>[
                  for (final NoteVisibility v in NoteVisibility.values)
                    ButtonSegment<NoteVisibility>(
                      value: v,
                      label: Text(v.label),
                      icon: Icon(
                        v == NoteVisibility.interna
                            ? Icons.lock_outline_rounded
                            : Icons.visibility_outlined,
                      ),
                    ),
                ],
                selected: <NoteVisibility>{_visibility},
                onSelectionChanged: (Set<NoteVisibility> s) =>
                    setState(() => _visibility = s.first),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  _visibility.help,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
              ),
              if (_visibilityChanged)
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da mudança de visibilidade',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar observação')),
      ],
    );
  }
}
