import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../auth/presentation/screens/profile_edit_screen.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../clinic_org/presentation/screens/clinic_org_screens.dart';
import '../../finance/domain/finance_models.dart';
import '../../finance/presentation/providers/finance_providers.dart';
import '../../shell/presentation/screens/profile_tab.dart';

String _money(int cents) {
  final String raw = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $raw';
}

class CrismedChildcareScreen extends StatefulWidget {
  const CrismedChildcareScreen({super.key});

  @override
  State<CrismedChildcareScreen> createState() => _CrismedChildcareScreenState();
}

class _CrismedChildcareScreenState extends State<CrismedChildcareScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const List<String> tabs = <String>[
      'Visão Geral',
      'Rotina Diária',
      'Sono',
      'Alimentação',
      'Desenvolvimento',
      'Prevenção',
      'Orientações por idade',
      'Plano de Cuidados',
      'Acompanhamento Familiar',
    ];
    return CrismedScaffold(
      actions: const <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Gerar Relatório (PDF)',
          icon: Icons.picture_as_pdf_outlined,
        ),
        CrismedActionSpec(
          label: 'Compartilhar com a Família',
          icon: Icons.share_rounded,
        ),
        CrismedActionSpec(label: 'Imprimir', icon: Icons.print_outlined),
        CrismedActionSpec(label: 'Agendar Retorno', icon: Icons.event_rounded),
        CrismedActionSpec(
          label: 'Salvar Puericultura',
          icon: Icons.check_rounded,
          primary: true,
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — plano de puericultura ilustrativo. A evolução assinada continua no prontuário.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Puericultura',
            subtitle:
                'Acompanhamento integral da saúde, desenvolvimento e rotina da criança',
            icon: Icons.child_care_rounded,
            primaryLabel: 'Novo Plano de Puericultura',
            onPrimary: () => crismedToast(
              context,
              'Plano local de exemplo. Não grava consulta.',
            ),
            onAi: () => context.go(Routes.aiHubPath),
          ),
          const SizedBox(height: 12),
          CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            birth: CrismedDemoPatient.birth,
            weight: CrismedDemoPatient.weight,
            height: CrismedDemoPatient.height,
            bmi: CrismedDemoPatient.bmi,
            percentile: CrismedDemoPatient.percentile,
            example: true,
            onChart: () => context.go(Routes.chartHubPath),
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: tabs,
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) const _ChildcareOverview() else _Topic(tabs[_tab]),
        ],
      ),
    );
  }
}

