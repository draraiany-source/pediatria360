import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/glass_card.dart';

/// Tela de abertura enquanto a autenticação é resolvida.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: AmbientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SvgPicture.asset(
                AppAssets.iconLogo,
                width: 96,
                height: 96,
              )
                  .animate()
                  .fadeIn(duration: AppMotion.slow, curve: AppMotion.enter)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    end: const Offset(1, 1),
                    duration: AppMotion.slow,
                    curve: AppMotion.enter,
                  ),
              const SizedBox(height: AppSpacing.xl),
              Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: 'Pediatria',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '360',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: AppMotion.fast).fadeIn(duration: AppMotion.slow),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Cuidado integral, cada fase importa',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkMuted,
                ),
              )
                  .animate(delay: AppMotion.normal)
                  .fadeIn(duration: AppMotion.slow),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: AppRadius.pillAll,
                  color: AppColors.brand,
                  backgroundColor: AppColors.softBlue,
                ),
              ).animate(delay: AppMotion.normal).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
