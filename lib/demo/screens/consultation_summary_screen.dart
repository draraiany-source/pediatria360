import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/audit_trail.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/clinical_tasks.dart';
import '../../shared/clinical/consultation_organizer.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/clinical/patient_notes.dart';
import '../../shared/previsit/pre_visit.dart';
import '../../shared/wellchild/milestones.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../demo_workspace.dart';
import '../widgets/demo_widgets.dart';
import 'diary_screens.dart' show showTaskDialog;
import 'history_screens.dart';
import 'patient_notes_screens.dart' show NoteVisibilityTag;
import 'pre_visit_screens.dart' show preVisitReviewUrl;

String consultationSummaryUrl(String patientId, String consultationId) =>
    '/pacientes/$patientId/consulta/$consultationId/resumo';

/// Resumo da consulta: queixa, pré-consulta, anamnese, exame físico,
/// avaliação, conduta e plano de retorno, com o organizador assistido (só
/// rascunho até o profissional revisar) e o registro de alterações.
class DemoConsultationSummaryScreen extends StatefulWidget {
  const DemoConsultationSummaryScreen({
    required this.patientId,
    required this.consultationId,
    super.key,
  });

  final String patientId;
  final String consultationId;

  @override
  State<DemoConsultationSummaryScreen> createState() =>
      _DemoConsultationSummaryScreenState();
}

