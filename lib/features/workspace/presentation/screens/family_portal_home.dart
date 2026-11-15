import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/module_flags.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/route_access.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../../core/widgets/capi_illustration.dart';
import '../../../../core/config/capi_pose.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../../notifications/presentation/notification_center_screen.dart';
import '../../../shell/presentation/providers/selected_patient_provider.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/telemedicine_screen.dart'
    show myAppointmentsProvider;

/// Portal visual da Area da Familia (mockups 01 e 03).
/// Reaproveita rotas/providers reais — nao inventa consultas nem contadores.
class FamilyPortalHome extends ConsumerWidget {
  const FamilyPortalHome({required this.user, super.key});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String greeting = user?.firstName.isNotEmpty == true
        ? user!.firstName
        : 'familia';
    final AsyncValue<List<Child>> childrenAsync = ref.watch(childrenProvider);
    final AsyncValue<List<Appointment>> apptsAsync =
        ref.watch(myAppointmentsProvider);
    final int unread = ref.watch(unreadCountProvider);
    final SelectedPatient? focused = ref.watch(selectedPatientProvider);
    final RemoteConfigService remote = ref.watch(remoteConfigProvider);
    final bool kidsOn = ModuleFlags.kidsSpaceEnabled(remote);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (canOpenRoute(ref, Routes.receptionistAiPath)) {
            context.push(Routes.receptionistAiPath);
          } else {
            context.go(Routes.aiPath);
          }
        },
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Conversar com a Tia Cris'),
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace s) => Center(child: Text('$e')),
        data: (List<Child> children) {
          final Child? active = _resolveChild(children, focused);
          if (active != null && focused == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (ref.read(selectedPatientProvider) == null) {
                ref.read(selectedPatientProvider.notifier).state = SelectedPatient(
                  childId: active.id,
                  name: active.name,
                  birthDate: active.birthDate,
                );
              }
            });
          }

          final Appointment? next = apptsAsync.maybeWhen(
            data: (List<Appointment> list) {
              final List<Appointment> upcoming = list
                  .where((Appointment a) => a.status.isActive && !a.isPast)
                  .toList()
                ..sort((Appointment a, Appointment b) =>
                    a.startsAt.compareTo(b.startsAt));
              return upcoming.isEmpty ? null : upcoming.first;
            },
            orElse: () => null,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              100,
            ),
            children: <Widget>[
              Text(
                'Area da Familia',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                active == null
                    ? 'Ola, $greeting! Cadastre uma crianca para acompanhar a rotina.'
                    : 'Ola, $greeting! Vamos cuidar da rotina do ${active.firstName}?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChildSwitcher(
                children: children,
                active: active,
                onSelect: (Child c) {
                  ref.read(selectedPatientProvider.notifier).state =
                      SelectedPatient(
                    childId: c.id,
                    name: c.name,
                    birthDate: c.birthDate,
                  );
                },
                onManage: () => context.push(Routes.childrenPath),
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool wide = c.maxWidth > 720;
                  final List<Widget> cards = <Widget>[
                    _StatusCard(
                      title: 'Proxima consulta',
                      value: next == null
                          ? 'Nenhuma marcada'
                          : DateFormat("dd/MM 'as' HH:mm").format(next.startsAt),
                      color: AppColors.softTeal,
                      accent: AppColors.success,
                      icon: Icons.event_available_rounded,
                      onTap: () => context.push(Routes.telemedicinePath),
                    ),
                    _StatusCard(
                      title: 'Pre-consulta',
                      value: 'Abrir quando houver convite',
                      color: AppColors.softPink,
                      accent: AppColors.navSelected,
                      icon: Icons.assignment_outlined,
                      onTap: () => context.push(Routes.clinicInvitePath),
                    ),
                    _StatusCard(
                      title: 'Novas orientacoes',
                      value: 'Ver biblioteca da familia',
                      color: AppColors.softBlue,
                      accent: AppColors.vital,
                      icon: Icons.menu_book_outlined,
                      onTap: () => context.go(Routes.libraryPath),
                    ),
                  ];
                  if (wide) {
                    return Row(
                      children: <Widget>[
                        for (int i = 0; i < cards.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(child: cards[i]),
                        ],
                      ],
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final Widget card in cards) ...<Widget>[
                        card,
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final bool wide = c.maxWidth > 800;
                  final Widget calendar = _FamilyCalendarCard(
                    next: next,
                    onAdd: () => context.push(Routes.familyBookingPath),
                    onOpenAgenda: () => context.push(Routes.telemedicinePath),
                  );
                  final Widget pre = _PreConsultaCard(
                    onFill: () => context.push(Routes.clinicInvitePath),
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: calendar),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(flex: 2, child: pre),
                      ],
                    );
                  }
                  return Column(
                    children: <Widget>[
                      calendar,
                      const SizedBox(height: AppSpacing.md),
                      pre,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _RoutineModules(
                activeChild: active,
                kidsOn: kidsOn,
                unread: unread,
              ),
              const SizedBox(height: AppSpacing.lg),
              _VaccineWalletCard(
                child: active,
                onOpen: active == null
                    ? () => context.push(Routes.childrenPath)
                    : () => context.push(Routes.vaccines(active.id)),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                color: AppColors.softLilac,
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Precisa de ajuda com agendamento?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        if (canOpenRoute(ref, Routes.receptionistAiPath)) {
                          context.push(Routes.receptionistAiPath);
                        } else {
                          context.go(Routes.aiPath);
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Conversar com a Tia Cris'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => context.push(Routes.clinicInvitePath),
                    icon: const Icon(Icons.groups_outlined, size: 18),
                    label: const Text('Equipe de cuidado'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(Routes.profilePath),
                    icon: const Icon(Icons.family_restroom_rounded, size: 18),
                    label: const Text('Responsaveis e permissoes'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(Routes.notificationsPath),
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(
                      unread == 0 ? 'Mensagens' : 'Mensagens ($unread)',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Child? _resolveChild(List<Child> children, SelectedPatient? focused) {
    if (children.isEmpty) {
      return null;
    }
    if (focused != null) {
      for (final Child c in children) {
        if (c.id == focused.childId) {
          return c;
        }
      }
    }
    return children.first;
  }
}

class _ChildSwitcher extends StatelessWidget {
  const _ChildSwitcher({
    required this.children,
    required this.active,
    required this.onSelect,
    required this.onManage,
  });

  final List<Child> children;
  final Child? active;
  final ValueChanged<Child> onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.lightSurface,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: AppColors.brandIndicator,
            child: Text(
              active?.initials ?? '?',
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: children.isEmpty
                ? const Text('Cadastre uma crianca para comecar')
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: active?.id,
                      hint: const Text('Selecione a crianca'),
                      items: <DropdownMenuItem<String>>[
                        for (final Child c in children)
                          DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                      ],
                      onChanged: (String? id) {
                        if (id == null) {
                          return;
                        }
                        final Child c =
                            children.firstWhere((Child x) => x.id == id);
                        onSelect(c);
                      },
                    ),
                  ),
          ),
          TextButton(
            onPressed: onManage,
            child: Text(children.isEmpty ? 'Cadastrar' : 'Trocar crianca'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.color,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: color,
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyCalendarCard extends StatelessWidget {
  const _FamilyCalendarCard({
    required this.next,
    required this.onAdd,
    required this.onOpenAgenda,
  });

  final Appointment? next;
  final VoidCallback onAdd;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime start =
        now.subtract(Duration(days: now.weekday - DateTime.monday));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Calendario familiar',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              TextButton(onPressed: onOpenAgenda, child: const Text('Agenda')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (int i = 0; i < 7; i++)
                Expanded(
                  child: _DayCell(
                    day: start.add(Duration(days: i)),
                    highlight: next != null &&
                        _sameDay(next!.startsAt, start.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (next != null)
            Text(
              'Proximo: ${DateFormat("dd/MM HH:mm").format(next!.startsAt)}'
              '${(next!.childName ?? "").isEmpty ? "" : " · ${next!.childName}"}',
              style: const TextStyle(color: AppColors.inkMuted),
            )
          else
            const Text(
              'Sem eventos da agenda neste periodo. '
              'Atividades so aparecem com dados reais.',
              style: TextStyle(color: AppColors.inkMuted),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agendar consulta'),
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.highlight});
  final DateTime day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bool today = _FamilyCalendarCard._sameDay(day, DateTime.now());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.brandIndicator
            : (today ? AppColors.lightSurfaceAlt : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            DateFormat('E').format(day),
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.brand : AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _VaccineWalletCard extends StatelessWidget {
  const _VaccineWalletCard({required this.child, required this.onOpen});
  final Child? child;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.softLilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Vacinas · Carteira digital',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const CapiIllustration(pose: CapiPose.aceno, size: 72),
          const SizedBox(height: AppSpacing.sm),
          Text(
            child == null
                ? 'Selecione ou cadastre uma crianca para ver a carteira.'
                : 'Registros de ${child!.firstName} na area de vacinas. '
                    'Nao exibimos status ilustrativo.',
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onOpen,
                  child: const Text('Ver carteira'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onOpen,
                  child: const Text('Abrir vacinas'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreConsultaCard extends StatelessWidget {
  const _PreConsultaCard({required this.onFill});
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Pre-consulta',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Envie duvidas e informacoes antes do atendimento. '
            'O formulario abre quando houver convite da clinica.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _CheckHint(icon: Icons.chat_bubble_outline, label: 'Queixas e duvidas'),
          const _CheckHint(icon: Icons.medication_outlined, label: 'Medicamentos em uso'),
          const _CheckHint(icon: Icons.image_outlined, label: 'Fotos e exames'),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onFill,
            child: const Text('Preencher pre-consulta'),
          ),
        ],
      ),
    );
  }
}

class _CheckHint extends StatelessWidget {
  const _CheckHint({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _RoutineModules extends StatelessWidget {
  const _RoutineModules({
    required this.activeChild,
    required this.kidsOn,
    required this.unread,
  });

  final Child? activeChild;
  final bool kidsOn;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final String? id = activeChild?.id;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool wide = c.maxWidth > 700;
        final List<Widget> cards = <Widget>[
          _DiaryCard(onRegister: () => context.go(Routes.toolsPath)),
          _DocsCard(
            onOpen: id == null
                ? () => context.push(Routes.childrenPath)
                : () => context.push(Routes.childDetail(id)),
          ),
          _SimpleModuleCard(
            title: 'Biblioteca da familia',
            subtitle: 'Conteudos revisados pela equipe. Sem capas ilustrativas.',
            action: 'Explorar biblioteca',
            color: AppColors.softLilac,
            onTap: () => context.go(Routes.libraryPath),
          ),
          _SimpleModuleCard(
            title: 'Orientacoes personalizadas',
            subtitle: 'Liberadas pela clinica quando houver conteudo real.',
            action: 'Ler orientacoes',
            color: AppColors.softMint,
            onTap: () => context.go(Routes.libraryPath),
          ),
        ];
        if (kidsOn) {
          cards.add(
            _SimpleModuleCard(
              title: 'Espaco Kids',
              subtitle: 'Jogos da sala de espera',
              action: 'Abrir',
              color: AppColors.softOrange,
              onTap: () => context.go(Routes.kidsPath),
            ),
          );
        }
        if (wide) {
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              for (final Widget w in cards)
                SizedBox(width: (c.maxWidth - AppSpacing.md) / 2, child: w),
            ],
          );
        }
        return Column(
          children: <Widget>[
            for (final Widget w in cards) ...<Widget>[
              w,
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Diario infantil',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _QuickChip(icon: Icons.local_drink_outlined, label: 'Mamadas'),
              _QuickChip(icon: Icons.restaurant_outlined, label: 'Alimentacao'),
              _QuickChip(icon: Icons.bedtime_outlined, label: 'Sono'),
              _QuickChip(icon: Icons.baby_changing_station, label: 'Fraldas'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Registros aparecem quando a familia salvar dados reais '
            'nas ferramentas de cuidados.',
            style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: onRegister,
            child: const Text('+ Registrar rotina'),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: AppColors.softYellow,
    );
  }
}

class _DocsCard extends StatelessWidget {
  const _DocsCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Receitas e documentos',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Receitas e declaracoes liberadas pelo medico aparecem aqui. '
            'Nao listamos exemplos do mockup.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: onOpen,
            child: const Text('Ver documentos'),
          ),
        ],
      ),
    );
  }
}

class _SimpleModuleCard extends StatelessWidget {
  const _SimpleModuleCard({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String action;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onTap, child: Text(action)),
          ),
        ],
      ),
    );
  }
}