class _ChildcareOverview extends StatelessWidget {
  const _ChildcareOverview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool stack = c.maxWidth < 980;
        final Widget left = const CrismedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CrismedSectionTitle('Acompanhamento na Puericultura'),
              CrismedCheckLine('Consulta de Rotina', trailing: '04/10/2026'),
              CrismedCheckLine('Crescimento', trailing: '04/10/2026'),
              CrismedCheckLine(
                'Desenvolvimento',
                trailing: 'Em avaliação',
                ok: false,
              ),
              CrismedCheckLine('Vacinação', trailing: 'Atualizada'),
              CrismedCheckLine('Próxima Puericultura', trailing: '04/01/2027'),
            ],
          ),
        );
        final Widget mid = const CrismedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CrismedSectionTitle('Rotina Diária (Sugestão — 5 anos)'),
              CrismedCheckLine('07:00  Acordar e higiene'),
              CrismedCheckLine('07:30  Café da manhã'),
              CrismedCheckLine('12:00  Almoço'),
              CrismedCheckLine('13:00  Descanso / Atividades leves'),
              CrismedCheckLine('16:00  Lanche da tarde'),
              CrismedCheckLine('18:00  Atividade física / Lazer'),
              CrismedCheckLine('19:30  Jantar'),
              CrismedCheckLine('20:30  Higiene e preparo para o sono'),
            ],
          ),
        );
        final Widget right = const Column(
          children: <Widget>[
            CrismedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CrismedSectionTitle('Sono'),
                  Text('Tempo ideal: 10–12 horas/dia'),
                  Text(
                    'Sono atual: 10h 30min · Adequado',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            CrismedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CrismedSectionTitle('Alimentação'),
                  Text(
                    'Alimentação variada · Boa aceitação · Hidratação adequada',
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            CrismedCard(
              child: Text(
                'Tia Cris — IA: posso analisar a rotina, orientar sono, atividade e prevenção. Nada disso substitui a consulta.',
              ),
            ),
          ],
        );
        final Widget bottom = const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            SizedBox(
              width: 280,
              child: CrismedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CrismedSectionTitle('Marcos do Desenvolvimento'),
                    CrismedCheckLine('Motor Grosso', trailing: 'Adequado'),
                    CrismedCheckLine('Motor Fino', trailing: 'Adequado'),
                    CrismedCheckLine('Linguagem', trailing: 'Adequado'),
                    CrismedCheckLine('Cognitivo', trailing: 'Adequado'),
                    CrismedCheckLine(
                      'Social e Emocional',
                      trailing: 'Adequado',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: CrismedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CrismedSectionTitle('Saúde Preventiva'),
                    CrismedCheckLine('Vacinas em dia (PNI + particular)'),
                    CrismedCheckLine('Saúde bucal (avaliação semestral)'),
                    CrismedCheckLine('Visão (avaliação anual)'),
                    CrismedCheckLine('Audição (quando indicado)'),
                    CrismedCheckLine('Prevenção de acidentes'),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: CrismedCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CrismedSectionTitle('Plano de Cuidados'),
                    Text(
                      'Período: Out/2026 – Jan/2027',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                    CrismedCheckLine('Manter acompanhamento do crescimento'),
                    CrismedCheckLine(
                      'Estimular leitura e atividades cognitivas',
                    ),
                    CrismedCheckLine('Rotina de sono regular'),
                    CrismedCheckLine('Alimentação saudável e hidratação'),
                    CrismedCheckLine('Reavaliação em 3 meses'),
                  ],
                ),
              ),
            ),
          ],
        );
        if (stack) {
          return Column(
            children: <Widget>[
              left,
              const SizedBox(height: 12),
              mid,
              const SizedBox(height: 12),
              right,
              const SizedBox(height: 12),
              bottom,
            ],
          );
        }
        return Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: left),
                const SizedBox(width: 12),
                Expanded(child: mid),
                const SizedBox(width: 12),
                Expanded(child: right),
              ],
            ),
            const SizedBox(height: 12),
            bottom,
          ],
        );
      },
    );
  }
}

class _Topic extends StatelessWidget {
  const _Topic(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      child: Text(
        '$title em modo de exemplo. Os registros reais da criança continuam no prontuário e no diário da família.',
      ),
    );
  }
}

class CrismedExamsScreen extends StatefulWidget {
  const CrismedExamsScreen({super.key});

  @override
  State<CrismedExamsScreen> createState() => _CrismedExamsScreenState();
}

