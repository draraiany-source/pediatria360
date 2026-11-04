import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';

enum _LeaveChoice { save, discard, stay }

/// Sair de um formulário com alterações pendentes pergunta antes: salvar,
/// descartar ou continuar editando. Cobre o voltar do sistema e do AppBar;
/// botões próprios de fechar devem chamar [leaveWithConfirmation].
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    required this.isDirty,
    required this.child,
    this.onSave,
    super.key,
  });

  final bool Function() isDirty;

  /// Salva e conclui a saída. Sem ele, só há descartar ou continuar.
  final Future<void> Function()? onSave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) return;
        leaveWithConfirmation(context, dirty: isDirty(), onSave: onSave);
      },
      child: child,
    );
  }
}

Future<void> leaveWithConfirmation(
  BuildContext context, {
  required bool dirty,
  Future<void> Function()? onSave,
}) async {
  if (dirty) {
    final _LeaveChoice? choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'Há alterações que ainda não foram salvas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.stay),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.discard),
            child: const Text('Descartar'),
          ),
          if (onSave != null)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(_LeaveChoice.save),
              child: const Text('Salvar'),
            ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _LeaveChoice.save:
        await onSave!();
        return;
      case _LeaveChoice.discard:
        break;
      case _LeaveChoice.stay:
      case null:
        return;
    }
  }
  if (!context.mounted) return;
  final NavigatorState nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    context.go(Routes.homePath);
  }
}
