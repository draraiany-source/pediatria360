import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/clinical_ui.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/commerce.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/telemedicine_repository.dart';
import 'screens/pre_visit_questionnaire_form_screen.dart';

final Provider<TelemedicineRepository> telemedicineRepositoryProvider =
    Provider<TelemedicineRepository>(
  (Ref ref) => TelemedicineRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

final StreamProvider<List<Appointment>> myAppointmentsProvider =
    StreamProvider<List<Appointment>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<Appointment>>.value(const <Appointment>[]);
  }
  return ref.watch(telemedicineRepositoryProvider).watchMyAppointments(uid);
});

/// A agenda do profissional — mesma coleção que `myAppointmentsProvider`,
/// filtrada pelo lado de quem atende, não de quem é atendido.
/// `watchProfessionalAgenda` já existia no repositório; nada consumia.
final StreamProvider<List<Appointment>> myAgendaProvider =
    StreamProvider<List<Appointment>>((Ref ref) {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) {
    return Stream<List<Appointment>>.value(const <Appointment>[]);
  }
  return ref
      .watch(telemedicineRepositoryProvider)
      .watchProfessionalAgenda(uid);
});

/// A disponibilidade semanal do próprio profissional — carregada uma vez
/// por acesso à tela; quem editar chama `setWeeklyAvailability` e invalida
/// este provider para recarregar.
final FutureProvider<Map<String, List<String>>> myAvailabilityProvider =
    FutureProvider<Map<String, List<String>>>((Ref ref) async {
  final String? uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const <String, List<String>>{};
  final Result<Map<String, List<String>>> result = await ref
      .watch(telemedicineRepositoryProvider)
      .myWeeklyAvailability(uid);
  return result.fold((Map<String, List<String>> v) => v, (_) => const <String, List<String>>{});
});

final FutureProvider<List<ProfessionalProfile>> professionalsProvider =
    FutureProvider<List<ProfessionalProfile>>((Ref ref) async {
  final Result<List<ProfessionalProfile>> result =
      await ref.watch(telemedicineRepositoryProvider).professionals();
  return result.valueOrNull ?? const <ProfessionalProfile>[];
});