class _DemoConsultationSummaryScreenState
    extends State<DemoConsultationSummaryScreen> {
  final TextEditingController _transcript = TextEditingController();
  bool _reviewed = false;

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  Future<void> _addendum(DemoConsultation c) async {
    final TextEditingController text = TextEditingController();
    String? error;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
          title: const Text('Adicionar adendo'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'A consulta finalizada não muda. O adendo fica abaixo, com '
                  'data e autor.',
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: text,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Texto do adendo',
                    errorText: error,
                  ),
                ),
              ],
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
                  demoSession.workspace.addAddendum(c, text.text);
                  Navigator.of(context).pop(true);
                } on StateError catch (e) {
                  setLocal(() => error = e.message);
                }
              },
              child: const Text('Salvar adendo'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if ((ok ?? false) && mounted) showDemoSnack(context, 'Adendo registrado.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(widget.patientId);
        final DemoConsultation? c = demoSession.consultationById(
          widget.consultationId,
        );
        if (p == null || c == null || c.patientId != p.id) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resumo da consulta')),
            body: DemoEmpty(
              title: 'Consulta não encontrada',
              message: 'Ela não existe ou é de outro paciente.',
              actionLabel: 'Pacientes',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final DemoWorkspace ws = demoSession.workspace;
        final String base = '/pacientes/${p.id}';
        final DemoAppointment? appt = c.appointmentId == null
            ? null
            : demoSession.appointments
                  .where((DemoAppointment a) => a.id == c.appointmentId)
                  .firstOrNull;
        final PreVisit? pv = ws.preVisitFor(c);
        final GrowthMeasurement? m = visitMeasurement(c);
        final List<ClinicalDocRecord> docs = demoSession
            .documentsFor(p.id)
            .where((ClinicalDocRecord d) => d.consultationId == c.id)
            .toList();
        final List<PatientNote> notes = ws
            .notesFor(p.id)
            .where((PatientNote n) => n.consultationId == c.id)
            .toList();
        final List<AuditEntry> audit = ws.auditFor(p.id, entityId: c.id);
        final OrganizedDraft? draft = ws.drafts[c.id];
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('$base/historico')),
            title: const Text('Resumo da consulta'),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              DemoTag(
                                c.isDraft ? 'Rascunho' : 'Finalizada',
                                color: c.isDraft
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${c.isWellChild ? 'Consulta de puericultura' : 'Consulta'} '
                            'de ${demoDate(c.startedAt)} às '
                            '${demoTime(c.startedAt)} - ${c.author}',
                          ),
                          Text(
                            'Última alteração: ${demoDate(c.updatedAt)} às '
                            '${demoTime(c.updatedAt)}',
                            style: const TextStyle(
                              color: AppColors.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                          if (appt != null)
                            Text(
                              'Horário da agenda: ${demoDate(appt.start)} às '
                              '${demoTime(appt.start)} - '
                              '${DemoWorkspace.statusLabel(appt.status)}',
                              style: const TextStyle(
                                color: AppColors.inkMuted,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: <Widget>[
                              if (c.isDraft && demoSession.canUseClinicalTools)
                                FilledButton.icon(
                                  onPressed: () =>
                                      context.go('$base/consulta/${c.id}'),
                                  icon: const Icon(Icons.edit_note_rounded),
                                  label: const Text('Continuar consulta'),
                                ),
                              if (appt != null && ws.canOpenAppointment(appt))
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      context.go('/agenda/${appt.id}'),
                                  icon: const Icon(Icons.event_outlined),
                                  label: const Text('Abrir horário'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => context.go('$base/historico'),
                                icon: const Icon(Icons.timeline_rounded),
                                label: const Text('Histórico do paciente'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.go('$base/observacoes'),
                                icon: const Icon(Icons.sticky_note_2_outlined),
                                label: const Text('Observações'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final bool saved = await showTaskDialog(
                                    context,
                                    patientId: p.id,
                                    consultationId: c.id,
                                    kind: TaskKind.acompanhamento,
                                  );
                                  if (saved && context.mounted) {
                                    showDemoSnack(context, 'Lembrete salvo.');
                                  }
                                },
                                icon: const Icon(Icons.add_alert_outlined),
                                label: const Text('Lembrete de acompanhamento'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (c.isDraft)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: DemoNotice(
                          icon: Icons.edit_note_rounded,
                          color: AppColors.warning,
                          text:
                              'Rascunho: ainda não faz parte do prontuário. '
                              'Revise e finalize na tela da consulta.',
                        ),
                      ),
                    if (c.isDraft &&
                        !c.isWellChild &&
                        demoSession.canUseClinicalTools)
                      _organizer(c, draft),
                    const DemoSectionTitle('Pré-consulta'),
                    _PreVisitCard(patientId: p.id, consultation: c, visit: pv),
                    const DemoSectionTitle('Registro da consulta'),
                    for (final (String label, String text)
                        in consultationSections(c))
                      _Section(label: label, text: text),
                    _Section(
                      label: 'Medidas da consulta',
                      text: m == null
                          ? ''
                          : '${m.values.summary()}'
                                '${m.consultationId == c.id ? '' : ' (medida mais próxima da data)'}',
                    ),
                    if (c.returnInDays != null)
                      _Section(
                        label: 'Retorno recomendado',
                        text:
                            'Em ${c.returnInDays} dias '
                            '(${demoDate(c.startedAt.add(Duration(days: c.returnInDays!)))})',
                      ),
                    if (c.isWellChild &&
                        c.wellChild!.milestones.isNotEmpty) ...<Widget>[
                      const DemoSectionTitle('Marcos do desenvolvimento'),
                      Card(
                        child: Column(
                          children: <Widget>[
                            for (final MilestoneObservation mo
                                in c.wellChild!.milestones)
                              ListTile(
                                dense: true,
                                title: Text(mo.title),
                                subtitle: Text(
                                  '${mo.area.label} - ${mo.state.label}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const DemoSectionTitle('Documentos desta consulta'),
                    if (docs.isEmpty)
                      const DemoNotice(
                        text: 'Nenhum documento emitido nesta consulta.',
                      ),
                    for (final ClinicalDocRecord d in docs)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text('${d.kind.label}: ${d.title}'),
                          subtitle: Text(d.status.label),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go('$base/documentos/${d.id}'),
                        ),
                      ),
                    if (notes.isNotEmpty) ...<Widget>[
                      const DemoSectionTitle('Observações vinculadas'),
                      for (final PatientNote n in notes)
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(n.text),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xs,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: NoteVisibilityTag(
                                  visibility: n.visibility,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (!c.isDraft) ...<Widget>[
                      DemoSectionTitle(
                        'Adendos',
                        trailing: demoSession.canUseClinicalTools
                            ? TextButton.icon(
                                onPressed: () => _addendum(c),
                                icon: const Icon(Icons.post_add_rounded),
                                label: const Text('Adicionar adendo'),
                              )
                            : null,
                      ),
                      if (c.addenda.isEmpty)
                        const DemoNotice(text: 'Nenhum adendo.'),
                      for (final ConsultationAddendum ad in c.addenda)
                        Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            title: Text(ad.text),
                            subtitle: Text(
                              '${demoDate(ad.at)} às ${demoTime(ad.at)} - '
                              '${ad.author}',
                            ),
                          ),
                        ),
                    ],
                    const DemoSectionTitle('Registro de alterações'),
                    if (audit.isEmpty)
                      const DemoNotice(text: 'Nenhuma alteração registrada.'),
                    for (final AuditEntry e in audit) AuditTile(entry: e),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _organizer(DemoConsultation c, OrganizedDraft? draft) {
    final DemoWorkspace ws = demoSession.workspace;
    final bool pending = draft != null && draft.status == DraftStatus.pendente;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: PremiumCard(
        borderColor: pending ? AppColors.honey : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_outlined, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Organizar a consulta com o assistente',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Simulação por regras, sem IA ativa. Distribui a pré-consulta e '
              'a transcrição nas seções vazias. O resultado fica como '
              'rascunho até você revisar e confirmar; nada vai para o '
              'prontuário sem isso.',
              style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
            ),
            if (!pending) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              // Único campo do item da lista: sem nó próprio, a semântica
              // juntaria todo o texto da tela no rótulo do campo.
              Semantics(
                container: true,
                child: TextField(
                  controller: _transcript,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText:
                        'Transcrição ou anotações da consulta (opcional)',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ws.organize(c, transcript: _transcript.text);
                    setState(() => _reviewed = false);
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Organizar rascunho'),
                ),
              ),
              if (draft != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Último rascunho: ${draft.status.label.toLowerCase()}'
                    '${draft.reviewedBy == null ? '' : ' por ${draft.reviewedBy}'}.',
                    style: const TextStyle(color: AppColors.inkMuted),
                  ),
                ),
            ] else ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              DemoTag(
                'Rascunho do assistente: ${draft.status.label}',
                color: AppColors.honey,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (draft.isEmpty)
                const Text(
                  'Nada a sugerir: as seções já estão preenchidas ou não há '
                  'pré-consulta nem transcrição.',
                ),
              for (final MapEntry<SummarySection, String> e
                  in draft.suggestions.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Sugestão para ${e.key.label}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(e.value),
                    ],
                  ),
                ),
              for (final String n in draft.notes)
                Text(
                  n,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),
              Text(
                '${draft.source} - ${demoTime(draft.createdAt)}',
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _reviewed,
                onChanged: draft.isEmpty
                    ? null
                    : (bool? v) => setState(() => _reviewed = v ?? false),
                title: const Text(
                  'Revisei o conteúdo sugerido e confirmo que está correto',
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: !_reviewed || draft.isEmpty
                        ? null
                        : () {
                            ws.applyDraft(c, reviewed: _reviewed);
                            setState(() => _reviewed = false);
                            showDemoSnack(
                              context,
                              'Rascunho aplicado ao registro da consulta.',
                            );
                          },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar ao registro'),
                  ),
                  TextButton(
                    onPressed: () {
                      ws.discardDraft(c);
                      setState(() => _reviewed = false);
                    },
                    child: const Text('Descartar rascunho'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bool empty = text.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              empty ? 'Não registrado.' : text.trim(),
              style: empty ? const TextStyle(color: AppColors.inkMuted) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreVisitCard extends StatelessWidget {
  const _PreVisitCard({
    required this.patientId,
    required this.consultation,
    required this.visit,
  });

  final String patientId;
  final DemoConsultation consultation;
  final PreVisit? visit;

  @override
  Widget build(BuildContext context) {
    final PreVisit? v = visit;
    final PreVisitAnswers? a = v?.sentAnswers;
    if (v == null || a == null) {
      return DemoNotice(
        text: consultation.appointmentId == null
            ? 'Consulta sem horário da agenda: não há pré-consulta vinculada.'
            : 'A família não enviou pré-consulta para este horário.',
      );
    }
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Enviada em ${demoDate(v.sentAt!)} às ${demoTime(v.sentAt!)}',
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (String label, String text) in <(String, String)>[
            ('Motivo', a.reason),
            ('Sintomas', a.symptoms),
            ('Medicamentos em uso', a.medications),
            ('Observações da família', a.notes),
          ])
            if (text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text('$label: ${text.trim()}'),
              ),
          if (v.sentAttachments.isNotEmpty)
            Text('${v.sentAttachments.length} anexo(s) enviado(s)'),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go(
                preVisitReviewUrl(patientId, consultationId: consultation.id),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Abrir pré-consulta'),
            ),
          ),
        ],
      ),
    );
  }
}
