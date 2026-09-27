import 'package:flutter/material.dart';

import '../../core/config/capi_pose.dart';
import '../../core/error/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/capi_illustration.dart';
import '../../core/widgets/state_views.dart';
import '../demo_session.dart';

/// Faixa fixa no topo de todas as telas: deixa claro que e demonstracao.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.honey,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => showDemoInfo(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.science_outlined,
                    size: 16, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'DEMONSTRAÇÃO - dados fictícios, nada é salvo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                  ),
                ),
                Text(
                  'Saiba mais',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.navy,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showDemoInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.science_outlined, color: AppColors.brand),
      title: const Text('Sobre esta demonstração'),
      content: const SingleChildScrollView(
        child: Text(
          'Esta versão existe para avaliar navegação e design.\n\n'
          '- Todos os nomes, datas e valores são fictícios.\n'
          '- Não há login, Firebase, prontuários reais, pagamentos ou IA.\n'
          '- O que você cadastrar fica só nesta aba e some ao recarregar.\n'
          '- A troca de perfil aqui é livre; no app real cada pessoa entra '
          'com a própria conta e as permissões são verificadas no servidor.\n'
          '- Funções marcadas como "simulado" ou "indisponível" não devem '
          'ser consideradas operacionais.',
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

/// Aviso para acoes que so existem de verdade na versao autenticada.
class DemoNotice extends StatelessWidget {
  const DemoNotice({
    required this.text,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.brand,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta curta "SIMULADO" / "INDISPONIVEL" ao lado de titulos.
class DemoTag extends StatelessWidget {
  const DemoTag(this.label, {super.key, this.color = AppColors.warning});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

void showDemoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Carregamento simulado com estado de erro opcional.
///
/// Da ao avaliador a chance de ver carregamento, vazio e falha de conexao
/// sem depender de rede: o atraso e local e a falha vem do interruptor
/// "Simular falha de conexao" no perfil.
class DemoLoader extends StatefulWidget {
  const DemoLoader({required this.builder, super.key, this.label});

  final WidgetBuilder builder;
  final String? label;

  @override
  State<DemoLoader> createState() => _DemoLoaderState();
}

class _DemoLoaderState extends State<DemoLoader> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (demoSession.simulateOffline) {
      throw const NetworkFailure(
        'Falha de conexão simulada. Desligue a simulação no Perfil '
        'e toque em Recarregar.',
      );
    }
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<void> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return LoadingState(label: widget.label ?? 'Carregando...');
        }
        if (snap.hasError) {
          final Object e = snap.error!;
          return ErrorState(
            failure: e is Failure ? e : const NetworkFailure(),
            onRetry: _retry,
          );
        }
        return widget.builder(context);
      },
    );
  }
}

/// Estado vazio com o Capi — so em vazio/boas-vindas, nunca sobre dado.
class DemoEmpty extends StatelessWidget {
  const DemoEmpty({
    required this.title,
    required this.message,
    super.key,
    this.pose = CapiPose.lupa,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final CapiPose pose;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CapiIllustration(pose: pose, size: 140),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Largura maxima do conteudo em telas grandes (navegador no computador).
class DemoContent extends StatelessWidget {
  const DemoContent({required this.child, super.key, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Cabecalho de secao simples, alinhado ao design system.
class DemoSectionTitle extends StatelessWidget {
  const DemoSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Formatacao simples pt-BR sem depender de locale carregado.
String demoDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String demoTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String demoMoney(double v) {
  final String fixed = v.toStringAsFixed(2);
  final List<String> parts = fixed.split('.');
  final String intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (Match m) => '${m[1]}.',
  );
  return 'R\$ $intPart,${parts[1]}';
}
