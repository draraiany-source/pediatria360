import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/app_user.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../children/presentation/providers/children_providers.dart';
import '../../../clinic_intake/domain/clinic_intake.dart';
import '../../../clinic_intake/presentation/clinic_intake_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'
    show activeClinicMembershipProvider;
import '../../../management/presentation/management_common.dart'
    show managementRepositoryProvider;
import '../../data/telemedicine_repository.dart';
import '../../domain/booking_options.dart';
import '../telemedicine_screen.dart'
    show myAgendaProvider, myAppointmentsProvider, telemedicineRepositoryProvider;

const int _slotWindowDays = 14;

/// O servidor explica a recusa (horário ocupado, responsável sem
/// autorização); a mensagem genérica de permissão esconderia o motivo.
String bookingFailureMessage(Failure f) {
  final Object? cause = f.cause;
  if (cause is FirebaseFunctionsException) {
    final String m = (cause.message ?? '').trim();
    if (m.isNotEmpty && cause.code != 'internal') return m;
  }
  return f.message;
}

String _two(int v) => v.toString().padLeft(2, '0');
String _day(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
const List<String> _weekdays = <String>['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
String _dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${_day(d)}';

typedef _SlotKey = ({String clinicId, String professionalId});

final AutoDisposeFutureProviderFamily<List<TimeSlot>, _SlotKey> _slotsProvider =
    FutureProvider.autoDispose.family<List<TimeSlot>, _SlotKey>(
  (Ref ref, _SlotKey key) async {
    final DateTime now = DateTime.now();
    final Result<List<TimeSlot>> r =
        await ref.watch(telemedicineRepositoryProvider).clinicSlots(
              clinicId: key.clinicId,
              professionalId: key.professionalId,
              from: DateTime(now.year, now.month, now.day),
              days: _slotWindowDays,
            );
    return r.fold((List<TimeSlot> v) => v, (Failure f) => throw f);
  },
);

/// Horários livres calculados no servidor para os próximos 14 dias.
class _SlotPicker extends ConsumerWidget {
  const _SlotPicker({
    required this.clinicId,
    required this.professionalId,
    required this.selected,
    required this.onSelected,
  });

  final String clinicId;
  final String professionalId;
  final TimeSlot? selected;
  final ValueChanged<TimeSlot> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _SlotKey key = (clinicId: clinicId, professionalId: professionalId);
    final AsyncValue<List<TimeSlot>> slots = ref.watch(_slotsProvider(key));
    return slots.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: LoadingState(label: 'Buscando horários livres...'),
      ),
      error: (Object e, _) => ErrorState(
        failure: e is Failure ? e : const UnexpectedFailure('Não foi possível buscar os horários.'),
        onRetry: () => ref.invalidate(_slotsProvider(key)),
      ),
      data: (List<TimeSlot> list) {
        final Map<DateTime, List<TimeSlot>> byDay = groupSlotsByDay(list);
        if (byDay.isEmpty) {
          return const InfoBanner(
            icon: Icons.event_busy_outlined,
            color: AppColors.warning,
            text: 'Sem horários livres nos próximos $_slotWindowDays dias para '
                'este profissional. Fale com a recepção da clínica.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final MapEntry<DateTime, List<TimeSlot>> e in byDay.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
                child: Text(
                  _dayLabel(e.key),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final TimeSlot s in e.value)
                    ChoiceChip(
                      key: ValueKey<String>('slot-${s.startsAt.toIso8601String()}'),
                      label: Text(_time(s.startsAt)),
                      selected: selected?.startsAt == s.startsAt,
                      onSelected: (_) => onSelected(s),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

Future<bool> _confirmBooking(
  BuildContext context, {
  required String childName,
  required String professional,
  required TimeSlot slot,
  required String note,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Confirmar agendamento?'),
      content: Text(
        '$childName com $professional\n'
        '${_dayLabel(slot.startsAt)} às ${_time(slot.startsAt)} '
        '(${slot.durationMinutes} min)\n\n$note',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('booking-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Agendar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _BookingScaffold extends StatelessWidget {
  const _BookingScaffold({required this.title, required this.content, this.bottom});

  final String title;
  final List<Widget> content;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: BackButton(
            onPressed: () => context.canPop() ? context.pop() : context.go(Routes.homePath),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            ContentBounds(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: bottom,
                    ),
                  ),
                ),
              ),
      );
}

// ---------------------------------------------------------------- Equipe

/// Recepção, gestão ou o próprio profissional marcam consulta para criança
/// que já é da clínica. O servidor exige a autorização do responsável para
/// o profissional e trava o horário em transação.
class ClinicBookingScreen extends ConsumerStatefulWidget {
  const ClinicBookingScreen({super.key});

  @override
  ConsumerState<ClinicBookingScreen> createState() => _ClinicBookingScreenState();
}

class _ClinicBookingScreenState extends ConsumerState<ClinicBookingScreen> {
  final TextEditingController _reason = TextEditingController();
  List<IntakeProfessionalOption> _professionals = const <IntakeProfessionalOption>[];
  bool _loadingProfessionals = true;
  BookingPatient? _patient;
  String? _professionalId;
  TimeSlot? _slot;
  bool _saving = false;
  String? _error;

  bool get _deskRole {
    final ClinicMembership? m = ref.read(activeClinicMembershipProvider);
    return m != null &&
        (m.role == ClinicRole.receptionist || m.role == ClinicRole.clinicAdmin);
  }

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadProfessionals() async {
    final ClinicMembership? m = ref.read(activeClinicMembershipProvider);
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (m == null) {
      setState(() => _loadingProfessionals = false);
      return;
    }
    final Result<List<IntakeProfessionalOption>> r =
        await ref.read(clinicIntakeRepositoryProvider).careProfessionals(m.clinicId);
    if (!mounted) return;
    final List<IntakeProfessionalOption> all =
        r.valueOrNull ?? const <IntakeProfessionalOption>[];
    setState(() {
      _loadingProfessionals = false;
      _professionals = _deskRole
          ? all
          : all.where((IntakeProfessionalOption o) => o.userId == uid).toList();
      if (_professionals.length == 1) _professionalId = _professionals.first.userId;
      if (r.isFailure) _error = r.failureOrNull?.message;
    });
  }

  void _pickPatient(BookingPatient? p) {
    setState(() {
      _patient = p;
      _slot = null;
      final String? last = p?.lastProfessionalId;
      if (last != null &&
          _professionals.any((IntakeProfessionalOption o) => o.userId == last)) {
        _professionalId = last;
      }
    });
  }

  Future<void> _submit() async {
    final ClinicMembership? m = ref.read(activeClinicMembershipProvider);
    final String? uid = ref.read(currentUserProvider)?.uid;
    final BookingPatient? p = _patient;
    final TimeSlot? slot = _slot;
    final String? prof = _professionalId;
    if (m == null || uid == null || p == null || slot == null || prof == null) {
      setState(() => _error = 'Escolha a criança, o profissional e o horário.');
      return;
    }
    final String profName = _professionals
        .firstWhere((IntakeProfessionalOption o) => o.userId == prof)
        .label;
    final bool ok = await _confirmBooking(
      context,
      childName: p.childName,
      professional: profName,
      slot: slot,
      note: 'A consulta entra confirmada na agenda da clínica e os lembretes '
          'autorizados pela família são programados.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final String reason = _reason.text.trim();
    final Result<String> r =
        await ref.read(telemedicineRepositoryProvider).createClinicAppointment(
              clinicId: m.clinicId,
              patientOwnerId: p.ownerUid,
              professionalId: prof,
              professionalName: profName,
              startsAt: slot.startsAt,
              type: AppointmentType.presencial,
              actorUid: uid,
              childId: p.childId,
              childName: p.childName,
              reason: reason.isEmpty ? null : reason,
              durationMinutes: slot.durationMinutes,
            );
    if (!mounted) return;
    r.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consulta de ${p.childName} marcada para '
              '${_dayLabel(slot.startsAt)} às ${_time(slot.startsAt)}.',
            ),
          ),
        );
        context.canPop() ? context.pop() : context.go(Routes.agendaPath);
      },
      (Failure f) {
        ref.invalidate(_slotsProvider((clinicId: m.clinicId, professionalId: prof)));
        setState(() {
          _saving = false;
          _slot = null;
          _error = bookingFailureMessage(f);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClinicMembership? m = ref.watch(activeClinicMembershipProvider);
    if (m == null || !m.active) {
      return const _BookingScaffold(
        title: 'Agendar consulta',
        content: <Widget>[
          InfoBanner(
            icon: Icons.business_outlined,
            color: AppColors.info,
            text: 'Escolha uma clínica ativa em "Minha clínica" para agendar.',
          ),
        ],
      );
    }

    final AsyncValue<List<BookingPatient>> patients = _deskRole
        ? ref
            .watch(_crmPatientsProvider(m.clinicId))
        : ref.watch(myAgendaProvider).whenData(bookingPatientsFromAppointments);

    return _BookingScaffold(
      title: 'Agendar consulta',
      content: <Widget>[
        const InfoBanner(
          icon: Icons.info_outline,
          color: AppColors.info,
          text: 'Para criança que já é da clínica. Paciente novo entra pela '
              'solicitação com convite. Não registre sintomas aqui.',
        ),
        const SizedBox(height: AppSpacing.md),
        patients.when(
          loading: () => const LoadingState(label: 'Carregando pacientes...'),
          error: (Object e, _) => ErrorState(
            failure: e is Failure ? e : const UnexpectedFailure('Não foi possível carregar os pacientes.'),
            onRetry: () => _deskRole
                ? ref.invalidate(_crmPatientsProvider(m.clinicId))
                : ref.invalidate(myAgendaProvider),
          ),
          data: (List<BookingPatient> list) {
            if (list.isEmpty) {
              return EmptyState(
                title: 'Nenhum paciente com consulta na clínica',
                message: 'Para a primeira consulta, use "Novo paciente".',
                actionLabel: 'Novo paciente',
                onAction: () => context.push(Routes.clinicIntakesPath),
              );
            }
            return DropdownButtonFormField<BookingPatient>(
              key: const Key('booking-patient'),
              initialValue: _patient,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Criança'),
              items: <DropdownMenuItem<BookingPatient>>[
                for (final BookingPatient p in list)
                  DropdownMenuItem<BookingPatient>(
                    value: p,
                    child: Text(p.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving ? null : _pickPatient,
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loadingProfessionals)
          const LoadingState(label: 'Carregando profissionais...')
        else
          DropdownButtonFormField<String>(
            key: ValueKey<String>('booking-professional-${_professionals.length}-$_professionalId'),
            initialValue: _professionalId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Profissional'),
            items: <DropdownMenuItem<String>>[
              for (final IntakeProfessionalOption o in _professionals)
                DropdownMenuItem<String>(value: o.userId, child: Text(o.label)),
            ],
            onChanged: _saving
                ? null
                : (String? v) => setState(() {
                      _professionalId = v;
                      _slot = null;
                    }),
          ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reason,
          maxLength: 300,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Tipo de atendimento (opcional)',
            helperText: 'Ex.: retorno, puericultura.',
          ),
        ),
        if (_patient != null && _professionalId != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text('Horário', style: Theme.of(context).textTheme.titleMedium),
          _SlotPicker(
            clinicId: m.clinicId,
            professionalId: _professionalId!,
            selected: _slot,
            onSelected: (TimeSlot s) => setState(() => _slot = s),
          ),
        ],
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          FilledButton.icon(
            key: const Key('booking-submit'),
            onPressed: _saving || _slot == null ? null : _submit,
            icon: const Icon(Icons.event_available_outlined),
            label: Text(_saving ? 'Agendando...' : 'Agendar'),
          ),
        ],
      ),
    );
  }
}

final AutoDisposeStreamProviderFamily<List<BookingPatient>, String> _crmPatientsProvider =
    StreamProvider.autoDispose.family<List<BookingPatient>, String>(
  (Ref ref, String clinicId) => ref
      .watch(managementRepositoryProvider)
      .watchCrmContacts(clinicId)
      .map(bookingPatientsFromCrm),
);

// ---------------------------------------------------------------- Família

/// A família pede consulta com profissional e clínica com quem já tem
/// atendimento. O servidor só aceita criança da própria conta e aplica a
/// política da clínica (pedido a confirmar ou já confirmado).
class FamilyBookingScreen extends ConsumerStatefulWidget {
  const FamilyBookingScreen({super.key});

  @override
  ConsumerState<FamilyBookingScreen> createState() => _FamilyBookingScreenState();
}

class _FamilyBookingScreenState extends ConsumerState<FamilyBookingScreen> {
  final TextEditingController _reason = TextEditingController();
  Child? _child;
  FamilyBookingTarget? _target;
  TimeSlot? _slot;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final Child? c = _child;
    final FamilyBookingTarget? t = _target;
    final TimeSlot? slot = _slot;
    if (c == null || t == null || slot == null) {
      setState(() => _error = 'Escolha a criança, o profissional e o horário.');
      return;
    }
    final bool ok = await _confirmBooking(
      context,
      childName: c.name,
      professional: t.label,
      slot: slot,
      note: 'Agendar não libera o prontuário da criança: isso continua sendo '
          'escolha sua em "Profissionais autorizados".',
    );
    if (!ok || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final String reason = _reason.text.trim();
    final Result<String> r = await ref.read(telemedicineRepositoryProvider).book(
          professionalId: t.professionalId,
          startsAt: slot.startsAt,
          childId: c.id,
          reason: reason.isEmpty ? null : reason,
          clinicId: t.clinicId,
          type: AppointmentType.presencial,
        );
    if (!mounted) return;
    r.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pedido enviado para ${_dayLabel(slot.startsAt)} às '
              '${_time(slot.startsAt)}. Acompanhe a confirmação em "Suas consultas".',
            ),
          ),
        );
        context.canPop() ? context.pop() : context.go(Routes.telemedicinePath);
      },
      (Failure f) {
        ref.invalidate(_slotsProvider((clinicId: t.clinicId, professionalId: t.professionalId)));
        setState(() {
          _saving = false;
          _slot = null;
          _error = bookingFailureMessage(f);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(currentUserProvider);
    final AsyncValue<List<Child>> children = ref.watch(childrenProvider);
    final AsyncValue<List<FamilyBookingTarget>> targets =
        ref.watch(myAppointmentsProvider).whenData(familyBookingTargets);

    return _BookingScaffold(
      title: 'Agendar consulta',
      content: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.emergency.withValues(alpha: 0.08),
            borderRadius: AppRadius.lgAll,
          ),
          child: const Text(
            'Agendamento não é atendimento de urgência. Em caso de gravidade, '
            'procure o pronto-socorro ou ligue 192.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (user == null)
          const LoadingState()
        else
          children.when(
            loading: () => const LoadingState(label: 'Carregando crianças...'),
            error: (Object e, _) => ErrorState(
              failure: e is Failure ? e : const UnexpectedFailure('Não foi possível carregar as crianças.'),
              onRetry: () => ref.invalidate(childrenProvider),
            ),
            data: (List<Child> kids) {
              final List<Child> own =
                  kids.where((Child k) => k.ownerId == user.uid).toList();
              if (own.isEmpty) {
                return EmptyState(
                  title: 'Cadastre a criança primeiro',
                  message: 'O agendamento é feito para uma criança da sua conta.',
                  actionLabel: 'Cadastrar criança',
                  onAction: () => context.push(Routes.childrenPath),
                );
              }
              return DropdownButtonFormField<Child>(
                key: const Key('family-booking-child'),
                initialValue: _child,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Criança'),
                items: <DropdownMenuItem<Child>>[
                  for (final Child k in own)
                    DropdownMenuItem<Child>(value: k, child: Text(k.name)),
                ],
                onChanged: _saving ? null : (Child? v) => setState(() => _child = v),
              );
            },
          ),
        const SizedBox(height: AppSpacing.md),
        targets.when(
          loading: () => const LoadingState(label: 'Carregando profissionais...'),
          error: (Object e, _) => ErrorState(
            failure: e is Failure ? e : const UnexpectedFailure('Não foi possível carregar suas consultas.'),
            onRetry: () => ref.invalidate(myAppointmentsProvider),
          ),
          data: (List<FamilyBookingTarget> list) {
            if (list.isEmpty) {
              return EmptyState(
                title: 'Nenhuma clínica vinculada',
                message: 'Pelo app, você agenda com profissionais da clínica '
                    'que já atende vocês. Para o primeiro atendimento, use o '
                    'convite enviado pela clínica.',
                actionLabel: 'Tenho um convite',
                onAction: () => context.push(Routes.clinicInvitePath),
              );
            }
            return DropdownButtonFormField<FamilyBookingTarget>(
              key: const Key('family-booking-professional'),
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Profissional'),
              items: <DropdownMenuItem<FamilyBookingTarget>>[
                for (final FamilyBookingTarget t in list)
                  DropdownMenuItem<FamilyBookingTarget>(
                    value: t,
                    child: Text(t.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (FamilyBookingTarget? v) => setState(() {
                        _target = v;
                        _slot = null;
                      }),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _reason,
          maxLength: 300,
          enabled: !_saving,
          decoration: const InputDecoration(
            labelText: 'Motivo da consulta (opcional)',
            helperText: 'Ex.: consulta de rotina, retorno.',
          ),
        ),
        if (_child != null && _target != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text('Horário', style: Theme.of(context).textTheme.titleMedium),
          _SlotPicker(
            clinicId: _target!.clinicId,
            professionalId: _target!.professionalId,
            selected: _slot,
            onSelected: (TimeSlot s) => setState(() => _slot = s),
          ),
        ],
      ],
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ),
          FilledButton.icon(
            key: const Key('family-booking-submit'),
            onPressed: _saving || _slot == null ? null : _submit,
            icon: const Icon(Icons.event_available_outlined),
            label: Text(_saving ? 'Enviando...' : 'Pedir horário'),
          ),
        ],
      ),
    );
  }
}
