import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../kids/presentation/kids_screens.dart';
import '../../finance/domain/finance_aggregators.dart';
import '../../finance/presentation/providers/finance_providers.dart';
import '../../library/presentation/screens/library_screen.dart';
import '../../security/presentation/screens/audit_logs_screen.dart';
import '../../security/presentation/screens/permission_matrix_screen.dart';

class CrismedDiaryScreen extends StatefulWidget {
  const CrismedDiaryScreen({super.key});

  @override
  State<CrismedDiaryScreen> createState() => _CrismedDiaryScreenState();
}

class _CrismedDiaryScreenState extends State<CrismedDiaryScreen> {
  int _tab = 0;
  bool _pedia = true;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Novo Registro',
          icon: Icons.add_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Registro de exemplo. Não grava no prontuário.',
          ),
        ),
        const CrismedActionSpec(
          label: 'Exportar Relatório (PDF)',
          icon: Icons.picture_as_pdf_outlined,
        ),
        const CrismedActionSpec(
          label: 'Enviar para o Pediatra',
          icon: Icons.send_rounded,
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo — o diário não grava sono, alimentação nem sintomas.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Diário Infantil e Rotina Familiar',
            subtitle:
                'Registre o dia a dia, acompanhe a evolução e compartilhe com a pediatra',
            icon: Icons.menu_book_rounded,
          ),
          const SizedBox(height: 12),
          const CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            example: true,
          ),
          const SizedBox(height: 8),
          const Text('Rotina do dia: 5 de 7 registros · 71% (exemplo)'),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>[
              'Diário do Dia',
              'Rotina Semanal',
              'Calendário Familiar',
              'Evolução e Gráficos',
              'Lembretes',
              'Compartilhar',
              'Permissões',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Tone(
                'Sono',
                '10h 20min',
                AppColors.brand,
                Icons.bedtime_rounded,
              ),
              _Tone(
                'Alimentação',
                '4 registros',
                AppColors.honey,
                Icons.restaurant_rounded,
              ),
              _Tone(
                'Medicamentos',
                '2 doses',
                AppColors.raspberry,
                Icons.medication_rounded,
              ),
              _Tone(
                'Sintomas',
                'Sem sintomas',
                AppColors.success,
                Icons.health_and_safety_outlined,
              ),
              _Tone(
                'Humor',
                'Feliz',
                AppColors.moduleLibrary,
                Icons.sentiment_satisfied_alt_rounded,
              ),
              _Tone(
                'Atividades',
                'Futebol',
                AppColors.moduleExams,
                Icons.sports_soccer_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Evolução da rotina (7 dias)'),
                Text('12/11 a 18/11 · sono em torno de 10h 20min (exemplo).'),
                SizedBox(height: 8),
                Text(
                  'Indicadores: alimentação 87% · atividade física 71% · humor positivo 92% · adesão 85%.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compartilhar com a Dra. Tia Cris (pediatra)'),
              subtitle: const Text(
                'Consentimento ilustrativo. Não envia o diário.',
              ),
              value: _pedia,
              onChanged: (bool v) => setState(() => _pedia = v),
            ),
          ),
          const SizedBox(height: 8),
          const CrismedCard(
            child: Text(
              'Próximos lembretes (exemplo): 14:00 medicação · amanhã consulta de retorno · 2/11 vacina dTpa.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Tone extends StatelessWidget {
  const _Tone(this.title, this.value, this.color, this.icon);

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(value, style: const TextStyle(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class CrismedPatientAreaScreen extends StatelessWidget {
  const CrismedPatientAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Agendar consulta',
          icon: Icons.event_rounded,
          onPressed: () => context.go(Routes.agendaPath),
        ),
        CrismedActionSpec(
          label: 'Solicitar retorno',
          icon: Icons.replay_rounded,
          onPressed: () => context.go(Routes.preVisitPath),
        ),
        const CrismedActionSpec(
          label: 'Baixar documentos (PDF)',
          icon: Icons.download_rounded,
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Dados de exemplo. Crianças cadastradas de verdade continuam em Minhas crianças.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Área do Paciente e Família',
            subtitle: 'Acompanhamento, orientações, rotina e cuidados',
            icon: Icons.family_restroom_rounded,
          ),
          const SizedBox(height: 12),
          const CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: 'Última consulta 04/10/2026 · próxima vacina influenza',
            weight: CrismedDemoPatient.weight,
            height: CrismedDemoPatient.height,
            example: true,
          ),
          const SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Go(
                'Calendário',
                Icons.calendar_month_rounded,
                () => context.go(Routes.agendaPath),
              ),
              _Go(
                'Pré-consulta',
                Icons.fact_check_rounded,
                () => context.go(Routes.preVisitPath),
              ),
              _Go(
                'Vacinas',
                Icons.vaccines_rounded,
                () => context.go(Routes.vaccinationHubPath),
              ),
              _Go(
                'Receitas',
                Icons.description_rounded,
                () => context.go(Routes.prescriptionsPath),
              ),
              _Go(
                'Exames',
                Icons.biotech_rounded,
                () => context.go(Routes.examsHubPath),
              ),
              _Go(
                'Orientações',
                Icons.lightbulb_rounded,
                () => context.go(Routes.libraryPath),
              ),
              _Go(
                'Biblioteca',
                Icons.menu_book_rounded,
                () => context.go(Routes.libraryPath),
              ),
              _Go(
                'Diário',
                Icons.edit_note_rounded,
                () => context.go(Routes.diaryPath),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Acompanhamento do desenvolvimento'),
                Text(
                  'Motor · Linguagem · Cognitivo · Social · Emocional — faixa ilustrativa, adequada.',
                ),
                SizedBox(height: 8),
                Text('Plano de cuidados: 50% concluído (exemplo).'),
                LinearProgressIndicator(
                  value: 0.5,
                  color: AppColors.brand,
                  backgroundColor: AppColors.softLilac,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Responsáveis (exemplo): Raiany Lorraine, titular · pai autorizado · avó com visualização. O vínculo real fica no cadastro de responsáveis.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Go extends StatelessWidget {
  const _Go(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      onTap: onTap,
      child: Column(
        children: <Widget>[
          CrismedIconBubble(icon: icon, color: AppColors.brand),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class CrismedReceptionistScreen extends StatelessWidget {
  const CrismedReceptionistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Recepção operacional',
          icon: Icons.desk_rounded,
          onPressed: () => context.go(Routes.clinicReceptionPath),
        ),
        CrismedActionSpec(
          label: 'Transferir para humano',
          icon: Icons.support_agent_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Transferência ilustrativa. A fila real abre na recepção.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Fila e agenda ilustrativas. A recepção que grava chegada abre no botão operacional.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'IA Recepcionista Tia Cris',
            subtitle: 'Atendimento para a família, com voz, chat e fila',
            icon: Icons.support_agent_rounded,
            primaryLabel: 'Novo atendimento',
            onPrimary: () => context.go(Routes.voiceChatPath),
            onAi: () => context.go(Routes.voiceChatPath),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Olá, eu sou a Tia Cris. Posso ajudar com horários, confirmação e dúvidas gerais. Não faço diagnóstico.',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ActionChip(
                label: const Text('Falar por voz (adulta)'),
                onPressed: () => context.go(Routes.voiceChatPath),
              ),
              ActionChip(
                label: const Text('Falar por voz (infantil)'),
                onPressed: () => context.go(Routes.voiceChatPath),
              ),
              ActionChip(
                label: const Text('Conversar por chat'),
                onPressed: () => context.go(Routes.aiPath),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Fila em tempo real (exemplo)'),
                Text('Mãe do Enzo · agendar consulta · 2 min'),
                Text('Pai da Lara · dúvida de vacina · 4 min'),
                Text('Responsável do Miguel · retorno · 6 min'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Agenda integrada, recepção infantil (jogos, histórias, sala de espera) e LGPD são visuais. A transferência humana não descarta a conversa desta tela.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedGrowthHubScreen extends StatelessWidget {
  const CrismedGrowthHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Curva da criança',
          icon: Icons.show_chart_rounded,
          onPressed: () => context.go(Routes.childrenPath),
        ),
        const CrismedActionSpec(
          label: 'Gerar Relatório (PDF)',
          icon: Icons.picture_as_pdf_outlined,
          primary: true,
        ),
      ],
      body: const CrismedBody(
        sample: true,
        sampleMessage:
            'Curva ilustrativa. A curva OMS com as medições reais abre em Crescimento da criança.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Crescimento e Desenvolvimento',
            subtitle: 'Antropometria, curvas OMS e marcos',
            icon: Icons.show_chart_rounded,
            primaryLabel: 'Novo registro',
          ),
          SizedBox(height: 12),
          CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            birth: CrismedDemoPatient.birth,
            weight: CrismedDemoPatient.weight,
            height: CrismedDemoPatient.height,
            bmi: CrismedDemoPatient.bmi,
            percentile: CrismedDemoPatient.percentile,
            example: true,
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Indicadores (exemplo)'),
                Text('Peso 18,4 kg · P62'),
                Text('Estatura 112 cm · P62'),
                Text('IMC 14,7 kg/m² · P62'),
                Text('Perímetro cefálico 51,5 cm · P50'),
                Text('Última avaliação: 04/10/2026'),
              ],
            ),
          ),
          SizedBox(height: 12),
          _GrowthLines(),
          SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Evolução longitudinal (exemplo)'),
                Text('10/04 · 17,2 kg · 110 cm · IMC 14,2 · PC 51,0'),
                Text('15/06 · 17,6 kg · 111 cm · IMC 14,3 · PC 51,2'),
                Text('20/08 · 18,0 kg · 111 cm · IMC 14,6 · PC 51,3'),
                Text('04/10 · 18,4 kg · 112 cm · IMC 14,7 · PC 51,5'),
              ],
            ),
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Marcos — 5 anos (exemplo)'),
                CrismedCheckLine('Motor grosso', trailing: 'Adequado'),
                CrismedCheckLine('Motor fino', trailing: 'Adequado'),
                CrismedCheckLine('Linguagem', trailing: 'Adequado'),
                CrismedCheckLine('Cognitivo', trailing: 'Adequado'),
                CrismedCheckLine('Social e emocional', trailing: 'Adequado'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthLines extends StatelessWidget {
  const _GrowthLines();

  @override
  Widget build(BuildContext context) {
    LineChartBarData line(List<double> ys, Color color) => LineChartBarData(
      spots: <FlSpot>[
        for (int i = 0; i < ys.length; i++) FlSpot(i.toDouble(), ys[i]),
      ],
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      isCurved: true,
    );
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CrismedSectionTitle(
            'Peso por idade · faixa ilustrativa P3–P97',
          ),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: <LineChartBarData>[
                  line(const <double>[12, 14, 16, 17, 18, 19], AppColors.line),
                  line(const <double>[
                    14,
                    16,
                    18,
                    19,
                    20,
                    21,
                  ], AppColors.brandSoft),
                  line(const <double>[16, 18, 20, 22, 23, 24], AppColors.line),
                  line(const <double>[
                    14.5,
                    16.2,
                    17.2,
                    17.6,
                    18.0,
                    18.4,
                  ], AppColors.success),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedKidsScreen extends StatefulWidget {
  const CrismedKidsScreen({this.stories = false, super.key});

  final bool stories;

  @override
  State<CrismedKidsScreen> createState() => _CrismedKidsScreenState();
}

class _CrismedKidsScreenState extends State<CrismedKidsScreen> {
  @override
  Widget build(BuildContext context) {
    return KidsSpaceScreen(startOnStories: widget.stories);
  }
}

class CrismedPlansScreen extends StatelessWidget {
  const CrismedPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Faturamento',
          icon: Icons.receipt_long_rounded,
          onPressed: () => context.go(Routes.billingPath),
        ),
      ],
      body: const CrismedBody(
        sample: true,
        sampleMessage:
            'Planos comerciais de exemplo. O gateway de pagamento segue desligado.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Planos, Assinaturas e Gestão Comercial',
            subtitle: 'Planos, cobranças, renovações e indicações',
            icon: Icons.workspace_premium_rounded,
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              CrismedKpi(
                label: 'Assinantes',
                value: '248',
                icon: Icons.groups_rounded,
                color: AppColors.brand,
                delta: '+18%',
              ),
              CrismedKpi(
                label: 'Novas assinaturas',
                value: '36',
                icon: Icons.person_add_alt_1_rounded,
                color: AppColors.success,
                delta: '+32%',
              ),
              CrismedKpi(
                label: 'Faturamento',
                value: 'R\$ 72.980',
                icon: Icons.payments_rounded,
                color: AppColors.moduleLibrary,
              ),
              CrismedKpi(
                label: 'Renovações',
                value: '92%',
                icon: Icons.autorenew_rounded,
                color: AppColors.honey,
              ),
              CrismedKpi(
                label: 'Inadimplência',
                value: '8%',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
              ),
            ],
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 180,
            children: <Widget>[
              _Price('Básico', 'R\$ 197/mês', 'Sem IA'),
              _Price('Profissional', 'R\$ 347/mês', 'IA essencial'),
              _Price('Premium', 'R\$ 597/mês', 'Mais escolhido'),
              _Price('Enterprise', 'Sob consulta', 'Multunidades'),
            ],
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Text(
              'Funil de exemplo: 428 leads, 162 propostas, 98 negociações, 36 contratos. Cupons, indicações e permissões comerciais não cobram ninguém.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price(this.name, this.price, this.note);

  final String name;
  final String price;
  final String note;

  @override
  Widget build(BuildContext context) {
    final bool hot = name == 'Premium';
    return CrismedCard(
      color: hot ? AppColors.softLilac : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hot)
            const Text(
              'Mais escolhido',
              style: TextStyle(
                color: AppColors.raspberry,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.brand,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(note, style: const TextStyle(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class CrismedPreVisitScreen extends StatefulWidget {
  const CrismedPreVisitScreen({super.key});

  @override
  State<CrismedPreVisitScreen> createState() => _CrismedPreVisitScreenState();
}

class _CrismedPreVisitScreenState extends State<CrismedPreVisitScreen> {
  int _step = 0;
  bool _lgpd = false;
  final Set<String> _symptoms = <String>{'Tosse', 'Febre'};

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Limpar',
          icon: Icons.restart_alt_rounded,
          onPressed: () => setState(() {
            _step = 0;
            _symptoms.clear();
            _lgpd = false;
          }),
        ),
        CrismedActionSpec(
          label: 'Salvar rascunho',
          icon: Icons.save_outlined,
          onPressed: () => crismedToast(context, 'Rascunho só nesta tela.'),
        ),
        CrismedActionSpec(
          label: 'Enviar pré-consulta',
          icon: Icons.send_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            _lgpd
                ? 'Envio de exemplo. A pediatra não recebe este formulário.'
                : 'Marque o consentimento LGPD.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Pré-Consulta Inteligente',
            subtitle: 'A família prepara a visita',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 8),
          Text(
            'Passo ${_step + 1} de 4',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_step + 1) / 4,
            color: AppColors.brand,
            backgroundColor: AppColors.softLilac,
          ),
          const SizedBox(height: 12),
          const CrismedPatientBanner(
            name: CrismedDemoPatient.name,
            age: CrismedDemoPatient.age,
            example: true,
          ),
          const SizedBox(height: 8),
          const Text(
            'Consulta agendada (exemplo): terça, 18/11/2026 às 14:30 · retorno pediatria.',
          ),
          const SizedBox(height: 12),
          if (_step == 0) ...<Widget>[
            const TextField(
              decoration: InputDecoration(labelText: 'Queixa principal'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String s in const <String>[
                  'Febre',
                  'Tosse',
                  'Coriza',
                  'Dor de garganta',
                  'Vômito',
                  'Diarreia',
                ])
                  FilterChip(
                    label: Text(s),
                    selected: _symptoms.contains(s),
                    onSelected: (bool v) => setState(() {
                      if (v) {
                        _symptoms.add(s);
                      } else {
                        _symptoms.remove(s);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Continuar'),
            ),
          ] else if (_step == 1) ...<Widget>[
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Há quanto tempo, histórico e medicamentos',
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _step = 2),
              child: const Text('Continuar'),
            ),
          ] else if (_step == 2) ...<Widget>[
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Alergias, dúvidas e anexos (descrição)',
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _step = 3),
              child: const Text('Ver resumo'),
            ),
          ] else ...<Widget>[
            const CrismedCard(
              child: Text(
                'Resumo para a pediatra (exemplo): tosse e febre há 3 dias, asma na infância, salbutamol se necessário. Sem conclusão diagnóstica.',
              ),
            ),
            SwitchListTile(
              value: _lgpd,
              title: const Text(
                'Autorizo o uso destas informações na pré-consulta (LGPD)',
              ),
              onChanged: (bool v) => setState(() => _lgpd = v),
            ),
          ],
        ],
      ),
    );
  }
}

class CrismedLibraryHubScreen extends StatelessWidget {
  const CrismedLibraryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Acervo completo',
          icon: Icons.menu_book_rounded,
          primary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const LibraryScreen()),
          ),
        ),
      ],
      body: const CrismedBody(
        sample: true,
        sampleMessage:
            'Vitrine de exemplo. O acervo publicado no Firestore abre em Acervo completo.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Biblioteca Digital',
            subtitle: 'Orientações para famílias, por tema e por idade',
            icon: Icons.local_library_rounded,
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por tema',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(label: Text('Alimentação saudável')),
              Chip(label: Text('Sono infantil')),
              Chip(label: Text('Desenvolvimento')),
              Chip(label: Text('Vacinação')),
              Chip(label: Text('Puericultura')),
              Chip(label: Text('Higiene')),
            ],
          ),
          SizedBox(height: 12),
          CrismedSectionTitle('E-books em destaque (exemplo)'),
          Text(
            'Introdução alimentar (6–24 meses) · Rotina do sono · Seletividade alimentar · Desenvolvimento 0–6 · Guia de vacinação · TDAH · Autismo · Cuidados na escola.',
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Text(
              'Orientações por idade 0–2, 3–5, 6–8 e 9–12. Favoritos e downloads desta vitrine não baixam arquivo.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedAdminScreen extends StatelessWidget {
  const CrismedAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Matriz de permissões',
          icon: Icons.grid_on_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PermissionMatrixScreen(),
            ),
          ),
        ),
        CrismedActionSpec(
          label: 'Auditoria',
          icon: Icons.receipt_long_rounded,
          primary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AuditLogsScreen()),
          ),
        ),
      ],
      body: const CrismedBody(
        sample: true,
        sampleMessage:
            'Lista ilustrativa. A matriz e os logs reais abrem nos botões e respeitam o papel de quem está logado.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Administração e Permissões',
            subtitle: 'Usuários, perfis, unidades e trilha de auditoria',
            icon: Icons.admin_panel_settings_rounded,
            primaryLabel: 'Novo usuário',
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              CrismedKpi(
                label: 'Usuários',
                value: '28',
                icon: Icons.groups_rounded,
                color: AppColors.brand,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Perfis',
                value: '7',
                icon: Icons.badge_rounded,
                color: AppColors.moduleLibrary,
              ),
              CrismedKpi(
                label: 'Profissionais',
                value: '12',
                icon: Icons.medical_services_rounded,
                color: AppColors.success,
              ),
              CrismedKpi(
                label: 'Unidades',
                value: '2',
                icon: Icons.apartment_rounded,
                color: AppColors.honey,
              ),
            ],
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Usuários (exemplo)'),
                Text('Dra. Tia Cris · Médica · Matriz · Ativo'),
                Text('Ana Beatriz · Recepção · Matriz · Ativo'),
                Text('Paulo Henrique · Fisioterapeuta · Matriz · Ativo'),
                Text('Renata Lima · Psicologia · Matriz · Ativo'),
                Text('Carlos Mendes · Financeiro · Matriz · Ativo'),
              ],
            ),
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle(
                  'Acesso ao prontuário (exemplo, não grava)',
                ),
                CrismedCheckLine('Visualizar prontuário completo'),
                CrismedCheckLine('Prescrever'),
                CrismedCheckLine('Compartilhar com a família'),
                Text(
                  'Perfis: administrador, médico, multidisciplinar, recepção, financeiro e família.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedReportsHubScreen extends ConsumerWidget {
  const CrismedReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FinanceDashboardKpis kpis = ref.watch(financeDashboardKpisProvider);
    final bool sample = kpis.revenueMonth == 0 && kpis.expensesMonth == 0;
    String money(int cents) => 'R\$ ${(cents / 100).toStringAsFixed(0)}';

    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Abrir indicadores',
          icon: Icons.insights_rounded,
          primary: true,
          onPressed: () => context.go(Routes.biPath),
        ),
        const CrismedActionSpec(
          label: 'Exportar (Excel)',
          icon: Icons.table_chart_outlined,
        ),
      ],
      body: CrismedBody(
        sample: sample,
        sampleMessage:
            'Indicadores de exemplo. Os cálculos do BI abrem em Indicadores.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Relatórios e Indicadores',
            subtitle: 'Clínico, operacional, financeiro e produtividade',
            icon: Icons.insights_rounded,
            primaryLabel: 'Novo relatório',
          ),
          const SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              const CrismedKpi(
                label: 'Consultas',
                value: '428',
                icon: Icons.event_available_rounded,
                color: AppColors.brand,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Retornos',
                value: '132',
                icon: Icons.replay_rounded,
                color: AppColors.success,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Faltas',
                value: '36',
                icon: Icons.event_busy_rounded,
                color: AppColors.danger,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Vacinas',
                value: '298',
                icon: Icons.vaccines_rounded,
                color: AppColors.raspberry,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Faturamento',
                value: sample ? 'R\$ 62.400' : money(kpis.revenueMonth),
                icon: Icons.payments_rounded,
                color: AppColors.moduleLibrary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CrismedSectionTitle('Financeiro do período'),
                Text(
                  sample
                      ? 'Receitas R\$ 62.400 · despesas R\$ 18.950 · resultado R\$ 43.450 (exemplo).'
                      : 'Receitas ${money(kpis.revenueMonth)} · despesas ${money(kpis.expensesMonth)} · resultado ${money(kpis.balance)}.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Produtividade por profissional e distribuição por especialidade são exemplo visual. O painel operacional real está em Indicadores.',
            ),
          ),
        ],
      ),
    );
  }
}
