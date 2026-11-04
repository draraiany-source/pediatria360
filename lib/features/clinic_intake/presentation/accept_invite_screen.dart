import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failures.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/clinical_ui.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../../shared/domain/entities/child.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../children/domain/child_access_grant.dart';
import '../../children/presentation/providers/children_providers.dart';
import '../domain/clinic_intake.dart';
import 'clinic_intake_providers.dart';

/// O que a família escolhe ao aceitar: só confirmar a consulta, ou também
/// autorizar o resumo, ou resumo e prontuário.
enum InviteAccessChoice {
  none,
  summaryOnly,
  chart;

  List<String> get scopes => switch (this) {
        InviteAccessChoice.none => const <String>[],
        InviteAccessChoice.summaryOnly => ChildAccessLevel.summaryOnly.scopes,
        InviteAccessChoice.chart => ChildAccessLevel.chart.scopes,
      };

  String get label => switch (this) {
        InviteAccessChoice.none => 'Só confirmar a consulta (decido o acesso depois)',
        InviteAccessChoice.summaryOnly => ChildAccessLevel.summaryOnly.label,
        InviteAccessChoice.chart => ChildAccessLevel.chart.label,
      };

  String get detail => switch (this) {
        InviteAccessChoice.none =>
          'O profissional não vê dados da criança nem registra atendimento '
              'até você autorizar em "Profissionais autorizados".',
        InviteAccessChoice.summaryOnly =>
          'Permite: ${ChildAccessLevel.summaryOnly.allows}\n'
              'Não permite: ${ChildAccessLevel.summaryOnly.denies}',
        InviteAccessChoice.chart =>
          'Permite: ${ChildAccessLevel.chart.allows}\n'
              'Não permite: ${ChildAccessLevel.chart.denies}',
      };
}

/// Convite da clínica: o responsável digita o código, confere a consulta,
/// escolhe a criança (da própria conta) e o acesso, e confirma.
class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key});

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final TextEditingController _code = TextEditingController();
  IntakePreview? _preview;
  String? _childId;
  InviteAccessChoice _choice = InviteAccessChoice.none;
  int _days = 90;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<IntakePreview> r =
        await ref.read(clinicIntakeRepositoryProvider).preview(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      r.fold((IntakePreview p) => _preview = p, (Failure f) => _error = f.message);
    });
  }

  Future<void> _accept() async {
    if (_childId == null) {
      setState(() => _error = 'Escolha a criança.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final Result<String> r = await ref.read(clinicIntakeRepositoryProvider).accept(
          code: _code.text,
          childId: _childId!,
          scopes: _choice.scopes,
          days: _days,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      r.fold(
        (_) => _done = _choice == InviteAccessChoice.none
            ? 'Consulta confirmada. O profissional ainda não tem acesso aos '
                'dados da criança; autorize quando quiser em '
                '"Profissionais autorizados".'
            : 'Consulta confirmada e acesso autorizado por $_days dias. Você '
                'pode revogar a qualquer momento.',
        (Failure f) => _error = f.message,
      );
    });
  }

  String _fmt(DateTime d) {
    final DateTime l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} às ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppUser? user = ref.watch(currentUserProvider);
    final List<Child> children =
        ref.watch(childrenProvider).valueOrNull ?? const <Child>[];
    final IntakePreview? p = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Convite da clínica')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (_done != null) ...<Widget>[
            InfoBanner(
              icon: Icons.check_circle_outline,
              color: AppColors.success,
              text: _done!,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(Routes.homePath),
              child: const Text('Voltar ao início'),
            ),
          ] else ...<Widget>[
            const InfoBanner(
              icon: Icons.mail_lock_outlined,
              color: AppColors.violet,
              text: 'Use o código enviado pela clínica. Só a conta com o '
                  'e-mail informado à clínica, já confirmado, aceita o '
                  'convite. Nada é compartilhado sem a sua escolha.',
            ),
            if (user != null && !user.emailVerified) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const InfoBanner(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                text: 'Seu e-mail ainda não foi confirmado. Confirme pelo link '
                    'enviado ao seu e-mail (Perfil > Confirmar e-mail) antes '
                    'de aceitar.',
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('invite-code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              enabled: p == null,
              decoration: const InputDecoration(
                labelText: 'Código do convite',
                hintText: 'XXXXX-XXXXX',
              ),
            ),
            if (p == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: FilledButton(
                  key: const Key('invite-check'),
                  onPressed: _busy ? null : _load,
                  child: Text(_busy ? 'Conferindo...' : 'Conferir convite'),
                ),
              ),
            if (p != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(p.clinicName ?? 'Consulta', style: theme.textTheme.titleMedium),
                    Text(
                      '${p.professionalName}'
                      '${(p.specialty ?? '').isEmpty ? '' : ' · ${p.specialty}'}',
                    ),
                    Text('${_fmt(p.startsAt)} · ${p.durationMinutes} min'),
                    Text('Criança informada pela clínica: ${p.childName}'),
                  ],
                ),
              ),
              const SectionHeader(title: 'Para qual criança?'),
              if (children.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'Cadastre a criança na sua conta antes de aceitar. O '
                      'convite não cria nem vincula criança de outra conta.',
                    ),
                    TextButton(
                      onPressed: () => context.push(
                        '${Routes.childrenPath}/${Routes.childFormPath}',
                      ),
                      child: const Text('Cadastrar criança'),
                    ),
                  ],
                ),
              for (final Child c in children)
                RadioListTile<String>(
                  key: Key('invite-child-${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: c.id,
                  groupValue: _childId,
                  onChanged: (String? v) => setState(() => _childId = v),
                  title: Text(c.name),
                ),
              const SectionHeader(title: 'Acesso aos dados da criança'),
              for (final InviteAccessChoice ch in InviteAccessChoice.values)
                RadioListTile<InviteAccessChoice>(
                  key: Key('invite-access-${ch.name}'),
                  contentPadding: EdgeInsets.zero,
                  value: ch,
                  groupValue: _choice,
                  onChanged: (InviteAccessChoice? v) =>
                      setState(() => _choice = v ?? _choice),
                  title: Text(ch.label),
                  subtitle: Text(ch.detail),
                  isThreeLine: true,
                ),
              if (_choice != InviteAccessChoice.none) ...<Widget>[
                Text('Validade', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int d in kChildAccessDurations)
                      ChoiceChip(
                        label: Text(d == 365 ? '1 ano' : '$d dias'),
                        selected: _days == d,
                        onSelected: (_) => setState(() => _days = d),
                      ),
                  ],
                ),
                Text(
                  'Vale só nesta clínica. Você pode revogar a qualquer momento.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const Key('invite-accept'),
                onPressed: _busy || _childId == null ? null : _accept,
                icon: const Icon(Icons.check),
                label: Text(_busy ? 'Confirmando...' : 'Confirmar'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
          ],
        ],
      ),
    );
  }
}
