import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/crismed_ui.dart';
import '../../../shared/domain/entities/app_user.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../emr/presentation/screens/professional_patients_screen.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../telemedicine/presentation/agenda_providers.dart';

/// Dashboard clínico no visual Crismed.
///
/// Contagens de pacientes e da agenda vêm dos providers já usados pelo
/// consultório. Gráficos, faturamento e alertas sem fonte real entram só
/// no modo de exemplo, com o aviso no topo.
class CrismedDashboard extends ConsumerWidget {
  const CrismedDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final AsyncValue<List<PatientSummary>> patientsAsync =
        ref.watch(professionalPatientsProvider);
    final AsyncValue<List<Appointment>> agendaAsync =
        ref.watch(unitScopedMyAgendaProvider);

    final List<PatientSummary> patients =
        patientsAsync.valueOrNull ?? const <PatientSummary>[];
    final List<Appointment> agenda =
        agendaAsync.valueOrNull ?? const <Appointment>[];
    final bool settled = !patientsAsync.isLoading && !agendaAsync.isLoading;
    final bool sample = settled && patients.isEmpty && agenda.isEmpty;

    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = start.add(const Duration(days: 1));
    final List<Appointment> today = agenda
        .where(
          (Appointment a) =>
              !a.startsAt.isBefore(start) && a.startsAt.isBefore(end),
        )
        .toList(growable: false)
      ..sort(
        (Appointment a, Appointment b) => a.startsAt.compareTo(b.startsAt),
      );

