import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import 'family_chrome.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../telemedicine/presentation/agenda_providers.dart';
import '../../telemedicine/presentation/professional_agenda_screen.dart';

class FamilyHomePortal extends StatelessWidget {
  const FamilyHomePortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4ECFF),
      body: Column(
        children: <Widget>[
          const FamilyPortalHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                const CrismedCard(
                  child: Text(
                    'Olá, amiguinho(a)! Eu sou a Tia Cris, recepcionista virtual. '
                    'Posso ajudar a agendar, acompanhar e brincar. Não sou médica.',
                  ),
                ),
                const SizedBox(height: 8),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Fale com a Tia Cris... (voz ou texto)',
                    prefixIcon: Icon(Icons.mic_none_rounded),
                    suffixIcon: Icon(Icons.send_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Busca ilustrativa: o microfone não grava.',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                  children: <Widget>[
                    _Tile(
                      'Agendar consulta',
                      Icons.event_available_rounded,
                      const Color(0xFFFF8AD4),
                      () => context.go(Routes.familyAgendaPath),
                    ),
                    _Tile(
                      'Pré-consulta digital',
                      Icons.fact_check_rounded,
                      const Color(0xFF7C6CF0),
                      () => context.go(Routes.preVisitPath),
                    ),
                    _Tile(
                      'Teleconsulta',
                      Icons.videocam_rounded,
                      const Color(0xFF5B8DEF),
                      () => context.go(Routes.telemedicinePath),
                    ),
                    _Tile(
                      'Espaço Kids',
                      Icons.sports_esports_rounded,
                      const Color(0xFFFFC857),
                      () => context.go(Routes.kidsPath),
                    ),
                    _Tile(
                      'Vacinas',
                      Icons.vaccines_rounded,
                      const Color(0xFF6EC6FF),
                      () => context.go(Routes.vaccinationHubPath),
                    ),
                    _Tile(
                      'Crescimento',
                      Icons.show_chart_rounded,
                      const Color(0xFF7BE0A2),
                      () => context.go(Routes.growthHubPath),
                    ),
                    _Tile(
                      'Desenvolvimento',
                      Icons.extension_rounded,
                      const Color(0xFFFFB4A2),
                      () => context.go(Routes.growthHubPath),
                    ),
                    _Tile(
                      'Rotina infantil',
                      Icons.bedtime_rounded,
                      const Color(0xFFD7C4FF),
                      () => context.go(Routes.diaryPath),
                    ),
                    _Tile(
                      'Receituário',
                      Icons.description_rounded,
                      const Color(0xFFFFE08A),
                      () => context.go(Routes.prescriptionsPath),
                    ),
                    _Tile(
                      'Exames',
                      Icons.science_rounded,
                      const Color(0xFFB8F2C8),
                      () => context.go(Routes.examsHubPath),
                    ),
                    _Tile(
                      'Orientações',
                      Icons.menu_book_rounded,
                      const Color(0xFFC9F27A),
                      () => context.go(Routes.libraryPath),
                    ),
                    _Tile(
                      'Biblioteca',
                      Icons.local_library_rounded,
                      const Color(0xFFB9C6FF),
                      () => context.go(Routes.libraryPath),
                    ),
                    _Tile(
                      'Equipe',
                      Icons.groups_rounded,
                      const Color(0xFFE7D4FF),
                      () => context.go(Routes.multidisciplinaryPath),
                    ),
                    _Tile(
                      'Área da família',
                      Icons.family_restroom_rounded,
                      const Color(0xFFFFD6E8),
                      () => context.go(Routes.patientAreaPath),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const FamilyBottomBar(current: 'Início'),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon, this.color, this.onTap);

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: AppColors.navy),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
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

/// Agenda no visual da família. A lista real entra quando há consultas;
/// confirmar horário aqui não grava no Firestore.
class FamilySmartAgenda extends ConsumerStatefulWidget {
  const FamilySmartAgenda({super.key});

  @override
  ConsumerState<FamilySmartAgenda> createState() => _FamilySmartAgendaState();
}

class _FamilySmartAgendaState extends ConsumerState<FamilySmartAgenda> {
  String _specialty = 'Pediatria Geral';
  String _professional = 'Dra. Tia Cris';
  int _day = 10;
  String _hour = '10:00';

  @override
  Widget build(BuildContext context) {
    final List<Appointment> agenda =
        ref.watch(unitScopedMyAgendaProvider).valueOrNull ??
        const <Appointment>[];
    final bool sample = agenda.isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF4ECFF),
      body: Column(
        children: <Widget>[
          const FamilyPortalHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                if (sample)
                  const CrismedSampleBanner(
                    message:
                        'Dados de exemplo — confirmar aqui não grava na agenda clínica.',
                  ),
                const CrismedCard(
                  child: Text(
                    'Posso ajudar a escolher especialidade, profissional, data e horário. A gravação oficial continua na agenda da clínica.',
                  ),
                ),
                const SizedBox(height: 8),
                if (!sample)
                  CrismedCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfessionalAgendaScreen(),
                      ),
                    ),
                    child: Text(
                      'Minhas consultas reais: ${agenda.length}. Toque para abrir a agenda operacional.',
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  '1. Especialidade',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final String s in const <String>[
                      'Pediatria Geral',
                      'Neuropediatria',
                      'Puericultura',
                      'Sono Infantil',
                    ])
                      ChoiceChip(
                        label: Text(s),
                        selected: _specialty == s,
                        onSelected: (_) => setState(() => _specialty = s),
                      ),
                  ],
                ),
                const Text(
                  '2. Profissional',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final String s in const <String>[
                      'Dra. Tia Cris',
                      'Dr. Felipe',
                      'Dra. Ana',
                    ])
                      ChoiceChip(
                        label: Text(s),
                        selected: _professional == s,
                        onSelected: (_) => setState(() => _professional = s),
                      ),
                  ],
                ),
                Text(
                  'Data: $_day/11/2026 · horário $_hour (exemplo)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final String h in const <String>[
                      '08:00',
                      '09:30',
                      '10:00',
                      '14:00',
                      '16:00',
                    ])
                      ChoiceChip(
                        label: Text(h),
                        selected: _hour == h,
                        onSelected: (_) => setState(() => _hour = h),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => crismedToast(
                    context,
                    'Pré-seleção $_specialty · $_professional · $_day/11 $_hour. Não foi gravada na agenda.',
                  ),
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Confirmar agendamento'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.action,
                  ),
                ),
              ],
            ),
          ),
          const FamilyBottomBar(current: 'Agenda'),
        ],
      ),
    );
  }
}

