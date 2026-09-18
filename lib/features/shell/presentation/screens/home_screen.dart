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
import '../../../../core/widgets/premium_chrome.dart';
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

  String _weekdayDate(DateTime now) {
    const List<String> days = <String>[
      'Segunda-feira',
      'Terca-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sabado',
      'Domingo',
    ];
    const List<String> months = <String>[
      'janeiro',
      'fevereiro',
      'marco',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]} de ${now.year}';
  }

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

    final int pendingDrafts =
        patients.where((PatientSummary p) => p.hasOpenDraft).length;

    final AppUser? current = user;
    final String displayName = current?.firstName.isNotEmpty == true
        ? (current!.role.isProfessional
            ? 'Dra. ${current.firstName}'
            : current.firstName)
        : 'Doutor(a)';

    final bool isWide = MediaQuery.sizeOf(context).width >= 1100;
    final bool hideMobileHeader = MediaQuery.sizeOf(context).width >= 900;

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
                  if (!hideMobileHeader)
                    AppHeader(notificationCount: unread),
                  const SizedBox(height: AppSpacing.sm),
                  // ---- Hero saudacao ----
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _weekdayDate(now),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '$greeting, $displayName!',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Que bom ter voce aqui. Vamos juntos cuidar '
                                'de cada infancia hoje.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PrimaryButton(
                                label: '+ Novo atendimento',
                                icon: Icons.add_rounded,
                                expanded: false,
                                onPressed: () => context.go(Routes.agendaPath),
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.sizeOf(context).width > 640) ...<Widget>[
                          const SizedBox(width: AppSpacing.md),
                          ClipRRect(
                            borderRadius: AppRadius.lgAll,
                            child: Image.asset(
                              AppAssets.illustHeroChild,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
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
                      ],
                    ),
                  ).animate().fadeIn(duration: AppMotion.fast),
                  const SizedBox(height: AppSpacing.xl),
                  // ---- KPIs ----
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final List<Widget> kpis = <Widget>[
                        PremiumKpiCard(
                          value: '${patients.length}',
                          label: 'Pacientes ativos',
                          icon: Icons.groups_rounded,
                          color: AppColors.teal,
                          helper: 'Carteira vinculada',
                          onTap: () => context.go(Routes.patientsPath),
                        ),
                        PremiumKpiCard(
                          value: '${today.length}',
                          label: 'Consultas hoje',
                          icon: Icons.today_rounded,
                          color: AppColors.brand,
                          helper: today.isEmpty
                              ? 'Nenhuma no momento'
                              : 'Agenda do dia',
                          onTap: () => context.go(Routes.agendaPath),
                        ),
                        PremiumKpiCard(
                          value: '$monthConsults',
                          label: 'Consultas no mes',
                          icon: Icons.event_available_rounded,
                          color: AppColors.moduleLibrary,
                          helper: 'Desde ${now.day}/${now.month}',
                          onTap: () => context.go(Routes.agendaPath),
                        ),
                        PremiumKpiCard(
                          value: pendingDrafts > 0 ? '$pendingDrafts' : '0',
                          label: 'Vacinas / pendencias',
                          icon: Icons.vaccines_outlined,
                          color: AppColors.raspberry,
                          trendLabel: pendingDrafts > 0 ? 'Atencao' : null,
                          trendPositive: false,
                          helper: 'Rascunhos e follow-ups',
                          onTap: () => context.push(Routes.childrenPath),
                        ),
                      ];
                      if (c.maxWidth > 900) {
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
                      if (c.maxWidth > 520) {
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
                  // ---- Acesso rapido (5 cards das refs) ----
                  BrandSectionHeader(
                    title: 'Acesso rapido',
                    actionLabel: 'Consultorio ?',
                    onAction: () => context.push(Routes.clinicPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final List<_QuickItem> items = <_QuickItem>[
                        _QuickItem(
                          'Pacientes',
                          'Carteira clinica',
                          Icons.groups_rounded,
                          AppColors.brand,
                          () => context.go(Routes.patientsPath),
                        ),
                        _QuickItem(
                          'Prontuario',
                          'Evolucoes e docs',
                          Icons.folder_shared_outlined,
                          AppColors.moduleLibrary,
                          () => context.go(Routes.patientsPath),
                        ),
                        _QuickItem(
                          'Vacinas',
                          'Caderneta digital',
                          Icons.vaccines_outlined,
                          AppColors.teal,
                          () => context.push(Routes.childrenPath),
                        ),
                        _QuickItem(
                          'Agenda',
                          'Consultas do dia',
                          Icons.calendar_month_rounded,
                          AppColors.moduleAgenda,
                          () => context.go(Routes.agendaPath),
                        ),
                        _QuickItem(
                          'Telemedicina',
                          'Atendimento remoto',
                          Icons.videocam_outlined,
                          AppColors.moduleTelemedicine,
                          () => context.push(Routes.telemedicinePath),
                        ),
                      ];
                      final int cols = c.maxWidth > 900
                          ? 5
                          : (c.maxWidth > 600 ? 3 : 2);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: AppSpacing.sm,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: cols >= 5 ? 1.15 : 1.25,
                        ),
                        itemBuilder: (BuildContext context, int i) {
                          final _QuickItem item = items[i];
                          return PremiumQuickTile(
                            label: item.label,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            color: item.color,
                            onTap: item.onTap,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // ---- Agenda + Atencao ----
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _TodayAgendaBlock(today: today),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: _AttentionBlock(
                            unread: unread,
                            pendingDrafts: pendingDrafts,
                            patients: patients,
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _TodayAgendaBlock(today: today),
                    const SizedBox(height: AppSpacing.xl),
                    _AttentionBlock(
                      unread: unread,
                      pendingDrafts: pendingDrafts,
                      patients: patients,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  // ---- Pacientes recentes + dica ----
                  BrandSectionHeader(
                    title: 'Pacientes recentes',
                    actionLabel: 'Ver todos ?',
                    onAction: () => context.go(Routes.patientsPath),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (patients.isEmpty)
                    const AppCard(
                      child: Text(
                        'Nenhum paciente na carteira ainda. '
                        'Cadastre ou vincule um paciente para comecar.',
                      ),
                    )
                  else
                    ...patients.take(5).map(
                          (PatientSummary p) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PatientTimelineScreen(
                                      patientId: p.patientId,
                                      patientName: p.name,
                                    ),
                                  ),
                                );
                              },
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundColor: AppColors.softBlue,
                                    child: Text(
                                      p.name.isNotEmpty
                                          ? p.name[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        color: AppColors.brand,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          p.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          p.hasOpenDraft
                                              ? 'Rascunho em aberto'
                                              : 'Acompanhamento',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: AppColors.inkMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.inkMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: AppSpacing.lg),
                  TipBanner(
                    title: 'Dica do dia',
                    body:
                        'Na puericultura, revise vacinas e marcos do '
                        'desenvolvimento em toda consulta de rotina.',
                    icon: Icons.lightbulb_outline_rounded,
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

class _QuickItem {
  const _QuickItem(
    this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _TodayAgendaBlock extends StatelessWidget {
  const _TodayAgendaBlock({required this.today});

  final List<Appointment> today;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BrandSectionHeader(
          title: 'Agenda de hoje',
          actionLabel: 'Ver agenda ?',
          onAction: () => context.go(Routes.agendaPath),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: today.isEmpty
              ? Row(
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
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < today.take(6).length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _AgendaTimelineRow(
                        appointment: today[i],
                        isLast: i == today.take(6).length - 1,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _AttentionBlock extends StatelessWidget {
  const _AttentionBlock({
    required this.unread,
    required this.pendingDrafts,
    required this.patients,
  });

  final int unread;
  final int pendingDrafts;
  final List<PatientSummary> patients;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const BrandSectionHeader(title: 'Atencao necessaria'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              PremiumAttentionRow(
                icon: Icons.vaccines_outlined,
                color: AppColors.danger,
                title: 'Vacinas e caderneta',
                subtitle: 'Revise doses pendentes e atrasos',
                count: null,
                actionLabel: 'Revisar',
                onTap: () => context.push(Routes.childrenPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumAttentionRow(
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.brand,
                title: 'Mensagens nao respondidas',
                subtitle: unread > 0
                    ? 'Ha comunicacoes aguardando leitura'
                    : 'Caixa em dia',
                count: unread > 0 ? unread : null,
                actionLabel: 'Responder',
                onTap: () => context.go(Routes.notificationsPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumAttentionRow(
                icon: Icons.edit_note_rounded,
                color: AppColors.warning,
                title: 'Retornos / rascunhos',
                subtitle: pendingDrafts > 0
                    ? '$pendingDrafts atendimento(s) pendente(s)'
                    : 'Nenhum rascunho aberto',
                count: pendingDrafts > 0 ? pendingDrafts : null,
                actionLabel: 'Ver lista',
                onTap: () => context.go(Routes.patientsPath),
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumAttentionRow(
                icon: Icons.biotech_outlined,
                color: AppColors.moduleLibrary,
                title: 'Exames e suplementacao',
                subtitle: 'Central clinica de exames e micronutrientes',
                actionLabel: 'Abrir',
                onTap: () => context.push(Routes.supplementPath),
              ),
              if (unread == 0 && pendingDrafts == 0) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.softTeal,
                    borderRadius: AppRadius.lgAll,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.tealDeep,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tudo em dia por aqui!',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.tealDeep,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgendaTimelineRow extends StatelessWidget {
  const _AgendaTimelineRow({
    required this.appointment,
    required this.isLast,
  });

  final Appointment appointment;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = appointment.childName?.trim().isNotEmpty == true
        ? appointment.childName!
        : 'Paciente';
    final String status = appointment.status.label;

    return InkWell(
      borderRadius: AppRadius.mdAll,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(
              Formatters.time(appointment.startsAt),
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: AppColors.line,
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.softBlue,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
                          appointment.type.label +
                              ((appointment.reason ?? '').isEmpty
                                  ? ''
                                  : ' ? ${appointment.reason}'),
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
            ),
          ),
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
