export 'closing_layouts.dart' show CrismedGrowthHubScreen;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../emr/presentation/screens/patient_timeline_screen.dart';
import '../../emr/presentation/screens/professional_patients_screen.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../telemedicine/presentation/agenda_providers.dart';
import '../../telemedicine/presentation/professional_agenda_screen.dart';

class CrismedAgendaScreen extends ConsumerStatefulWidget {
  const CrismedAgendaScreen({super.key});

  @override
  ConsumerState<CrismedAgendaScreen> createState() =>
      _CrismedAgendaScreenState();
}

class _CrismedAgendaScreenState extends ConsumerState<CrismedAgendaScreen> {
  DateTime _selected = DateTime.now();
  int _view = 0;
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Appointment>> async = ref.watch(
      unitScopedMyAgendaProvider,
    );
    final List<Appointment> all = async.valueOrNull ?? const <Appointment>[];
    final bool sample = !async.isLoading && all.isEmpty;
    final DateTime day = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
    );
    final List<Appointment> ofDay = all.where((Appointment a) {
      final DateTime d = DateTime(
        a.startsAt.year,
        a.startsAt.month,
        a.startsAt.day,
      );
      return d == day;
    }).toList();

    final List<_Slot> slots = sample
        ? const <_Slot>[
            _Slot('08:30', 'Helena Martins', 'Confirmada', true),
            _Slot('09:10', 'Miguel Alves', 'Aguardando', false),
            _Slot('09:40', 'Lívia Costa', 'Encaixe', true),
            _Slot('12:00', 'Intervalo de almoço', 'Pausa', false),
            _Slot('14:00', 'Theo Nunes', 'Confirmada', true),
          ]
        : <_Slot>[
            for (final Appointment a in ofDay)
              _Slot(
                crismedHour(a.startsAt),
                a.childName ?? 'Paciente',
                a.status.label,
                a.type == AppointmentType.teleconsulta,
              ),
            const _Slot('12:00', 'Intervalo de almoço', 'Pausa', false),
          ];

    final List<_Slot> visible = _filter == 0
        ? slots
        : slots
              .where(
                (_Slot s) =>
                    s.status ==
                    const <String>[
                      'Confirmada',
                      'Aguardando',
                      'Encaixe',
                    ][_filter - 1],
              )
              .toList();

    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Agenda operacional',
          icon: Icons.open_in_new_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ProfessionalAgendaScreen(),
            ),
          ),
        ),
        CrismedActionSpec(
          label: 'Nova consulta',
          icon: Icons.add_rounded,
          primary: true,
          onPressed: () => context.go(Routes.consultasPath),
        ),
      ],
      body: CrismedBody(
        sample: sample,
        children: <Widget>[
          CrismedPageHeader(
            title: 'Agenda inteligente',
            subtitle: _view == 0
                ? 'Visão do dia'
                : _view == 1
                ? 'Visão da semana'
                : 'Visão do mês',
            icon: Icons.calendar_month_rounded,
            primaryLabel: 'Encaixe',
            onPrimary: () => crismedToast(
              context,
              'Encaixe visual — use a agenda operacional para gravar.',
            ),
            onAi: () => crismedToast(
              context,
              'Sugestão da IA: concentrar retornos após as 14h (exemplo).',
            ),
          ),
          const SizedBox(height: 14),
          CrismedWrap(
            minWidth: 160,
            children: <Widget>[
              CrismedKpi(
                label: 'Hoje',
                value: sample ? '14' : '${ofDay.length}',
                icon: Icons.today_rounded,
                color: AppColors.brand,
              ),
              const CrismedKpi(
                label: 'Confirmadas',
                value: '9',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Aguardando',
                value: '3',
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.honey,
                delta: 'ex.',
              ),
              const CrismedKpi(
                label: 'Encaixes',
                value: '2',
                icon: Icons.schedule_rounded,
                color: AppColors.raspberry,
                delta: 'ex.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          CrismedPillTabs(
            labels: const <String>['Dia', 'Semana', 'Mês'],
            index: _view,
            onChanged: (int i) => setState(() => _view = i),
          ),
          const SizedBox(height: 12),
          if (_view == 2)
            _MonthGrid(
              selected: _selected,
              onSelect: (DateTime d) => setState(() {
                _selected = d;
                _view = 0;
              }),
            )
          else ...<Widget>[
            CrismedPillTabs(
              labels: const <String>[
                'Todos',
                'Confirmada',
                'Aguardando',
                'Encaixe',
              ],
              index: _filter,
              onChanged: (int i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            for (final _Slot slot in visible) _SlotTile(slot: slot),
          ],
          const SizedBox(height: 12),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CrismedSectionTitle('Painel IA da agenda'),
                Text(
                  'Exemplo: há uma janela de 20 min às 11h. Dois retornos de puericultura podem ser agrupados na quinta.',
                ),
                SizedBox(height: 8),
                Text(
                  'Próximos retornos: Helena (7 dias), Miguel (14 dias).',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slot {
  const _Slot(this.time, this.name, this.status, this.video);

  final String time;
  final String name;
  final String status;
  final bool video;
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot});

  final _Slot slot;

  @override
  Widget build(BuildContext context) {
    final bool pause = slot.status == 'Pausa';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CrismedCard(
        color: pause ? AppColors.softLilac : Colors.white,
        child: Row(
          children: <Widget>[
            Text(
              slot.time,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                slot.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (!pause && slot.video)
              const Icon(
                Icons.videocam_rounded,
                color: AppColors.brand,
                size: 18,
              ),
            if (!pause)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chat_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
            Text(
              slot.status,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final DateTime first = DateTime(selected.year, selected.month);
    final int days = DateTime(selected.year, selected.month + 1, 0).day;
    final int lead = first.weekday - 1;
    return CrismedCard(
      child: Column(
        children: <Widget>[
          Text(
            '${_monthName(selected.month)} ${selected.year}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (int i = 0; i < lead; i++) const SizedBox.shrink(),
              for (int d = 1; d <= days; d++)
                InkWell(
                  onTap: () =>
                      onSelect(DateTime(selected.year, selected.month, d)),
                  child: Center(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: d == selected.day
                          ? AppColors.raspberry
                          : Colors.transparent,
                      child: Text(
                        '$d',
                        style: TextStyle(
                          color: d == selected.day
                              ? Colors.white
                              : AppColors.navy,
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
    );
  }
}

String _monthName(int month) {
  const List<String> names = <String>[
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return names[month - 1];
}

class CrismedPatientsScreen extends ConsumerStatefulWidget {
  const CrismedPatientsScreen({super.key});

  @override
  ConsumerState<CrismedPatientsScreen> createState() =>
      _CrismedPatientsScreenState();
}

class _CrismedPatientsScreenState extends ConsumerState<CrismedPatientsScreen> {
  int _filter = 0;
  int _tab = 0;
  String _query = '';
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PatientSummary>> async = ref.watch(
      professionalPatientsProvider,
    );
    final List<PatientSummary> all =
        async.valueOrNull ?? const <PatientSummary>[];
    final bool sample = !async.isLoading && all.isEmpty;
    final List<PatientSummary> filtered = all.where((PatientSummary p) {
      final bool text =
          _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      final bool status = switch (_filter) {
        1 => p.encounterCount > 0,
        2 => p.hasOpenDraft || p.lastEncounterAt != null,
        3 => p.encounterCount == 0,
        _ => true,
      };
      return text && status;
    }).toList();
    final PatientSummary? current = filtered.isEmpty
        ? null
        : filtered[_selected.clamp(0, filtered.length - 1)];

    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Abrir prontuário',
          icon: Icons.folder_shared_rounded,
          primary: true,
          onPressed: current == null
              ? () => context.go(Routes.chartHubPath)
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PatientTimelineScreen(
                      patientId: current.patientId,
                      patientName: current.name,
                    ),
                  ),
                ),
        ),
      ],
      body: CrismedBody(
        sample: sample,
        children: <Widget>[
          CrismedPageHeader(
            title: 'Pacientes',
            subtitle: 'Acompanhamento pediátrico',
            icon: Icons.groups_rounded,
            primaryLabel: 'Novo paciente',
            onPrimary: () => crismedToast(
              context,
              'O cadastro real continua no fluxo de crianças e prontuário.',
            ),
            onAi: () => context.go(Routes.clinicalAiPath),
          ),
          const SizedBox(height: 14),
          CrismedWrap(
            minWidth: 160,
            children: <Widget>[
              CrismedKpi(
                label: 'Ativos',
                value: sample ? '128' : '${all.length}',
                icon: Icons.favorite_rounded,
                color: AppColors.brand,
              ),
              CrismedKpi(
                label: 'Em acompanhamento',
                value: sample
                    ? '86'
                    : '${all.where((PatientSummary p) => p.lastEncounterAt != null).length}',
                icon: Icons.timeline_rounded,
                color: AppColors.moduleLibrary,
              ),
              CrismedKpi(
                label: 'Retornos pendentes',
                value: sample
                    ? '11'
                    : '${all.where((PatientSummary p) => p.hasOpenDraft).length}',
                icon: Icons.replay_rounded,
                color: AppColors.honey,
              ),
              CrismedKpi(
                label: 'Inativos',
                value: sample
                    ? '9'
                    : '${all.where((PatientSummary p) => p.encounterCount == 0).length}',
                icon: Icons.person_off_outlined,
                color: AppColors.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar paciente',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>['Todos', 'Ativos', 'Em acomp.', 'Inativos'],
            index: _filter,
            onChanged: (int i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget list = Column(
                children: <Widget>[
                  if (sample)
                    for (final String name in const <String>[
                      'Helena Martins',
                      'Miguel Alves',
                      'Lívia Costa',
                      'Theo Nunes',
                    ])
                      _FakePatient(name: name)
                  else
                    for (int i = 0; i < filtered.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CrismedCard(
                          onTap: () => setState(() => _selected = i),
                          color: i == _selected
                              ? AppColors.softLilac
                              : Colors.white,
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                backgroundColor: AppColors.softPink,
                                child: Text(filtered[i].initials),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      filtered[i].name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      filtered[i].ageLabel.isEmpty
                                          ? 'Idade não informada'
                                          : filtered[i].ageLabel,
                                      style: const TextStyle(
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
                  if (!sample && filtered.isEmpty)
                    const Text('Nenhum paciente neste filtro.'),
                ],
              );
              final Widget detail = _PatientDetail(
                name: current?.name ?? 'Helena Martins',
                age: current?.ageLabel.isNotEmpty == true
                    ? current!.ageLabel
                    : '4 anos',
                example: current == null,
                tab: _tab,
                onTab: (int i) => setState(() => _tab = i),
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  children: <Widget>[list, const SizedBox(height: 12), detail],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 4, child: list),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: detail),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FakePatient extends StatelessWidget {
  const _FakePatient({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CrismedCard(
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: AppColors.softPink,
              child: Text(name.characters.first),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const Text(
              'Exemplo',
              style: TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientDetail extends StatelessWidget {
  const _PatientDetail({
    required this.name,
    required this.age,
    required this.example,
    required this.tab,
    required this.onTab,
  });

  final String name;
  final String age;
  final bool example;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CrismedPatientCard(
          name: name,
          age: age,
          birth: example ? '12/03/2022 (exemplo)' : 'não informado',
          weight: '16,2 kg · P50',
          height: '102 cm · P55',
          bmi: '15,6 · P48',
          exampleMetrics: true,
        ),
        const SizedBox(height: 10),
        CrismedPillTabs(
          labels: const <String>[
            'Dados',
            'Crescimento',
            'Vacinas',
            'Responsáveis',
            'Ações',
          ],
          index: tab,
          onChanged: onTab,
        ),
        const SizedBox(height: 10),
        CrismedCard(
          child: Text(switch (tab) {
            1 =>
              'Curva OMS ilustrativa. Abra Crescimento para a curva da criança cadastrada.',
            2 =>
              'Carteira ilustrativa. O calendário PNI real fica em Vacinação da criança.',
            3 => 'Responsável: Ana Martins · WhatsApp (exemplo).',
            4 => 'Próximas ações: retorno em 7 dias, vacina e curva de peso.',
            _ =>
              'Acompanhamento pediátrico, última consulta e percentis de exemplo quando não há medição ligada a este resumo.',
          }),
        ),
      ],
    );
  }
}

class CrismedConsultasScreen extends ConsumerStatefulWidget {
  const CrismedConsultasScreen({super.key});

  @override
  ConsumerState<CrismedConsultasScreen> createState() =>
      _CrismedConsultasScreenState();
}

class _CrismedConsultasScreenState
    extends ConsumerState<CrismedConsultasScreen> {
  int _tab = 0;
  int _seconds = 0;
  bool _running = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _tick() {
    if (!_running) return;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_running) return;
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
          label: 'Receita',
          icon: Icons.description_outlined,
          onPressed: () => context.go(Routes.prescriptionsPath),
        ),
        CrismedActionSpec(
          label: 'Finalizar consulta',
          icon: Icons.check_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Consulta encerrada na tela. A evolução assinada continua no prontuário real.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Fila e conduta de exemplo. A gravação clínica real fica na IA Clínica e no editor de evolução.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Consultas',
            subtitle: 'Fila do dia e atendimento',
            icon: Icons.medical_services_rounded,
            primaryLabel: _running ? 'Pausar' : 'Iniciar',
            onPrimary: () {
              setState(() => _running = !_running);
              if (_running) _tick();
            },
            onAi: () => context.go(Routes.clinicalAiPath),
          ),
          const SizedBox(height: 12),
          CrismedCard(
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Em atendimento: Helena Martins (exemplo)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  clock,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const CrismedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Fila do dia',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text('1. Helena Martins — em atendimento'),
                Text('2. Miguel Alves — aguardando'),
                Text('3. Lívia Costa — encaixe'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>[
              'Anamnese',
              'Exame físico',
              'Histórico',
              'Exames',
              'Conduta',
              'Receita',
              'Resumo IA',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 10),
          if (_tab == 0) ...<Widget>[
            const TextField(
              decoration: InputDecoration(labelText: 'Queixa principal (QP)'),
            ),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(
                labelText: 'História da doença atual (HDA)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(labelText: 'Antecedentes'),
            ),
          ] else if (_tab == 1) ...<Widget>[
            const TextField(
              decoration: InputDecoration(
                labelText: 'Peso / estatura / FC / FR / Temp',
              ),
            ),
            const SizedBox(height: 8),
            const TextField(
              decoration: InputDecoration(labelText: 'Exame físico'),
              maxLines: 3,
            ),
          ] else if (_tab == 4) ...<Widget>[
            const TextField(decoration: InputDecoration(labelText: 'CID-10')),
            const SizedBox(height: 8),
            const CrismedCard(
              child: Text(
                'Sugestão da IA para revisar (exemplo): hidratação, retorno em 48h se febre, orientar sinais de alarme. Nada disso é diagnóstico.',
              ),
            ),
          ] else
            CrismedCard(
              child: Text(
                'Conteúdo da aba ilustrativo. O prontuário assinado não é alterado por esta tela.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class CrismedChartScreen extends StatefulWidget {
  const CrismedChartScreen({super.key});

  @override
  State<CrismedChartScreen> createState() => _CrismedChartScreenState();
}

class _CrismedChartScreenState extends State<CrismedChartScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Anexo',
          icon: Icons.attach_file_rounded,
          onPressed: () => crismedToast(
            context,
            'Anexo fica no prontuário real do paciente.',
          ),
        ),
        CrismedActionSpec(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          onPressed: () => crismedToast(
            context,
            'A exportação oficial continua no visualizador de documentos.',
          ),
        ),
        CrismedActionSpec(
          label: 'Salvar evolução',
          icon: Icons.save_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'Rascunho local. Para assinar, abra o prontuário do paciente.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Evolução ilustrativa. A linha do tempo real abre pelo paciente, com as mesmas regras de acesso.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Prontuário e evolução',
            subtitle: 'SOAP, linha do tempo e documentos',
            icon: Icons.folder_shared_rounded,
            primaryLabel: 'Assinar',
            onPrimary: () => crismedToast(
              context,
              'Assinatura digital permanece no fluxo do prontuário.',
            ),
            onAi: () => context.go(Routes.clinicalAiPath),
          ),
          const SizedBox(height: 12),
          const CrismedPatientCard(
            name: 'Helena Martins',
            age: '4 anos',
            birth: '12/03/2022',
            weight: '16,2 kg · P50',
            height: '102 cm · P55',
            bmi: '15,6 · P48',
            exampleMetrics: true,
          ),
          const SizedBox(height: 10),
          CrismedPillTabs(
            labels: const <String>[
              'Evolução SOAP',
              'Histórico',
              'Anexos',
              'Exames',
              'Vacinação',
              'Crescimento',
              'Multidisciplinar',
              'Permissões',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) ...<Widget>[
            const _Soap(
              'S',
              'Subjetivo',
              'Mãe refere febre há 2 dias e tosse noturna.',
              AppColors.brand,
            ),
            const _Soap(
              'O',
              'Objetivo',
              'BEG, hidratada, ausculta limpa, orofaringe sem placas.',
              AppColors.success,
            ),
            const _Soap(
              'A',
              'Avaliação',
              'Quadro compatível com infecção de vias aéreas. Revisar.',
              AppColors.honey,
            ),
            const _Soap(
              'P',
              'Plano',
              'Hidratação, sintomáticos, retorno se piora. Sem prescrição automática.',
              AppColors.raspberry,
            ),
            const SizedBox(height: 8),
            const Text(
              'Modelos de evolução: puericultura, respiratório, retorno (exemplo).',
            ),
          ] else
            const CrismedCard(
              child: Text(
                'Linha do tempo, anexos e permissões reais continuam no prontuário do paciente. Esta aba mostra a organização visual do módulo.',
              ),
            ),
        ],
      ),
    );
  }
}

class _Soap extends StatelessWidget {
  const _Soap(this.letter, this.title, this.body, this.color);

  final String letter;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CrismedCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CrismedVaccinationScreen extends StatefulWidget {
  const CrismedVaccinationScreen({super.key});

  @override
  State<CrismedVaccinationScreen> createState() =>
      _CrismedVaccinationScreenState();
}

class _CrismedVaccinationScreenState extends State<CrismedVaccinationScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return CrismedScaffold(
      actions: <CrismedActionSpec>[
        CrismedActionSpec(
          label: 'Registrar dose',
          icon: Icons.add_rounded,
          primary: true,
          onPressed: () => crismedToast(
            context,
            'O registro da dose real fica na carteira da criança.',
          ),
        ),
      ],
      body: CrismedBody(
        sample: true,
        sampleMessage:
            'Calendário PNI de referência e carteirinha ilustrativa. Doses aplicadas continuam no cadastro da criança.',
        children: <Widget>[
          CrismedPageHeader(
            title: 'Vacinação',
            subtitle: 'PNI, particulares e carteirinha',
            icon: Icons.vaccines_rounded,
            primaryLabel: 'Carteirinha',
            onPrimary: () => setState(() => _tab = 4),
            onAi: () => crismedToast(
              context,
              'IA: revisar atraso de reforço (exemplo, sem aplicar dose).',
            ),
          ),
          const SizedBox(height: 12),
          CrismedPillTabs(
            labels: const <String>[
              'Calendário PNI',
              'Particulares',
              'Histórico',
              'Pendências',
              'Carteirinha',
              'Lotes e estoque',
              'Relatórios',
            ],
            index: _tab,
            onChanged: (int i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_tab == 4)
            const CrismedCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Carteirinha digital (exemplo)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 96,
                    color: AppColors.brand,
                  ),
                  Text('QR ilustrativo — não valida dose em campanha.'),
                ],
              ),
            )
          else if (_tab == 5)
            CrismedCard(
              onTap: () => context.go(Routes.inventoryPath),
              child: const Text(
                'Lotes e estoque usam o módulo de estoque já existente. Toque para abrir.',
              ),
            )
          else
            const Column(
              children: <Widget>[
                _Dose('BCG', 'Ao nascer', 'Aplicada'),
                _Dose('Pentavalente', '2, 4 e 6 meses', 'Pendente'),
                _Dose('Tríplice viral', '12 meses', 'Próxima'),
                _Dose('Influenza', 'Campanha', 'Particular / rede'),
              ],
            ),
        ],
      ),
    );
  }
}

class _Dose extends StatelessWidget {
  const _Dose(this.name, this.when, this.status);

  final String name;
  final String when;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CrismedCard(
        child: Row(
          children: <Widget>[
            const CrismedIconBubble(
              icon: Icons.vaccines_rounded,
              color: AppColors.raspberry,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(when, style: const TextStyle(color: AppColors.inkMuted)),
                ],
              ),
            ),
            Text(
              status,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
