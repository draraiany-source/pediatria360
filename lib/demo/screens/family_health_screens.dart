import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/family_release.dart';
import '../../shared/clinical/growth.dart';
import '../../shared/previsit/pre_visit_guidance.dart';
import '../../shared/wellchild/milestones.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import 'documents_screens.dart' show docKindIcon;
import 'pre_visit_screens.dart';

String familyHealthUrl(String patientId) => '/rotina/$patientId/saude';

String familyDocumentsUrl(String patientId, {String? from}) =>
    '/rotina/$patientId/documentos${from == null ? '' : '?de=$from'}';

String _kindLabel(DemoAppointmentKind k) =>
    k == DemoAppointmentKind.teleconsulta ? 'Teleconsulta' : 'Presencial';

String _weekday(DateTime d) => const <String>[
  'segunda',
  'terça',
  'quarta',
  'quinta',
  'sexta',
  'sábado',
  'domingo',
][d.weekday - 1];

String _num(double v) =>
    v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',');

AppBar _bar(BuildContext context, String title, DemoPatient? p, String back) =>
    AppBar(
      leading: BackButton(onPressed: () => context.go(back)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title),
          if (p != null)
            Text(
              p.name,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
        ],
      ),
    );

/// Orientações antes da consulta, escritas pela clínica.
class DemoVisitGuidance extends StatelessWidget {
  const DemoVisitGuidance({required this.appointment, super.key});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<String> items = demoSession.preVisitGuidanceFor(appointment);
    final VisitCategory cat = demoSession.visitCategoryOf(appointment);
    return Container(
      key: ValueKey<String>('orientacoes-previas-${appointment.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.checklist_rounded, color: AppColors.brand),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Antes da consulta - ${cat.label.toLowerCase()}',
                  style: t.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final String s in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('•  '),
                  Expanded(child: Text(s, style: t.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PreVisitGuidanceRules.safetyNotice,
            style: t.bodySmall?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!demoSession.preVisitGuidance.isReviewed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                PreVisitGuidanceRules.suggestedLabel,
                style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Saúde

/// Visão de saúde da criança para o responsável: consultas, crescimento,
/// vacinas, marcos e orientações. Só o que a clínica liberou.
class DemoFamilyHealthScreen extends StatelessWidget {
  const DemoFamilyHealthScreen({required this.patientId, super.key});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(patientId);
        final String back = '/pacientes/$patientId';
        if (p == null) {
          return Scaffold(
            appBar: _bar(context, 'Saúde e desenvolvimento', null, back),
            body: DemoEmpty(
              title: 'Criança não encontrada',
              message: 'Esta criança não está vinculada ao seu perfil.',
              actionLabel: 'Ver crianças',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final TextTheme t = Theme.of(context).textTheme;
        final List<DemoAppointment> upcoming = demoSession
            .upcomingAppointmentsFor(p.id);
        final List<FamilyVisit> visits = demoSession.familyVisits(p.id);
        final List<GrowthMeasurement> growth = demoSession
            .growthFor(p.id)
            .where((GrowthMeasurement m) => !m.voided)
            .toList();
        final GrowthMeasurement? last = growth.isEmpty ? null : growth.last;
        final List<DemoVaccineRecord> vaccines = demoSession.vaccines
            .where((DemoVaccineRecord v) => v.patientId == p.id)
            .toList();
        final int given = vaccines
            .where(
              (DemoVaccineRecord v) => v.status == DemoVaccineStatus.registrada,
            )
            .length;
        final int pending = vaccines.length - given;
        final DemoConsultation? lastWellChild = demoSession
            .consultationsFor(p.id)
            .where((DemoConsultation c) => c.isWellChild && !c.isDraft)
            .firstOrNull;
        final List<MilestoneObservation> achieved =
            lastWellChild?.wellChild?.milestones
                .where(
                  (MilestoneObservation m) =>
                      m.state == MilestoneState.adquirido,
                )
                .toList() ??
            const <MilestoneObservation>[];
        final int orientations = demoSession.familyOrientations(p.id).length;
        final int docs = demoSession.familyDocuments(p.id).length;
        final String band = demoSession.visitAge(p, demoSession.now).band.label;

        Widget link(String label, IconData icon, String to, {Key? key}) =>
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: OutlinedButton.icon(
                key: key,
                onPressed: () => context.go(to),
                icon: Icon(icon),
                label: Text(label),
              ),
            );

        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: _bar(context, 'Saúde e desenvolvimento', p, back),
          body: DemoContent(
            maxWidth: 860,
            child: ListView(
              key: const ValueKey<String>('saude-familia'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.verified_user_outlined,
                  color: Color(0xFF0B6B8A),
                  text:
                      'Aqui aparecem as consultas, medidas, vacinas e '
                      'documentos que a clínica registrou e liberou para '
                      'você. As anotações clínicas do prontuário ficam com o '
                      'profissional.',
                ),
                const DemoSectionTitle('Próximas consultas'),
                if (upcoming.isEmpty)
                  Text(
                    'Nenhuma consulta marcada.',
                    style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  )
                else
                  for (final DemoAppointment a in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_weekday(a.start)}, '
                              '${formatDocDateTime(a.start)}',
                              style: t.titleSmall,
                            ),
                            Text(
                              '${a.typeLabel ?? a.reason} - '
                              '${_kindLabel(a.kind)}',
                              style: t.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            DemoVisitGuidance(appointment: a),
                            const SizedBox(height: AppSpacing.sm),
                            FilledButton.tonalIcon(
                              onPressed: () => context.go(
                                preVisitFamilyUrl(a.id, from: 'saude'),
                              ),
                              icon: const Icon(Icons.assignment_outlined),
                              label: const Text('Abrir pré-consulta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                const DemoSectionTitle('Consultas anteriores'),
                if (visits.isEmpty)
                  Text(
                    'Nenhuma consulta concluída ainda.',
                    style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  )
                else
                  for (final FamilyVisit v in visits)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.brand,
                        ),
                        title: Text(
                          '${v.kindLabel} - ${formatDocDate(v.date)}',
                        ),
                        subtitle: Text(
                          '${v.professional} - ${v.clinic}'
                          '${v.returnDate == null ? '' : '\nRetorno combinado: ${formatDocDate(v.returnDate!)}'}'
                          '\n${v.documents.isEmpty ? 'Nenhum documento liberado' : '${v.documents.length} documento(s) liberado(s)'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.go(familyDocumentsUrl(p.id, from: 'saude')),
                      ),
                    ),
                link(
                  docs == 0
                      ? 'Documentos da consulta'
                      : 'Documentos da consulta ($docs)',
                  Icons.folder_shared_outlined,
                  familyDocumentsUrl(p.id, from: 'saude'),
                  key: const ValueKey<String>('saude-documentos'),
                ),
                const DemoSectionTitle('Crescimento'),
                Text(
                  last == null
                      ? 'Nenhuma medida registrada pela clínica.'
                      : 'Última medida em ${formatDocDate(last.values.date)}: '
                            '${<String>[if (last.values.weightKg != null) '${_num(last.values.weightKg!)} kg', if (last.values.lengthCm != null) '${_num(last.values.lengthCm!)} cm'].join(' e ')}.',
                  style: t.bodyMedium,
                ),
                if (demoSession.canSeeGrowth)
                  link(
                    'Ver curvas de crescimento',
                    Icons.show_chart_rounded,
                    '/pacientes/${p.id}/crescimento',
                  ),
                const DemoSectionTitle('Vacinação'),
                Text(
                  vaccines.isEmpty
                      ? 'Nenhuma vacina lançada.'
                      : '$given dose(s) registrada(s)'
                            '${pending == 0 ? '.' : ' e $pending pendente(s).'}',
                  style: t.bodyMedium,
                ),
                if (demoSession.canOpen(DemoModule.vacinacao))
                  link(
                    'Ver calendário de vacinação',
                    Icons.vaccines_outlined,
                    '/vacinacao',
                  ),
                const DemoSectionTitle('Marcos do desenvolvimento'),
                if (achieved.isEmpty)
                  Text(
                    'Nenhum marco registrado na puericultura.',
                    style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  )
                else ...<Widget>[
                  Text(
                    'Conquistas registradas na puericultura de '
                    '${formatDocDate(lastWellChild!.startedAt)}:',
                    style: t.bodyMedium,
                  ),
                  for (final MilestoneObservation m in achieved)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: AppColors.honey,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text('${m.title} (${m.area.label})')),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Dúvidas sobre o desenvolvimento: anote na pré-consulta '
                  'para conversar com o profissional.',
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const DemoSectionTitle('Orientações por faixa etária'),
                Text('Faixa atual: $band.', style: t.bodyMedium),
                Text(
                  orientations == 0
                      ? 'A clínica ainda não liberou orientações para esta '
                            'criança.'
                      : '$orientations orientação(ões) liberada(s) pela '
                            'clínica.',
                  style: t.bodySmall,
                ),
                link(
                  'Ver orientações da clínica',
                  Icons.menu_book_outlined,
                  '/rotina/${p.id}/orientacoes',
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ Pós-consulta

/// Receitas, atestados, encaminhamentos, exames e orientações liberados.
class DemoFamilyDocumentsScreen extends StatefulWidget {
  const DemoFamilyDocumentsScreen({
    required this.patientId,
    super.key,
    this.from,
  });

  final String patientId;
  final String? from;

  @override
  State<DemoFamilyDocumentsScreen> createState() =>
      _DemoFamilyDocumentsScreenState();
}

class _DemoFamilyDocumentsScreenState extends State<DemoFamilyDocumentsScreen> {
  String? _group;

  String get _back => widget.from == 'saude'
      ? familyHealthUrl(widget.patientId)
      : '/pacientes/${widget.patientId}';

  bool _shows(ClinicalDocRecord d) =>
      _group == null || FamilyReleaseRules.groupOf(d.kind) == _group;

  Widget _tile(BuildContext context, ClinicalDocRecord d) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: ListTile(
      leading: Icon(docKindIcon(d.kind), color: AppColors.brand),
      title: Text(d.title),
      subtitle: Text(
        '${FamilyReleaseRules.groupOf(d.kind)} - emitido em '
        '${formatDocDate(d.current.issuedAt!)}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(
        '/rotina/${widget.patientId}/documentos/${d.id}'
        '${widget.from == null ? '' : '?de=${widget.from}'}',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(widget.patientId);
        final TextTheme t = Theme.of(context).textTheme;
        if (p == null) {
          return Scaffold(
            appBar: _bar(context, 'Documentos da consulta', null, _back),
            body: DemoEmpty(
              title: 'Criança não encontrada',
              message: 'Esta criança não está vinculada ao seu perfil.',
              actionLabel: 'Ver crianças',
              onAction: () => context.go('/pacientes'),
            ),
          );
        }
        final List<FamilyVisit> visits = demoSession
            .familyVisits(p.id)
            .where((FamilyVisit v) => v.documents.any(_shows))
            .toList();
        final List<ClinicalDocRecord> loose = demoSession
            .familyLooseDocuments(p.id)
            .where(_shows)
            .toList();
        final bool any = demoSession.familyDocuments(p.id).isNotEmpty;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: _bar(context, 'Documentos da consulta', p, _back),
          body: DemoContent(
            maxWidth: 820,
            child: ListView(
              key: const ValueKey<String>('pos-consulta-lista'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.verified_outlined,
                  color: Color(0xFF0B6B8A),
                  text:
                      'Documentos emitidos e liberados pelo profissional. '
                      'Siga sempre o que foi combinado na consulta e, em caso '
                      'de dúvida, fale com a clínica.',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (any)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _group == null,
                        onSelected: (_) => setState(() => _group = null),
                      ),
                      for (final (String g, _) in FamilyReleaseRules.groups)
                        ChoiceChip(
                          label: Text(g),
                          selected: _group == g,
                          onSelected: (_) => setState(() => _group = g),
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (!any)
                  const SizedBox(
                    height: 280,
                    child: DemoEmpty(
                      title: 'Nenhum documento liberado',
                      message:
                          'Quando o profissional liberar receitas, atestados, '
                          'encaminhamentos, exames ou orientações, eles '
                          'aparecem aqui.',
                    ),
                  )
                else if (visits.isEmpty && loose.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Nenhum documento deste tipo.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                for (final FamilyVisit v in visits) ...<Widget>[
                  DemoSectionTitle(
                    '${v.kindLabel} de ${formatDocDate(v.date)}',
                  ),
                  Text('${v.professional} - ${v.clinic}', style: t.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  for (final ClinicalDocRecord d in v.documents)
                    if (_shows(d)) _tile(context, d),
                ],
                if (loose.isNotEmpty) ...<Widget>[
                  const DemoSectionTitle('Outros documentos'),
                  for (final ClinicalDocRecord d in loose) _tile(context, d),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
