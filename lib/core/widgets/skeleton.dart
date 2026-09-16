import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_tokens.dart';

/// Bloco base do skeleton loading.
class Skeleton extends StatelessWidget {
  const Skeleton({
    this.width = double.infinity,
    this.height = 16,
    this.radius = AppRadius.smAll,
    super.key,
  });

  /// Linha de texto.
  const Skeleton.line({double width = double.infinity, Key? key})
      : this(width: width, height: 14, key: key);

  /// Circulo (avatares).
  const Skeleton.circle({double size = 48, Key? key})
      : this(
          width: size,
          height: size,
          radius: AppRadius.pillAll,
          key: key,
        );

  final double width;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: scheme.surfaceContainerHighest,
      highlightColor: scheme.surface,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: radius,
        ),
      ),
    );
  }
}

/// Skeleton de um cartao de conteudo (artigo, protocolo, aula).
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.height = 96, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Skeleton(width: height, height: height, radius: AppRadius.mdAll),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Skeleton(height: 18),
                const SizedBox(height: AppSpacing.sm),
                const Skeleton(height: 14, width: 220),
                const SizedBox(height: AppSpacing.sm),
                Skeleton(height: 14, width: height * 1.4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de skeletons — usada enquanto a primeira pagina carrega.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 6, this.itemHeight = 96, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: AppSpacing.screen,
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) =>
          SkeletonCard(height: itemHeight),
    );
  }
}
