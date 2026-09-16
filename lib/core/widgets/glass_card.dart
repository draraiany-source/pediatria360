import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Superficie de vidro (glassmorphism).
///
/// Usada nas camadas que flutuam sobre conteudo: barra de navegacao, cabecalho
/// do perfil da crianca e o painel de resumo da IA. Nao e usada em cartoes de
/// leitura longa — texto clinico precisa de fundo opaco.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = AppSpacing.card,
    this.borderRadius = AppRadius.lgAll,
    this.blur = 18,
    this.onTap,
    this.gradient,
    this.showBorder = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill =
        isDark ? AppColors.glassDarkFill : AppColors.glassLightFill;
    final Color border =
        isDark ? AppColors.glassDarkBorder : AppColors.glassLightBorder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? fill : null,
            gradient: gradient,
            borderRadius: borderRadius,
            border: showBorder ? Border.all(color: border) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fundo ambiente com dois halos suaves. Fica atras dos cartoes de vidro para
/// que o desfoque tenha o que desfocar.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.ambientDark : AppColors.ambientLight,
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            right: -80,
            child: _Halo(
              color: AppColors.petrolSoft.withValues(alpha: isDark ? 0.28 : 0.35),
              size: 320,
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Halo(
              color: AppColors.raspberry.withValues(alpha: isDark ? 0.18 : 0.22),
              size: 360,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