class FamilyPreVisitView extends StatefulWidget {
  const FamilyPreVisitView({super.key});

  @override
  State<FamilyPreVisitView> createState() => _FamilyPreVisitViewState();
}

class _FamilyPreVisitViewState extends State<FamilyPreVisitView> {
  final Set<String> _symptoms = <String>{'Tosse'};
  String _when = '3–7 dias';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4ECFF),
      body: Column(
        children: <Widget>[
          const FamilyPortalHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                const CrismedSampleBanner(
                  message:
                      'Dados de exemplo — enviar não grava a pré-consulta clínica.',
                ),
                const CrismedCard(
                  child: Text(
                    'Conte o que está acontecendo. O formulário oficial do prontuário não é alterado por esta tela.',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paciente: Enzo Gabriel (6 anos) · consulta 10/11/2026 às 10:00 (exemplo)',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _complaint,
                  decoration: const InputDecoration(
                    labelText: 'Queixa principal',
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Há quanto tempo?'),
                Wrap(
                  spacing: 6,
                  children: <Widget>[
                    for (final String w in const <String>[
                      'Hoje',
                      '1–2 dias',
                      '3–7 dias',
                      '1–2 semanas',
                    ])
                      ChoiceChip(
                        label: Text(w),
                        selected: _when == w,
                        onSelected: (_) => setState(() => _when = w),
                      ),
                  ],
                ),
                const Text('Sintomas'),
                Wrap(
                  spacing: 6,
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
                TextField(
                  controller: _questions,
                  decoration: const InputDecoration(
                    labelText: 'Dúvidas para o médico',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Consentimento LGPD para esta pré-consulta',
                  ),
                  value: _lgpd,
                  onChanged: (bool v) => setState(() => _lgpd = v),
                ),
                FilledButton.icon(
                  onPressed: () => crismedToast(
                    context,
                    _lgpd
                        ? 'Pré-consulta de exemplo não foi enviada ao prontuário.'
                        : 'Marque o consentimento LGPD.',
                  ),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar Pré-Consulta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.action,
                  ),
                ),
              ],
            ),
          ),
          const FamilyBottomBar(current: 'Consultas'),
        ],
      ),
    );
  }
}
