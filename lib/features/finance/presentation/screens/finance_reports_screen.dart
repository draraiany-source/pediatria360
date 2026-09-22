import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/finance_aggregators.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';
import '../services/receipt_pdf_service.dart';

class FinanceReportsScreen extends ConsumerWidget {
  const FinanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatorios')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar recebiveis (CSV)'),
            subtitle: const Text('Copia para area de transferencia'),
            onTap: () => _exportReceivablesCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: const Text('Origem da receita'),
            onTap: () => _showOrigin(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Recibo exemplo (PDF)'),
            onTap: () => _samplePdf(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReceivablesCsv(BuildContext context, WidgetRef ref) async {
    final List<FinanceReceivable> list =
        ref.read(financeReceivablesProvider).valueOrNull ??
            const <FinanceReceivable>[];
    final StringBuffer sb = StringBuffer()
      ..writeln('id,descricao,total_centavos,pago_centavos,status,vencimento');
    for (final FinanceReceivable r in list) {
      sb.writeln(
        '${r.id},${r.description.replaceAll(',', ';')},'
        '${r.totalCents},${r.paidCents},${r.status.name},${r.dueAt.toIso8601String()}',
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copiado (text/csv).')),
      );
    }
  }

  void _showOrigin(BuildContext context, WidgetRef ref) {
    final List<FinanceReceivable> list =
        ref.read(financeReceivablesProvider).valueOrNull ??
            const <FinanceReceivable>[];
    final List<OriginBreakdown> rows = OriginBreakdown.fromReceivables(list);
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => ListView(
        children: rows
            .map(
              (OriginBreakdown o) => ListTile(
                title: Text(o.origin.label),
                subtitle: Text('${o.count} pagamentos'),
                trailing: Text('${(o.percent * 100).toStringAsFixed(0)}%'),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _samplePdf(BuildContext context, WidgetRef ref) async {
    final List<FinanceReceivable> list =
        ref.read(financeReceivablesProvider).valueOrNull ??
            const <FinanceReceivable>[];
    if (list.isEmpty) return;
    final FinanceReceivable r = list.first;
    final FinanceReceipt receipt = FinanceReceipt(
      id: 'sample',
      ownerId: r.ownerId,
      receivableId: r.id,
      amountCents: r.paidCents > 0 ? r.paidCents : r.totalCents,
      method: PaymentMethodKind.pix,
      issuedAt: DateTime.now(),
    );
    final bytes = await ReceiptPdfService.build(
      receipt: receipt,
      receivable: r,
      clinicName: 'Pediatria 360',
    );
    if (context.mounted) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    }
  }
}
