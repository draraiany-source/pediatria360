import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/state_views.dart';

/// Rota inexistente. Acontece com deep link antigo ou URL digitada na web.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagina nao encontrada')),
      body: EmptyState(
        icon: Icons.explore_off_rounded,
        title: 'Esse endereco nao existe',
        message:
            'Nao encontramos nada em "$location". O link pode ter '
            'mudado de lugar.',
        actionLabel: 'Ir para o inicio',
        onAction: () => context.go(Routes.homePath),
      ),
    );
  }
}
