import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/child_avatar.dart';
import '../../core/widgets/clinical_ui.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';
import 'home_screen.dart' show DemoStatusChip;
import 'pre_visit_screens.dart';

DemoPatient? _patient(String id) => demoSession.patients
    .where((DemoPatient p) => p.id == id)
    .firstOrNull;

/// Agenda por dia com seletor de data.
class DemoAgendaScreen extends StatefulWidget {
  const DemoAgendaScreen({super.key});

  @override
  State<DemoAgendaScreen> createState() => _DemoAgendaScreenState();
}

class _DemoAgendaScreenState extends State<DemoAgendaScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  void _shift(int days) =>
      setState(() => _day = _day.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    final bool isToday = DateUtils.isSameDay(_day, DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Agenda'),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDemoSnack(context,
            'Novo agendamento só pode ser testado na versão autenticada.'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agendar'),
      ),
      body: DemoLoader(
        label: 'Carregando agenda...',
        builder: (BuildContext context) => ListenableBuilder(
          listenable: demoSession,
          builder: (BuildContext context, _) {
            final List<DemoAppointment> list = demoSession.appointments
                .where((DemoAppointment a) => DateUtils.isSameDay(a.start, _day))
                .toList()
              ..sort((DemoAppointment a, DemoAppointment b) =>
                  a.start.compareTo(b.start));
            return DemoContent(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Dia anterior',
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Text(
                            isToday
                                ? 'Hoje, ${demoDate(_day)}'
                                : demoDate(_day),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Próximo dia',
                          onPressed: () => _shift(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: () => setState(
                          () => _day = DateUtils.dateOnly(DateTime.now())),
                      child: const Text('Voltar para hoje'),
                    ),
                  Expanded(
                    child: list.isEmpty
                        ? const DemoEmpty(
                            title: 'Dia livre',
                            message: 'Nenhum atendimento neste dia.',
                            pose: CapiPose.celebracao,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.sm, AppSpacing.lg, 96),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (BuildContext context, int i) {
                              final DemoAppointment a = list[i];
                              final DemoPatient? p = _patient(a.patientId);
                              return PremiumCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                onTap: () => context.go('/agenda/${a.id}'),
                                child: Row(
                                  children: <Widget>[
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        demoTime(a.start),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(p?.name ?? 'Paciente',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall),
                                          Row(
                                            children: <Widget>[
                                              Icon(
                                                a.kind ==
                                                        DemoAppointmentKind
                                                            .teleconsulta
                                                    ? Icons.videocam_outlined
                                                    : Icons.place_outlined,
                                                size: 14,
                                                color: AppColors.inkMuted,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(a.reason,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DemoStatusChip(status: a.status),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Detalhe do agendamento com mudanca de status (so em memoria).
class DemoAppointmentDetailScreen extends StatelessWidget {
  const DemoAppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoAppointment? a = demoSession.appointments
            .where((DemoAppointment x) => x.id == appointmentId)
            .firstOrNull;
        if (a == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agendamento')),
            body: DemoEmpty(
              title: 'Agendamento não encontrado',
              message: 'Volte para a agenda.',
              actionLabel: 'Agenda',
              onAction: () => context.go('/agenda'),
            ),
          );
        }
        final DemoPatient? p = _patient(a.patientId);
        final bool isReception =
            demoSession.profile == DemoProfile.recepcao;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(title: const Text('Agendamento')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              if (p != null)
                                ChildAvatarImage(
                                  name: p.name,
                                  seed: p.id,
                                  photoUrl: p.avatarAsset == null
                                      ? null
                                      : ChildAvatarRef.encode(p.avatarAsset!),
                                ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  p?.name ?? 'Paciente',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: AppColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              DemoStatusChip(status: a.status),
                            ],
                          ),
                          const Divider(height: AppSpacing.xl),
                          _Info(Icons.event_outlined,
                              '${demoDate(a.start)} às ${demoTime(a.start)}'),
                          _Info(
                            a.kind == DemoAppointmentKind.teleconsulta
                                ? Icons.videocam_outlined
                                : Icons.place_outlined,
                            a.kind == DemoAppointmentKind.teleconsulta
                                ? 'Teleconsulta (protótipo, vídeo indisponível)'
                                : 'Presencial',
                          ),
                          _Info(Icons.notes_rounded, a.reason),
                        ],
                      ),
                    ),
                    const DemoSectionTitle('Atualizar status'),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final DemoAppointmentStatus s
                            in DemoAppointmentStatus.values)
                          ChoiceChip(
                            label: Text(switch (s) {
                              DemoAppointmentStatus.agendado => 'Agendado',
                              DemoAppointmentStatus.confirmado => 'Confirmado',
                              DemoAppointmentStatus.chegou => 'Chegou',
                              DemoAppointmentStatus.concluido => 'Concluído',
                            }),
                            selected: a.status == s,
                            onSelected: (_) {
                              demoSession.setAppointmentStatus(a, s);
                              showDemoSnack(context,
                                  'Status alterado só nesta demonstração.');
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DemoPreVisitAppointmentInfo(appointment: a),
                    if (!isReception &&
                        p != null &&
                        demoSession.canSeeClinicalRecord)
                      FilledButton.icon(
                        onPressed: () =>
                            context.go('/pacientes/${p.id}/prontuario'),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Abrir prontuário'),
                      ),
                    if (isReception)
                      const DemoNotice(
                        icon: Icons.shield_outlined,
                        text: 'A recepção registra chegada, mas não abre o '
                            'prontuario.',
                      ),
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

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
