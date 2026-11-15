import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/capi_illustration.dart';
import '../../core/widgets/clinical_ui.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

/// Porta de entrada da demonstracao: escolha de perfil, sem login.
class DemoWelcomeScreen extends StatelessWidget {
  const DemoWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: <Widget>[
          const DemoBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: DemoContent(
                maxWidth: 880,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: AppRadius.xlAll,
                      ),
                      child: Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CapiIllustration(
                            pose: CapiPose.aceno,
                            size: wide ? 150 : 120,
                          ),
                          SizedBox(
                            width: wide ? AppSpacing.xl : 0,
                            height: wide ? 0 : AppSpacing.md,
                          ),
                          _HeroText(
                            wide: wide,
                            child: Column(
                              crossAxisAlignment: wide
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Pediatria 360',
                                  textAlign:
                                      wide ? TextAlign.start : TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Demonstração para avaliar navegação e '
                                  'design. Escolha um perfil para ver o app '
                                  'como cada pessoa o veria.',
                                  textAlign:
                                      wide ? TextAlign.start : TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const DemoNotice(
                      icon: Icons.lock_outline_rounded,
                      text: 'Sem login e sem conexão com o Firebase: todos os '
                          'dados são fictícios e ficam só nesta aba. O app '
                          'real continua exigindo conta própria para cada '
                          'perfil.',
                    ),
                    const DemoSectionTitle('Entrar como'),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints c) {
                        final int columns = c.maxWidth >= 720 ? 2 : 1;
                        const double gap = AppSpacing.md;
                        final double w =
                            (c.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: <Widget>[
                            for (final DemoProfile p in DemoProfile.values)
                              SizedBox(
                                width: w,
                                child: _ProfileCard(profile: p),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto do cartao: ocupa o resto da linha no computador; no celular a
/// coluna nao tem altura limitada, entao nao pode usar Flexible.
class _HeroText extends StatelessWidget {
  const _HeroText({required this.wide, required this.child});

  final bool wide;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      wide ? Expanded(child: child) : child;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Entrar como ${profile.label}',
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        onTap: () {
          demoSession.enter(profile);
          context.go('/inicio');
        },
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(profile.icon, color: AppColors.brand),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}
