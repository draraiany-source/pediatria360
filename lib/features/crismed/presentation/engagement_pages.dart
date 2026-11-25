import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../notifications/presentation/notification_center_screen.dart';

export 'reference_layouts.dart';
export 'closing_layouts.dart';

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
