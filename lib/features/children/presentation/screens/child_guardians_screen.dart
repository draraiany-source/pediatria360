import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/child.dart';
import '../../domain/child_guardian.dart';
import '../providers/guardians_providers.dart';

/// Gestao de responsaveis vinculados ao cadastro unico da crianca.
class ChildGuardiansScreen extends ConsumerStatefulWidget {
  const ChildGuardiansScreen({required this.child, super.key});

  final Child child;

  @override
  ConsumerState<ChildGuardiansScreen> createState() =>
      _ChildGuardiansScreenState();
}

class _ChildGuardiansScreenState extends ConsumerState<ChildGuardiansScreen> {
  Future<void> _openEditor({ChildGuardianLink? existing}) async {
    final ChildGuardianLink? saved = await showModalBottomSheet<ChildGuardianLink>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _GuardianEditorSheet(
        child: widget.child,
        existing: existing,
      ),
    );
    if (saved == null || !mounted) return;
    final Result<void> result =
        await ref.read(childGuardiansControllerProvider.notifier).upsert(saved);
    if (!mounted) return;
    result.fold(
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Responsavel salvo.')),
      ),
      (Failure f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChildGuardianLink>> async = ref.watch(
      childGuardiansProvider(
        (ownerId: widget.child.ownerId, childId: widget.child.id),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Responsaveis')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Vincular'),
      ),
      body: async.when(
        loading: () => const LoadingState(label: 'Carregando responsaveis...'),
        error: (Object e, StackTrace st) => ErrorState(
          failure: e is Failure
              ? e
              : ServerFailure(e.toString()),
          onRetry: () => ref.invalidate(
            childGuardiansProvider(
              (ownerId: widget.child.ownerId, childId: widget.child.id),
            ),
          ),
        ),
        data: (List<ChildGuardianLink> links) {
          if (links.isEmpty) {
            return EmptyState(
              icon: Icons.family_restroom_outlined,
              title: 'Nenhum responsavel vinculado',
              message:
                  'Vincule mae, pai ou tutor com permissoes explicitas. '
                  'Sem autorizacao ativa, o acesso permanece pendente.',
              actionLabel: 'Vincular responsavel',
              onAction: () => _openEditor(),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: links.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              final ChildGuardianLink link = links[i];
              final bool pending = link.isPendingAuthorization;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: pending
                        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.4)
                        : Theme.of(context).dividerColor,
                  ),
                ),
                title: Text(
                  link.displayName.isEmpty ? link.email : link.displayName,
                ),
                subtitle: Text(
                  '${link.relationship.label} · ${link.status.label}'
                  '${pending ? ' · pendente de autorizacao' : ''}\n'
                  'Ver dados: ${link.canViewData ? 'sim' : 'nao'} · '
                  'Docs: ${link.canSendDocuments ? 'sim' : 'nao'} · '
                  'Solicitacoes: ${link.canMakeRequests ? 'sim' : 'nao'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (String v) async {
                    if (v == 'edit') {
                      await _openEditor(existing: link);
                    } else if (v == 'revoke') {
                      final Result<void> r = await ref
                          .read(childGuardiansControllerProvider.notifier)
                          .revoke(
                            ownerId: widget.child.ownerId,
                            childId: widget.child.id,
                            guardianUid: link.guardianUid,
                          );
                      if (!context.mounted) return;
                      r.fold(
                        (_) {},
                        (Failure f) => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(f.message))),
                      );
                    }
                  },
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'edit', child: Text('Editar')),
                    PopupMenuItem<String>(
                      value: 'revoke',
                      child: Text('Revogar acesso'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _GuardianEditorSheet extends StatefulWidget {
  const _GuardianEditorSheet({required this.child, this.existing});

  final Child child;
  final ChildGuardianLink? existing;

  @override
  State<_GuardianEditorSheet> createState() => _GuardianEditorSheetState();
}

class _GuardianEditorSheetState extends State<_GuardianEditorSheet> {
  late final TextEditingController _uid;
  late final TextEditingController _name;
  late final TextEditingController _email;
  GuardianRelationship _relationship = GuardianRelationship.other;
  GuardianAuthStatus _status = GuardianAuthStatus.pending;
  bool _view = false;
  bool _docs = false;
  bool _requests = false;

  @override
  void initState() {
    super.initState();
    final ChildGuardianLink? e = widget.existing;
    _uid = TextEditingController(text: e?.guardianUid ?? '');
    _name = TextEditingController(text: e?.displayName ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    if (e != null) {
      _relationship = e.relationship;
      _status = e.status;
      _view = e.canViewData;
      _docs = e.canSendDocuments;
      _requests = e.canMakeRequests;
    }
  }

  @override
  void dispose() {
    _uid.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets pad = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + pad.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.existing == null
                  ? 'Vincular responsavel'
                  : 'Editar permissoes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _uid,
              enabled: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'UID do responsavel (Firebase Auth)',
                helperText:
                    'Use o UID da conta ja cadastrada. Evita duplicar pessoas.',
              ),
            ),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            DropdownButtonFormField<GuardianRelationship>(
              value: _relationship,
              items: GuardianRelationship.values
                  .map(
                    (GuardianRelationship r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label),
                    ),
                  )
                  .toList(),
              onChanged: (GuardianRelationship? v) {
                if (v != null) setState(() => _relationship = v);
              },
              decoration: const InputDecoration(labelText: 'Vinculo'),
            ),
            DropdownButtonFormField<GuardianAuthStatus>(
              value: _status,
              items: GuardianAuthStatus.values
                  .map(
                    (GuardianAuthStatus s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    ),
                  )
                  .toList(),
              onChanged: (GuardianAuthStatus? v) {
                if (v != null) setState(() => _status = v);
              },
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            SwitchListTile(
              title: const Text('Pode ver dados da crianca'),
              value: _view,
              onChanged: (bool v) => setState(() => _view = v),
            ),
            SwitchListTile(
              title: const Text('Pode enviar documentos'),
              value: _docs,
              onChanged: (bool v) => setState(() => _docs = v),
            ),
            SwitchListTile(
              title: const Text('Pode realizar solicitacoes'),
              value: _requests,
              onChanged: (bool v) => setState(() => _requests = v),
            ),
            if (_status == GuardianAuthStatus.active &&
                !_view &&
                !_docs &&
                !_requests)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Ativo sem permissoes: a equipe deve concluir a autorizacao '
                  'antes de liberar o acesso.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: () {
                final String uid = _uid.text.trim();
                if (uid.isEmpty) return;
                Navigator.of(context).pop(
                  ChildGuardianLink(
                    guardianUid: uid,
                    ownerId: widget.child.ownerId,
                    childId: widget.child.id,
                    relationship: _relationship,
                    status: _status,
                    createdAt: widget.existing?.createdAt ??
                        DateTime.now().toUtc(),
                    displayName: _name.text.trim(),
                    email: _email.text.trim(),
                    canViewData: _view,
                    canSendDocuments: _docs,
                    canMakeRequests: _requests,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
