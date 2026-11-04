import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/clinical_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../domain/clinic_intake.dart';
import 'clinic_intake_providers.dart';

String _dateTime(DateTime d) {
  final DateTime l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

/// Mostra o código uma única vez, com a mensagem para enviar à família.
Future<void> showInviteCodeDialog(
  BuildContext context, {
  required IntakeInvite invite,
  required String guardianName,
  required String childName,
  required String? clinicName,
}) {
  final String message = invite.messageFor(
    guardianName: guardianName,
    childName: childName,
    clinicName: clinicName,
  );
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Convite para a família'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Código (aparece só agora):'),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              invite.code,
              key: const Key('intake-invite-code'),
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Envie a mensagem abaixo ao responsável. O envio pelo WhatsApp '
              'ainda é simulado: copie e cole no canal da clínica.',
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(message),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Clipboard.setData(ClipboardData(text: message)),
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar mensagem'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Concluir'),
        ),
      ],
    ),
  );
}

/// Solicitações de paciente novo: pendentes, confirmadas e canceladas. A
/// recepção organiza a agenda daqui sem abrir prontuário.
class ClinicIntakesScreen extends ConsumerWidget {
  const ClinicIntakesScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, ClinicIntake i) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Cancelar solicitação?'),
        content: Text(
          'O código enviado para ${i.guardianName} deixa de valer e o horário '
          'é liberado.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar solicitação'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final Result<void> r = await ref.read(clinicIntakeRepositoryProvider).cancel(i.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.fold((_) => 'Solicitação cancelada.', (Failure f) => f.message)),
      ),
    );
  }

  Future<void> _renew(BuildContext context, WidgetRef ref, ClinicIntake i) async {
    final Result<IntakeInvite> r =
        await ref.read(clinicIntakeRepositoryProvider).renewCode(i.id);
    if (!context.mounted) return;
    await r.fold(
      (IntakeInvite inv) => showInviteCodeDialog(
        context,
        invite: inv,
        guardianName: i.guardianName,
        childName: i.childName,
        clinicName: i.clinicName,
      ),
      (Failure f) async => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ClinicIntake>> async = ref.watch(visibleIntakesProvider);
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações de paciente novo')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('intake-new'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewIntakeScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nova solicitação'),
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando solicitações...'),
        error: (Object e, StackTrace st) => ErrorState(
          failure: e is Failure ? e : ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(visibleIntakesProvider),
        ),
        data: (List<ClinicIntake> list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_ind_outlined,
              title: 'Nenhuma solicitação',
              message: 'Registre o pedido de consulta de um paciente novo. A '
                  'família confirma pelo app e escolhe o que autorizar.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            children: <Widget>[
              const InfoBanner(
                icon: Icons.lock_outline,
                color: AppColors.violet,
                text: 'Solicitação é só agenda: não cria vínculo com criança '
                    'nem abre prontuário. O atendimento clínico depende da '
                    'autorização do responsável.',
              ),
              const SizedBox(height: AppSpacing.md),
              for (final ClinicIntake i in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                i.childName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            AppTag(
                              label: i.inviteExpired(now)
                                  ? 'Convite vencido'
                                  : i.status.label,
                              color: switch (i.status) {
                                ClinicIntakeStatus.pendingGuardian =>
                                  i.inviteExpired(now) ? AppColors.danger : AppColors.warning,
                                ClinicIntakeStatus.linked => AppColors.success,
                                ClinicIntakeStatus.cancelled => AppColors.inkMuted,
                              },
                            ),
                          ],
                        ),
                        Text(
                          '${_dateTime(i.requestedStartsAt)} · ${i.durationMinutes} min · '
                          '${i.professionalName}',
                        ),
                        Text('Responsável: ${i.guardianName} · ${i.guardianEmail}'),
                        if (i.accessLabel.isNotEmpty) Text(i.accessLabel),
                        if (i.status == ClinicIntakeStatus.pendingGuardian)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              children: <Widget>[
                                TextButton(
                                  onPressed: () => _cancel(context, ref, i),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _renew(context, ref, i),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Novo código'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Formulário da recepção (ou do profissional, para si). Só dados
/// administrativos; nada clínico.
class NewIntakeScreen extends ConsumerStatefulWidget {
  const NewIntakeScreen({super.key});

  @override
  ConsumerState<NewIntakeScreen> createState() => _NewIntakeScreenState();
}

class _NewIntakeScreenState extends ConsumerState<NewIntakeScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _child = TextEditingController();
  final TextEditingController _guardian = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  DateTime? _birth;
  DateTime? _startsAt;
  int _duration = 30;
  String? _professionalId;
  List<IntakeProfessionalOption> _options = const <IntakeProfessionalOption>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfessionals();
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _child,
      _guardian,
      _email,
      _phone,
      _reason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfessionals() async {
    final ClinicMembership? m = ref.read(activeClinicMembershipProvider);
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (m == null) {
      if (uid != null) {
        setState(() {
          _options = <IntakeProfessionalOption>[
            IntakeProfessionalOption(userId: uid, label: 'Eu'),
          ];
          _professionalId = uid;
        });
      }
      return;
    }
    final Result<List<IntakeProfessionalOption>> r =
        await ref.read(clinicIntakeRepositoryProvider).careProfessionals(m.clinicId);
    if (!mounted) return;
    final List<IntakeProfessionalOption> opts =
        r.valueOrNull ?? const <IntakeProfessionalOption>[];
    final bool deskRole = m.role == ClinicRole.receptionist || m.role == ClinicRole.clinicAdmin;
    setState(() {
      _options = deskRole
          ? opts
          : opts.where((IntakeProfessionalOption o) => o.userId == uid).toList();
      if (_options.length == 1) _professionalId = _options.first.userId;
    });
  }

  Future<void> _pickBirth() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(now.year - 21),
      lastDate: now,
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _pickStart() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (t == null) return;
    setState(() => _startsAt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_birth == null || _startsAt == null || _professionalId == null) {
      setState(() => _error = 'Preencha nascimento, horário e profissional.');
      return;
    }
    final ClinicMembership? m = ref.read(activeClinicMembershipProvider);
    setState(() => _saving = true);
    final Result<IntakeInvite> r = await ref.read(clinicIntakeRepositoryProvider).create(
          clinicId: m?.clinicId,
          professionalId: _professionalId!,
          childName: _child.text,
          childBirthDate: _birth!,
          guardianName: _guardian.text,
          guardianEmail: _email.text,
          guardianPhone: _phone.text,
          startsAt: _startsAt!,
          durationMinutes: _duration,
          reason: _reason.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    await r.fold(
      (IntakeInvite inv) async {
        await showInviteCodeDialog(
          context,
          invite: inv,
          guardianName: _guardian.text.trim(),
          childName: _child.text.trim(),
          clinicName: m?.clinicName,
        );
        if (mounted) Navigator.of(context).pop();
      },
      (Failure f) async => setState(() => _error = f.message),
    );
  }

  String? _required(String? v) =>
      (v ?? '').trim().length < 2 ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d, {bool time = false}) {
      if (d == null) return 'Escolher';
      String two(int v) => v.toString().padLeft(2, '0');
      final String day = '${two(d.day)}/${two(d.month)}/${d.year}';
      return time ? '$day ${two(d.hour)}:${two(d.minute)}' : day;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nova solicitação')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const InfoBanner(
              icon: Icons.info_outline,
              color: AppColors.info,
              text: 'Registre só dados de agenda e contato. A família confirma '
                  'pelo app com o código e decide se autoriza o acesso '
                  'clínico. Não registre sintomas ou diagnóstico aqui.',
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey<String>('intake-professional-${_options.length}'),
              initialValue: _professionalId,
              decoration: const InputDecoration(labelText: 'Profissional'),
              items: <DropdownMenuItem<String>>[
                for (final IntakeProfessionalOption o in _options)
                  DropdownMenuItem<String>(value: o.userId, child: Text(o.label)),
              ],
              onChanged: (String? v) => setState(() => _professionalId = v),
              validator: (String? v) => v == null ? 'Escolha o profissional' : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e horário'),
              trailing: Text(fmt(_startsAt, time: true)),
              onTap: _pickStart,
            ),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Duração'),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem<int>(value: 20, child: Text('20 min')),
                DropdownMenuItem<int>(value: 30, child: Text('30 min')),
                DropdownMenuItem<int>(value: 45, child: Text('45 min')),
                DropdownMenuItem<int>(value: 60, child: Text('60 min')),
              ],
              onChanged: (int? v) => setState(() => _duration = v ?? 30),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('intake-child-name'),
              controller: _child,
              decoration: const InputDecoration(labelText: 'Nome da criança'),
              validator: _required,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nascimento da criança'),
              trailing: Text(fmt(_birth)),
              onTap: _pickBirth,
            ),
            TextFormField(
              key: const Key('intake-guardian-name'),
              controller: _guardian,
              decoration: const InputDecoration(labelText: 'Nome do responsável'),
              validator: _required,
            ),
            TextFormField(
              key: const Key('intake-guardian-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail do responsável',
                helperText: 'Só a conta com este e-mail, confirmado, aceita o convite.',
              ),
              validator: (String? v) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
                      ? null
                      : 'E-mail inválido',
            ),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone (opcional)'),
            ),
            TextFormField(
              controller: _reason,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Tipo de atendimento (opcional)',
                helperText: 'Ex.: primeira consulta, puericultura.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('intake-submit'),
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send_outlined),
              label: Text(_saving ? 'Registrando...' : 'Registrar e gerar convite'),
            ),
          ],
        ),
      ),
    );
  }
}
