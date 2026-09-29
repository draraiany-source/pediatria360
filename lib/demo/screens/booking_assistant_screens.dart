import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/scheduling/assistant_text.dart';
import '../../shared/scheduling/booking_assistant.dart';
import '../../shared/scheduling/reminders.dart';
import '../demo_data.dart';
import '../demo_scheduling.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import 'family_health_screens.dart';
import 'pre_visit_screens.dart' show preVisitFamilyUrl;

const String bookingPath = '/agendar';
const String familyMessagesPath = '/mensagens';

String bookingUrl({AssistantIntent? intent, String? appointmentId}) {
  final List<String> q = <String>[
    if (intent != null) 'acao=${intent.name}',
    if (appointmentId != null) 'consulta=$appointmentId',
  ];
  return q.isEmpty ? bookingPath : '$bookingPath?${q.join('&')}';
}

AssistantIntent? intentFromSlug(String? slug) {
  for (final AssistantIntent i in AssistantIntent.values) {
    if (i.name == slug) return i;
  }
  return null;
}

// ------------------------------------------------------------ Assistente

/// Conversa de agendamento (responsável; a recepção usa a mesma tela para
/// marcar por telefone).
class DemoBookingAssistantScreen extends StatefulWidget {
  const DemoBookingAssistantScreen({
    super.key,
    this.intent,
    this.appointmentId,
  });

  final AssistantIntent? intent;
  final String? appointmentId;

  @override
  State<DemoBookingAssistantScreen> createState() =>
      _DemoBookingAssistantScreenState();
}

