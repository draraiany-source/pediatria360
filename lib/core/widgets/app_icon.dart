import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Icone premium com fallback Material se o asset faltar.
class AppIcon extends StatelessWidget {
  const AppIcon({
    required this.asset,
    super.key,
    this.size = 24,
    this.fallback,
    this.color,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final IconData? fallback;
  final Color? color;
  final BoxFit fit;

  /// Tamanhos padronizados do design system.
  static const double nav = 26;
  static const double card = 40;
  static const double quick = 56;
  static const double dashboard = 64;
  static const double empty = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Icon(
            fallback ?? Icons.medical_services_outlined,
            size: size * 0.72,
            color: color ?? AppColors.brand,
          );
        },
      ),
    );
  }
}
