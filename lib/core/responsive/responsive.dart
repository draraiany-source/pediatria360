import 'package:flutter/widgets.dart';

/// Classes de tamanho de tela.
enum ScreenSize { compact, medium, expanded, large }

/// Pontos de quebra alinhados ao Material 3.
class Breakpoints {
  const Breakpoints._();

  static const double medium = 600; // tablet retrato
  static const double expanded = 900; // tablet paisagem
  static const double large = 1280; // desktop / web

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) {
    if (width >= large) return ScreenSize.large;
    if (width >= expanded) return ScreenSize.expanded;
    if (width >= medium) return ScreenSize.medium;
    return ScreenSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize => Breakpoints.of(this);

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isTablet =>
      screenSize == ScreenSize.medium || screenSize == ScreenSize.expanded;
  bool get isDesktop => screenSize == ScreenSize.large;

  /// `true` quando a navegacao deve usar rail/drawer em vez de barra inferior.
  bool get usesRail => screenSize != ScreenSize.compact;

  /// Escolhe um valor por classe de tamanho, com fallback em cascata.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) =>
      switch (screenSize) {
        ScreenSize.compact => compact,
        ScreenSize.medium => medium ?? compact,
        ScreenSize.expanded => expanded ?? medium ?? compact,
        ScreenSize.large => large ?? expanded ?? medium ?? compact,
      };

  /// Numero de colunas sugerido para grades de conteudo.
  int get gridColumns => responsive<int>(
        compact: 1,
        medium: 2,
        expanded: 3,
        large: 4,
      );

  /// Largura maxima de leitura confortavel (evita linhas longas na web).
  double get contentMaxWidth => responsive<double>(
        compact: double.infinity,
        medium: 720,
        expanded: 900,
        large: 1120,
      );
}

/// Centraliza o conteudo e limita a largura em telas grandes.
class ContentBounds extends StatelessWidget {
  const ContentBounds({
    required this.child,
    this.maxWidth,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.contentMaxWidth,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Renderiza layouts diferentes por classe de tamanho, sem duplicar estado.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    this.large,
    super.key,
  });

  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;
  final WidgetBuilder? large;

  @override
  Widget build(BuildContext context) {
    final WidgetBuilder builder = context.responsive<WidgetBuilder>(
      compact: compact,
      medium: medium,
      expanded: expanded,
      large: large,
    );
    return builder(context);
  }
}
