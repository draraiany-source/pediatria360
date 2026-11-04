import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/clinical_ui.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../domain/child_access_grant.dart';
import '../providers/child_access_providers.dart';

String _date(DateTime? d) {
  if (d == null) return '-';
  final DateTime l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

/// Profissionais que o responsável autorizou para esta criança: concede,
/// acompanha (ativas, vencidas, revogadas, antigas) e revoga.
class ChildAccessScreen extends ConsumerWidget {
  const ChildAccessScreen({required this.child, super.key});

  final Child child;

  ChildAccessKey get _key => (ownerId: child.ownerId, childId: child.id);

  Future<void> _openGrant(
    BuildContext context,
    WidgetRef ref, {
    AccessCandidate? preset,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _GrantSheet(child: child, preset: preset),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autorização registrada.')),
      );
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    ChildAccessGrant g,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Revogar autorização?'),
        content: Text(
          '${g.displayName} deixa de ver o cadastro de ${child.name} e não '
          'consegue registrar nada novo a partir de agora.\n\n'
          'O que já foi registrado continua no prontuário, e o profissional '
          'ainda consegue ler os próprios registros já feitos. Essa regra de '
          'guarda está em revisão e não foi validada juridicamente.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revogar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final Result<void> r = await ref.read(childAccessRepositoryProvider).revoke(
          ownerId: child.ownerId,
          childId: child.id,
          professionalId: g.professionalId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.fold((_) => 'Autorização revogada.', (Failure f) => f.message),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ChildAccessGrant>> async =
        ref.watch(childAccessGrantsProvider(_key));

    return Scaffold(
      appBar: AppBar(title: const Text('Profissionais autorizados')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('child-access-new'),
        onPressed: () => _openGrant(context, ref),
        icon: const Icon(Icons.add_moderator_outlined),
        label: const Text('Autorizar'),
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando autorizações...'),
        error: (Object e, StackTrace st) => ErrorState(
          failure: e is Failure ? e : ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(childAccessGrantsProvider(_key)),
        ),
        data: (List<ChildAccessGrant> grants) {
          List<ChildAccessGrant> by(ChildAccessStatus s) => grants
              .where((ChildAccessGrant g) => g.status == s)
              .toList(growable: false);
          final List<ChildAccessGrant> active = by(ChildAccessStatus.active);
          final List<ChildAccessGrant> expired = by(ChildAccessStatus.expired);
          final List<ChildAccessGrant> revoked = by(ChildAccessStatus.revoked);
          final List<ChildAccessGrant> legacy = by(ChildAccessStatus.invalid);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            children: <Widget>[
              InfoBanner(
                icon: Icons.shield_outlined,
                color: AppColors.violet,
                text: 'Só você decide quem acessa os dados de ${child.name}. '
                    'Marcar consulta não dá acesso. "Somente resumo" mostra '
                    'o cadastro básico; "Resumo e prontuário" permite '
                    'registrar atendimentos, documentos e usar IA.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _LevelsExplainer(),
              if (grants.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: EmptyState(
                    icon: Icons.verified_user_outlined,
                    title: 'Nenhum profissional autorizado',
                    message: 'Toque em "Autorizar" para escolher um '
                        'profissional das suas consultas ou buscar pelo '
                        'e-mail dele.',
                  ),
                ),
              _Section(
                title: 'Ativas',
                grants: active,
                onRevoke: (ChildAccessGrant g) => _revoke(context, ref, g),
              ),
              _Section(
                title: 'Vencidas',
                grants: expired,
                onRenew: (ChildAccessGrant g) =>
                    _openGrant(context, ref, preset: _candidateOf(g)),
              ),
              _Section(
                title: 'Revogadas',
                grants: revoked,
                onRenew: (ChildAccessGrant g) =>
                    _openGrant(context, ref, preset: _candidateOf(g)),
              ),
              _Section(
                title: 'Antigas, sem efeito',
                subtitle: 'Autorizações de versões anteriores não valem mais. '
                    'Se quiser manter o acesso, autorize de novo.',
                grants: legacy,
                onRenew: (ChildAccessGrant g) =>
                    _openGrant(context, ref, preset: _candidateOf(g)),
              ),
            ],
          );
        },
      ),
    );
  }

  static AccessCandidate _candidateOf(ChildAccessGrant g) => AccessCandidate(
        professionalId: g.professionalId,
        professionalName: g.displayName,
        clinicId: g.clinicId,
        clinicName: g.clinicName,
      );
}

class _LevelsExplainer extends StatelessWidget {
  const _LevelsExplainer();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'O que cada autorização permite',
        style: theme.textTheme.titleSmall,
      ),
      children: <Widget>[
        for (final ChildAccessLevel l in ChildAccessLevel.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.label),
            subtitle: Text('Permite: ${l.allows}\nNão permite: ${l.denies}'),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.grants,
    this.subtitle,
    this.onRevoke,
    this.onRenew,
  });

  final String title;
  final String? subtitle;
  final List<ChildAccessGrant> grants;
  final void Function(ChildAccessGrant)? onRevoke;
  final void Function(ChildAccessGrant)? onRenew;

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(title: '$title (${grants.length})'),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ),
        for (final ChildAccessGrant g in grants)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _GrantCard(grant: g, onRevoke: onRevoke, onRenew: onRenew),
          ),
      ],
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.grant, this.onRevoke, this.onRenew});

  final ChildAccessGrant grant;
  final void Function(ChildAccessGrant)? onRevoke;
  final void Function(ChildAccessGrant)? onRenew;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ChildAccessLevel? level = grant.level;
    final Color tone = switch (grant.status) {
      ChildAccessStatus.active => AppColors.success,
      ChildAccessStatus.expired => AppColors.warning,
      ChildAccessStatus.revoked => AppColors.danger,
      ChildAccessStatus.invalid => AppColors.inkMuted,
    };
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(grant.displayName, style: theme.textTheme.titleMedium),
              ),
              AppTag(label: grant.statusLabel, color: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            grant.clinicId == null
                ? 'Em qualquer clínica'
                : 'Somente na clínica ${grant.clinicName ?? ''}'.trim(),
            style: theme.textTheme.bodySmall,
          ),
          if (level != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(level.label, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            switch (grant.status) {
              ChildAccessStatus.active =>
                'Concedida em ${_date(grant.grantedAt)} · vale até ${_date(grant.expiresAt)}',
              ChildAccessStatus.expired => 'Venceu em ${_date(grant.expiresAt)}',
              ChildAccessStatus.revoked => 'Revogada em ${_date(grant.revokedAt)}',
              ChildAccessStatus.invalid => 'Sem validade definida: não dá acesso.',
            },
            style: theme.textTheme.bodySmall,
          ),
          if (grant.source == ChildAccessGrant.sourceInvite)
            Text(
              'Concedida ao aceitar o convite da clínica.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: grant.isActive
                ? (onRevoke == null
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        onPressed: () => onRevoke!(grant),
                        icon: const Icon(Icons.block_outlined),
                        label: const Text('Revogar'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ))
                : (onRenew == null
                    ? const SizedBox.shrink()
                    : TextButton.icon(
                        onPressed: () => onRenew!(grant),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Autorizar de novo'),
                      )),
          ),
        ],
      ),
    );
  }
}

