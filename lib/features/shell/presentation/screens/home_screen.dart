import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/sync_providers.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../emr/presentation/screens/patient_timeline_screen.dart';
import '../../../emr/presentation/screens/professional_patients_screen.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/telemedicine_screen.dart'
    show myAgendaProvider;

/// Home — dashboard clínico (referências Pediatria360).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia';
    if (hour < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final bool isPro = user?.role.isProfessional ?? false;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(syncServiceProvider).sync();
            await ref.read(remoteConfigProvider).refresh();
            ref.invalidate(professionalPatientsProvider);
            ref.invalidate(myAgendaProvider);
          },
          child: isPro
              ? _ProfessionalHome(user: user, greeting: _greeting())
              : _FamilyHome(user: user, greeting: _greeting()),
        ),
      ),
    );
  }
}

class _ProfessionalHome extends ConsumerWidget {
  const _ProfessionalHome({required this.user, required this.greeting});

  final AppUser? user;
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<PatientSummary>> patientsAsync =
        ref.watch(professionalPatientsProvider);
    final AsyncValue<List<Appointment>> agendaAsync =
        ref.watch(myAgendaProvider);
    final int unread = ref.watch(unreadCountProvider);

    final List<PatientSummary> patients =
        patientsAsync.valueOrNull ?? const <PatientSummary>[];
    final List<Appointment> agenda =
        agendaAsync.valueOrNull ?? const <Appointment>[];

    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final DateTime todayEnd = todayStart.add(const Duration(days: 1));
    final DateTime monthStart = DateTime(now.year, now.month);

    final List<Appointment> today = agenda
        .where(
          (Appointment a) =>
              a.startsAt.isAfter(todayStart) &&
              a.startsAt.isBefore(todayEnd) &&
              a.status.isActive,
        )
        .toList(growable: false)
      ..sort(
        (Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt),
      );

    final int monthConsults = agenda
        .where((Appointment a) => a.startsAt.isAfter(monthStart))
        .length;

