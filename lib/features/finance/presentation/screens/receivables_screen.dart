import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/state_views.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/domain/entities/commerce.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/domain/entities/clinic_organization.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart'
    show activeClinicMembershipProvider, documentClinicNameProvider;
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
        error: (Object e, _) => ErrorState(
          failure: ErrorMapper.map(e),
          onRetry: () => ref.invalidate(financeReceivablesProvider),
        ),
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
                    '${fmt.format(r.dueAt)} • ${st.label} • '
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
                      if (FinanceAccess.canManageLedger(
                        user: ref.read(currentUserProvider),
                        clinicMembership: ref.read(activeClinicMembershipProvider),
                      )) ...<PopupMenuItem<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Editar valor'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'cancel',
                          child: Text('Cancelar cobrança'),
                        ),
                        if (r.paidCents > 0)
                          const PopupMenuItem<String>(
                            value: 'receipt',
                            child: Text('Pré-visualizar recibo'),
                          ),
                      ],
                      if (r.appointmentId != null)
                        const PopupMenuItem<String>(
                          value: 'appt',
                          child: Text('Abrir agenda'),
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
    final ClinicMembership? membership =
        ref.read(activeClinicMembershipProvider);
    if (uid == null) return;

    switch (action) {
      case 'pay':
        final _PaymentInput? input = await _paymentDialog(context, r.openCents);
        if (input == null) return;
        final Result<FinanceReceivable> result = await repo.registerPayment(
          receivable: r,
          amountCents: input.cents,
          method: input.method,
          byUserId: uid,
          membership: membership,
        );
        if (context.mounted) {
          _feedback(context, result.failureOrNull, 'Pagamento registrado.');
        }
      case 'edit':
        final int? total = await _amountDialog(
          context,
          r.totalCents,
          title: 'Novo total (centavos)',
          min: r.paidCents > 0 ? r.paidCents : 1,
        );
        if (total == null) return;
        final Result<void> result = await repo.upsertReceivable(
          r.copyWith(totalCents: total, updatedAt: DateTime.now()),
          membership: membership,
        );
        if (context.mounted) {
          _feedback(context, result.failureOrNull, 'Valor atualizado.');
        }
      case 'cancel':
        if (r.paidCents > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esta cobrança já tem pagamento registrado. Use o estorno '
                'antes de cancelar.',
              ),
            ),
          );
          return;
        }
        final bool confirmed = await _confirm(
          context,
          title: 'Cancelar cobrança?',
          body: '${r.description.isNotEmpty ? r.description : r.id}\n'
              'Valor: ${formatCents(r.totalCents)}. O cancelamento fica no '
              'histórico e não pode ser desfeito por aqui.',
          action: 'Cancelar cobrança',
        );
        if (!confirmed) return;
        final Result<void> result = await repo.cancelReceivable(
          receivable: r,
          byUserId: uid,
          membership: membership,
        );
        if (context.mounted) {
          _feedback(context, result.failureOrNull, 'Cobrança cancelada.');
        }
      case 'receipt':
        final FinanceReceipt receipt = FinanceReceipt(
          id: 'preview',
          ownerId: r.ownerId,
          receivableId: r.id,
          amountCents: r.paidCents,
          method: PaymentMethodKind.other,
          issuedAt: DateTime.now(),
          patientId: r.childId,
          receiptNumber: 'PRÉVIA — SEM VALOR DE RECIBO',
        );
        final bytes = await ReceiptPdfService.build(
          receipt: receipt,
          receivable: r,
          clinicName: ref.read(documentClinicNameProvider),
        );
        if (context.mounted) {
          await Printing.layoutPdf(onLayout: (_) async => bytes);
        }
      case 'appt':
        if (r.appointmentId != null) {
          context.go(Routes.agendaPath);
        }
      case 'patient':
        if (r.childId != null) {
          context.push(Routes.clinicPatient360(r.childId!));
        }
    }
    ref.invalidate(financeReceivablesProvider);
  }

  void _feedback(BuildContext context, Failure? failure, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? success
              : 'Não foi possível concluir: ${failure.message}',
        ),
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<_PaymentInput?> _paymentDialog(
    BuildContext context,
    int openCents,
  ) async {
    final TextEditingController c = TextEditingController(text: '$openCents');
    PaymentMethodKind method = PaymentMethodKind.pix;
    String? error;
    final _PaymentInput? v = await showDialog<_PaymentInput>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: const Text('Registrar pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Em aberto: ${formatCents(openCents)}'),
              TextField(
                controller: c,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor recebido (centavos)',
                  helperText: 'Valor menor que o aberto fica como parcial.',
                ),
              ),
              DropdownButton<PaymentMethodKind>(
                value: method,
                isExpanded: true,
                items: PaymentMethodKind.values
                    .map(
                      (PaymentMethodKind m) =>
                          DropdownMenuItem<PaymentMethodKind>(
                        value: m,
                        child: Text(m.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (PaymentMethodKind? m) {
                  if (m != null) setLocal(() => method = m);
                },
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final int cents = int.tryParse(c.text) ?? 0;
                if (cents <= 0 || cents > openCents) {
                  setLocal(
                    () => error =
                        'Informe um valor entre 1 e $openCents centavos.',
                  );
                  return;
                }
                Navigator.pop(ctx, _PaymentInput(cents, method));
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    return v;
  }

  Future<int?> _amountDialog(
    BuildContext context,
    int defaultCents, {
    String title = 'Valor (centavos)',
    int min = 1,
  }) async {
    final TextEditingController c =
        TextEditingController(text: '$defaultCents');
    String? error;
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Centavos',
              errorText: error,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final int value = int.tryParse(c.text) ?? 0;
                if (value < min) {
                  setLocal(() => error = 'O valor mínimo é $min centavos.');
                  return;
                }
                Navigator.pop(ctx, value);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    return v;
  }
}

class _PaymentInput {
  const _PaymentInput(this.cents, this.method);

  final int cents;
  final PaymentMethodKind method;
}
