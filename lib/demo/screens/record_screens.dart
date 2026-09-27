import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

/// Prontuario ficticio: linha do tempo de evolucoes.
class DemoRecordScreen extends StatelessWidget {
  const DemoRecordScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Prontuário')),
            body: DemoEmpty(
              title: 'Paciente não encontrado',
              message: 'Volte para a lista de pacientes.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final List<DemoEncounter> list = demoSession.encounters
            .where((DemoEncounter e) => e.patientId == p.id)
            .toList();
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Prontuário'),
                Text(p.name,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                context.go('/pacientes/${p.id}/prontuario/nova'),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Nova evolução'),
          ),
          body: DemoLoader(
            label: 'Carregando prontuário...',
            builder: (BuildContext context) => list.isEmpty
                ? const DemoEmpty(
                    title: 'Sem evoluções',
                    message: 'Registre a primeira consulta deste paciente.',
                    pose: CapiPose.boasVindas,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                    children: <Widget>[
                      DemoContent(
                        maxWidth: 760,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const DemoNotice(
                              text: 'Prontuário fictício. No app real o '
                                  'acesso é auditado e limitado ao '
                                  'profissional com vínculo ao paciente.',
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final DemoEncounter e in list)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: PremiumCard(
                                  padding:
                                      const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: Text(
                                              e.type,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                          ),
                                          Text(demoDate(e.date),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(e.summary),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Nova evolucao com rascunho SIMULADO que exige revisao antes de confirmar.
class DemoEncounterEditorScreen extends StatefulWidget {
  const DemoEncounterEditorScreen({required this.patientId, super.key});

  final String patientId;

  @override
  State<DemoEncounterEditorScreen> createState() =>
      _DemoEncounterEditorScreenState();
}

class _DemoEncounterEditorScreenState
    extends State<DemoEncounterEditorScreen> {
  final TextEditingController _notes = TextEditingController();
  bool _draftLoading = false;
  bool _fromDraft = false;
  bool _reviewed = false;

  static const String _simulatedDraft =
      'RASCUNHO SIMULADO (texto fixo, sem IA)\n'
      'Queixa: [preencher]\n'
      'Exame físico: [preencher]\n'
      'Conduta: [a definir pelo profissional]';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _dirty => _notes.text.trim().isNotEmpty;

  Future<void> _generateDraft() async {
    setState(() => _draftLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _draftLoading = false;
      _fromDraft = true;
      _reviewed = false;
      _notes.text = _simulatedDraft;
    });
  }

  Future<void> _leave() async {
    if (_dirty) {
      final bool? discard = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) => AlertDialog(
          title: const Text('Descartar evolução?'),
          content: const Text('O texto digitado será perdido.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Continuar editando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) context.go('/pacientes/${widget.patientId}/prontuario');
  }

  void _confirm() {
    final String text = _notes.text.trim();
    if (text.isEmpty) {
      showDemoSnack(context, 'Escreva a evolução antes de confirmar.');
      return;
    }
    if (text.contains('[preencher]') || text.contains('[a definir')) {
      showDemoSnack(context,
          'Revise o rascunho: ainda há campos entre colchetes a preencher.');
      return;
    }
    demoSession.addEncounter(DemoEncounter(
      patientId: widget.patientId,
      date: DateTime.now(),
      type: 'Evolução (demonstração)',
      summary: text,
    ));
    _notes.clear();
    showDemoSnack(
        context, 'Evolução adicionada só nesta aba. Nada foi gravado.');
    context.go('/pacientes/${widget.patientId}/prontuario');
  }

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.patientById(widget.patientId);
    final bool canConfirm = !_fromDraft || _reviewed;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancelar',
            icon: const Icon(Icons.close_rounded),
            onPressed: _leave,
          ),
          title: Text('Nova evolução - ${p?.name ?? ''}'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              maxWidth: 760,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(Icons.auto_awesome_outlined,
                                color: AppColors.brand),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text('Assistente de rascunho',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                            ),
                            const DemoTag('Simulado'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Na demonstração não há IA nem gravação de voz: o '
                          'botão insere um modelo fixo. No app real a IA só '
                          'prepara um rascunho, e o profissional revisa e '
                          'confirma antes de qualquer registro.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _draftLoading ? null : _generateDraft,
                          icon: _draftLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.description_outlined),
                          label: const Text('Inserir rascunho simulado'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _notes,
                    minLines: 8,
                    maxLines: 16,
                    onChanged: (_) => setState(() => _reviewed = false),
                    decoration: const InputDecoration(
                      labelText: 'Evolução',
                      alignLabelWithHint: true,
                      hintText: 'Descreva a consulta (texto fictício)',
                    ),
                  ),
                  if (_fromDraft) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    CheckboxListTile(
                      value: _reviewed,
                      onChanged: (bool? v) =>
                          setState(() => _reviewed = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Revisei e ajustei o rascunho; o texto final é '
                          'de minha responsabilidade.'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _leave,
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: canConfirm ? _confirm : null,
                          child: const Text('Confirmar evolução'),
                        ),
                      ),
                    ],
                  ),
                  if (_fromDraft && !_reviewed) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Confirmar fica bloqueado até a revisão do rascunho.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
