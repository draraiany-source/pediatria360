import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../library/presentation/screens/library_screen.dart';
import '../../notifications/presentation/notification_center_screen.dart';

export 'reference_layouts.dart';

class CrismedClinicalAiScreen extends StatefulWidget {
  const CrismedClinicalAiScreen({super.key});

  @override
  State<CrismedClinicalAiScreen> createState() =>
      _CrismedClinicalAiScreenState();
}

class _CrismedClinicalAiScreenState extends State<CrismedClinicalAiScreen> {
  bool _recording = false;
  bool _consent = false;
  int _seconds = 0;
  final Set<String> _docs = <String>{'Receituário'};

  void _tick() {
    if (!_recording) return;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_recording) return;
      setState(() => _seconds += 1);
      _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String clock =
        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Aprovar e salvar',
          icon: Icons.verified_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            _consent
                ? 'Revisão local. O prontuário só muda no fluxo de assinatura.'
                : 'Marque o consentimento LGPD antes de aprovar.',
          ),
        ),
        CrismedActionSpec(
          label: 'Fluxo de voz',
          icon: Icons.mic_rounded,
          onPressed: () => context.go(Routes.clinicVoicePath),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Transcrição e SOAP de exemplo. A sessão gravada de verdade abre em Consultório → IA, com consentimento e revisão.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'IA clínica e transcrição',
            subtitle: 'Consulta, SOAP e documentos para revisar',
            icon: Icons.auto_awesome_rounded,
            primaryLabel: _recording ? 'Parar' : 'Gravar',
            onPrimary: () {
              if (!_consent) {
                crismedToast(
                  context,
                  'O consentimento LGPD precisa estar marcado.',
                );
                return;
              }
              setState(() => _recording = !_recording);
              if (_recording) _tick();
            },
            onAi: () => crismedToast(
              context,
              'A IA sugere texto para revisão. Não diagnostica.',
            ),
          ),
          const SizedBox(height: 12),
          const CrismedPatientCard(
            name: 'Helena Martins',
            age: '4 anos',
            birth: '12/03/2022',
            exampleMetrics: true,
            weight: '16,2 kg',
            height: '102 cm',
            bmi: 'P50',
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      _recording
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded,
                      color: _recording ? AppColors.raspberry : AppColors.brand,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clock,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    const Text('Onda ilustrativa'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: CustomPaint(
                    painter: _WavePainter(active: _recording),
                    size: const Size(double.infinity, 42),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  activeThumbColor: AppColors.success,
                  title: const Text(
                    'Consentimento LGPD para transcrever esta consulta',
                  ),
                  onChanged: (bool v) => setState(() => _consent = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Transcrição editável (exemplo)',
              hintText:
                  'Mãe: ela tossiu a noite toda.\nMédico: vamos ver a garganta.',
            ),
          ),
          const SizedBox(height: 8),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Evolução SOAP sugerida pela IA (revisar)',
            ),
          ),
          const SizedBox(height: 8),
          const CrismedCard(
            child: Text(
              'Resumo clínico (exemplo): quadro de vias aéreas, sem sinal de gravidade descrito nesta conversa. Conferir exame físico antes de assinar.',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sugestões de documentos',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final String doc in const <String>[
            'Receituário',
            'Atestado',
            'Encaminhamento',
            'Orientações',
            'Exportar PDF',
          ])
            CheckboxListTile(
              value: _docs.contains(doc),
              contentPadding: EdgeInsets.zero,
              title: Text(doc),
              onChanged: (bool? v) => setState(() {
                if (v ?? false) {
                  _docs.add(doc);
                } else {
                  _docs.remove(doc);
                }
              }),
            ),
          const CrismedCard(
            child: Text(
              'Histórico de transcrições (exemplo): 12/11 retorno · 03/10 puericultura. Segurança: áudio não sai do fluxo clínico e a família autoriza antes da gravação.',
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = active ? AppColors.raspberry : AppColors.brandSoft
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    for (double x = 0; x <= size.width; x += 8) {
      final double y =
          size.height / 2 +
          (active ? 10 : 4) * ((x / 16).floor().isEven ? -1 : 1);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.active != active;
}

class CrismedNotificationsScreen extends StatefulWidget {
  const CrismedNotificationsScreen({super.key});

  @override
  State<CrismedNotificationsScreen> createState() =>
      _CrismedNotificationsScreenState();
}

class _CrismedNotificationsScreenState
    extends State<CrismedNotificationsScreen> {
  bool _whatsapp = true;
  bool _sms = false;
  bool _email = true;
  bool _family = true;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Caixa de avisos',
          icon: Icons.inbox_rounded,
          primary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NotificationCenterScreen(),
            ),
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Indicadores de envio ilustrativos. Os avisos já recebidos abrem na caixa real.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Notificações e lembretes',
            subtitle: 'WhatsApp, SMS, e-mail e família',
            icon: Icons.forum_rounded,
            onAi: () => crismedToast(
              context,
              'Automação de texto sugerida, sem disparo real.',
            ),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 150,
            children: <Widget>[
              CrismedKpi(
                label: 'Mensagens',
                value: '86',
                icon: Icons.send_rounded,
                color: AppColors.brand,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Entrega',
                value: '94%',
                icon: Icons.done_all_rounded,
                color: AppColors.success,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Leitura',
                value: '71%',
                icon: Icons.mark_email_read_outlined,
                color: AppColors.moduleLibrary,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Confirmações',
                value: '38',
                icon: Icons.event_available_rounded,
                color: AppColors.raspberry,
                delta: 'ex.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _whatsapp,
            title: const Text('WhatsApp'),
            onChanged: (bool v) => setState(() => _whatsapp = v),
          ),
          SwitchListTile(
            value: _sms,
            title: const Text('SMS'),
            onChanged: (bool v) => setState(() => _sms = v),
          ),
          SwitchListTile(
            value: _email,
            title: const Text('E-mail'),
            onChanged: (bool v) => setState(() => _email = v),
          ),
          const CrismedSectionTitle('Tipos de lembrete'),
          const CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Mini('Consulta', Icons.event_rounded, AppColors.brand),
              _Mini('Vacina', Icons.vaccines_rounded, AppColors.raspberry),
              _Mini('Retorno', Icons.replay_rounded, AppColors.honey),
              _Mini('Exame', Icons.biotech_rounded, AppColors.moduleExams),
              _Mini('Aniversário', Icons.cake_rounded, AppColors.moduleLibrary),
              _Mini('Cobrança', Icons.payments_rounded, AppColors.success),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _family,
            title: const Text(
              'Preferências da família e permissão de recebimento',
            ),
            subtitle: const Text(
              'Consentimento LGPD ilustrativo — não grava nesta tela.',
            ),
            onChanged: (bool v) => setState(() => _family = v),
          ),
          const CrismedCard(
            child: Text(
              'Histórico semanal (exemplo): seg 12 · ter 18 · qua 9 · qui 21 · sex 15. Próximo contato automático: lembrete de consulta amanhã às 8h.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      child: Column(
        children: <Widget>[
          CrismedIconBubble(icon: icon, color: color),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
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
  int _age = 1;

  @override
  Widget build(BuildContext context) {
    final List<String> ages = <String>['0–2', '3–5', '6–8', '9–12'];
    return CrismedScaffold(
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Jogos, histórias e conquistas ilustrativos. Sem conteúdo clínico.',
        children: <Widget>[
          CrismedPageHeader(
            title: widget.stories
                ? 'Histórias e entretenimento'
                : 'Espaço Kids',
            subtitle: 'Faixa ${ages[_age]} anos',
            icon: Icons.toys_rounded,
            primaryLabel: widget.stories ? 'Jogos' : 'Histórias',
            onPrimary: () => context.go(
              widget.stories ? Routes.kidsPath : Routes.storiesPath,
            ),
            onAi: () => crismedToast(
              context,
              'A Tia Cris sugere uma história curta para a idade (exemplo).',
            ),
          ),
          const SizedBox(height: 12),
          CrismedPillTabs(
            labels: ages,
            index: _age,
            onChanged: (int i) => setState(() => _age = i),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Play('Memória', Color(0xFF7A4EBF)),
              _Play('Cores', Color(0xFFF26B9A)),
              _Play('Números', Color(0xFF2EAF6A)),
              _Play('Corpo humano', Color(0xFF6B8CFF)),
              _Play('Histórias', Color(0xFFFF8A3D)),
              _Play('Colorir', Color(0xFF8B7CF6)),
              _Play('Músicas', Color(0xFF2EAF6A)),
              _Play('Áudio calmo', Color(0xFF7A4EBF)),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Trilha e conquistas'),
                Text('Habilidade da semana: nomear cores (exemplo).'),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.4,
                  color: AppColors.raspberry,
                  backgroundColor: AppColors.softPink,
                ),
                SizedBox(height: 8),
                Text('Controle parental: tempo de tela ilustrativo, 20 min.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Play extends StatelessWidget {
  const _Play(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      color: color.withValues(alpha: 0.12),
      onTap: () => crismedToast(context, '$label é um cartão de exemplo.'),
      child: Column(
        children: <Widget>[
          Icon(Icons.star_rounded, color: color, size: 32),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class CrismedDiaryScreen extends StatelessWidget {
  const CrismedDiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Salvar o dia',
          icon: Icons.save_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Registro local de exemplo. Não grava no prontuário.',
          ),
        ),
      ],
      body: const CrismedBody(
        sample: true,
        children: <Widget>[
          CrismedPageHeader(
            title: 'Diário infantil',
            subtitle: 'Rotina da família',
            icon: Icons.menu_book_rounded,
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Mini('Sono', Icons.bedtime_rounded, AppColors.brand),
              _Mini('Alimentação', Icons.restaurant_rounded, AppColors.honey),
              _Mini(
                'Medicamentos',
                Icons.medication_rounded,
                AppColors.raspberry,
              ),
              _Mini('Sintomas', Icons.thermostat_rounded, AppColors.danger),
              _Mini(
                'Humor',
                Icons.sentiment_satisfied_alt_rounded,
                AppColors.success,
              ),
              _Mini(
                'Atividades',
                Icons.directions_run_rounded,
                AppColors.moduleExams,
              ),
            ],
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Text(
              'Gráfico de 7 dias, compartilhamento com a pediatra, lembretes e resumo da IA: tudo ilustrativo nesta tela.',
            ),
          ),
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
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Área da família em modo demonstração. Crianças cadastradas continuam em Minhas crianças.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Área do paciente e família',
            subtitle: 'Atalhos do cuidado em casa',
            icon: Icons.family_restroom_rounded,
          ),
          const SizedBox(height: 12),
          CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Jump(
                'Calendário',
                Icons.calendar_month_rounded,
                () => context.go(Routes.agendaPath),
              ),
              _Jump(
                'Pré-consulta',
                Icons.fact_check_rounded,
                () => context.go(Routes.preVisitPath),
              ),
              _Jump(
                'Vacinas',
                Icons.vaccines_rounded,
                () => context.go(Routes.vaccinationHubPath),
              ),
              _Jump(
                'Receitas',
                Icons.description_rounded,
                () => context.go(Routes.prescriptionsPath),
              ),
              _Jump(
                'Exames',
                Icons.biotech_rounded,
                () => context.go(Routes.examsHubPath),
              ),
              _Jump(
                'Orientações',
                Icons.lightbulb_rounded,
                () => context.go(Routes.libraryPath),
              ),
              _Jump(
                'Biblioteca',
                Icons.menu_book_rounded,
                () => context.go(Routes.libraryPath),
              ),
              _Jump(
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
                CrismedSectionTitle('Plano de cuidados'),
                Text('Progresso ilustrativo da semana.'),
                SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: CircularProgressIndicator(
                      value: 0.62,
                      strokeWidth: 8,
                      color: AppColors.brand,
                      backgroundColor: AppColors.softLilac,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Responsáveis e acessos: mãe com leitura, pai com diário (exemplo).',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Jump extends StatelessWidget {
  const _Jump(this.label, this.icon, this.onTap);

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

class CrismedPreVisitScreen extends StatefulWidget {
  const CrismedPreVisitScreen({super.key});

  @override
  State<CrismedPreVisitScreen> createState() => _CrismedPreVisitScreenState();
}

class _CrismedPreVisitScreenState extends State<CrismedPreVisitScreen> {
  int _step = 0;
  bool _lgpd = false;
  final Set<String> _symptoms = <String>{};

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: _step < 3 ? 'Continuar' : 'Enviar',
          icon: Icons.send_rounded,
          primary: true,
          onPressed: () {
            if (_step < 3) {
              setState(() => _step += 1);
              return;
            }
            crismedToast(
              context,
              _lgpd
                  ? 'Pré-consulta de exemplo enviada só nesta tela.'
                  : 'Marque o consentimento LGPD.',
            );
          },
        ),
      ],
      body: CrismedBody(
        sample: true,
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Pré-consulta inteligente',
            subtitle: 'A família prepara a visita',
            icon: Icons.fact_check_rounded,
          ),
          const SizedBox(height: 12),
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
          if (_step == 0) ...<Widget>[
            const TextField(
              decoration: InputDecoration(labelText: 'Queixa principal'),
            ),
            const SizedBox(height: 8),
            const Text('Sintomas'),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final String s in const <String>[
                  'Febre',
                  'Tosse',
                  'Dor',
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
          ] else if (_step == 1)
            const TextField(
              decoration: InputDecoration(
                labelText: 'Há quanto tempo? Histórico e medicamentos',
              ),
              maxLines: 4,
            )
          else if (_step == 2)
            const TextField(
              decoration: InputDecoration(
                labelText: 'Alergias, dúvidas e anexos (descrição)',
              ),
              maxLines: 4,
            )
          else ...<Widget>[
            const CrismedCard(
              child: Text(
                'Resumo para o pediatra (IA, exemplo): queixa referida pela família, sem conclusão diagnóstica. Revise antes da consulta.',
              ),
            ),
            SwitchListTile(
              value: _lgpd,
              title: const Text(
                'Consentimento LGPD para compartilhar com a pediatra',
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
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Vitrine ilustrativa. O acervo publicado no Firestore abre em Acervo completo.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Biblioteca digital',
            subtitle: 'Temas, e-books e orientações por idade',
            icon: Icons.local_library_rounded,
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por tema',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          const CrismedWrap(
            minWidth: 140,
            children: <Widget>[
              _Mini('Sono', Icons.bedtime_rounded, AppColors.brand),
              _Mini('Alimentação', Icons.restaurant_rounded, AppColors.honey),
              _Mini('Febre', Icons.thermostat_rounded, AppColors.raspberry),
              _Mini('Vacinas', Icons.vaccines_rounded, AppColors.success),
              _Mini(
                'Desenvolvimento',
                Icons.child_care_rounded,
                AppColors.moduleLibrary,
              ),
              _Mini(
                'Segurança',
                Icons.health_and_safety_rounded,
                AppColors.moduleExams,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CrismedCard(
            child: Text(
              'Carrossel de e-books, materiais compartilhados, favoritos e downloads: exemplos até o acervo real carregar.',
            ),
          ),
        ],
      ),
    );
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
            'Planos comerciais de exemplo. Cobrança real depende do gateway, que segue desligado.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Planos e assinaturas',
            subtitle: 'Gestão comercial',
            icon: Icons.workspace_premium_rounded,
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 150,
            children: <Widget>[
              CrismedKpi(
                label: 'Assinantes',
                value: '42',
                icon: Icons.groups_rounded,
                color: AppColors.brand,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'MRR',
                value: 'R\$ 18 mil',
                icon: Icons.payments_rounded,
                color: AppColors.success,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Churn',
                value: '2%',
                icon: Icons.trending_down_rounded,
                color: AppColors.honey,
                delta: 'ex.',
              ),
              CrismedKpi(
                label: 'Indicações',
                value: '7',
                icon: Icons.share_rounded,
                color: AppColors.raspberry,
                delta: 'ex.',
              ),
            ],
          ),
          SizedBox(height: 12),
          CrismedWrap(
            minWidth: 200,
            children: <Widget>[
              _Plan('Básico', 'R\$ 197', false),
              _Plan('Profissional', 'R\$ 347', false),
              _Plan('Premium', 'R\$ 597', true),
              _Plan('Enterprise', 'Sob consulta', false),
            ],
          ),
          SizedBox(height: 12),
          CrismedCard(
            child: Text(
              'Assinantes recentes, funil, cobranças, renovações, cupons e permissões: painel ilustrativo. O faturamento de convênio continua no módulo existente.',
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan(this.name, this.price, this.highlight);

  final String name;
  final String price;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      color: highlight ? AppColors.softLilac : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (highlight)
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
        ],
      ),
    );
  }
}

class CrismedHomologationScreen extends StatelessWidget {
  const CrismedHomologationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const List<String> steps = <String>[
      'Desenvolvimento',
      'Homologação',
      'Publicação',
      'Monitoramento',
    ];
    return CrismedScaffold(
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Painel de publicação ilustrativo. Não dispara build nem loja.',
        children: <Widget>[
          const CrismedPageHeader(
            title: 'Homologação e monitoramento',
            subtitle: 'Ambientes, testes e LGPD',
            icon: Icons.rocket_launch_rounded,
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Text(
              'Etapa atual (exemplo): Homologação · ${steps.length} passos no fluxo.',
            ),
          ),
          SizedBox(height: 8),
          _MiniRow(),
          SizedBox(height: 8),
          CrismedCard(
            child: Text(
              'Dev 1.0.0-dev · Homolog 1.0.0-hml · Prod aguardando. Android, iOS e Web listados só como status visual. Logs e suporte não leem produção daqui.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow();

  @override
  Widget build(BuildContext context) {
    return const CrismedWrap(
      minWidth: 140,
      children: <Widget>[
        _Mini('Dev', Icons.code_rounded, AppColors.brand),
        _Mini('Homolog', Icons.science_rounded, AppColors.honey),
        _Mini('Prod', Icons.cloud_done_rounded, AppColors.success),
        _Mini('LGPD', Icons.privacy_tip_rounded, AppColors.raspberry),
      ],
    );
  }
}

class CrismedVoiceChatScreen extends StatefulWidget {
  const CrismedVoiceChatScreen({super.key});

  @override
  State<CrismedVoiceChatScreen> createState() => _CrismedVoiceChatScreenState();
}

class _CrismedVoiceChatScreenState extends State<CrismedVoiceChatScreen> {
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    const List<String> modes = <String>['Voz adulta', 'Voz infantil', 'Chat'];
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Transferir para humano',
          icon: Icons.support_agent_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Transferência ilustrativa. A recepção humana abre no consultório.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        children: <Widget>[
          CrismedPageHeader(
            title: 'Atendimento por voz e chat',
            subtitle: modes[_mode],
            icon: Icons.record_voice_over_rounded,
            onAi: () => context.go(Routes.aiPath),
          ),
          const SizedBox(height: 12),
          CrismedPillTabs(
            labels: modes,
            index: _mode,
            onChanged: (int i) => setState(() => _mode = i),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: CrismedCard(
              child: Text(
                'Olá, sou a Tia Cris. Posso ajudar com horário e orientações gerais. Não faço diagnóstico.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: CrismedCard(
              color: AppColors.softLilac,
              child: Text('Quero remarcar a consulta da Helena.'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String c in const <String>[
                'Horários',
                'Vacinas',
                'Endereço',
                'Falar com a equipe',
              ])
                ActionChip(
                  label: Text(c),
                  onPressed: () =>
                      crismedToast(context, 'Comando de exemplo: $c'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Limites: a IA não prescreve, não acessa prontuário sem permissão e pode passar para uma pessoa.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
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
          label: 'Recepção',
          icon: Icons.desk_rounded,
          primary: true,
          onPressed: () => context.go(Routes.clinicReceptionPath),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Fila ilustrativa. A recepção operacional abre no botão Recepção.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'IA recepcionista',
            subtitle: 'Voz, chat e fila',
            icon: Icons.support_agent_rounded,
            onAi: () => crismedToast(
              context,
              'A recepcionista virtual não marca consulta sozinha.',
            ),
          ),
          const SizedBox(height: 12),
          CrismedCard(
            onTap: () => context.go(Routes.voiceChatPath),
            child: const Text('Falar por voz ou chat com a recepção virtual.'),
          ),
          const SizedBox(height: 8),
          const CrismedCard(
            child: Text(
              'Fila em tempo real (exemplo): 2 aguardando, 1 em triagem. Agenda integrada e sala infantil são visuais. LGPD: a família é informada de que fala com uma assistente.',
            ),
          ),
        ],
      ),
    );
  }
}

class CrismedPrescriptionsScreen extends StatelessWidget {
  const CrismedPrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrismedSimpleHub(
      title: 'Prescrições',
      subtitle: 'Receituário, atestado e orientações',
      icon: Icons.description_rounded,
      sampleMessage:
          'Lista ilustrativa. O documento assinado sai do editor clínico já existente.',
      body:
          'Sugestões da IA ficam para revisão. Atalhos: receita, atestado, encaminhamento e orientações. Nada é emitido nesta vitrine.',
      primaryLabel: 'Nova receita',
      onPrimary: () => crismedToast(
        context,
        'Abra o editor de documentos a partir do prontuário do paciente.',
      ),
      routeLabel: 'Suplementação',
      route: Routes.supplementPrescriptionPath,
    );
  }
}

class CrismedReportsHubScreen extends StatelessWidget {
  const CrismedReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CrismedSimpleHub(
      title: 'Relatórios',
      subtitle: 'Indicadores da clínica',
      icon: Icons.insights_rounded,
      sampleMessage: 'Capa ilustrativa. Os indicadores calculados abrem no BI.',
      body:
          'Produção, agenda, recepção e operação seguem o painel de indicadores já existente.',
      routeLabel: 'Abrir relatórios',
      route: Routes.biPath,
    );
  }
}

class CrismedSimpleHub extends StatelessWidget {
  const CrismedSimpleHub({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    required this.sampleMessage,
    this.primaryLabel,
    this.onPrimary,
    this.routeLabel,
    this.route,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String body;
  final String sampleMessage;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? routeLabel;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        if (route != null && routeLabel != null)
          CrismedActionSpec(
            label: routeLabel!,
            icon: Icons.open_in_new_rounded,
            primary: true,
            onPressed: () => context.go(route!),
          ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage: sampleMessage,
        children: <Widget>[
          CrismedPageHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            primaryLabel: primaryLabel,
            onPrimary: onPrimary,
            onAi: () => crismedToast(
              context,
              'A IA da Tia Cris resume esta tela. Não grava dado clínico.',
            ),
          ),
          const SizedBox(height: 12),
          CrismedCard(child: Text(body)),
        ],
      ),
    );
  }
}
