import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/branding/brand_logo.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../demo_clinical.dart';

String brandHeaderLabel(BrandLogo? logo) => logo == null
    ? 'Identidade padrão do Pediatria360'
    : 'Logomarca da conta (${logo.fileName}, enviada em '
          '${formatDocDate(logo.uploadedAt)})';

/// Logomarca da conta ou, sem ela, a identidade padrão do Pediatria360.
class DemoBrandMark extends StatelessWidget {
  const DemoBrandMark({this.logo, this.height = 48, super.key});

  final BrandLogo? logo;
  final double height;

  @override
  Widget build(BuildContext context) {
    final BrandLogo? l = logo;
    if (l == null) return _DefaultMark(height: height);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height, maxWidth: height * 3.5),
      child: Image.memory(
        l.bytes,
        key: ValueKey<String>('logo-${l.id}'),
        height: height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        semanticLabel: 'Logomarca da conta',
        errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
            _DefaultMark(height: height),
      ),
    );
  }
}

class _DefaultMark extends StatelessWidget {
  const _DefaultMark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Identidade padrão Pediatria360',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.child_care_rounded,
                color: AppColors.teal,
                size: height * 0.7,
              ),
              const SizedBox(width: 6),
              Text(
                'Pedi360',
                style: TextStyle(
                  fontSize: height * 0.32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identidade da clínica ou profissional no painel.
class DemoClinicPanelCard extends StatelessWidget {
  const DemoClinicPanelCard({
    required this.account,
    required this.logo,
    super.key,
  });

  final DemoAccount account;
  final BrandLogo? logo;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Widget text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          account.clinic,
          style: t.titleMedium?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text('${account.name} - ${account.registry}', style: t.bodySmall),
        if (logo == null)
          Text(
            'Sem logomarca: painel e documentos usam a identidade padrão do '
            'Pediatria360.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
      ],
    );
    final Widget action = OutlinedButton.icon(
      key: const ValueKey<String>('painel-logomarca'),
      onPressed: () => GoRouter.of(context).go('/perfil/logomarca'),
      icon: const Icon(Icons.image_outlined),
      label: Text(logo == null ? 'Cadastrar logomarca' : 'Logomarca'),
    );
    return Semantics(
      container: true,
      label: 'Painel de ${account.clinic}: ${brandHeaderLabel(logo)}',
      child: Container(
        key: const ValueKey<String>('painel-marca'),
        margin: const EdgeInsets.only(top: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.line),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Widget mark = DemoBrandMark(logo: logo, height: 56);
            if (c.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  mark,
                  const SizedBox(height: AppSpacing.sm),
                  text,
                  const SizedBox(height: AppSpacing.sm),
                  action,
                ],
              );
            }
            return Row(
              children: <Widget>[
                mark,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: text),
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Cabeçalho do documento como sai no PDF e na impressão.
class DemoDocHeader extends StatelessWidget {
  const DemoDocHeader({
    required this.account,
    required this.logo,
    required this.kindLabel,
    super.key,
  });

  final DemoAccount account;
  final BrandLogo? logo;
  final String kindLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final Widget info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          account.clinic,
          style: t.titleSmall?.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${account.name} - ${account.registry} - ${account.specialty}',
          style: t.bodySmall,
        ),
        Text(account.address, style: t.bodySmall),
      ],
    );
    final Widget kind = Text(
      kindLabel.toUpperCase(),
      textAlign: TextAlign.end,
      style: t.labelMedium?.copyWith(
        color: AppColors.navy,
        fontWeight: FontWeight.w800,
      ),
    );
    return Semantics(
      container: true,
      label: 'Cabeçalho do documento: ${brandHeaderLabel(logo)}',
      child: Container(
        key: const ValueKey<String>('doc-header'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.line),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            if (c.maxWidth < 460) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DemoBrandMark(logo: logo, height: 44),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: kind),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  info,
                ],
              );
            }
            return Row(
              children: <Widget>[
                DemoBrandMark(logo: logo, height: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: info),
                const SizedBox(width: AppSpacing.sm),
                kind,
              ],
            );
          },
        ),
      ),
    );
  }
}