/// Telemedicina: consultas do usuário e profissionais disponíveis.
class TelemedicineScreen extends ConsumerWidget {
  const TelemedicineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Appointment>> appointments =
        ref.watch(myAppointmentsProvider);
    final AsyncValue<List<ProfessionalProfile>> professionals =
        ref.watch(professionalsProvider);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.darkBackground
          : theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Telemedicina'),
        backgroundColor: theme.brightness == Brightness.dark
            ? AppColors.darkBackground
            : null,
        leading: IconButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.homePath),
          icon: const AppIcon(
            asset: AppIcons.back,
            size: 22,
            fallback: Icons.arrow_back_rounded,
          ),
          tooltip: 'Voltar',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          ContentBounds(
            maxWidth: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.14),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: const AppIcon(
                              asset: AppIcons.telemedicine,
                              size: 20,
                              fallback: Icons.videocam_outlined,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Consulta online',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Agende e acompanhe teleconsultas com pediatras '
                        'disponíveis. Não substitui atendimento de emergência.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Sala de vídeo preparada — integração futura.
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: AppRadius.xlAll,
                        ),
                        child: Column(
                          children: <Widget>[
                            const Icon(
                              Icons.videocam_off_outlined,
                              color: Colors.white70,
                              size: 40,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Área da consulta',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              AppConfig.videoConsultationEnabled
                                  ? 'Pronto para conectar'
                                  : 'Integração de vídeo ainda não ativa',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                _CallControl(
                                  icon: Icons.mic_outlined,
                                  asset: AppIcons.microphone,
                                  label: 'Microfone',
                                  enabled: AppConfig.videoConsultationEnabled,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _CallControl(
                                  icon: Icons.videocam_outlined,
                                  asset: AppIcons.videoCall,
                                  label: 'Câmera',
                                  enabled: AppConfig.videoConsultationEnabled,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                _CallControl(
                                  icon: Icons.call_end_rounded,
                                  label: 'Encerrar',
                                  enabled: AppConfig.videoConsultationEnabled,
                                  danger: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // O aviso vem primeiro, antes de qualquer opção de agendar.
                // Quem abre telemedicina com uma criança passando mal precisa
                // ler isto antes de esperar por um horário.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.emergency.withValues(alpha: 0.08),
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: AppColors.emergency.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.emergency_outlined,
                        color: AppColors.emergency,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Teleconsulta não atende emergência. Em caso de '
                          'gravidade, procure o pronto-socorro ou ligue 192.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                appointments.when(
                  loading: () =>
                      const SkeletonList(itemCount: 2, itemHeight: 72),
                  error: (Object e, StackTrace s) => const SizedBox.shrink(),
                  data: (List<Appointment> list) {
                    final List<Appointment> active = list
                        .where(
                          (Appointment a) => a.status.isActive && !a.isPast,
                        )
                        .toList();

                    if (active.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SectionHeader(
                          title: 'Suas consultas',
                          eyebrow: 'Agendadas',
                        ),
                        for (final Appointment a in active)
                          _AppointmentCard(appointment: a),
                      ],
                    );
                  },
                ),
                if (!AppConfig.videoConsultationEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.10),
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Agendamento de teleconsulta indisponível nesta '
                              'versão.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SectionHeader(
                  title: 'Profissionais',
                  eyebrow: 'Disponíveis',
                ),
                professionals.when(
                  loading: () =>
                      const SkeletonList(itemCount: 3, itemHeight: 80),
                  error: (Object e, StackTrace s) => const EmptyState(
                    icon: Icons.medical_services_outlined,
                    title: 'Não conseguimos carregar essas informações',
                    message: 'Tente novamente em alguns instantes.',
                  ),
                  data: (List<ProfessionalProfile> list) {
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.medical_services_outlined,
                        title: 'Nenhum profissional disponível',
                        message: 'Os atendentes aparecem aqui depois que a '
                            'equipe verificar o registro profissional.',
                      );
                    }

                    return Column(
                      children: <Widget>[
                        for (final ProfessionalProfile p in list)
                          _ProfessionalCard(professional: p),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final Result<String> result = await ref
        .read(telemedicineRepositoryProvider)
        .joinRoom(appointment.id);

    if (!context.mounted) return;

    await result.fold(
      (String url) async {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      (Failure failure) async {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    appointment.professionalName,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                AppTag(
                  label: appointment.status.label,
                  color: appointment.status == AppointmentStatus.confirmed
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Formatters.dateTime(appointment.startsAt),
              style: theme.textTheme.bodyMedium,
            ),
            if (appointment.childName != null)
              Text(
                'Para ${appointment.childName}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.lg),
            if (appointment.canEnterRoom)
              AppButton(
                label: 'Entrar na consulta',
                icon: Icons.videocam_rounded,
                asset: AppIcons.telemedicine,
                onPressed: () => _join(context, ref),
              )
            else
              Row(
                children: <Widget>[
                  AppIcon(
                    asset: AppIcons.schedule,
                    size: 14,
                    fallback: Icons.schedule_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'A sala abre 10 minutos antes do horário.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (appointment.canCancelFree)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                      ),
                      onPressed: () => ref
                          .read(telemedicineRepositoryProvider)
                          .cancel(appointment.id),
                      child: const Text('Cancelar'),
                    ),
                ],
              ),
            // Só enquanto a regra do servidor ainda aceita escrita — a
            // mesma janela (requested/confirmed) que
            // `firestore.rules/pre_visit_questionnaires` exige. Mostrar
            // o botão fora dessa janela levaria a um envio que a regra
            // rejeitaria, sem explicação nenhuma pra família.
            if (appointment.childId != null &&
                (appointment.status == AppointmentStatus.requested ||
                    appointment.status == AppointmentStatus.confirmed))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: BorderSide(
                      color: AppColors.brand.withValues(alpha: 0.45),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PreVisitQuestionnaireFormScreen(
                        appointmentId: appointment.id,
                        childId: appointment.childId!,
                        professionalId: appointment.professionalId,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Preencher pré-consulta'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.professional});

  final ProfessionalProfile professional;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        child: Row(
          children: <Widget>[
            if (professional.photoUrl != null)
              CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(professional.photoUrl!),
              )
            else
              PersonAvatar(
                name: professional.name,
                seed: professional.uid,
                radius: 26,
              ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    professional.name,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    professional.specialty,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (professional.crm != null)
                    Text(
                      'CRM ${professional.crm}',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    professional.priceCents == 0
                        ? 'Consultar valor'
                        : formatCents(professional.priceCents),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                foregroundColor: AppColors.brand,
                backgroundColor: AppColors.brand.withValues(alpha: 0.16),
              ),
              onPressed: AppConfig.videoConsultationEnabled
                  ? () {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Abrindo agenda...'),
                          ),
                        );
                    }
                  // `null` desativa o botão visualmente: quem olha a
                  // tela já vê que não dá para agendar, sem precisar
                  // tocar para descobrir.
                  : null,
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.label,
    required this.enabled,
    this.asset,
    this.danger = false,
  });

  final IconData icon;
  final String? asset;
  final String label;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        IconButton.filled(
          onPressed: enabled
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        danger
                            ? 'Encerrar estará disponível com o provedor de vídeo.'
                            : '$label: integração futura.',
                      ),
                    ),
                  );
                }
              : null,
          style: IconButton.styleFrom(
            backgroundColor: danger
                ? AppColors.danger
                : Colors.white.withValues(alpha: 0.15),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
          ),
          icon: asset != null
              ? AppIcon(
                  asset: asset!,
                  size: 22,
                  fallback: icon,
                  color: Colors.white,
                )
              : Icon(icon),
          tooltip: label,
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
