import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';

extension PopOrHome on BuildContext {
  /// Volta se houver pagina anterior; senao vai ao inicio.
  ///
  /// Telas abertas por link direto, notificacao ou `go` podem ser a unica
  /// pagina da pilha, e `pop` ali deixaria o usuario sem saida.
  void popOrHome() {
    if (canPop()) {
      pop();
    } else {
      go(Routes.homePath);
    }
  }
}

/// Botao de voltar para telas fora do shell.
class BackOrHomeButton extends StatelessWidget {
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: context.popOrHome,
    );
  }
}
