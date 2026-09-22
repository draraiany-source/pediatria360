import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../telemedicine/data/telemedicine_repository.dart';
import '../../../telemedicine/presentation/telemedicine_screen.dart'
    show myAgendaProvider;
import '../../domain/finance_aggregators.dart';
import '../providers/finance_providers.dart';

class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Appointment> agenda =
        ref.watch(myAgendaProvider).valueOrNull ?? const <Appointment>[];
    final FinancePeriod period = ref.watch(financePeriodProvider);
    final ProductionReport report = ProductionReport.fromAppointments(
      appointments: agenda,
      period: period,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Producao')),
      body: report.rows.isEmpty
          ? const Center(child: Text('Sem atendimentos no periodo.'))
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: report.rows.length,
              itemBuilder: (BuildContext context, int i) {
                final ProductionReportRow row = report.rows[i];
                return ListTile(
                  title: Text(row.professionalName),
                  subtitle: Text(
                    'Consultas ${row.consults} 뿯½ Retornos ${row.returns} 뿯½ '
                    'Tele ${row.teleconsults} 뿯½ Cancel. ${row.cancellations} 뿯½ '
                    'Faltas ${row.noShows}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(formatCents(row.revenueCents)),
                      Text('Ticket ${formatCents(row.ticketCents)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
