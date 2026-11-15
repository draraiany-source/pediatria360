import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/module_flags.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/remote_config_service.dart';

/// Modo sala de espera: so jogos, sem navegacao clinica.
class KidsKioskScreen extends ConsumerWidget {
  const KidsKioskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RemoteConfigService remote = ref.watch(remoteConfigProvider);
    final bool ok = ModuleFlags.kidsKioskEnabled(remote);
    if (!ok) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kids kiosk')),
        body: const Center(
          child: Text(
            'Modo kiosk desligado (kids_kiosk_enabled / KIDS_KIOSK_ENABLED).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text(
                    'Sala de espera — Espaco Kids',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sem prontuarios, sem receitas, sem financeiro. '
                    'Peca a um adulto da clinica para encerrar a sessao.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(Routes.kidsPath),
                    child: const Text('Comecar a brincar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
