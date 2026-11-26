import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../telemedicine/presentation/agenda_providers.dart';
import '../../telemedicine/presentation/professional_agenda_screen.dart';
import '../../telemedicine/presentation/screens/pre_visit_questionnaire_form_screen.dart';
import 'family_chrome.dart';
import 'kids_screens.dart';

class FamilyHomePortal extends StatefulWidget {
  const FamilyHomePortal({this.section = 'Início', super.key});

  final String section;

  @override
  State<FamilyHomePortal> createState() => _FamilyHomePortalState();
}

class _FamilyHomePortalState extends State<FamilyHomePortal> {
  final TextEditingController _talk = TextEditingController();

  @override
  void dispose() {
    _talk.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _talk.text.trim();
    crismedToast(
      context,
      text.isEmpty
          ? 'O microfone não grava. Escreva uma mensagem para a Tia Cris.'
          : 'Mensagem ilustrativa. A Tia Cris não acessa prontuário nem diagnostica.',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const KidsAssistantScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FamilyScaffold(
      section: widget.section,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: <Widget>[
          const FamilyHero(
            portrait: FamilyArt.wave,
            title: 'Olá, amiguinho(a)!\nEu sou a Tia Cris!',
            body:
                'Sua recepcionista inteligente do Crisdepaula Pediatria. '
                'Vamos agendar consultas, acompanhar a sua saúde, '
                'brincar, aprender e tirar dúvidas juntos?',
            trailing: FamilyTeddy(size: 78),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            child: TextField(
              controller: _talk,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Fale com a Tia Cris... (voz ou texto)',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.graphic_eq_rounded),
                suffixIcon: IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: AppColors.brand),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Busca ilustrativa: o microfone não grava áudio.',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 10),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.35,
            children: <Widget>[
              _BigTile(
                'Agendar\nconsulta',
                Icons.event_available_rounded,
                const Color(0xFFFF7AC8),
                () => context.go(Routes.familyAgendaPath),
              ),
              _BigTile(
                'Pré-consulta\ndigital',
                Icons.assignment_turned_in_rounded,
                const Color(0xFF7C6BF2),
                () => context.go(Routes.preVisitPath),
              ),
              _BigTile(
                'Teleconsulta',
                Icons.videocam_rounded,
                const Color(0xFF5B8DEF),
                () => context.go(Routes.telemedicinePath),
              ),
              _BigTile(
                'Espaço\nKids',
                Icons.sports_esports_rounded,
                const Color(0xFFFFC857),
                () => context.go(Routes.kidsPath),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.15,
            children: <Widget>[
              _SmallTile(
                'Vacinas',
                'Carteira digital',
                Icons.vaccines_rounded,
                const Color(0xFFE7F4FF),
                () => context.go(Routes.vaccinationHubPath),
              ),
              _SmallTile(
                'Crescimento',
                'Curvas e IMC',
                Icons.show_chart_rounded,
                const Color(0xFFE9FFF1),
                () => context.go(Routes.growthHubPath),
              ),
              _SmallTile(
                'Desenvolvimento',
                'Marcos e triagens',
                Icons.extension_rounded,
                const Color(0xFFFFF4D8),
                () => context.go(Routes.growthHubPath),
              ),
              _SmallTile(
                'Rotina Infantil',
                'Sono, alimentação e cuidados',
                Icons.bedtime_rounded,
                const Color(0xFFF3E9FF),
                () => context.go(Routes.diaryPath),
              ),
              _SmallTile(
                'Receituário',
                'Receitas, atestados e encaminhamentos',
                Icons.description_rounded,
                const Color(0xFFFFF8E4),
                () => context.go(Routes.prescriptionsPath),
              ),
              _SmallTile(
                'Exames',
                'Resultados e laudos',
                Icons.science_rounded,
                const Color(0xFFE7FFF4),
                () => context.go(Routes.examsHubPath),
              ),
              _SmallTile(
                'Orientações de Saúde',
                'Guias e cuidados',
                Icons.menu_book_rounded,
                const Color(0xFFF3FFE4),
                () => context.go(Routes.libraryPath),
              ),
              _SmallTile(
                'Biblioteca',
                'Livros, vídeos e conteúdos',
                Icons.local_library_rounded,
                const Color(0xFFE8EEFF),
                () => context.go(Routes.libraryPath),
              ),
              _SmallTile(
                'Equipe Multidisciplinar',
                'Fono, psicologia, fisio e nutrição',
                Icons.groups_rounded,
                const Color(0xFFF6EEFF),
                () => context.go(Routes.multidisciplinaryPath),
              ),
              _SmallTile(
                'Área da Família',
                'Acompanhamento completo',
                Icons.family_restroom_rounded,
                const Color(0xFFFFF0F6),
                () => context.go(Routes.patientAreaPath),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFFE9D8FF),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => context.go(Routes.kidsPath),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Image.asset(
                          FamilyArt.bannerChild,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Espaço Kids da Tia Cris',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                          Text(
                            'Jogos, histórias, desenhos e atividades educativas!',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go(Routes.kidsPath),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Entrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7A4EBF),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.onTap,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agenda no visual da família. A lista real entra quando há consultas.
/// Confirmar um horário nesta tela não grava no Firestore.
class FamilySmartAgenda extends ConsumerStatefulWidget {
  const FamilySmartAgenda({super.key});

  @override
  ConsumerState<FamilySmartAgenda> createState() => _FamilySmartAgendaState();
}

class _FamilySmartAgendaState extends ConsumerState<FamilySmartAgenda> {
  static const List<String> _specialties = <String>[
    'Pediatria Geral',
    'Neuropediatria',
    'Puericultura',
    'Alergia e Imunologia',
    'Sono Infantil',
    'Outras Especialidades',
  ];
  static const List<(String, String)> _professionals = <(String, String)>[
    ('Dra. Tia Cris', 'Pediatria'),
    ('Dr. Felipe', 'Pediatra'),
    ('Dra. Ana', 'Neuropediatra'),
  ];
  static const List<String> _hourOptions = <String>[
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
  ];

  String _tab = 'Agendar Consulta';
  String _specialty = 'Pediatria Geral';
  String _professional = 'Dra. Tia Cris';
  int _day = 10;
  String _hour = '10:00';

  @override
  Widget build(BuildContext context) {
    final List<Appointment> agenda =
        ref.watch(unitScopedMyAgendaProvider).valueOrNull ??
        const <Appointment>[];
    return FamilyScaffold(
      section: 'Agenda',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: <Widget>[
          const FamilyHero(
            portrait: FamilyArt.agenda,
            title: 'Agenda Inteligente com a Tia Cris!',
            body:
                'Posso agendar, confirmar, remarcar ou cancelar sua consulta de forma rápida e segura!',
            trailing: FamilyTeddy(size: 70),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final String tab in const <String>[
                  'Agendar Consulta',
                  'Minhas Consultas',
                  'Retornos',
                  'Fila de Espera',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(tab),
                      selected: _tab == tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_tab == 'Agendar Consulta') _picker(agenda.isEmpty),
          if (_tab == 'Minhas Consultas') _mine(agenda),
          if (_tab == 'Retornos')
            _Hint(
              agenda.isEmpty
                  ? 'Nenhum retorno real nesta conta. A lista abaixo é exemplo.'
                  : 'Retornos saem das consultas já gravadas na agenda.',
            ),
          if (_tab == 'Fila de Espera')
            const _Hint(
              'Fila de espera ilustrativa. Nada é gravado a partir desta tela.',
            ),
        ],
      ),
    );
  }

  Widget _picker(bool sample) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '1  Escolha a especialidade',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (final String name in _specialties)
                _SelectCard(
                  title: name,
                  selected: _specialty == name,
                  onTap: () => setState(() => _specialty = name),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '2  Escolha o profissional',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              for (final (String, String) person in _professionals)
                _SelectCard(
                  title: person.$1,
                  subtitle: person.$2,
                  selected: _professional == person.$1,
                  onTap: () => setState(() => _professional = person.$1),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _calendar()),
            const SizedBox(width: 8),
            Expanded(child: _hourPicker()),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _Summary('Consulta: $_specialty'),
            _Summary('Profissional: $_professional'),
            _Summary('Data: ${_day.toString().padLeft(2, '0')}/11/2026'),
            _Summary('Horário: $_hour'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => crismedToast(
              context,
              'Pré-seleção $_specialty · $_professional · '
              '${_day.toString().padLeft(2, '0')}/11 $_hour. '
              'Não foi gravada na agenda.',
            ),
            icon: const Icon(Icons.event_available_rounded),
            label: const Text('Confirmar Agendamento'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.action,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (sample)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Dados de exemplo — esta tela não grava no Firestore. '
              'A agenda operacional continua no módulo existente.',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _ActionChip(
              Icons.chat_rounded,
              'Confirmação no WhatsApp',
              const Color(0xFF25D366),
              () async {
                await launchUrl(
                  Uri.parse('https://wa.me/'),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
            _ActionChip(
              Icons.notifications_active_rounded,
              'Lembrete automático',
              const Color(0xFF7A4EBF),
              () => crismedToast(
                context,
                'Lembrete de exemplo. Nada foi agendado.',
              ),
            ),
            _ActionChip(
              Icons.sync_rounded,
              'Remarcar consulta',
              const Color(0xFF5B8DEF),
              () => crismedToast(
                context,
                'Remarcação ilustrativa. Use a agenda operacional para gravar.',
              ),
            ),
            _ActionChip(
              Icons.close_rounded,
              'Cancelar consulta',
              const Color(0xFFFF5A6B),
              () => crismedToast(
                context,
                'Cancelamento ilustrativo. Nenhuma consulta foi alterada.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _calendar() {
    const List<String> weeks = <String>[
      'Dom',
      'Seg',
      'Ter',
      'Qua',
      'Qui',
      'Sex',
      'Sáb',
    ];
    final DateTime first = DateTime(2026, 11);
    final int lead = first.weekday % 7;
    final int days = DateTime(2026, 12, 0).day;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Novembro 2026',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                for (final String w in weeks)
                  Expanded(
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (int i = 0; i < lead; i++) const SizedBox.shrink(),
                for (int day = 1; day <= days; day++)
                  InkWell(
                    onTap: () => setState(() => _day = day),
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: day == _day
                              ? const Color(0xFF7A4EBF)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 10,
                            color: day == _day ? Colors.white : AppColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hourPicker() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Escolha o horário',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (final String hour in _hourOptions)
                  ChoiceChip(
                    label: Text(hour, style: const TextStyle(fontSize: 11)),
                    selected: _hour == hour,
                    onSelected: (_) => setState(() => _hour = hour),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mine(List<Appointment> agenda) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ProfessionalAgendaScreen(),
            ),
          ),
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Abrir agenda operacional'),
        ),
        const SizedBox(height: 8),
        if (agenda.isEmpty)
          const _Hint(
            'Nenhuma consulta real nesta conta. Os horários da aba Agendar são exemplo e não são gravados.',
          )
        else
          for (final Appointment item in agenda)
            Card(
              child: ListTile(
                title: Text(item.childName ?? item.professionalName),
                subtitle: Text(
                  '${item.startsAt.day.toString().padLeft(2, '0')}/'
                  '${item.startsAt.month.toString().padLeft(2, '0')} '
                  '${item.startsAt.hour.toString().padLeft(2, '0')}:'
                  '${item.startsAt.minute.toString().padLeft(2, '0')}'
                  '${item.specialty == null ? '' : ' · ${item.specialty}'}',
                ),
              ),
            ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? const Color(0xFF7A4EBF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 132,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: selected ? Colors.white70 : AppColors.inkMuted,
                      fontSize: 10,
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

class _Summary extends StatelessWidget {
  const _Summary(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: onTap,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.inkMuted));
  }
}

/// Pré-consulta no visual da família. O envio desta tela não grava prontuário.
/// Quando existe consulta real, abre o formulário oficial já existente.
class FamilyPreVisitView extends ConsumerStatefulWidget {
  const FamilyPreVisitView({super.key});

  @override
  ConsumerState<FamilyPreVisitView> createState() => _FamilyPreVisitViewState();
}

class _FamilyPreVisitViewState extends ConsumerState<FamilyPreVisitView> {
  final Set<String> _symptoms = <String>{'Tosse'};
  String _when = '3–7 dias';
  String _feeding = 'Normal';
  String _sleep = 'Regular';
  String _gut = 'Normal';
  bool _vaccinated = true;
  bool _lgpd = false;
  final TextEditingController _complaint = TextEditingController();
  final TextEditingController _questions = TextEditingController();

  @override
  void dispose() {
    _complaint.dispose();
    _questions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Appointment> agenda =
        ref.watch(unitScopedMyAgendaProvider).valueOrNull ??
        const <Appointment>[];
    final Appointment? official = agenda.cast<Appointment?>().firstWhere(
      (Appointment? item) =>
          item != null &&
          (item.childId ?? '').isNotEmpty &&
          item.professionalId.isNotEmpty,
      orElse: () => null,
    );
    return FamilyScaffold(
      section: 'Consultas',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: <Widget>[
          const FamilyHero(
            portrait: FamilyArt.tablet,
            title: 'Pré-Consulta Digital',
            body:
                'Conte para mim o que está acontecendo com o Enzo. '
                'Assim, o médico já recebe tudo organizado antes da consulta!',
            trailing: FamilyTeddy(size: 68),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Expanded(
                child: _InfoPill(
                  'Paciente: Enzo Gabriel (6 anos)',
                  Icons.child_care_rounded,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: _InfoPill(
                  'Consulta: 10/11/2026 às 10:00',
                  Icons.event_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Queixa principal *',
            child: TextField(
              controller: _complaint,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Descreva o que está acontecendo... (ex.: febre, tosse, dor)',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Há quanto tempo?',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String w in const <String>[
                  'Hoje',
                  '1–2 dias',
                  '3–7 dias',
                  '1–2 semanas',
                  'Mais de 2 semanas',
                ])
                  ChoiceChip(
                    label: Text(w),
                    selected: _when == w,
                    onSelected: (_) => setState(() => _when = w),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Sintomas atuais',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final (String, IconData) s in const <(String, IconData)>[
                  ('Febre', Icons.thermostat_rounded),
                  ('Tosse', Icons.coronavirus_rounded),
                  ('Coriza', Icons.air_rounded),
                  ('Dor de garganta', Icons.sick_rounded),
                  ('Vômito', Icons.water_drop_rounded),
                  ('Diarreia', Icons.bubble_chart_rounded),
                  ('Manchas na pele', Icons.blur_on_rounded),
                  ('Sonolência', Icons.bedtime_rounded),
                ])
                  FilterChip(
                    avatar: Icon(s.$2, size: 16),
                    label: Text(s.$1),
                    selected: _symptoms.contains(s.$1),
                    onSelected: (bool v) => setState(() {
                      if (v) {
                        _symptoms.add(s.$1);
                      } else {
                        _symptoms.remove(s.$1);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Informações importantes',
            child: Column(
              children: <Widget>[
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.medication_rounded),
                  title: Text('Medicamentos em uso'),
                  subtitle: Text('Exemplo — não altera o prontuário'),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.warning_amber_rounded),
                  title: Text('Alergias conhecidas'),
                  subtitle: Text('Exemplo'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.vaccines_rounded),
                  title: const Text('Vacinação em dia?'),
                  value: _vaccinated,
                  onChanged: (bool v) => setState(() => _vaccinated = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Anexos (opcional)',
            child: Wrap(
              spacing: 6,
              children: <Widget>[
                for (final String label in const <String>[
                  'Tirar foto',
                  'Galeria',
                  'PDF',
                  'Resultados',
                ])
                  ActionChip(
                    label: Text(label),
                    onPressed: () => crismedToast(
                      context,
                      'Anexo ilustrativo. Nenhum arquivo é enviado.',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Rotina e hábitos',
            child: Column(
              children: <Widget>[
                _Drop('Alimentação', _feeding, const <String>[
                  'Normal',
                  'Reduzida',
                  'Seletiva',
                ], (String v) => setState(() => _feeding = v)),
                _Drop('Sono', _sleep, const <String>[
                  'Regular',
                  'Agitado',
                  'Insônia',
                ], (String v) => setState(() => _sleep = v)),
                _Drop('Intestino', _gut, const <String>[
                  'Normal',
                  'Preso',
                  'Solto',
                ], (String v) => setState(() => _gut = v)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            title: 'Suas dúvidas para o médico',
            child: TextField(
              controller: _questions,
              decoration: const InputDecoration(
                hintText:
                    'Ex.: Precisa fazer algum exame? Como aliviar a tosse?',
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Panel(
            title: 'Dica da Tia Cris',
            child: Text(
              'Quanto mais informações você enviar, mais completa será a avaliação do médico. Esta assistente não diagnostica nem prescreve.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Consentimento para organizar estas informações'),
            value: _lgpd,
            onChanged: (bool v) => setState(() => _lgpd = v),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => crismedToast(
                context,
                _lgpd
                    ? 'Pré-consulta de exemplo não foi enviada ao prontuário.'
                    : 'Marque o consentimento antes de enviar.',
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Enviar Pré-Consulta'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.action,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (official != null)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PreVisitQuestionnaireFormScreen(
                    appointmentId: official.id,
                    childId: official.childId!,
                    professionalId: official.professionalId,
                  ),
                ),
              ),
              child: const Text('Abrir o formulário oficial desta consulta'),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Dados de exemplo. O formulário oficial abre quando existe uma consulta real, e só ele grava a pré-consulta.',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 16, color: AppColors.brand),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop(this.label, this.value, this.options, this.onChanged);

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 100, child: Text(label)),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            items: <DropdownMenuItem<String>>[
              for (final String option in options)
                DropdownMenuItem<String>(value: option, child: Text(option)),
            ],
            onChanged: (String? next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ],
    );
  }
}
