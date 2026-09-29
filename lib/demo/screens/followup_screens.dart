import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/scheduling/follow_up.dart';
import '../../shared/scheduling/reminders.dart';
import '../../shared/scheduling/slots.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_scheduling.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

const String followUpPath = '/acompanhamento';
const String followUpCriteriaPath = '/acompanhamento/criterios';
const String remindersPath = '/lembretes';

String _dmy(DateTime d) => demoDate(d);

String _dmyHm(DateTime d) => '${demoDate(d)} ${demoTime(d)}';

Color reminderStatusColor(ReminderStatus s) => switch (s) {
  ReminderStatus.naoEnviado => AppColors.warning,
  ReminderStatus.enviado => AppColors.inkMuted,
  ReminderStatus.entregue => AppColors.info,
  ReminderStatus.lido => AppColors.brand,
  ReminderStatus.respondido => AppColors.success,
  ReminderStatus.falhou => AppColors.danger,
};

// ------------------------------------------------------------ Painel

/// Frequentes, inativos e retorno próximo, com filtros.
class DemoFollowUpScreen extends StatefulWidget {
  const DemoFollowUpScreen({super.key, this.initial});

  final FollowUpCategory? initial;

  @override
  State<DemoFollowUpScreen> createState() => _DemoFollowUpScreenState();
}

class _DemoFollowUpScreenState extends State<DemoFollowUpScreen> {
  late FollowUpCategory _cat = widget.initial ?? FollowUpCategory.inativo;
  String? _professional;
  String? _unit;
  late int _period = demoSession.scheduling.criteria.frequentWindowMonths;

