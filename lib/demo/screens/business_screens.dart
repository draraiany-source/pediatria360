import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/capi_pose.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/demo_widgets.dart';

/// Biblioteca: lista filtravel de conteudos ilustrativos.
class DemoLibraryScreen extends StatefulWidget {
  const DemoLibraryScreen({super.key});

  @override
  State<DemoLibraryScreen> createState() => _DemoLibraryScreenState();
}

class _DemoLibraryScreenState extends State<DemoLibraryScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final List<DemoArticle> all = demoSession.articles;
    final List<String> categories = all
        .map((DemoArticle a) => a.category)
        .toSet()
        .toList();
    final List<DemoArticle> list = _category == null
        ? all
        : all.where((DemoArticle a) => a.category == _category).toList();
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(title: const Text('Biblioteca')),
      body: DemoLoader(
        label: 'Carregando conteúdos...',
        builder: (BuildContext context) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                      for (final String c in categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int columns = c.maxWidth >= 700 ? 2 : 1;
                      const double gap = AppSpacing.md;
                      final double w =
                          (c.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          for (final DemoArticle a in list)
                            SizedBox(
                              width: w,
                              child: PremiumCard(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                onTap: () => context.go('/biblioteca/${a.id}'),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.moduleLibrary
                                            .withValues(alpha: 0.12),
                                        borderRadius: AppRadius.mdAll,
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_outlined,
                                        color: AppColors.moduleLibrary,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            a.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            '${a.category} - ${a.minutes} min',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoArticleScreen extends StatelessWidget {
  const DemoArticleScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context) {
    final DemoArticle? a = demoSession.articles
        .where((DemoArticle x) => x.id == articleId)
        .firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conteúdo')),
        body: DemoEmpty(
          title: 'Conteúdo não encontrado',
          message: 'Volte para a biblioteca.',
          actionLabel: 'Biblioteca',
          onAction: () => context.go('/biblioteca'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(a.category)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          DemoContent(
            maxWidth: 680,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  a.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${a.minutes} min de leitura',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                const DemoNotice(
                  text:
                      'Texto ilustrativo. Os conteúdos reais passam por '
                      'revisão profissional antes de publicados.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(a.summary, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Parágrafo de exemplo para avaliar tipografia, largura de '
                  'linha e espaçamento da leitura. Este texto não contém '
                  'orientação de saúde e existe apenas para demonstrar o '
                  'layout da tela de conteúdo no celular e no computador.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Relatorios: graficos simples com numeros ficticios rotulados como tal.
class DemoReportsScreen extends StatelessWidget {
  const DemoReportsScreen({super.key});

  static const List<(String, double)> _weekly = <(String, double)>[
    ('Seg', 6),
    ('Ter', 9),
    ('Qua', 4),
    ('Qui', 8),
    ('Sex', 7),
  ];

  @override
  Widget build(BuildContext context) {
    final int total = _weekly
        .fold<double>(0, (double s, (String, double) e) => s + e.$2)
        .round();
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Relatórios'),
        automaticallyImplyLeading: false,
      ),
      body: DemoLoader(
        label: 'Calculando indicadores...',
        builder: (BuildContext context) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoNotice(
                    icon: Icons.science_outlined,
                    color: AppColors.warning,
                    text:
                        'Todos os números desta tela são fictícios, apenas '
                        'para avaliar o layout dos gráficos.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: MetricCard(
                          label: 'Atendimentos na semana',
                          value: '$total',
                          icon: Icons.event_available_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      const Expanded(
                        child: MetricCard(
                          label: 'Faltas',
                          value: '2',
                          icon: Icons.event_busy_outlined,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const DemoSectionTitle('Atendimentos por dia (fictício)'),
                  const PremiumCard(
                    child: SizedBox(
                      height: 200,
                      child: _BarChart(values: _weekly),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => showDemoSnack(
                      context,
                      'Exportação só pode ser testada na versão autenticada.',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Exportar relatório'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});

  final List<(String, double)> values;

  @override
  Widget build(BuildContext context) {
    final double max = values
        .map(((String, double) e) => e.$2)
        .reduce((double a, double b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final (String, double) v in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    v.$2.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: v.$2 / max,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.warmGradient,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(v.$1, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Financeiro: lancamentos ficticios, pagamentos desativados.
class DemoFinanceScreen extends StatefulWidget {
  const DemoFinanceScreen({super.key});

  @override
  State<DemoFinanceScreen> createState() => _DemoFinanceScreenState();
}

class _DemoFinanceScreenState extends State<DemoFinanceScreen> {
  DemoInvoiceStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final List<DemoInvoice> all = demoSession.invoices;
    final List<DemoInvoice> list = _filter == null
        ? all
        : all.where((DemoInvoice i) => i.status == _filter).toList();
    double sum(DemoInvoiceStatus s) => all
        .where((DemoInvoice i) => i.status == s)
        .fold<double>(0, (double t, DemoInvoice i) => t + i.amount);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Financeiro'),
        automaticallyImplyLeading: false,
      ),
      body: DemoLoader(
        label: 'Carregando lançamentos...',
        builder: (BuildContext context) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            DemoContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const DemoNotice(
                    icon: Icons.credit_card_off_outlined,
                    color: AppColors.danger,
                    text:
                        'Valores fictícios. Cobrança e pagamento online estão '
                        'INDISPONÍVEIS nesta demonstração e desativados no '
                        'app real.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int columns = c.maxWidth >= 600 ? 3 : 1;
                      const double gap = AppSpacing.md;
                      final double w =
                          (c.maxWidth - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: <Widget>[
                          SizedBox(
                            width: w,
                            child: MetricCard(
                              label: 'Recebido',
                              value: demoMoney(sum(DemoInvoiceStatus.pago)),
                              icon: Icons.check_circle_outline,
                              color: AppColors.tealDeep,
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: MetricCard(
                              label: 'A receber',
                              value: demoMoney(sum(DemoInvoiceStatus.aberto)),
                              icon: Icons.schedule_rounded,
                              color: AppColors.brand,
                            ),
                          ),
                          SizedBox(
                            width: w,
                            child: MetricCard(
                              label: 'Em atraso',
                              value: demoMoney(sum(DemoInvoiceStatus.atrasado)),
                              icon: Icons.error_outline_rounded,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const DemoSectionTitle('Lançamentos'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final DemoInvoiceStatus s
                          in DemoInvoiceStatus.values)
                        ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: _filter == s,
                          onSelected: (_) => setState(() => _filter = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (list.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: DemoEmpty(
                        title: 'Nada por aqui',
                        message: 'Nenhum lançamento com este filtro.',
                        pose: CapiPose.lupa,
                      ),
                    )
                  else
                    for (final DemoInvoice i in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          onTap: () => _openInvoice(context, i),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      i.description,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    Text(
                                      'Vencimento ${demoDate(i.due)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    demoMoney(i.amount),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  ClinicalBadge(
                                    label: _statusLabel(i.status),
                                    color: _statusColor(i.status),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoice(BuildContext context, DemoInvoice i) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                i.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('${demoMoney(i.amount)} - vence ${demoDate(i.due)}'),
              const SizedBox(height: AppSpacing.lg),
              const FilledButton(
                onPressed: null,
                child: Text('Cobrar online (indisponível)'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(DemoInvoiceStatus s) => switch (s) {
    DemoInvoiceStatus.aberto => 'Em aberto',
    DemoInvoiceStatus.pago => 'Pago',
    DemoInvoiceStatus.atrasado => 'Atrasado',
  };

  static Color _statusColor(DemoInvoiceStatus s) => switch (s) {
    DemoInvoiceStatus.aberto => AppColors.brand,
    DemoInvoiceStatus.pago => AppColors.tealDeep,
    DemoInvoiceStatus.atrasado => AppColors.danger,
  };
}

/// Perfil da sessao de demonstracao: troca de perfil, sair, simulacoes.
class DemoProfileScreen extends StatelessWidget {
  const DemoProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoProfile? profile = demoSession.profile;
        if (profile == null) return const SizedBox.shrink();
        final bool brand = demoSession.canBrand;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            title: const Text('Perfil'),
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PremiumCard(
                      child: Row(
                        children: <Widget>[
                          PersonAvatar(
                            name: brand
                                ? demoSession.account.name
                                : 'Usuário Demonstração',
                            seed: brand ? demoSession.account.id : profile.name,
                            radius: 28,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  brand
                                      ? demoSession.account.name
                                      : 'Usuário Demonstração',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  brand
                                      ? '${profile.label} · ${demoSession.account.clinic}'
                                      : profile.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  brand
                                      ? demoSession.account.email
                                      : 'demo@exemplo.invalid',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (brand) ...<Widget>[
                      const DemoSectionTitle('Identidade da clínica'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: const ValueKey<String>('perfil-logomarca'),
                          leading: SizedBox(
                            width: 72,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: DemoBrandMark(
                                logo: demoSession.myLogo,
                                height: 32,
                              ),
                            ),
                          ),
                          title: const Text(
                            'Logomarca da clínica ou profissional',
                          ),
                          subtitle: Text(
                            demoSession.myLogo == null
                                ? 'Não cadastrada: usando a identidade padrão '
                                      'do Pediatria360'
                                : 'Cadastrada: ${demoSession.myLogo!.fileName}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.go('/perfil/logomarca'),
                        ),
                      ),
                    ],
                    const DemoSectionTitle('Conta'),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: <Widget>[
                          if (brand) ...<Widget>[
                            ListTile(
                              key: const ValueKey<String>('trocar-conta'),
                              leading: const Icon(
                                Icons.manage_accounts_outlined,
                              ),
                              title: const Text(
                                'Trocar de conta (demonstração)',
                              ),
                              subtitle: Text(
                                'Em uso: ${demoSession.account.name}',
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _switchAccount(context),
                            ),
                            const Divider(height: 1),
                          ],
                          ListTile(
                            leading: const Icon(Icons.switch_account_outlined),
                            title: const Text('Trocar perfil'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.go('/'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('Privacidade e termos'),
                            subtitle: const Text(
                              'Disponível na versão autenticada',
                            ),
                            onTap: () => showDemoSnack(
                              context,
                              'Política e termos ficam no app autenticado.',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.info_outline_rounded),
                            title: const Text('Sobre a demonstração'),
                            onTap: () => showDemoInfo(context),
                          ),
                        ],
                      ),
                    ),
                    const DemoSectionTitle('Testar estados'),
                    Card(
                      margin: EdgeInsets.zero,
                      child: SwitchListTile(
                        secondary: const Icon(Icons.wifi_off_rounded),
                        title: const Text('Simular falha de conexão'),
                        subtitle: const Text(
                          'Listas passam a mostrar a tela de erro com '
                          'botão Recarregar.',
                        ),
                        value: demoSession.simulateOffline,
                        onChanged: demoSession.setSimulateOffline,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _confirmLeave(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sair da demonstração'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchAccount(BuildContext context) async {
    final String? id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'Contas fictícias de profissionais. Cada uma tem a sua '
                  'logomarca, os seus documentos e os seus modelos de receita.',
                ),
              ),
              for (final DemoAccount a in DemoProfessional.accounts)
                ListTile(
                  key: ValueKey<String>('conta-${a.id}'),
                  leading: Icon(
                    a.id == demoSession.account.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppColors.brand,
                  ),
                  title: Text(a.name),
                  subtitle: Text(a.clinic),
                  onTap: () => Navigator.of(sheet).pop(a.id),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
    if (id == null || !context.mounted) return;
    demoSession.switchAccount(id);
    showDemoSnack(context, 'Conta em uso: ${demoSession.account.name}.');
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Sair da demonstração?'),
        content: const Text(
          'Os dados que você adicionou nesta aba serão descartados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      demoSession.leave();
      context.go('/');
    }
  }
}
