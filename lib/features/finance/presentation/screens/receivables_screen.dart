import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'
    show activeClinicMembershipProvider;
import '../../data/finance_repository.dart';
import '../../domain/finance_access.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_providers.dart';
import '../services/receipt_pdf_service.dart';

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({this.highlightId, super.key});

  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinanceReceivable>> async =
        ref.watch(financeReceivablesProvider);
    final DateTime now = DateTime.now();
    final DateFormat fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Contas a receber')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<FinanceReceivable> list) {
          final List<FinanceReceivable> open = list
              .where((FinanceReceivable r) => r.effectiveStatus(now).isOpen)
              .toList(growable: false);
          if (open.isEmpty) {
            return const Center(child: Text('Nenhuma conta em aberto.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: open.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              final FinanceReceivable r = open[i];
              final ReceivableStatus st = r.effectiveStatus(now);
              final bool hi = highlightId != null && r.id == highlightId;
              return Material(
                color: hi ? AppColors.brand.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  title: Text(r.description.isNotEmpty ? r.description : r.id),
                  subtitle: Text(
                    '${fmt.format(r.dueAt)} 뿯½ ${st.label} 뿯½ '
                    'Aberto ${formatCents(r.openCents)}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (String v) => _action(context, ref, r, v),
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (FinanceAccess.canRegisterPayment(
                        user: ref.read(currentUserProvider),
                        clinicMembership: ref.read(activeClinicMembershipProvider),
                      ))
                        const PopupMenuItem<String>(
                          value: 'pay',
                          child: Text('Registrar pagamento'),
                        ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Editar valor'),
                      ),
                      if (FinanceAccess.canManageLedger(
                        user: ref.read(currentUserProvider),
                        clinicMembership: ref.read(activeClinicMembershipProvider),
                      )) ...<PopupMenuItem<String>>[
                        const PopupMenuItem<String>(
                          value: 'cancel',
                          child: Text('Cancelar'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'receipt',
                          child: Text('Emitir recibo PDF'),
                        ),
                      ],
                      if (r.appointmentId != null)
                        const PopupMenuItem<String>(
                          value: 'appt',
                          child: Text('Abrir consulta'),
                        ),
                      if (r.childId != null)
                        const PopupMenuItem<String>(
                          value: 'patient',
                          child: Text('Paciente 360'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    FinanceReceivable r,
    String action,
  ) async {
    final FinanceRepository repo = ref.read(financeRepositoryProvider);
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    switch (action) {
      case 'pay':
        final int? cents = await _amountDialog(context, r.openCents);
        if (cents == null || cents <= 0) return;
        await repo.registerPayment(
          receivable: r,
          amountCents: cents,
          method: PaymentMethodKind.pix,
          byUserId: uid,
        );
      case 'edit':
        final int? total = await _amountDialog(context, r.totalCents, title: 'Novo total');
        if (total == null) return;
        await repo.upsertReceivable(r.copyWith(totalCents: total, updatedAt: DateTime.now()));
      case 'cancel':
        await repo.cancelReceivable(receivable: r, byUserId: uid);
      case 'receipt':
        final FinanceReceipt receipt = FinanceReceipt(
          id: 'preview',
          ownerId: r.ownerId,
          receivableId: r.id,
          amountCents: r.paidCents > 0 ? r.paidCents : r.totalCents,
          method: PaymentMethodKind.pix,
          issuedAt: DateTime.now(),
          patientId: r.childId,
          receiptNumber: 'PREVIEW',
        );
        final bytes = await ReceiptPdfService.build(
          receipt: receipt,
          receivable: r,
          clinicName: 'Consultorio',
        );
        if (context.mounted) {
          await Printing.layoutPdf(onLayout: (_) async => bytes);
        }
      case 'appt':
        if (r.appointmentId != null) {
          context.push(Routes.appointment(r.appointmentId!));
        }
      case 'patient':
        if (r.childId != null) {
          context.push(Routes.clinicPatient360(r.childId!));
        }
    }
    ref.invalidate(financeReceivablesProvider);
  }

  Future<int?> _amountDialog(
    BuildContext context,
    int defaultCents, {
    String title = 'Valor (centavos)',
  }) async {
    final TextEditingController c =
        TextEditingController(text: '$defaultCents');
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Centavos'),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    c.dispose();
    return v;
  }
}
