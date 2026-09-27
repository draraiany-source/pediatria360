import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

/// Mostrada quando o perfil atual tenta abrir um modulo de outro perfil
/// (por exemplo digitando o endereco direto).
class DemoRestrictedScreen extends StatelessWidget {
  const DemoRestrictedScreen({required this.module, super.key, this.title});

  final DemoModule module;

  /// Nome exibido quando a area bloqueada e uma subtela (ex.: Prontuario).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final String profile = demoSession.profile?.label ?? 'este perfil';
    final String name = title ?? module.label;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.softBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 32, color: AppColors.brand),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Acesso restrito',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$name não faz parte da área de $profile.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                const DemoNotice(
                  icon: Icons.shield_outlined,
                  text: 'No app real o bloqueio acontece no roteador e nas '
                      'regras do Firebase, não só escondendo o botão. Aqui é '
                      'apenas uma ilustração.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () => context.go('/inicio'),
                      child: const Text('Ir para o início'),
                    ),
                    OutlinedButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Trocar perfil'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