    final String name = user?.firstName.isNotEmpty == true
        ? 'Dra. ${user!.firstName}'
        : 'Dra. Tia Cris';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: <Widget>[
          if (sample) const CrismedSampleBanner(),
          _Greeting(
            greeting: _greeting(now),
            name: name,
            date: _longDate(now),
          ),
          const SizedBox(height: 16),
          const CrismedSectionTitle('Ações Rápidas'),
          _ShortcutRow(onOpen: (String route) => context.go(route)),
          const SizedBox(height: 16),
          CrismedWrap(
            minWidth: 170,
            children: <Widget>[
              CrismedKpi(
                label: 'Pacientes ativos',
                value: sample ? '128' : '${patients.length}',
                icon: Icons.groups_rounded,
                color: AppColors.brand,
                delta: sample ? '+4%' : null,
                onTap: () => context.go(Routes.patientsPath),
              ),
              CrismedKpi(
                label: 'Consultas hoje',
                value: sample ? '14' : '${today.length}',
                icon: Icons.event_available_rounded,
                color: AppColors.moduleAgenda,
                delta: sample ? '+8%' : null,
                onTap: () => context.go(Routes.agendaPath),
              ),
              CrismedKpi(
                label: 'Retornos',
                value: sample
                    ? '6'
                    : '${patients.where((PatientSummary p) => p.hasOpenDraft).length}',
                icon: Icons.replay_rounded,
                color: AppColors.moduleLibrary,
                delta: sample ? '-2%' : null,
                positive: false,
              ),
              CrismedKpi(
                label: 'Vacinas hoje',
                value: sample ? '5' : '—',
                icon: Icons.vaccines_rounded,
                color: AppColors.raspberry,
                delta: sample ? '+1%' : null,
                onTap: () => context.go(Routes.vaccinationHubPath),
              ),
              CrismedKpi(
                label: 'Exames pendentes',
                value: sample ? '9' : '—',
                icon: Icons.biotech_rounded,
                color: AppColors.moduleExams,
                delta: sample ? '+3%' : null,
                onTap: () => context.go(Routes.examsHubPath),
              ),
              CrismedKpi(
                label: 'Faturamento',
                value: sample ? 'R\$ 12,4 mil' : '—',
                icon: Icons.payments_rounded,
                color: AppColors.success,
                delta: sample ? '+6%' : null,
                onTap: () => context.go(Routes.financeHubPath),
              ),
              CrismedKpi(
                label: 'Resultado',
                value: sample ? 'R\$ 4,1 mil' : '—',
                icon: Icons.trending_up_rounded,
                color: AppColors.tealDeep,
                delta: sample ? '+2%' : null,
                onTap: () => context.go(Routes.reportsHubPath),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 980;
              final Widget agendaCard = _AgendaCard(
                sample: sample,
                today: today,
                onOpen: () => context.go(Routes.agendaPath),
              );
              final Widget bars = const _BarsCard();
              if (stacked) {
                return Column(
                  children: <Widget>[
                    agendaCard,
                    const SizedBox(height: 12),
                    bars,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: agendaCard),
                  const SizedBox(width: 12),
                  const Expanded(flex: 6, child: _BarsCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool stacked = constraints.maxWidth < 980;
              if (stacked) {
                return const Column(
                  children: <Widget>[
                    _DonutCard(),
                    SizedBox(height: 12),
                    _ChecklistCard(),
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _DonutCard()),
                  SizedBox(width: 12),
                  Expanded(child: _ChecklistCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const _GrowthStrip(),
          const SizedBox(height: 12),
          const _AlertsCard(),
          const CrismedClinicFooter(),
        ],
      ),
    );
  }
}

String _greeting(DateTime now) {
  if (now.hour < 12) return 'Bom dia';
  if (now.hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

String _longDate(DateTime now) {
  const List<String> days = <String>[
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  const List<String> months = <String>[
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return '${days[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}';
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.greeting,
    required this.name,
    required this.date,
  });

  final String greeting;
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$greeting, $name',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              date,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        _ChipSelect(icon: Icons.calendar_today_rounded, label: date),
        const _ChipSelect(
          icon: Icons.apartment_rounded,
          label: 'Unidade Centro (exemplo)',
        ),
      ],
    );
  }
}

class _ChipSelect extends StatelessWidget {
  const _ChipSelect({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.pillAll,
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x143C2463), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.navy,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    const List<(String, IconData, Color, String)> items =
        <(String, IconData, Color, String)>[
      ('Nova Consulta', Icons.medical_services_rounded, AppColors.brand, Routes.consultasPath),
      ('Novo Paciente', Icons.person_add_alt_1_rounded, AppColors.raspberry, Routes.patientsPath),
      ('Registrar Vacina', Icons.vaccines_rounded, AppColors.moduleVaccines, Routes.vaccinationHubPath),
      ('Atualizar Crescimento', Icons.show_chart_rounded, AppColors.success, Routes.growthHubPath),
      ('Puericultura', Icons.child_care_rounded, AppColors.moduleLibrary, Routes.childcarePath),
      ('Solicitar Exame', Icons.biotech_rounded, AppColors.moduleExams, Routes.examsHubPath),
      ('Nova Receita', Icons.description_rounded, AppColors.moduleMedications, Routes.prescriptionsPath),
      ('Emitir Atestado', Icons.verified_rounded, AppColors.honey, Routes.consultasPath),
      ('Lançamento Financeiro', Icons.payments_rounded, AppColors.tealDeep, Routes.financeHubPath),
      ('Gerar Relatório', Icons.insights_rounded, AppColors.brandSoft, Routes.reportsHubPath),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final (String, IconData, Color, String) item in items)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => onOpen(item.$4),
                borderRadius: AppRadius.lgAll,
                child: SizedBox(
                  width: 112,
                  child: Column(
                    children: <Widget>[
                      CrismedIconBubble(icon: item.$2, color: item.$3, size: 52),
                      const SizedBox(height: 6),
                      Text(
                        item.$1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.navy,
                              fontWeight: FontWeight.w700,
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

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({
    required this.sample,
    required this.today,
    required this.onOpen,
  });

  final bool sample;
  final List<Appointment> today;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, String)> rows = sample
        ? const <(String, String, String)>[
            ('08:30', 'Helena Martins', 'Confirmada'),
            ('09:00', 'Miguel Alves', 'Aguardando'),
            ('09:30', 'Lívia Costa', 'Encaixe'),
            ('10:00', 'Theo Nunes', 'Confirmada'),
          ]
        : <(String, String, String)>[
            for (final Appointment a in today.take(6))
              (
                crismedHour(a.startsAt),
                a.childName ?? 'Paciente',
                a.status.label,
              ),
          ];
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: CrismedSectionTitle('Agenda de hoje')),
              TextButton(onPressed: onOpen, child: const Text('Abrir')),
            ],
          ),
          if (rows.isEmpty)
            const Text('Nenhuma consulta no dia.')
          else
            for (final (String, String, String) row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Text(
                      row.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(row.$2)),
                    _Status(row.$3),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (label) {
      'Confirmada' => AppColors.success,
      'Encaixe' => AppColors.honey,
      _ => AppColors.brand,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _BarsCard extends StatelessWidget {
  const _BarsCard();

  @override
  Widget build(BuildContext context) {
    const List<double> values = <double>[42, 48, 45, 60, 58, 72];
    const List<String> months = <String>['Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov'];
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CrismedSectionTitle('Evolução de consultas'),
          Text(
            'Últimos 6 meses (exemplo visual)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: 80,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            months[i],
                            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: values[i],
                          width: 16,
                          color: i == values.length - 1
                              ? AppColors.raspberry
                              : AppColors.brand,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard();

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CrismedSectionTitle('Perfil dos atendimentos'),
          const Text(
            'Exemplo visual',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 42,
                sectionsSpace: 3,
                sections: <PieChartSectionData>[
                  PieChartSectionData(
                    value: 46,
                    color: AppColors.brand,
                    title: '46%',
                    radius: 28,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  PieChartSectionData(
                    value: 28,
                    color: AppColors.raspberry,
                    title: '28%',
                    radius: 28,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  PieChartSectionData(
                    value: 26,
                    color: AppColors.success,
                    title: '26%',
                    radius: 28,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Wrap(
            spacing: 12,
            children: <Widget>[
              _Legend('Consulta', AppColors.brand),
              _Legend('Retorno', AppColors.raspberry),
              _Legend('Urgência', AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
      ],
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

  @override
  Widget build(BuildContext context) {
    const List<(String, bool)> items = <(String, bool)>[
      ('Revisar retorno da Helena', true),
      ('Assinar evolução do Miguel', false),
      ('Cobrar exame da Lívia', false),
      ('Confirmar vacina de amanhã', true),
    ];
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CrismedSectionTitle('Próximas ações'),
          const Text(
            'Exemplo visual',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
          for (final (String, bool) item in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: item.$2,
              onChanged: (_) {},
              title: Text(item.$1),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.success,
            ),
        ],
      ),
    );
  }
}

class _GrowthStrip extends StatelessWidget {
  const _GrowthStrip();

  @override
  Widget build(BuildContext context) {
    return CrismedCard(
      onTap: () => context.go(Routes.growthHubPath),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CrismedSectionTitle('Crescimento e desenvolvimento'),
          Text(
            'Peso, estatura e IMC na faixa OMS — exemplo visual até haver medição da criança selecionada.',
            style: TextStyle(color: AppColors.inkMuted),
          ),
          SizedBox(height: 10),
          _Band(label: 'Peso', value: '16,2 kg · P50'),
          SizedBox(height: 6),
          _Band(label: 'Estatura', value: '102 cm · P55'),
          SizedBox(height: 6),
          _Band(label: 'IMC', value: '15,6 · P48'),
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: ClipRRect(
            borderRadius: AppRadius.pillAll,
            child: const LinearProgressIndicator(
              value: 0.55,
              minHeight: 8,
              color: AppColors.brand,
              backgroundColor: AppColors.softLilac,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
      ],
    );
  }
}

class _AlertsCard extends StatelessWidget {
  const _AlertsCard();

  @override
  Widget build(BuildContext context) {
    const List<(IconData, String, String)> alerts = <(IconData, String, String)>[
      (Icons.vaccines_outlined, 'Vacina atrasada', 'Theo Nunes · pentavalente'),
      (Icons.science_outlined, 'Exame sem laudo', 'Lívia Costa · hemograma'),
      (Icons.event_busy_outlined, 'Retorno sem confirmação', 'Miguel Alves · 7 dias'),
    ];
    return CrismedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CrismedSectionTitle('Alertas e pendências'),
          const Text(
            'Exemplo visual',
            style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final (IconData, String, String) alert in alerts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CrismedIconBubble(icon: alert.$1, color: AppColors.warning, size: 36),
              title: Text(alert.$2),
              subtitle: Text(alert.$3),
            ),
        ],
      ),
    );
  }
}
