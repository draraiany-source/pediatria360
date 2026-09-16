import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Botao primario com estado de carregamento embutido.
///
/// Enquanto [isLoading] for `true` o botao fica desabilitado — evita duplo
/// envio de formulario, um bug classico em cadastro de prontuario.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    this.variant = AppButtonVariant.primary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final VoidCallback? effectiveOnPressed = isLoading ? null : onPressed;

    final Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.primary
                  ? scheme.onPrimary
                  : scheme.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
      AppButtonVariant.secondary => FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
          ),
          child: content,
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: content,
        ),
      AppButtonVariant.danger => FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
          ),
          child: content,
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum AppButtonVariant { primary, secondary, outline, text, danger }

/// Campo de texto padrao do app.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final List<String>? autofillHints;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: _obscured ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      textCapitalization: widget.textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                tooltip: _obscured ? 'Mostrar senha' : 'Ocultar senha',
              )
            : widget.suffix,
      ),
    );
  }
}

/// Cabecalho de secao com etiqueta (eyebrow) e acao opcional.
///
/// A etiqueta classifica o bloco (ex.: `PROTOCOLO`, `CURVA OMS`) — carrega
/// informacao, nao enfeite.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: AppTypography.eyebrow(theme.colorScheme.primary),
                  ),
                if (eyebrow != null) const SizedBox(height: AppSpacing.xs),
                Text(title, style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Etiqueta compacta (categoria, nivel, faixa etaria).
class AppTag extends StatelessWidget {
  const AppTag({
    required this.label,
    this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effective = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: effective.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: effective),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: effective,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Valor clinico com unidade — usa a face monoespacada para manter os numeros
/// alinhados entre linhas de uma tabela de doses.
class DataValue extends StatelessWidget {
  const DataValue({
    required this.value,
    this.unit,
    this.size = 22,
    this.color,
    super.key,
  });

  final String value;
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color effective = color ?? theme.colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          value,
          style: AppTypography.data(
            effective,
            size: size,
            weight: FontWeight.w700,
          ),
        ),
        if (unit != null) ...<Widget>[
          // Gap fino entre o valor e a unidade (ex.: "72" + "cm") — kerning
          // tipográfico, não espaçamento entre blocos de conteúdo.
          const SizedBox(width: 3),
          Text(
            unit!,
            style: AppTypography.data(
              effective.withValues(alpha: 0.65),
              size: size * 0.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Cartão de módulo/funcionalidade — ícone, título, subtítulo opcional,
/// indicador de status opcional. Padrão único de tamanho, padding e raio
/// em todo lugar que usar isto, em vez de cada tela inventar o próprio.
///
/// ## Origem
///
/// Extraído de um widget que já existia, funcionando bem, mas preso como
/// privado dentro de `home_screen.dart` — só a Home conseguia usar. Mesmo
/// visual, mesmo comportamento; a mudança é só ficar público e ganhar o
/// slot de indicador que a Home não precisava mas outras telas (Caderneta,
/// Agenda) podem.
///
/// ## Sobre o ícone dimensional
///
/// `asset` é opcional e espera um SVG (os 10 módulos em
/// `assets/icons/modules/`). Sem `asset`, cai no `icon` do Material — e o
/// mesmo acontece se o arquivo do asset faltar em tempo de execução
/// (`placeholderBuilder`), para nunca deixar um vazio no lugar do ícone.
/// Ícone dimensional só faz sentido em cartão grande como este — numa
/// lista clínica densa (16–24px) o volume vira borrão, por isso não é o
/// widget certo para linha de lista, só para entrada de módulo.
class ModuleCard extends StatelessWidget {
  const ModuleCard({
    required this.title,
    required this.color,
    this.subtitle,
    this.icon = Icons.widgets_outlined,
    this.asset,
    this.badge,
    this.onTap,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Caminho do SVG dimensional, ex.: `assets/icons/modules/growth.svg`.
  final String? asset;

  final Color color;

  /// Selo pequeno no canto — contagem, "novo", estado. Só aparece se
  /// fornecido; a maioria dos módulos não precisa de um.
  final Widget? badge;

  final VoidCallback? onTap;

  /// `false` mostra o cartão apagado e desabilita o toque — para módulo
  /// que existe mas ainda não está disponível, sem escondê-lo da visão
  /// geral do produto.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double opacity = enabled ? 1.0 : 0.5;
    final Color borderColor = isDark
        ? AppColors.violet.withValues(alpha: 0.22)
        : theme.colorScheme.outline.withValues(alpha: 0.55);

    return Opacity(
      opacity: opacity,
      child: Material(
        color: isDark ? AppColors.darkSurface : theme.colorScheme.surface,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: borderColor),
              gradient: isDark ? AppColors.cardGlow : null,
              boxShadow: isDark ? AppShadows.card : AppShadows.soft,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: asset == null
                            ? Icon(icon, color: color, size: 22)
                            : SvgPicture.asset(
                                asset!,
                                width: 28,
                                height: 28,
                                placeholderBuilder: (BuildContext context) =>
                                    Icon(icon, color: color, size: 22),
                              ),
                      ),
                      if (badge != null) badge!,
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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

/// Banner informativo — ícone, cor semântica, texto. Extraído de
/// `child_detail_screen.dart` (onde vivia como `_InfoBanner`, privado)
/// porque `patient_timeline_screen.dart` precisava do mesmo padrão visual
/// para alerta de alergia, e duplicar de novo seria repetir o problema que
/// a extração do `ModuleCard` já resolveu uma vez.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
