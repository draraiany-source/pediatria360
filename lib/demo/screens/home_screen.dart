import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/capi_illustration.dart';
import '../../core/widgets/child_avatar.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

/// Inicio por perfil — cada area ve atalhos e resumo proprios.
class DemoHomeScreen extends StatelessWidget {
  const DemoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoProfile? profile = demoSession.profile;
        if (profile == null) return const SizedBox.shrink();
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: const Text('Início'),
            automaticallyImplyLeading: false,
            actions: <Widget>[
              IconButton(
                tooltip: 'Trocar perfil',
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.switch_account_outlined),
              ),
            ],
          ),
          body: DemoLoader(
            label: 'Carregando início...',
            builder: (BuildContext context) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                DemoContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Greeting(profile: profile),
                      ..._body(context, profile),
                      const SizedBox(height: AppSpacing.xl),
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

  List<Widget> _body(BuildContext context, DemoProfile profile) {
    final DemoSession s = demoSession;
    final List<DemoAppointment> today =
        s.appointments
            .where(
              (DemoAppointment a) =>
                  DateUtils.isSameDay(a.start, DateTime.now()),
            )
            .toList()
          ..sort(
            (DemoAppointment a, DemoAppointment b) =>
                a.start.compareTo(b.start),
          );

    switch (profile) {
      case DemoProfile.profissional:
        return <Widget>[
          _MetricsRow(
            items: <(String, String, IconData, Color)>[
              (
                'Consultas hoje',
                '${today.length}',
                Icons.event_outlined,
                AppColors.brand,
              ),
              (
                'Pacientes',
                '${s.patients.length}',
                Icons.people_outline,
                AppColors.teal,
              ),
              (
                'Aguardando',
                '${today.where((DemoAppointment a) => a.status == DemoAppointmentStatus.chegou).length}',
                Icons.hourglass_top_rounded,
                AppColors.warning,
              ),
            ],
          ),
          DemoSectionTitle(
            'Consultas de hoje',
            trailing: TextButton(
              onPressed: () => context.go('/agenda'),
              child: const Text('Ver agenda'),
            ),
          ),
          for (final DemoAppointment a in today) _ConsultTile(appointment: a),
          if (s.consultations.any(
            (DemoConsultation c) => c.isDraft,
          )) ...<Widget>[
            const DemoSectionTitle('Consultas em andamento'),
            for (final DemoConsultation c in s.consultations.where(
              (DemoConsultation c) => c.isDraft,
            ))
              _DraftConsultTile(consultation: c),
          ],
          DemoSectionTitle(
            'Pacientes',
            trailing: TextButton(
              onPressed: () => context.go('/pacientes'),
              child: const Text('Ver todos'),
            ),
          ),
          _PatientStrip(patients: s.patients),
          const DemoSectionTitle('Atalhos'),
          const _Shortcuts(
            items: <(String, IconData, String)>[
              (
                'Calculadora de doses',
                Icons.calculate_outlined,
                '/calculadora',
              ),
              (
                'Suplementação',
                Icons.medication_liquid_outlined,
                '/suplementacao',
              ),
              ('Vacinação', Icons.vaccines_outlined, '/vacinacao'),
              ('Telemedicina', Icons.videocam_outlined, '/telemedicina'),
              ('Biblioteca', Icons.menu_book_outlined, '/biblioteca'),
            ],
          ),
        ];
      case DemoProfile.recepcao:
        return <Widget>[
          _MetricsRow(
            items: <(String, String, IconData, Color)>[
              (
                'Agendados hoje',
                '${today.length}',
                Icons.event_outlined,
                AppColors.brand,
              ),
              (
                'Chegaram',
                '${today.where((DemoAppointment a) => a.status == DemoAppointmentStatus.chegou).length}',
                Icons.how_to_reg_outlined,
                AppColors.teal,
              ),
            ],
          ),
          const DemoSectionTitle('Agenda do dia'),
          for (final DemoAppointment a in today)
            _AppointmentTile(appointment: a),
          const SizedBox(height: AppSpacing.md),
          const DemoNotice(
            icon: Icons.shield_outlined,
            text:
                'A recepção vê agenda e cadastro, mas não o prontuário. '
                'No app real essa restrição também é aplicada nas regras do '
                'Firebase.',
          ),
        ];
      case DemoProfile.financeiro:
        final double open = s.invoices
            .where((DemoInvoice i) => i.status != DemoInvoiceStatus.pago)
            .fold<double>(0, (double sum, DemoInvoice i) => sum + i.amount);
        return <Widget>[
          _MetricsRow(
            items: <(String, String, IconData, Color)>[
              (
                'Em aberto (fictício)',
                demoMoney(open),
                Icons.receipt_long_outlined,
                AppColors.warning,
              ),
              (
                'Lançamentos',
                '${s.invoices.length}',
                Icons.list_alt_rounded,
                AppColors.brand,
              ),
            ],
          ),
          const DemoSectionTitle('Atalhos'),
          const _Shortcuts(
            items: <(String, IconData, String)>[
              ('Financeiro', Icons.payments_outlined, '/financeiro'),
              ('Relatórios', Icons.insights_outlined, '/relatorios'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const DemoNotice(
            icon: Icons.shield_outlined,
            text:
                'O financeiro não acessa dados clínicos. Valores desta tela '
                'são fictícios.',
          ),
        ];
      case DemoProfile.administrador:
        return <Widget>[
          _MetricsRow(
            items: <(String, String, IconData, Color)>[
              (
                'Conteúdos',
                '${s.articles.length}',
                Icons.menu_book_outlined,
                AppColors.moduleLibrary,
              ),
              ('Perfis de equipe', '4', Icons.groups_outlined, AppColors.brand),
            ],
          ),
          const DemoSectionTitle('Atalhos'),
          const _Shortcuts(
            items: <(String, IconData, String)>[
              ('Relatórios', Icons.insights_outlined, '/relatorios'),
              ('Biblioteca', Icons.menu_book_outlined, '/biblioteca'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const DemoNotice(
            text:
                'Gestão de equipe, convites e auditoria existem apenas na '
                'versão autenticada.',
          ),
        ];
      case DemoProfile.responsavel:
        final List<DemoPatient> kids = s.visiblePatients;
        return <Widget>[
          const DemoSectionTitle('Crianças sob seus cuidados'),
          for (final DemoPatient p in kids)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => context.go('/pacientes/${p.id}'),
                child: Row(
                  children: <Widget>[
                    ChildAvatarImage(
                      name: p.name,
                      seed: p.id,
                      photoUrl: p.avatarAsset == null
                          ? null
                          : ChildAvatarRef.encode(p.avatarAsset!),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            p.ageLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          const DemoSectionTitle('Atalhos'),
          const _Shortcuts(
            items: <(String, IconData, String)>[
              ('Rotina e diário', Icons.event_note_outlined, '/rotina'),
              ('Vacinação', Icons.vaccines_outlined, '/vacinacao'),
              ('Biblioteca', Icons.menu_book_outlined, '/biblioteca'),
              ('Telemedicina', Icons.videocam_outlined, '/telemedicina'),
            ],
          ),
        ];
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: AppRadius.xlAll,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Olá! Você está como',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
                Text(
                  profile.label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const CapiIllustration(pose: CapiPose.boasVindas, size: 88),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.items});

  final List<(String, String, IconData, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final int columns = c.maxWidth >= 600 ? items.length : 2;
          const double gap = AppSpacing.md;
          final double w = (c.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final (String, String, IconData, Color) i in items)
                SizedBox(
                  width: w,
                  child: MetricCard(
                    label: i.$1,
                    value: i.$2,
                    icon: i.$3,
                    color: i.$4,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.items});

  final List<(String, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final (String, IconData, String) i in items)
          // O ActionChip e anunciado como caixa de selecao no Flutter Web.
          Semantics(
            button: true,
            label: i.$1,
            excludeSemantics: true,
            onTap: () => context.go(i.$3),
            child: ActionChip(
              avatar: Icon(i.$2, size: 18, color: AppColors.brand),
              label: Text(i.$1),
              onPressed: () => context.go(i.$3),
            ),
          ),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.patients
        .where((DemoPatient x) => x.id == appointment.patientId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.go('/agenda/${appointment.id}'),
        child: Row(
          children: <Widget>[
            Text(
              demoTime(appointment.start),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p?.name ?? 'Paciente',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    appointment.reason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            DemoStatusChip(status: appointment.status),
          ],
        ),
      ),
    );
  }
}

/// Abre a consulta em rascunho do paciente ou inicia uma nova.
void openConsultationFor(BuildContext context, String patientId) {
  final DemoConsultation c =
      demoSession
          .consultationsFor(patientId)
          .where((DemoConsultation c) => c.isDraft)
          .firstOrNull ??
      demoSession.startConsultation(patientId);
  context.go('/pacientes/$patientId/consulta/${c.id}');
}

/// Consulta do dia em destaque: horário em bloco escuro e ação de atender.
class _ConsultTile extends StatelessWidget {
  const _ConsultTile({required this.appointment});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DemoPatient? p = demoSession.patients
        .where((DemoPatient x) => x.id == appointment.patientId)
        .firstOrNull;
    final bool narrow = MediaQuery.sizeOf(context).width < 520;
    final Widget action = FilledButton.icon(
      onPressed: p == null ? null : () => openConsultationFor(context, p.id),
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Atender'),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        onTap: () => context.go('/agenda/${appointment.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    demoTime(appointment.start),
                    textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        p?.name ?? 'Paciente',
                        style: t.titleMedium?.copyWith(color: AppColors.navy),
                      ),
                      Text(
                        '${appointment.reason}${p == null ? '' : ' · ${p.ageLabel}'}',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
                ),
                DemoStatusChip(status: appointment.status),
                if (!narrow) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  action,
                ],
              ],
            ),
            if (narrow) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftConsultTile extends StatelessWidget {
  const _DraftConsultTile({required this.consultation});

  final DemoConsultation consultation;

  @override
  Widget build(BuildContext context) {
    final DemoPatient? p = demoSession.patients
        .where((DemoPatient x) => x.id == consultation.patientId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: AppColors.warning,
        onTap: () => context.go(
          '/pacientes/${consultation.patientId}/consulta/${consultation.id}',
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.pending_actions_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p?.name ?? 'Paciente',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    consultation.complaint.isEmpty
                        ? 'Rascunho sem motivo registrado'
                        : consultation.complaint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Text('Continuar'),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _PatientStrip extends StatelessWidget {
  const _PatientStrip({required this.patients});

  final List<DemoPatient> patients;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: patients.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final DemoPatient p = patients[i];
          return SizedBox(
            width: 168,
            child: PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () => context.go('/pacientes/${p.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ChildAvatarImage(
                    name: p.name,
                    seed: p.id,
                    radius: 18,
                    photoUrl: p.avatarAsset == null
                        ? null
                        : ChildAvatarRef.encode(p.avatarAsset!),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall,
                  ),
                  Text(
                    p.weightKg == null
                        ? '${p.ageLabel} · sem peso'
                        : '${p.ageLabel} · ${formatDoseNumber(p.weightKg!)} kg',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Chip de status de agendamento, reutilizado pela agenda.
class DemoStatusChip extends StatelessWidget {
  const DemoStatusChip({required this.status, super.key});

  final DemoAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      DemoAppointmentStatus.agendado => ('Agendado', AppColors.inkMuted),
      DemoAppointmentStatus.confirmado => ('Confirmado', AppColors.brand),
      DemoAppointmentStatus.chegou => ('Chegou', AppColors.warning),
      DemoAppointmentStatus.concluido => ('Concluído', AppColors.tealDeep),
    };
    return ClinicalBadge(label: label, color: color);
  }
}