    final AppUser? current = user;
    final String displayName = current?.firstName.isNotEmpty == true
        ? (current!.role.isProfessional
            ? 'Dra. ${current.firstName}'
            : current.firstName)
        : 'Doutor(a)';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            child: ContentBounds(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppHeader(notificationCount: unread),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    color: Colors.white,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '$greeting, $displayName!',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Que bom ter você aqui. Vamos juntos cuidar '
                                'de cada infância hoje.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PrimaryButton(
                                label: 'Novo atendimento',
                                icon: Icons.add_rounded,
                                expanded: false,
                                onPressed: () => context.go(Routes.agendaPath),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        ClipRRect(
                          borderRadius: AppRadius.lgAll,
                          child: Image.asset(
                            AppAssets.illustHeroChild,
                            width: 96,
                            height: 108,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 96,
                              height: 108,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    AppColors.softBlue,
                                    AppColors.softTeal,
                                  ],
                                ),
                                borderRadius: AppRadius.lgAll,
                              ),
                              child: Icon(
                                Icons.child_care_rounded,
                                size: 48,
                                color: AppColors.brand.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: AppMotion.fast),
                  const SizedBox(height: AppSpacing.xl),
                  const BrandSectionHeader(title: 'Visão geral'),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int pendingDrafts = patients
                          .where((PatientSummary p) => p.hasOpenDraft)
                          .length;
                      final List<Widget> kpis = <Widget>[
                        _KpiCard(
                          value: '${patients.length}',
                          label: 'Pacientes ativos',
                          icon: Icons.groups_rounded,
                          color: AppColors.teal,
                          onTap: () => context.go(Routes.patientsPath),
                        ),
                        _KpiCard(
                          value: '${today.length}',
                          label: 'Consultas hoje',
                          icon: Icons.today_rounded,
                          color: AppColors.brand,
                          onTap: () => context.go(Routes.agendaPath),
                        ),
                        _KpiCard(
                          value: '$monthConsults',
                          label: 'Consultas no mês',
                          icon: Icons.event_available_rounded,
                          color: AppColors.moduleLibrary,
                          onTap: () => context.go(Routes.agendaPath),
                        ),
                        _KpiCard(
                          value: pendingDrafts > 0 ? '$pendingDrafts' : '—',
                          label: 'Vacinas / pendências',
                          icon: Icons.vaccines_outlined,
                          color: AppColors.raspberry,
                          onTap: () => context.push(Routes.childrenPath),
                        ),
                      ];
                      if (c.maxWidth > 640) {
                        return Row(
                          children: kpis
                              .map(
                                (Widget w) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      right: AppSpacing.sm,
                                    ),
                                    child: w,
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      }
                      if (c.maxWidth > 420) {
                        return Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(child: kpis[0]),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: kpis[1]),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: <Widget>[
                                Expanded(child: kpis[2]),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: kpis[3]),
                              ],
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: kpis
                            .map(
                              (Widget w) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                child: w,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BrandSectionHeader(
                    title: 'Acesso rápido',
                    actionLabel: 'Ver todos →',
                    onAction: () => context.go(Routes.patientsPath),
                  ),
                  QuickAccessCard(
                    label: 'Pacientes',
                    subtitle: 'Carteira e acompanhamento clínico',
                    icon: Icons.groups_rounded,
                    color: AppColors.teal,
                    wide: true,
                    onTap: () => context.go(Routes.patientsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Prontuário',
                    subtitle: 'Histórico, evoluções e documentos',
                    icon: Icons.folder_shared_outlined,
                    color: AppColors.moduleLibrary,
                    wide: true,
                    onTap: () => context.go(Routes.patientsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Vacinas',
                    subtitle: 'Calendário e doses pendentes',
                    icon: Icons.vaccines_outlined,
                    color: AppColors.raspberry,
                    wide: true,
                    onTap: () => context.push(Routes.childrenPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Agenda',
                    subtitle: 'Consultas e retornos do dia',
                    icon: Icons.calendar_month_rounded,
                    color: AppColors.moduleAgenda,
                    wide: true,
                    onTap: () => context.go(Routes.agendaPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  QuickAccessCard(
                    label: 'Telemedicina',
                    subtitle: 'Atendimento remoto seguro',
                    icon: Icons.videocam_outlined,
                    color: AppColors.moduleTelemedicine,
                    wide: true,
                    onTap: () => context.push(Routes.telemedicinePath),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BrandSectionHeader(
                    title: 'Agenda de hoje',
                    actionLabel: 'Ver agenda →',
                    onAction: () => context.go(Routes.agendaPath),
                  ),
                  if (today.isEmpty)
                    AppCard(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.softTeal,
                              borderRadius: AppRadius.mdAll,
                            ),
                            child: const Icon(
                              Icons.event_available_outlined,
                              color: AppColors.tealDeep,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Agenda livre para hoje',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Quando houver consultas, elas aparecem aqui.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...today.take(5).map(
                          (Appointment a) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _AgendaRow(appointment: a),
                          ),
                        ),
                  if (today.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.go(Routes.agendaPath),
                        child: const Text('Ver todos os atendimentos'),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  const BrandSectionHeader(title: 'Atenção necessária'),
                  _AttentionCard(
                    icon: Icons.edit_note_rounded,
                    color: AppColors.warning,
                    title: 'Atendimentos pendentes',
                    message: patients.any((PatientSummary p) => p.hasOpenDraft)
                        ? '${patients.where((PatientSummary p) => p.hasOpenDraft).length} rascunho(s) aguardando conclusão'
                        : 'Nenhum rascunho aberto no momento',
                    onTap: () => context.go(Routes.patientsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AttentionCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.brand,
                    title: 'Mensagens',
                    message: unread > 0
                        ? '$unread mensagem(ns) não lida(s)'
                        : 'Caixa em dia — sem mensagens novas',
                    onTap: () => context.go(Routes.notificationsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _AttentionCard(
                    icon: Icons.vaccines_outlined,
                    color: AppColors.raspberry,
                    title: 'Vacinas e retornos',
                    message:
                        'Revise o calendário vacinal e retornos programados',
                    onTap: () => context.push(Routes.childrenPath),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TipBanner(
                    title: 'Dica do dia',
                    body:
                        'Revise o calendário vacinal nas consultas de rotina — '
                        'prevenção é o melhor acompanhamento.',
                    icon: Icons.shield_outlined,
                    trailing: Image.asset(
                      AppAssets.illustTeddyTip,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.toys_outlined,
                        size: 40,
                        color: AppColors.brand.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.inkMuted.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.appointment});

  final Appointment appointment;

  Color _timeColor(int index) {
    const List<Color> palette = <Color>[
      AppColors.teal,
      AppColors.moduleLibrary,
      AppColors.raspberry,
    ];
    return palette[appointment.startsAt.hour % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = appointment.childName?.trim().isNotEmpty == true
        ? appointment.childName!
        : 'Paciente';
    final Color accent = _timeColor(0);
    final String status = appointment.status.label;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PatientTimelineScreen(
              patientId: appointment.patientId,
              patientName: name,
            ),
          ),
        );
      },
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.mdAll,
            ),
            child: Text(
              Formatters.time(appointment.startsAt),
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
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
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${appointment.type.label}'
                  '${(appointment.reason ?? '').isEmpty ? '' : ' • ${appointment.reason}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          StatusChip.fromStatusLabel(status),
        ],
      ),
    );
  }
}

class _FamilyHome extends ConsumerWidget {
  const _FamilyHome({required this.user, required this.greeting});

  final AppUser? user;
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfigService config = ref.watch(remoteConfigProvider);
    final int unread = ref.watch(unreadCountProvider);
    final ThemeData theme = Theme.of(context);

    final List<_FamilyShortcut> shortcuts = <_FamilyShortcut>[
      _FamilyShortcut(
        'Minhas crianças',
        Icons.child_care_rounded,
        AppColors.teal,
        () => context.push(Routes.childrenPath),
      ),
      _FamilyShortcut(
        'Conteúdos',
        Icons.menu_book_outlined,
        AppColors.moduleLibrary,
        () => context.go(Routes.libraryPath),
      ),
      _FamilyShortcut(
        'Cuidados',
        Icons.medical_services_outlined,
        AppColors.moduleFirstAid,
        () => context.go(Routes.toolsPath),
      ),
      if (config.telemedicineEnabled)
        _FamilyShortcut(
          'Teleconsulta',
          Icons.videocam_outlined,
          AppColors.moduleTelemedicine,
          () => context.push(Routes.telemedicinePath),
        ),
      _FamilyShortcut(
        'IA pediátrica',
        Icons.auto_awesome_rounded,
        AppColors.brand,
        () => context.go(Routes.aiPath),
      ),
      if (config.marketplaceEnabled)
        _FamilyShortcut(
          'Loja',
          Icons.shopping_bag_outlined,
          AppColors.moduleShop,
          () => context.push(Routes.shopPath),
        ),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            child: ContentBounds(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppHeader(notificationCount: unread),
                  Text(
                    '$greeting, ${user?.firstName ?? 'Família'}!',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Acompanhe o cuidado do seu pequeno com tranquilidade.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BrandSectionHeader(title: 'Para cuidar hoje'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: shortcuts
                        .map(
                          (_FamilyShortcut s) => SizedBox(
                            width: 110,
                            child: QuickAccessCard(
                              label: s.title,
                              icon: s.icon,
                              color: s.color,
                              onTap: s.onTap,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const TipBanner(
                    title: 'Dica do dia',
                    body:
                        'Mantenha a caderneta de vacinação em dia e registre '
                        'dúvidas antes da consulta.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FamilyShortcut {
  const _FamilyShortcut(this.title, this.icon, this.color, this.onTap);

  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