  static const List<int> _periods = <int>[3, 6, 12, 24];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoScheduling store = demoSession.scheduling;
        final String? locked = store.lockedProfessionalId;
        final List<(DemoPatient, FollowUpStatus)> all = store.followUp(
          professionalId: _professional,
          unitId: _unit,
          periodMonths: _period,
        );
        final Map<FollowUpCategory, int> counts = countFollowUp(
          all.map(((DemoPatient, FollowUpStatus) e) => e.$2),
        );
        final List<(DemoPatient, FollowUpStatus)> members =
            all
                .where(
                  ((DemoPatient, FollowUpStatus) e) => e.$2.isIn(_cat),
                )
                .toList()
              ..sort(
                (
                  (DemoPatient, FollowUpStatus) a,
                  (DemoPatient, FollowUpStatus) b,
                ) => a.$1.name.compareTo(b.$1.name),
              );
        final int protectedCount = all
            .where(
              ((DemoPatient, FollowUpStatus) e) => e.$2.inactiveButScheduled,
            )
            .length;
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/inicio')),
            title: const Text('Acompanhamento de pacientes'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Critérios da clínica',
                onPressed: () => context.go(followUpCriteriaPath),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          body: ListView(
            key: const ValueKey<String>('acompanhamento-lista'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (locked != null)
                      Text(
                        'Seus pacientes - ${DemoProfessional.byId(locked).name}',
                        style: t.titleSmall,
                      )
                    else ...<Widget>[
                      _FilterRow(
                        label: 'Profissional',
                        options: <(String?, String)>[
                          (null, 'Todos'),
                          for (final DemoAccount a in DemoProfessional.accounts)
                            (a.id, a.name),
                        ],
                        selected: _professional,
                        onSelected: (String? v) => setState(() {
                          _professional = v;
                          if (v != null) _unit = null;
                        }),
                      ),
                      _FilterRow(
                        label: 'Clínica',
                        options: <(String?, String)>[
                          (null, 'Todas'),
                          for (final DemoUnit u in DemoScheduling.units)
                            (u.id, u.name),
                        ],
                        selected: _unit,
                        onSelected: (String? v) => setState(() {
                          _unit = v;
                          if (v != null) _professional = null;
                        }),
                      ),
                    ],
                    _FilterRow(
                      label: 'Período',
                      options: <(String?, String)>[
                        for (final int m in _periods) ('$m', '$m meses'),
                      ],
                      selected: '$_period',
                      onSelected: (String? v) =>
                          setState(() => _period = int.parse(v!)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final FollowUpCategory c in FollowUpCategory.values)
                          _IndicatorCard(
                            category: c,
                            count: counts[c] ?? 0,
                            selected: c == _cat,
                            onTap: () => setState(() => _cat = c),
                          ),
                      ],
                    ),
                    DemoSectionTitle('${_cat.label} (${members.length})'),
                    Text(
                      store.criteria.describe(_cat),
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_cat == FollowUpCategory.inativo && protectedCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: DemoNotice(
                          icon: Icons.event_available_outlined,
                          text: protectedCount == 1
                              ? '1 paciente passou do prazo, mas já tem '
                                    'consulta marcada e não conta como inativo.'
                              : '$protectedCount pacientes passaram do prazo, '
                                    'mas já têm consulta marcada e não contam '
                                    'como inativos.',
                        ),
                      ),
                    if (members.isEmpty)
                      Text(
                        'Nenhum paciente neste indicador com os filtros atuais.',
                        style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                      ),
                    for (final (DemoPatient p, FollowUpStatus st) in members)
                      _FollowUpTile(patient: p, status: st),
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

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String?, String)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final (String? id, String name) in options)
            ChoiceChip(
              label: Text(name),
              selected: selected == id,
              onSelected: (_) => onSelected(id),
            ),
        ],
      ),
    );
  }
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.category,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final FollowUpCategory category;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  Color get _color => switch (category) {
    FollowUpCategory.frequente => AppColors.success,
    FollowUpCategory.inativo => AppColors.raspberry,
    FollowUpCategory.retornoProximo => AppColors.brand,
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return SizedBox(
      width: 180,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Indicador ${category.label}: $count',
        excludeSemantics: true,
        child: PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor: selected ? _color : null,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$count',
                style: t.headlineMedium?.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(category.label, style: t.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.patient, required this.status});

  final DemoPatient patient;
  final FollowUpStatus status;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DemoScheduling store = demoSession.scheduling;
    final List<DemoContactAttempt> tries = store.attemptsFor(patient.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(patient.name, style: t.titleSmall),
            Text(patient.guardianName, style: t.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            _Line(
              Icons.history_rounded,
              status.lastVisit == null
                  ? 'Sem consulta registrada'
                  : 'Última consulta: ${_dmy(status.lastVisit!)}',
            ),
            _Line(
              Icons.event_outlined,
              status.nextAppointment == null
                  ? 'Próximo agendamento: nenhum'
                  : 'Próximo agendamento: ${_dmyHm(status.nextAppointment!)}',
            ),
            if (status.recommendedReturn != null)
              _Line(Icons.update_rounded, returnLabel(status)),
            _Line(
              Icons.bar_chart_rounded,
              'Consultas no período: ${status.visitsInPeriod}',
            ),
            _Line(
              Icons.phone_in_talk_outlined,
              tries.isEmpty
                  ? 'Tentativas de contato: 0'
                  : 'Tentativas de contato: ${tries.length} (última em '
                        '${_dmy(tries.first.at)}, ${tries.first.channel.label}: '
                        '${tries.first.outcome})',
            ),
            if (store.canOperate)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => showContactAttemptDialog(context, patient),
                  icon: const Icon(Icons.add_call, size: 18),
                  label: Text('Registrar contato com ${patient.name}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: color ?? AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _contactOutcomes = <String>[
  'Agendou consulta',
  'Não atendeu',
  'Sem resposta',
  'Pediu para ligar depois',
  'Não deseja retornar',
];

Future<void> showContactAttemptDialog(
  BuildContext context,
  DemoPatient patient,
) async {
  final (ContactChannel, String, String)? result =
      await showDialog<(ContactChannel, String, String)>(
        context: context,
        builder: (BuildContext context) =>
            _ContactAttemptDialog(patientName: patient.name),
      );
  if (result == null) return;
  demoSession.scheduling.addContactAttempt(
    patient.id,
    channel: result.$1,
    outcome: result.$2,
    note: result.$3,
  );
  if (context.mounted) {
    showDemoSnack(context, 'Tentativa de contato registrada.');
  }
}

class _ContactAttemptDialog extends StatefulWidget {
  const _ContactAttemptDialog({required this.patientName});

  final String patientName;

  @override
  State<_ContactAttemptDialog> createState() => _ContactAttemptDialogState();
}

class _ContactAttemptDialogState extends State<_ContactAttemptDialog> {
  ContactChannel _channel = ContactChannel.telefone;
  String _outcome = _contactOutcomes[1];
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar tentativa de contato'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.patientName),
            const SizedBox(height: AppSpacing.sm),
            const Text('Canal'),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                for (final ContactChannel c in ContactChannel.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c == _channel,
                    onSelected: (_) => setState(() => _channel = c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Resultado'),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                for (final String o in _contactOutcomes)
                  ChoiceChip(
                    label: Text(o),
                    selected: o == _outcome,
                    onSelected: (_) => setState(() => _outcome = o),
                  ),
              ],
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Observação (sem dados clínicos)',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_channel, _outcome, _note.text)),
          child: const Text('Salvar contato'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Critérios

class DemoFollowUpCriteriaScreen extends StatefulWidget {
  const DemoFollowUpCriteriaScreen({super.key});

  @override
  State<DemoFollowUpCriteriaScreen> createState() =>
      _DemoFollowUpCriteriaScreenState();
}

class _DemoFollowUpCriteriaScreenState
    extends State<DemoFollowUpCriteriaScreen> {
  late FollowUpCriteria _c = demoSession.scheduling.criteria;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: demoSession,
    builder: (BuildContext context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final DemoScheduling store = demoSession.scheduling;
    final bool edit = store.canEditClinicSettings;
    final SchedulingPolicy p = store.policy;
    final TextTheme t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(followUpPath)),
        title: const Text('Critérios de acompanhamento'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          DemoContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!edit)
                  const DemoNotice(
                    icon: Icons.lock_outline_rounded,
                    text: 'Só a administração da clínica altera os critérios. '
                        'Aqui você consulta os valores em uso.',
                  ),
                _Stepper(
                  label: 'Inativo após (meses sem consulta)',
                  value: _c.inactiveAfterMonths,
                  min: 1,
                  max: FollowUpCriteria.maxInactiveMonths,
                  enabled: edit,
                  onChanged: (int v) =>
                      setState(() => _c = _c.copyWith(inactiveAfterMonths: v)),
                ),
                _Stepper(
                  label: 'Retorno próximo (dias antes da data recomendada)',
                  value: _c.returnSoonDays,
                  min: 1,
                  max: FollowUpCriteria.maxReturnSoonDays,
                  enabled: edit,
                  onChanged: (int v) =>
                      setState(() => _c = _c.copyWith(returnSoonDays: v)),
                ),
                _Stepper(
                  label: 'Frequente (consultas no período)',
                  value: _c.frequentMinVisits,
                  min: 2,
                  max: FollowUpCriteria.maxFrequentVisits,
                  enabled: edit,
                  onChanged: (int v) =>
                      setState(() => _c = _c.copyWith(frequentMinVisits: v)),
                ),
                _Stepper(
                  label: 'Período padrão (meses)',
                  value: _c.frequentWindowMonths,
                  min: 1,
                  max: FollowUpCriteria.maxWindowMonths,
                  enabled: edit,
                  onChanged: (int v) =>
                      setState(() => _c = _c.copyWith(frequentWindowMonths: v)),
                ),
                const SizedBox(height: AppSpacing.sm),
                const DemoNotice(
                  icon: Icons.event_available_outlined,
                  text: 'Quem já tem consulta futura marcada nunca é '
                      'classificado como inativo.',
                ),
                if (edit) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _c == store.criteria
                        ? null
                        : () {
                            try {
                              store.setCriteria(_c);
                              showDemoSnack(context, 'Critérios salvos.');
                            } on StateError catch (e) {
                              showDemoSnack(context, e.message);
                            }
                          },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar critérios'),
                  ),
                ],
                const DemoSectionTitle('Regras de agendamento da clínica'),
                Text(
                  'Antecedência mínima para marcar: ${p.minLeadHours} h\n'
                  'Agenda aberta até ${p.maxDaysAhead} dias à frente\n'
                  'Remarcar pelo app: até ${p.selfRescheduleUntilHours} h antes\n'
                  'Cancelar pelo app: até ${p.selfCancelUntilHours} h antes\n'
                  'Fora desses prazos, só a recepção altera.',
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            IconButton(
              tooltip: 'Diminuir: $label',
              onPressed: enabled && value > min
                  ? () => onChanged(value - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Aumentar: $label',
              onPressed: enabled && value < max
                  ? () => onChanged(value + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Lembretes

class DemoRemindersScreen extends StatefulWidget {
  const DemoRemindersScreen({super.key});

  @override
  State<DemoRemindersScreen> createState() => _DemoRemindersScreenState();
}

class _DemoRemindersScreenState extends State<DemoRemindersScreen> {
  late final Set<int> _offsets = demoSession.scheduling.reminderSettings.offsetsHours
      .toSet();

  void _run() {
    try {
      final DemoReminderRun run = demoSession.scheduling.processReminders();
      showDemoSnack(
        context,
        run.total == 0
            ? 'Nenhum lembrete pendente agora.'
            : 'Rodada concluída: ${run.sent} enviado(s), ${run.failed} '
                  'falha(s), ${run.blocked} não enviado(s) por consentimento '
                  'ou preferência.',
      );
    } on StateError catch (e) {
      showDemoSnack(context, e.message);
    }
  }

  void _save() {
    try {
      demoSession.scheduling.setReminderSettings(
        demoSession.scheduling.reminderSettings.copyWith(
          offsetsHours: _offsets.toList()..sort((int a, int b) => b - a),
        ),
      );
      showDemoSnack(context, 'Intervalos salvos.');
    } on StateError catch (e) {
      showDemoSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoScheduling store = demoSession.scheduling;
        final bool edit = store.canEditClinicSettings;
        final TextTheme t = Theme.of(context).textTheme;
        final List<DemoReceptionAlert> alerts = store.openAlerts;
        final List<ReminderRecord> log = store.reminderLog;
        final bool dirty =
            !_sameSet(_offsets, store.reminderSettings.offsetsHours.toSet());
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/inicio')),
            title: const Text('Lembretes de consulta'),
          ),
          body: ListView(
            key: const ValueKey<String>('lembretes-lista'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _WhatsAppCard(),
                    const DemoSectionTitle('Quando enviar'),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final int h in ReminderSettings.choices)
                          FilterChip(
                            label: Text(offsetLabel(h)),
                            selected: _offsets.contains(h),
                            onSelected: edit
                                ? (bool on) => setState(
                                    () => on ? _offsets.add(h) : _offsets.remove(h),
                                  )
                                : null,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      edit
                          ? 'Até ${ReminderSettings.maxReminders} lembretes '
                                'por consulta.'
                          : 'Intervalos definidos pela administração da '
                                'clínica.',
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                    if (edit)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: dirty ? _save : null,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar intervalos'),
                        ),
                      ),
                    if (store.canOperate) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _run,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Enviar lembretes pendentes agora'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No app real, uma função agendada faz esta rodada '
                        'periodicamente.',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                    DemoSectionTitle('Contato manual (${alerts.length})'),
                    if (alerts.isEmpty)
                      Text(
                        'Nenhuma pendência para a recepção.',
                        style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                      ),
                    for (final DemoReceptionAlert a in alerts)
                      DemoAlertTile(alert: a),
                    DemoSectionTitle('Registro de envios (${log.length})'),
                    for (final ReminderRecord r in log) DemoReminderTile(record: r),
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

bool _sameSet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

class _WhatsAppCard extends StatelessWidget {
  const _WhatsAppCard();

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.chat_outlined, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Integração com WhatsApp', style: t.titleSmall),
              ),
              const ClinicalBadge(
                label: 'Modo simulação',
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Provedor: ${DemoWhatsAppSimulator.provider}.\n'
            'Modelo aprovado: ${DemoWhatsAppSimulator.templateName} '
            '(categoria utilidade), com os botões Confirmar, Reagendar e '
            'Cancelar.\n'
            'Nenhuma mensagem sai desta demonstração. O envio real depende '
            'das credenciais da Meta e da autorização da clínica.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Uma linha do registro: status, horário, destinatário e resposta.
class DemoReminderTile extends StatelessWidget {
  const DemoReminderTile({required this.record, super.key});

  final ReminderRecord record;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final ReminderRecord r = record;
    final DemoPatient? p = demoSession.patients
        .where((DemoPatient x) => x.id == r.patientId)
        .firstOrNull;
    final List<String> times = <String>[
      'Criado ${_dmyHm(r.createdAt)}',
      if (r.sentAt != null) 'enviado ${demoTime(r.sentAt!)}',
      if (r.deliveredAt != null) 'entregue ${demoTime(r.deliveredAt!)}',
      if (r.readAt != null) 'lido ${demoTime(r.readAt!)}',
      if (r.repliedAt != null) 'respondido ${demoTime(r.repliedAt!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: demoSession.canOpen(DemoModule.agenda)
            ? () => context.go('/agenda/${r.appointmentId}')
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${p?.name ?? 'Paciente'} - ${offsetLabel(r.offsetHours)}',
                    style: t.titleSmall,
                  ),
                ),
                ClinicalBadge(
                  label: r.status.label,
                  color: reminderStatusColor(r.status),
                ),
              ],
            ),
            _Line(
              Icons.person_outline,
              'Para: ${r.recipientName} (${r.recipientMasked}) - '
              '${r.channel.label}',
            ),
            _Line(Icons.schedule_rounded, times.join(', ')),
            if (r.reply != null)
              _Line(
                Icons.reply_rounded,
                'Resposta: ${r.reply!.label}',
                color: AppColors.success,
              ),
            if (r.failureReason != null)
              _Line(
                Icons.error_outline_rounded,
                r.failureReason!,
                color: AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}

class DemoAlertTile extends StatelessWidget {
  const DemoAlertTile({required this.alert, super.key});

  final DemoReceptionAlert alert;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DemoScheduling store = demoSession.scheduling;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: AppColors.warning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.support_agent_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(alert.kind.label, style: t.titleSmall)),
                Text(_dmyHm(alert.at), style: t.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(alert.text, style: t.bodySmall),
            Wrap(
              spacing: AppSpacing.xs,
              children: <Widget>[
                if (alert.appointmentId != null &&
                    demoSession.canOpen(DemoModule.agenda))
                  TextButton(
                    onPressed: () =>
                        context.go('/agenda/${alert.appointmentId}'),
                    child: const Text('Abrir agendamento'),
                  ),
                if (store.canOperate)
                  TextButton.icon(
                    onPressed: () => _resolve(context),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Registrar contato feito'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(BuildContext context) async {
    String outcome = 'Confirmou por telefone';
    const List<String> outcomes = <String>[
      'Confirmou por telefone',
      'Remarcado pela recepção',
      'Cancelado pela recepção',
      'Não atendeu',
    ];
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter set) => AlertDialog(
          title: const Text('Contato manual'),
          content: Wrap(
            spacing: AppSpacing.xs,
            children: <Widget>[
              for (final String o in outcomes)
                ChoiceChip(
                  label: Text(o),
                  selected: o == outcome,
                  onSelected: (_) => set(() => outcome = o),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Concluir pendência'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    demoSession.scheduling.resolveAlert(alert.id, resolution: outcome);
    if (context.mounted) showDemoSnack(context, 'Pendência concluída.');
  }
}

// ------------------------------------------------------------ Agendamento

/// Lembretes e histórico no detalhe do agendamento (recepção e
/// profissional).
class DemoAppointmentReminders extends StatelessWidget {
  const DemoAppointmentReminders({required this.appointment, super.key});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final DemoScheduling store = demoSession.scheduling;
    if (!store.canSeeReminders) return const SizedBox.shrink();
    final List<ReminderRecord> list = store.remindersFor(appointment.id);
    final List<ReminderEvent> events = store.historyFor(appointment.id);
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionTitle('Lembretes enviados'),
        if (list.isEmpty)
          Text(
            'Nenhum lembrete ainda para esta consulta.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        for (final ReminderRecord r in list) DemoReminderTile(record: r),
        if (events.isNotEmpty) ...<Widget>[
          const DemoSectionTitle('Histórico do agendamento'),
          for (final ReminderEvent e in events)
            _Line(Icons.circle, '${_dmyHm(e.at)} - ${e.text}'),
        ],
      ],
    );
  }
}

/// Remarcar e cancelar pela recepção, com horários realmente livres.
class DemoAppointmentActions extends StatelessWidget {
  const DemoAppointmentActions({required this.appointment, super.key});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final DemoScheduling store = demoSession.scheduling;
    if (!store.canManageAgenda || !appointment.status.holdsSlot) {
      return const SizedBox.shrink();
    }
    if (appointment.status == DemoAppointmentStatus.concluido) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _reschedule(context),
            icon: const Icon(Icons.event_repeat_rounded),
            label: const Text('Remarcar'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.event_busy_rounded),
            label: const Text('Cancelar consulta'),
          ),
        ],
      ),
    );
  }

  Future<void> _reschedule(BuildContext context) async {
    final DemoScheduling store = demoSession.scheduling;
    final DemoAppointment a = appointment;
    final List<DateTime> slots = store.findSlots(
      SlotQuery(
        professionalId: a.professionalId,
        durationMinutes: a.durationMinutes,
        from: demoSession.now,
        patientId: a.patientId,
        ignoreAppointmentId: a.id,
      ),
      limit: 6,
    );
    final DateTime? chosen = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text('Horários livres (${a.durationMinutes} min)'),
        children: <Widget>[
          if (slots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Nenhum horário livre nas próximas duas semanas.'),
            ),
          for (final DateTime s in slots)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text(reminderWhen(s)),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmar remarcação'),
        content: Text(
          'De ${reminderWhen(a.start)} para ${reminderWhen(chosen)}. A '
          'família recebe novo lembrete conforme a preferência de contato.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar remarcação'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      store.reschedule(a.id, chosen);
      showDemoSnack(context, 'Consulta remarcada para ${reminderWhen(chosen)}.');
    } on Exception catch (e) {
      showDemoSnack(context, e.toString());
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar consulta?'),
        content: Text(
          'O horário de ${reminderWhen(appointment.start)} fica livre para '
          'outro paciente.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Manter'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar consulta'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    demoSession.scheduling.cancel(appointment.id);
    showDemoSnack(context, 'Consulta cancelada. Horário liberado.');
  }
}

// ------------------------------------------------------------ Início

/// Atalhos do módulo no início de recepção, profissional e administração.
class DemoSchedulingHomeCard extends StatelessWidget {
  const DemoSchedulingHomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final DemoScheduling store = demoSession.scheduling;
    if (!store.canSeeFollowUp) return const SizedBox.shrink();
    final int pending = store.openAlerts.length;
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionTitle('Acompanhamento e lembretes'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: () => context.go(followUpPath),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Acompanhamento de pacientes'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go(remindersPath),
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                store.canOperate && pending > 0
                    ? 'Lembretes - $pending para contato manual'
                    : 'Lembretes de consulta',
              ),
            ),
            if (store.canManageAgenda)
              FilledButton.tonalIcon(
                onPressed: () => context.go('/agendar'),
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Agendar consulta'),
              ),
          ],
        ),
        if (store.canOperate && pending > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Lembretes que falharam ou não puderam ser enviados aparecem '
              'para contato manual.',
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }
}
