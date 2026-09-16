import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/remote_config_service.dart';
import '../../../../core/widgets/state_views.dart';

/// Exibida quando `maintenance_mode` esta ligado no Remote Config.
///
/// A mensagem vem do servidor: a equipe muda o texto sem publicar versao nova.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfigService config = ref.watch(remoteConfigProvider);

    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.construction_rounded,
          title: 'Em manutencao',
          message: config.maintenanceMessage,
          actionLabel: 'Tentar novamente',
          onAction: () async => config.refresh(),
        ),
      ),
    );
  }
}