class _DemoBookingAssistantScreenState
    extends State<DemoBookingAssistantScreen> {
  late BookingAssistant _a = demoSession.scheduling.assistantFor(
    intent: widget.intent,
    appointmentId: widget.appointmentId,
  );
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _toBottom();
  }

  @override
  void didUpdateWidget(DemoBookingAssistantScreen old) {
    super.didUpdateWidget(old);
    if (old.intent != widget.intent ||
        old.appointmentId != widget.appointmentId) {
      _a = demoSession.scheduling.assistantFor(
        intent: widget.intent,
        appointmentId: widget.appointmentId,
      );
      _toBottom();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _a.send(text));
    _text.clear();
    _toBottom();
  }

  void _restart() {
    setState(() => _a = demoSession.scheduling.assistantFor(restart: true));
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final bool reception = demoSession.profile == DemoProfile.recepcao;
    final List<String> options = _a.options;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go(reception ? '/agenda' : '/inicio'),
        ),
        title: Text(
          reception ? 'Agendar consulta' : 'Agendar com o assistente',
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Recomeçar conversa',
            onPressed: _restart,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: DemoContent(
        maxWidth: 720,
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: DemoNotice(
                icon: Icons.smart_toy_outlined,
                text:
                    'Demonstração: as respostas do assistente são simuladas '
                    'por regras, sem modelo de IA ativo. Os horários, bloqueios '
                    'e permissões são os reais da agenda de exemplo, e nada é '
                    'gravado sem a sua confirmação.',
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey<String>('assistente-conversa'),
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _a.messages.length,
                itemBuilder: (BuildContext context, int i) =>
                    _Bubble(message: _a.messages[i]),
              ),
            ),
            if (options.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final String o in options)
                      OutlinedButton(onPressed: () => _send(o), child: Text(o)),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                          labelText: 'Mensagem para o assistente',
                          hintText: 'Ex.: retorno da Luna na terça de manhã',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      tooltip: 'Enviar mensagem',
                      onPressed: () => _send(_text.text),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final bool user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: user ? AppColors.brand : Colors.white,
                  borderRadius: AppRadius.lgAll,
                  border: user ? null : Border.all(color: AppColors.line),
                ),
                child: Text(
                  message.text,
                  style: t.bodyMedium?.copyWith(
                    color: user ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
              if (message.card != null) _Card(card: message.card!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});

  final AssistantCard card;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final (Color color, IconData icon) = switch (card.kind) {
      AssistantCardKind.urgency => (AppColors.emergency, Icons.emergency),
      AssistantCardKind.summary => (AppColors.brand, Icons.fact_check_outlined),
      AssistantCardKind.booked => (AppColors.success, Icons.event_available),
      AssistantCardKind.rescheduled => (AppColors.success, Icons.event_repeat),
      AssistantCardKind.cancelled => (AppColors.inkMuted, Icons.event_busy),
      AssistantCardKind.handoff => (AppColors.warning, Icons.support_agent),
    };
    final bool family = demoSession.profile == DemoProfile.responsavel;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    card.title,
                    style: t.titleSmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final String l in card.lines) Text(l, style: t.bodySmall),
            if ((card.kind == AssistantCardKind.booked ||
                    card.kind == AssistantCardKind.rescheduled) &&
                card.appointmentId != null &&
                family &&
                demoSession.appointmentById(card.appointmentId!) !=
                    null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              DemoVisitGuidance(
                appointment: demoSession.appointmentById(card.appointmentId!)!,
              ),
            ],
            if (card.kind == AssistantCardKind.booked &&
                card.appointmentId != null &&
                family) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: () => context.go(
                  preVisitFamilyUrl(card.appointmentId!, from: 'agendar'),
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Preencher pré-consulta'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Mensagens

/// Conversa simulada do WhatsApp do responsável com a clínica.
class DemoFamilyMessagesScreen extends StatefulWidget {
  const DemoFamilyMessagesScreen({super.key});

  @override
  State<DemoFamilyMessagesScreen> createState() =>
      _DemoFamilyMessagesScreenState();
}

class _DemoFamilyMessagesScreenState extends State<DemoFamilyMessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => demoSession.scheduling.markFamilyMessagesRead(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoScheduling store = demoSession.scheduling;
        final List<ReminderRecord> list = store.familyMessages();
        final GuardianContact c = store.familyContact;
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/inicio')),
            title: const Text('Mensagens da clínica'),
          ),
          body: ListView(
            key: const ValueKey<String>('mensagens-lista'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DemoNotice(
                      icon: Icons.chat_outlined,
                      text:
                          'Simulação da conversa no WhatsApp. No app real a '
                          'mensagem chega pelo número oficial da clínica.',
                    ),
                    const DemoSectionTitle('Preferência de contato'),
                    PremiumCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Receber lembretes de consulta'),
                            subtitle: Text(
                              c.reminderConsent && c.consentAt != null
                                  ? 'Autorizado em ${demoDate(c.consentAt!)}'
                                  : 'Sem autorização, a clínica não envia '
                                        'lembretes automáticos.',
                            ),
                            value: c.reminderConsent,
                            onChanged: (bool v) =>
                                store.setFamilyContact(consent: v),
                          ),
                          Text('Canal preferido', style: t.labelLarge),
                          Wrap(
                            spacing: AppSpacing.xs,
                            children: <Widget>[
                              for (final ContactChannel ch
                                  in ContactChannel.values)
                                ChoiceChip(
                                  label: Text(ch.label),
                                  selected: c.preferred == ch,
                                  onSelected: (_) =>
                                      store.setFamilyContact(preferred: ch),
                                ),
                            ],
                          ),
                          Text(
                            'Número: ${maskPhone(c.phone)} (fictício)',
                            style: t.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const DemoSectionTitle('Conversa'),
                    if (list.isEmpty)
                      Text(
                        'Nenhuma mensagem da clínica.',
                        style: t.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    for (final ReminderRecord r in list)
                      _ReminderMessage(record: r),
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

class _ReminderMessage extends StatelessWidget {
  const _ReminderMessage({required this.record});

  final ReminderRecord record;

  void _reply(BuildContext context, ReminderReply reply) {
    try {
      demoSession.scheduling.replyToReminder(record.id, reply);
    } on StateError catch (e) {
      showDemoSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DemoScheduling store = demoSession.scheduling;
    final DemoAppointment? a = demoSession.appointmentById(
      record.appointmentId,
    );
    final bool open = record.awaitingReply && a != null && a.status.holdsSlot;
    final String? answer = store.replyAnswers[record.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(record.text, style: t.bodyMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${demoDate(record.createdAt)} ${demoTime(record.createdAt)}',
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                    if (open) ...<Widget>[
                      const Divider(),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          for (final ReminderReply r in ReminderReply.values)
                            OutlinedButton(
                              onPressed: () => _reply(context, r),
                              child: Text(r.label),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (record.reply != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Text(
                  record.reply!.label,
                  style: t.bodyMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
          if (answer != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(answer, style: t.bodyMedium),
                      if (record.reply == ReminderReply.reagendar &&
                          a != null &&
                          a.status == DemoAppointmentStatus.reagendar &&
                          store.policy.canSelfReschedule(
                            a.start,
                            demoSession.now,
                          )) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go(
                            bookingUrl(
                              intent: AssistantIntent.remarcar,
                              appointmentId: a.id,
                            ),
                          ),
                          icon: const Icon(Icons.event_repeat_rounded),
                          label: const Text('Escolher novo horário'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Início

/// Agendar e mensagens no início do responsável.
class DemoFamilySchedulingCard extends StatelessWidget {
  const DemoFamilySchedulingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final int unread = demoSession.scheduling.unreadFamilyMessages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const DemoSectionTitle('Consultas'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () =>
                  context.go(bookingUrl(intent: AssistantIntent.agendar)),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Agendar consulta'),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.go(bookingUrl(intent: AssistantIntent.remarcar)),
              icon: const Icon(Icons.event_repeat_rounded),
              label: const Text('Remarcar'),
            ),
            FilledButton.tonalIcon(
              onPressed: () =>
                  context.go(bookingUrl(intent: AssistantIntent.cancelar)),
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Cancelar'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.go(familyMessagesPath),
              icon: const Icon(Icons.chat_outlined),
              label: Text(
                unread == 0
                    ? 'Mensagens da clínica'
                    : 'Mensagens da clínica ($unread nova${unread == 1 ? '' : 's'})',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
