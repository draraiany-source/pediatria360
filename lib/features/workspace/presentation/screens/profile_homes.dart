import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/capi_pose.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/feature_unavailable.dart';
import '../../../../core/widgets/capi_illustration.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/agenda_providers.dart'
    show unitScopedMyAgendaProvider;
import '../../domain/workspace_profile.dart';
import '../providers/workspace_providers.dart';
import '../widgets/workspace_switcher.dart';

/// Home por area de trabalho — sem numeros ilustrativos.
class WorkspaceHomeScreen extends ConsumerWidget {
  const WorkspaceHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WorkspaceProfile workspace = ref.watch(currentWorkspaceProvider);
    final AppUser? user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: switch (workspace) {
          WorkspaceProfile.admin => _AdminHome(user: user),
          WorkspaceProfile.professional => _ProfessionalHome(user: user),
          WorkspaceProfile.receptionist => _ReceptionHome(user: user),
          WorkspaceProfile.finance => _FinanceHome(user: user),
          WorkspaceProfile.patient => _PatientHome(user: user),
        },
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.title,
    required this.subtitle,
    this.capiPose,
  });

  final String title;
  final String subtitle;
  final CapiPose? capiPose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(unreadCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Pedi360',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const WorkspaceSwitcher(),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: 'Notificacoes',
                onPressed: () => context.push(Routes.notificationsPath),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.softBlue,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.navy.withValues(alpha: 0.8),
                            ),
                      ),
                    ],
                  ),
                ),
                if (capiPose != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  CapiIllustration(pose: capiPose!, size: 96),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- Admin

class _AdminHome extends ConsumerWidget {
  const _AdminHome({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : 'administrador';

    return ListView(
      children: <Widget>[
        _HomeHeader(
          title: 'Bem-vindo(a), $name',
          subtitle: WorkspaceProfile.admin.homeSubtitle,
          capiPose: CapiPose.boasVindas,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Modulos de gestao',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavTile(
                title: 'Usuarios e permissoes',
                subtitle: 'Matriz de acesso da equipe',
                icon: Icons.manage_accounts_outlined,
                color: AppColors.teal,
                onTap: () => context.push(Routes.permissionsPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Conteudos',
                subtitle: 'CMS e biblioteca educacional',
                icon: Icons.school_outlined,
                color: AppColors.raspberry,
                onTap: () => context.push(Routes.adminPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Relatorios / BI',
                subtitle: 'Indicadores com dados reais do tenant',
                icon: Icons.bar_chart_rounded,
                color: AppColors.brand,
                onTap: () => context.push(Routes.biPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Auditoria',
                subtitle: 'Registros de alteracoes relevantes',
                icon: Icons.fact_check_outlined,
                color: AppColors.navy,
                onTap: () => context.push(Routes.auditPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              const FeatureOffBanner(
                text:
                    'Convite de funcionarios e gestao de unidades dependem de '
                    'configuracao administrativa na clinica. Indicadores so '
                    'aparecem quando houver dados no Firebase.',
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- Professional

class _ProfessionalHome extends ConsumerWidget {
  const _ProfessionalHome({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Appointment>> agendaAsync =
        ref.watch(unitScopedMyAgendaProvider);
    final List<Appointment> agenda =
        agendaAsync.valueOrNull ?? const <Appointment>[];
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart.add(const Duration(days: 1));
    final List<Appointment> today = agenda
        .where(
          (Appointment a) =>
              a.startsAt.isAfter(todayStart) &&
              a.startsAt.isBefore(todayEnd) &&
              a.status.isActive,
        )
        .toList(growable: false)
      ..sort((Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt));
    final Appointment? next = today.isEmpty ? null : today.first;
    final String name = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : 'profissional';

    return ListView(
      children: <Widget>[
        _HomeHeader(
          title: 'Ola, $name',
          subtitle: WorkspaceProfile.professional.homeSubtitle,
          capiPose: CapiPose.aceno,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppCard(
                child: next == null
                    ? EmptyState(
                        title: 'Nenhuma consulta na agenda de hoje',
                        message:
                            'Quando houver horarios, a proxima consulta '
                            'aparece aqui.',
                        icon: Icons.event_available_outlined,
                        illustration: AppAssets.capiLupa,
                        actionLabel: 'Abrir agenda',
                        onAction: () => context.go(Routes.agendaPath),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(Icons.calendar_month,
                                  color: AppColors.teal),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'PROXIMA CONSULTA',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => context.go(Routes.agendaPath),
                                child: const Text('Ver agenda'),
                              ),
                            ],
                          ),
                          Text(
                            (next.childName ?? '').isEmpty
                                ? 'Paciente'
                                : next.childName ?? 'Paciente',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            DateFormat("HH:mm · dd/MM").format(next.startsAt),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _QuickSquare(
                    title: 'Agenda',
                    subtitle: 'Atendimentos',
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.teal,
                    onTap: () => context.go(Routes.agendaPath),
                  ),
                  _QuickSquare(
                    title: 'Prontuario',
                    subtitle: 'Pacientes',
                    icon: Icons.folder_shared_outlined,
                    color: AppColors.brand,
                    onTap: () => context.go(Routes.patientsPath),
                  ),
                  _QuickSquare(
                    title: 'Prescricoes',
                    subtitle: 'Apos assinatura',
                    icon: Icons.medication_outlined,
                    color: AppColors.raspberry,
                    onTap: () => context.go(Routes.patientsPath),
                  ),
                  _QuickSquare(
                    title: 'IA clinica',
                    subtitle: AppConfig.voiceConsultationEnabled
                        ? 'Rascunho'
                        : 'Indisponivel',
                    icon: Icons.auto_awesome,
                    color: AppColors.honey,
                    onTap: () {
                      if (AppConfig.voiceConsultationEnabled) {
                        context.push(Routes.clinicVoicePath);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Consulta com IA ainda nao esta disponivel '
                              'nesta versao. Use o assistente no editor de '
                              'prontuario apos abrir um atendimento.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!AppConfig.voiceConsultationEnabled)
                const FeatureOffBanner(
                  text:
                      'Rascunho por voz/IA de consulta: fora do teste fechado. '
                      'O assistente de texto no prontuario exige revisao '
                      'manual antes de assinar.',
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickSquare extends StatelessWidget {
  const _QuickSquare({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double width =
        (MediaQuery.sizeOf(context).width - AppSpacing.lg * 2 - AppSpacing.sm) /
            2;
    return SizedBox(
      width: width.clamp(140, 220),
      child: AppCard(
        onTap: onTap,
        color: color.withValues(alpha: 0.12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- Reception

class _ReceptionHome extends ConsumerWidget {
  const _ReceptionHome({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Appointment>> agendaAsync =
        ref.watch(unitScopedMyAgendaProvider);
    final List<Appointment> agenda =
        agendaAsync.valueOrNull ?? const <Appointment>[];
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart.add(const Duration(days: 1));
    final List<Appointment> today = agenda
        .where(
          (Appointment a) =>
              a.startsAt.isAfter(todayStart) &&
              a.startsAt.isBefore(todayEnd) &&
              a.status.isActive,
        )
        .toList(growable: false)
      ..sort((Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt));

    return ListView(
      children: <Widget>[
        _HomeHeader(
          title: 'Area da recepcao',
          subtitle: WorkspaceProfile.receptionist.homeSubtitle,
          capiPose: CapiPose.aceno,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _QuickSquare(
                    title: 'Agenda',
                    subtitle: 'Do dia',
                    icon: Icons.event_outlined,
                    color: AppColors.raspberry,
                    onTap: () => context.go(Routes.agendaPath),
                  ),
                  _QuickSquare(
                    title: 'Check-in',
                    subtitle: 'Recepcao',
                    icon: Icons.how_to_reg_rounded,
                    color: AppColors.teal,
                    onTap: () => context.push(Routes.clinicReceptionPath),
                  ),
                  _QuickSquare(
                    title: 'Pendencias',
                    subtitle: 'Fila',
                    icon: Icons.inbox_outlined,
                    color: AppColors.brand,
                    onTap: () => context.push(Routes.clinicPendingPath),
                  ),
                  _QuickSquare(
                    title: 'Mensagens',
                    subtitle: 'Central',
                    icon: Icons.mail_outline,
                    color: AppColors.honey,
                    onTap: () => context.push(Routes.notificationsPath),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Atendimentos de hoje',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (agendaAsync.isLoading)
                const LoadingState(label: 'Carregando agenda…')
              else if (today.isEmpty)
                EmptyState(
                  title: 'Nenhum atendimento hoje',
                  message:
                      'A lista preenche com a agenda real da clinica. '
                      'Nao exibimos dados ilustrativos.',
                  icon: Icons.event_busy_outlined,
                  illustration: AppAssets.capiLupa,
                  actionLabel: 'Abrir agenda',
                  onAction: () => context.go(Routes.agendaPath),
                )
              else
                ...today.take(8).map((Appointment a) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      onTap: () => context.push(Routes.clinicReceptionPath),
                      child: Row(
                        children: <Widget>[
                          Text(
                            DateFormat('HH:mm').format(a.startsAt),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  (a.childName ?? '').isEmpty
                                      ? 'Paciente'
                                      : a.childName ?? 'Paciente',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  a.status.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.md),
              const FeatureOffBanner(
                text:
                    'Recepcao nao acessa evolucao clinica nem prescricoes. '
                    'Cadastro clinico detalhado permanece com o profissional.',
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- Finance

class _FinanceHome extends ConsumerWidget {
  const _FinanceHome({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: <Widget>[
        _HomeHeader(
          title: 'Painel financeiro',
          subtitle: WorkspaceProfile.finance.homeSubtitle,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FeatureOffBanner(
                text:
                    'Valores e graficos so aparecem com lancamentos reais. '
                    'Nao usamos numeros ilustrativos do mockup.',
              ),
              const SizedBox(height: AppSpacing.md),
              _NavTile(
                title: 'Dashboard financeiro',
                subtitle: 'Visao geral dos lancamentos',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.teal,
                onTap: () => context.push(Routes.financePath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Contas a receber',
                subtitle: 'Pagamentos e status',
                icon: Icons.receipt_long_outlined,
                color: AppColors.success,
                onTap: () => context.push(Routes.financeReceivablesPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Contas a pagar',
                subtitle: 'Despesas e pendencias',
                icon: Icons.money_off_csred_outlined,
                color: AppColors.warning,
                onTap: () => context.push(Routes.financePayablesPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Relatorios',
                subtitle: 'Receitas, despesas e indicadores',
                icon: Icons.bar_chart_rounded,
                color: AppColors.honey,
                onTap: () => context.push(Routes.financeReportsPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Faturamento',
                subtitle: 'Guias e lotes (sem TISS operadora)',
                icon: Icons.request_quote_outlined,
                color: AppColors.brand,
                onTap: () => context.push(Routes.billingPath),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- Patient

class _PatientHome extends ConsumerWidget {
  const _PatientHome({required this.user});
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String name = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : 'familia';

    return ListView(
      children: <Widget>[
        _HomeHeader(
          title: 'Ola, $name',
          subtitle: WorkspaceProfile.patient.homeSubtitle,
          capiPose: CapiPose.aceno,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _NavTile(
                title: 'Minhas criancas',
                subtitle: 'Cadastro e acompanhamento',
                icon: Icons.child_care_outlined,
                color: AppColors.brand,
                onTap: () => context.push(Routes.childrenPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Biblioteca e orientacoes',
                subtitle: 'Conteudos confiaveis por fase',
                icon: Icons.menu_book_outlined,
                color: AppColors.honey,
                onTap: () => context.go(Routes.libraryPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Cuidados e ferramentas',
                subtitle: 'Primeiros socorros e calculadoras',
                icon: Icons.medical_services_outlined,
                color: AppColors.teal,
                onTap: () => context.go(Routes.toolsPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'IA educativa',
                subtitle: 'Duvidas gerais — nao substitui consulta',
                icon: Icons.smart_toy_outlined,
                color: AppColors.raspberry,
                onTap: () => context.go(Routes.aiPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              _NavTile(
                title: 'Mensagens',
                subtitle: 'Notificacoes da conta',
                icon: Icons.notifications_outlined,
                color: AppColors.navy,
                onTap: () => context.push(Routes.notificationsPath),
              ),
              const SizedBox(height: AppSpacing.md),
              const FeatureOffBanner(
                text:
                    'Agendamento online, exames e documentos compartilhados '
                    'pelo consultorio aparecem quando houver dados vinculados '
                    'as suas criancas. Ensino (biblioteca/cursos) permanece '
                    'disponivel neste perfil.',
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ],
    );
  }
}