/// Formulário de concessão: profissional (das consultas ou por e-mail),
/// clínica, nível e validade, com confirmação do que será liberado.
class _GrantSheet extends ConsumerStatefulWidget {
  const _GrantSheet({required this.child, this.preset});

  final Child child;
  final AccessCandidate? preset;

  @override
  ConsumerState<_GrantSheet> createState() => _GrantSheetState();
}

class _GrantSheetState extends ConsumerState<_GrantSheet> {
  final TextEditingController _email = TextEditingController();
  List<AccessCandidate> _candidates = const <AccessCandidate>[];
  AccessCandidate? _selected;
  bool _onlyThisClinic = true;
  ChildAccessLevel _level = ChildAccessLevel.summaryOnly;
  int _days = 90;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.preset;
    _onlyThisClinic = widget.preset?.clinicId != null;
    _loadCandidates();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final Result<List<AccessCandidate>> r = await ref
        .read(childAccessRepositoryProvider)
        .candidatesFromMyAppointments(widget.child.ownerId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _candidates = r.valueOrNull ?? const <AccessCandidate>[];
    });
  }

  Future<void> _lookup() async {
    setState(() => _error = null);
    final Result<AccessCandidate> r = await ref
        .read(childAccessRepositoryProvider)
        .lookupProfessional(_email.text);
    if (!mounted) return;
    r.fold(
      (AccessCandidate c) => setState(() {
        _selected = c;
        _onlyThisClinic = false;
      }),
      (Failure f) => setState(() => _error = f.message),
    );
  }

  Future<void> _confirm() async {
    final AccessCandidate? c = _selected;
    if (c == null) return;
    final bool restrict = _onlyThisClinic && c.clinicId != null;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Confirmar autorização'),
        content: Text(
          '${c.professionalName} · ${_level.label}\n'
          '${restrict ? 'Somente na clínica ${c.clinicName ?? ''}' : 'Em qualquer clínica'}'
          ' · por $_days dias\n\n'
          'Permite: ${_level.allows}\n\nNão permite: ${_level.denies}\n\n'
          'Você pode revogar a qualquer momento.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            key: const Key('child-access-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Autorizar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final Result<void> r = await ref.read(childAccessRepositoryProvider).grant(
          ownerId: widget.child.ownerId,
          childId: widget.child.id,
          professionalId: c.professionalId,
          professionalName: c.professionalName,
          level: _level,
          days: _days,
          clinicId: restrict ? c.clinicId : null,
          clinicName: restrict ? c.clinicName : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    r.fold(
      (_) => Navigator.of(context).pop(true),
      (Failure f) => setState(() => _error = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccessCandidate? sel = _selected;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Autorizar profissional para ${widget.child.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('1. Profissional', style: theme.textTheme.titleSmall),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...<Widget>[
              if (_candidates.isEmpty && widget.preset == null)
                Text(
                  'Nenhum profissional nas suas consultas. Busque pelo e-mail.',
                  style: theme.textTheme.bodySmall,
                ),
              for (final AccessCandidate c in <AccessCandidate>{
                if (widget.preset != null) widget.preset!,
                ..._candidates,
              })
                RadioListTile<AccessCandidate>(
                  contentPadding: EdgeInsets.zero,
                  value: c,
                  groupValue: sel,
                  onChanged: (AccessCandidate? v) => setState(() {
                    _selected = v;
                    _onlyThisClinic = v?.clinicId != null;
                  }),
                  title: Text(c.professionalName),
                  subtitle: Text(
                    <String>[
                      if ((c.specialty ?? '').isNotEmpty) c.specialty!,
                      if (c.clinicId != null)
                        (c.clinicName ?? '').isEmpty
                            ? 'Clínica da consulta'
                            : c.clinicName!,
                    ].join(' · '),
                  ),
                ),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('child-access-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Ou busque pelo e-mail do profissional',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Buscar',
                  onPressed: _lookup,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            if (sel != null && !_candidates.contains(sel) && sel != widget.preset)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Selecionado: ${sel.professionalName}'
                  '${(sel.specialty ?? '').isEmpty ? '' : ' · ${sel.specialty}'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (sel?.clinicId != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _onlyThisClinic,
                onChanged: (bool v) => setState(() => _onlyThisClinic = v),
                title: Text(
                  'Somente na clínica ${sel?.clinicName ?? 'da consulta'}',
                ),
                subtitle: const Text(
                  'Fora dessa clínica o profissional não usa esta autorização.',
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text('2. O que compartilhar', style: theme.textTheme.titleSmall),
            for (final ChildAccessLevel l in ChildAccessLevel.values)
              RadioListTile<ChildAccessLevel>(
                key: Key('child-access-level-${l.name}'),
                contentPadding: EdgeInsets.zero,
                value: l,
                groupValue: _level,
                onChanged: (ChildAccessLevel? v) =>
                    setState(() => _level = v ?? _level),
                title: Text(l.label),
                subtitle: Text('Permite: ${l.allows}\nNão permite: ${l.denies}'),
                isThreeLine: true,
              ),
            const SizedBox(height: AppSpacing.md),
            Text('3. Validade', style: theme.textTheme.titleSmall),
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
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('child-access-submit'),
              onPressed: sel == null || _saving ? null : _confirm,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Salvando...' : 'Revisar e autorizar'),
            ),
          ],
        ),
      ),
    );
  }
}