class _CrismedExamsScreenState extends State<CrismedExamsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Módulo de exames',
          icon: Icons.biotech_rounded,
          onPressed: () => context.go(Routes.supplementLabsPath),
        ),
        const CrismedActionSpec(
          label: 'Gerar Laudo (PDF)',
          icon: Icons.picture_as_pdf_outlined,
        ),
        CrismedActionSpec(
          label: 'Integrar ao Prontuário',
          icon: Icons.check_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Integração ilustrativa. O laudo real entra pelo prontuário.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — pedidos e resultados ilustrativos. O laboratório real abre no módulo de exames.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Exames e Resultados',
            subtitle:
                'Solicitação, resultados, imagens, anexos e análise com IA',
            icon: Icons.science_rounded,
            primaryLabel: 'Solicitar Exame',
            onPrimary: () => context.go(Routes.supplementLabsPath),
            onAi: () => crismedToast(
              context,
              'A IA só sugere revisão. Não libera laudo.',
            ),
          ),
          const SizedBox(height: 12),
          CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            birth: CrismedDemoPatient.birth,
            weight: CrismedDemoPatient.weight,
            height: CrismedDemoPatient.height,
            bmi: CrismedDemoPatient.bmi,
            percentile: CrismedDemoPatient.percentile,
            example: true,
            onChart: () => context.go(Routes.chartHubPath),
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>[
              'Visão Geral',
              'Solicitar Exames',
              'Resultados',
              'Imagens',
              'Anexos',
              'Histórico',
              'Alertas',
              'Protocolos',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 150,
            children: <Widget>[
              CrismedKpi(
                label: 'Exames solicitados',
                value: '24',
                icon: Icons.science_outlined,
                color: AppColors.brand,
              ),
              CrismedKpi(
                label: 'Resultados recebidos',
                value: '20',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              CrismedKpi(
                label: 'Aguardando',
                value: '3',
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.honey,
              ),
              CrismedKpi(
                label: 'Atenção',
                value: '1',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Resultados recentes'),
                Text('Hemograma completo · Hb 12,8 g/dL · 11,5–15,5 · Normal'),
                Text('PCR · 0,8 mg/dL · < 0,6 · Atenção'),
                Text('Urocultura + EAS · Negativa · Normal'),
                Text('Vitamina D (25-OH) · 28 ng/mL · ≥ 30 · Insuficiente'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Alertas de exemplo: PCR levemente acima da referência; vitamina D abaixo do ideal. Sugestão de reavaliação em 30 dias, com revisão médica.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedMultiScreen extends StatefulWidget {
  const CrismedMultiScreen({super.key});

  @override
  State<CrismedMultiScreen> createState() => _CrismedMultiScreenState();
}

class _CrismedMultiScreenState extends State<CrismedMultiScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: const <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Gerar Relatório (PDF)',
          icon: Icons.picture_as_pdf_outlined,
        ),
        CrismedActionSpec(
          label: 'Compartilhar com a Família',
          icon: Icons.share_rounded,
        ),
        CrismedActionSpec(
          label: 'Salvar Plano Terapêutico',
          icon: Icons.check_rounded,
          primary: true,
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — plano terapêutico ilustrativo. Não cria evolução no prontuário.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Multidisciplinar',
            subtitle: 'Equipe integrada, plano terapêutico e acompanhamento',
            icon: Icons.diversity_3_rounded,
            primaryLabel: 'Novo Plano Terapêutico',
            onPrimary: () =>
                crismedToast(context, 'PTI de exemplo, sem gravação.'),
            onAi: () => context.go(Routes.aiHubPath),
          ),
          const SizedBox(height: 12),
          CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            birth: CrismedDemoPatient.birth,
            weight: CrismedDemoPatient.weight,
            height: CrismedDemoPatient.height,
            bmi: CrismedDemoPatient.bmi,
            percentile: CrismedDemoPatient.percentile,
            example: true,
            onChart: () => context.go(Routes.chartHubPath),
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>[
              'Visão Geral',
              'Equipe',
              'Plano Terapêutico',
              'Evoluções',
              'Agenda da Equipe',
              'Permissões',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Equipe'),
                Text(
                  'Psicologia · Fonoaudiologia · Fisioterapia · Terapia Ocupacional · Nutrição · Psicopedagogia',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Plano terapêutico integrado (PTI)'),
                Text(
                  'Objetivo: linguagem, autorregulação e desenvolvimento escolar. Em andamento.',
                ),
                SizedBox(height: 8),
                Text(
                  'Psicologia 100% · Fonoaudiologia 70% · T.O. 60% · Fisioterapia 100% · Nutrição 100% · Psicopedagogia 65%',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Agenda da equipe (exemplo)'),
                Text('09:00 Fonoaudiologia · Confirmado'),
                Text('10:00 Psicologia · Confirmado'),
                Text('14:00 Terapia ocupacional · Aguardando'),
                Text('15:30 Fisioterapia · Confirmado'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedFinanceHubScreen extends ConsumerWidget {
  const CrismedFinanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<FinanceReceivable> recv =
        ref.watch(financeReceivablesProvider).valueOrNull ??
        const <FinanceReceivable>[];
    final List<FinancePayable> pay =
        ref.watch(financePayablesProvider).valueOrNull ??
        const <FinancePayable>[];
    final bool sample = recv.isEmpty && pay.isEmpty;
    final int billed = recv.fold<int>(
      0,
      (int a, FinanceReceivable r) => a + r.totalCents,
    );
    final int received = recv.fold<int>(
      0,
      (int a, FinanceReceivable r) => a + r.paidCents,
    );
    final int toPay = pay.fold<int>(
      0,
      (int a, FinancePayable p) => a + p.amountCents,
    );

    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Fluxo de Caixa',
          icon: Icons.waterfall_chart_rounded,
          onPressed: () => context.go(Routes.financeCashFlowPath),
        ),
        CrismedActionSpec(
          label: 'DRE',
          icon: Icons.pie_chart_outline_rounded,
          onPressed: () => context.go(Routes.financeDrePath),
        ),
        CrismedActionSpec(
          label: 'Abrir financeiro',
          icon: Icons.account_balance_wallet_rounded,
          primary: true,
          onPressed: () => context.go(Routes.financePath),
        ),
      ],
      body: CrismedBody(
        sample: sample,
        sampleMessage:
            'Dados de exemplo — não há lançamentos nesta sessão. O caixa real abre nos módulos de receber e pagar.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Financeiro',
            subtitle:
                'Gestão de receitas, despesas, convênios, repasses e fluxo de caixa',
            icon: Icons.account_balance_wallet_rounded,
            primaryLabel: 'Nova Receita/Despesa',
            onPrimary: () => context.go(Routes.financeReceivablesPath),
            onAi: () => crismedToast(
              context,
              'A IA financeira só comenta os números já lançados.',
            ),
          ),
          const SizedBox(height: 12),
          const CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: 'Última consulta 04/10/2026',
            example: true,
          ),
          const SizedBox(height: 12),
          CrismedWrap(
            minWidth: 160,
            children: <Widget>[
              CrismedKpi(
                label: 'Faturamento',
                value: sample ? 'R\$ 62.400' : _money(billed),
                icon: Icons.trending_up_rounded,
                color: AppColors.brand,
                delta: sample ? '+12,8%' : null,
              ),
              CrismedKpi(
                label: 'Despesas',
                value: sample ? 'R\$ 18.950' : _money(toPay),
                icon: Icons.trending_down_rounded,
                color: AppColors.raspberry,
                delta: sample ? '+5,4%' : null,
                positive: false,
              ),
              CrismedKpi(
                label: 'Resultado',
                value: sample ? 'R\$ 43.450' : _money(received - toPay),
                icon: Icons.account_balance_rounded,
                color: AppColors.success,
              ),
              CrismedKpi(
                label: 'A receber',
                value: sample ? 'R\$ 9.800' : _money(billed - received),
                icon: Icons.payments_rounded,
                color: AppColors.honey,
              ),
              CrismedKpi(
                label: 'A pagar',
                value: sample ? 'R\$ 4.320' : '${pay.length}',
                icon: Icons.request_quote_rounded,
                color: AppColors.moduleExams,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CrismedSectionTitle('Contas a receber'),
                if (recv.isEmpty)
                  const Text(
                    'Consulta — Enzo Gabriel · R\$ 350 · Hoje (exemplo)\nRetorno — Ana Beatriz · R\$ 280 · 18/10 (exemplo)',
                  )
                else
                  for (final FinanceReceivable item in recv.take(6))
                    Text(
                      '${item.description} · ${_money(item.openCents)} · ${item.status.label}',
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Convênios, repasses e conciliação bancária desta visão são exemplo visual. Guias e glosas reais ficam em Convênios.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedUnitsScreen extends ConsumerWidget {
  const CrismedUnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicOrganization? clinic = ref
        .watch(activeClinicProvider)
        .valueOrNull;
    final List<ClinicMembership> members =
        ref.watch(myClinicMembershipsProvider).valueOrNull ??
        const <ClinicMembership>[];
    final bool sample = clinic == null && members.isEmpty;

    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Abrir clínicas',
          icon: Icons.apartment_rounded,
          primary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ClinicOrgHubScreen()),
          ),
        ),
      ],
      body: CrismedBody(
        sample: sample,
        sampleMessage:
            'Dados de exemplo — nenhuma clínica ativa nesta sessão. O cadastro real abre em Minha clínica.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Gestão de Unidades, Profissionais e Salas',
            subtitle: 'Organize a clínica, equipes, escalas e consultórios',
            icon: Icons.apartment_rounded,
            primaryLabel: 'Nova Unidade',
            onPrimary: () => context.go(Routes.clinicOrgCreatePath),
            onAi: () => crismedToast(
              context,
              'Sugestão operacional de exemplo. Não altera a escala.',
            ),
          ),
          const SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              CrismedKpi(
                label: 'Unidades',
                value: sample ? '3' : '1',
                icon: Icons.location_city_rounded,
                color: AppColors.brand,
              ),
              CrismedKpi(
                label: 'Profissionais',
                value: sample ? '12' : '${members.length}',
                icon: Icons.groups_rounded,
                color: AppColors.moduleLibrary,
              ),
              const CrismedKpi(
                label: 'Especialidades',
                value: '8',
                icon: Icons.medical_information_rounded,
                color: AppColors.raspberry,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Ocupação',
                value: '86%',
                icon: Icons.meeting_room_rounded,
                color: AppColors.success,
                delta: 'ex.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CrismedSectionTitle('Unidades'),
                if (clinic != null)
                  Text(
                    '${clinic.tradeName.isEmpty ? clinic.name : clinic.tradeName} · ${clinic.active ? 'Ativa' : 'Inativa'}',
                  )
                else ...const <Widget>[
                  Text(
                    'Crisdepaula Matriz · Canal das Caraíbas · PA · Ativa (exemplo)',
                  ),
                  Text(
                    'Crisdepaula Filial 01 · Parauapebas · PA · Ativa (exemplo)',
                  ),
                  Text(
                    'Crisdepaula Filial 02 · Diamantino · MT · Ativa (exemplo)',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CrismedSectionTitle('Profissionais'),
                if (members.isEmpty)
                  const Text(
                    'Dra. Tia Cris · Pediatria · Ativa (exemplo)\nDr. Lucas Mendes · Neuropediatria (exemplo)\nDra. Ana Luísa · Nutrição (exemplo)',
                  )
                else
                  for (final ClinicMembership m in members.take(8))
                    Text('${m.role.label} · ${m.active ? 'Ativo' : 'Inativo'}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Salas: Consultório 01 ocupado, Sala de avaliação livre (exemplo). Permissões reais seguem o RBAC da clínica.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedSettingsScreen extends StatefulWidget {
  const CrismedSettingsScreen({super.key});

  @override
  State<CrismedSettingsScreen> createState() => _CrismedSettingsScreenState();
}

class _CrismedSettingsScreenState extends State<CrismedSettingsScreen> {
  int _tab = 0;
  bool _whatsapp = true;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Conta e perfil',
          icon: Icons.person_rounded,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ProfileTab())),
        ),
        CrismedActionSpec(
          label: 'Salvar Configurações',
          icon: Icons.check_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Preferências visuais locais. A conta real abre em Conta e perfil.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Identidade e preferências de exemplo. Nome, CRM e senha continuam no perfil da conta.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Configurações e Identidade Visual',
            subtitle:
                'Ajuste a clínica, permissões e a cara do Crisdepaula Pediatria',
            icon: Icons.tune_rounded,
            primaryLabel: 'Editar perfil',
            onPrimary: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProfileEditScreen(),
              ),
            ),
            onAi: () =>
                crismedToast(context, 'A IA não altera permissões sozinha.'),
          ),
          const SizedBox(height: 12),
          CrismedPillTabs(
            labels: const <String>[
              'Visão Geral',
              'Identidade Visual',
              'Usuários',
              'Permissões',
              'Integrações',
              'Segurança',
              'Preferências',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Informações da clínica'),
                Text('Nome: Crisdepaula Pediatria (exemplo)'),
                Text('CNPJ: 00.000.000/0001-00 (exemplo)'),
                Text('Endereço: Canal das Caraíbas — PA (exemplo)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembretes por WhatsApp'),
                  value: _whatsapp,
                  onChanged: (bool v) => setState(() => _whatsapp = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tema escuro (preferência local)'),
                  value: _dark,
                  onChanged: (bool v) => setState(() => _dark = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Usuários de exemplo: 2 administradores, 12 profissionais, recepção e equipe multidisciplinar. O RBAC real não muda nesta tela.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedInsuranceScreen extends StatelessWidget {
  const CrismedInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Abrir faturamento',
          icon: Icons.receipt_long_rounded,
          primary: true,
          onPressed: () => context.go(Routes.billingPath),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — guias, glosas e repasses ilustrativos. O faturamento real, com permissão, abre no módulo de convênios.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Convênios e Faturamento',
            subtitle: 'TISS, autorizações, glosas, repasses e recebimentos',
            icon: Icons.health_and_safety_rounded,
            primaryLabel: 'Nova guia',
            onPrimary: () => context.go(Routes.billingGuidesPath),
            onAi: () => crismedToast(
              context,
              'A IA não envia guia nem dá baixa em glosa.',
            ),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 150,
            children: <Widget>[
              CrismedKpi(
                label: 'Guias no mês',
                value: '452',
                icon: Icons.description_rounded,
                color: AppColors.brand,
                delta: '+12%',
              ),
              CrismedKpi(
                label: 'Faturado',
                value: 'R\$ 85.240',
                icon: Icons.payments_rounded,
                color: AppColors.success,
                delta: '+18%',
              ),
              CrismedKpi(
                label: 'Recebido',
                value: 'R\$ 72.980',
                icon: Icons.account_balance_rounded,
                color: AppColors.moduleLibrary,
              ),
              CrismedKpi(
                label: 'Pendente',
                value: 'R\$ 12.260',
                icon: Icons.pending_actions_rounded,
                color: AppColors.raspberry,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Convênios cadastrados'),
                CrismedCheckLine('Unimed', trailing: 'Ativo'),
                CrismedCheckLine('Hapvida', trailing: 'Ativo'),
                CrismedCheckLine('Bradesco Saúde', trailing: 'Ativo'),
                CrismedCheckLine('SulAmérica', trailing: 'Ativo'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Autorizações 386 · em análise 28 · negadas 6. Glosas 18, recuperadas 11. Repasses a conferir. Tudo ilustrativo até abrir o faturamento.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedAiHubScreen extends StatelessWidget {
  const CrismedAiHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Abrir transcrição',
          icon: Icons.mic_rounded,
          onPressed: () => context.go(Routes.clinicalAiPath),
        ),
        CrismedActionSpec(
          label: 'Chat clínico',
          icon: Icons.forum_rounded,
          primary: true,
          onPressed: () => context.go(Routes.aiPath),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — indicadores e automações ilustrativos. A conversa real abre no chat e na transcrição.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Central de Inteligência Artificial',
            subtitle:
                'IA na rotina clínica, administrativa e no cuidado pediátrico',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          const CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: 'Última consulta 04/10/2026 · retorno 04/01/2027',
            example: true,
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 150,
            children: <Widget>[
              CrismedKpi(
                label: 'Novas consultas',
                value: '128',
                icon: Icons.event_available_rounded,
                color: AppColors.brand,
                delta: '+18%',
              ),
              CrismedKpi(
                label: 'Pacientes',
                value: '89',
                icon: Icons.groups_rounded,
                color: AppColors.success,
                delta: '+22%',
              ),
              CrismedKpi(
                label: 'Faltas',
                value: '12',
                icon: Icons.event_busy_rounded,
                color: AppColors.danger,
                delta: '-40%',
                positive: false,
              ),
              CrismedKpi(
                label: 'Documentos IA',
                value: '67',
                icon: Icons.description_rounded,
                color: AppColors.moduleLibrary,
                delta: '+35%',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: CrismedCard(
              child: BarChart(
                BarChartData(
                  maxY: 300,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  barGroups: <BarChartGroupData>[
                    for (int i = 0; i < 6; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: <BarChartRodData>[
                          BarChartRodData(
                            toY: 80 + i * 28,
                            width: 18,
                            color: AppColors.brand,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Automações supervisionadas'),
                CrismedCheckLine('Lembrete de consulta (WhatsApp)'),
                CrismedCheckLine('Aviso de vacina'),
                CrismedCheckLine('Orientações pós-consulta'),
                Text(
                  'A IA não aplica sugestão sem revisão. Consentimento e trilha de auditoria seguem as regras já existentes.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
