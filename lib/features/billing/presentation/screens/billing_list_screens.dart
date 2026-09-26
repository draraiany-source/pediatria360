import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/billing_access.dart';
import '../../domain/billing_aggregators.dart';
import '../../domain/billing_models.dart';
import '../providers/billing_providers.dart';

class InsurancePlansScreen extends ConsumerWidget {
  const InsurancePlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BillingListScaffold(
      title: 'Planos e operadoras',
      allowed: BillingAccess.canManagePlans(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: ref.watch(billingPlansProvider),
      onRetry: () => ref.invalidate(billingPlansProvider),
      emptyLabel: 'Nenhum plano cadastrado.',
      itemBuilder: (InsurancePlan p) => ListTile(
        title: Text('${p.operatorName} — ${p.planName}'),
        subtitle: Text(
          p.code.isEmpty ? (p.active ? 'Ativo' : 'Inativo') : 'Codigo ${p.code}',
        ),
        trailing: p.active ? null : const Icon(Icons.pause_circle_outline),
      ),
    );
  }
}

class AuthorizationsScreen extends ConsumerWidget {
  const AuthorizationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeClinicMembershipProvider);
    final AsyncValue<List<InsuranceAuthorization>> async =
        ref.watch(billingAuthorizationsProvider);
    return _BillingListScaffold(
      title: 'Autorizacoes',
      allowed: BillingAccess.canAccessModule(
        user: user,
        clinicMembership: membership,
      ),
      async: async,
      onRetry: () => ref.invalidate(billingAuthorizationsProvider),
      emptyLabel: 'Nenhuma autorizacao.',
      itemBuilder: (InsuranceAuthorization a) {
        if (!BillingAccess.canViewAuthorization(
          user: user,
          clinicMembership: membership,
          auth: a,
        )) {
          return const SizedBox.shrink();
        }
        return ListTile(
          title: Text(a.procedureName.isEmpty ? a.procedureCode : a.procedureName),
          subtitle: Text('${a.status.name} · ${a.authNumber}'),
          trailing: Text(a.childId),
        );
      },
    );
  }
}

class GuidesScreen extends ConsumerWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BillingListScaffold(
      title: 'Guias de faturamento',
      allowed: ref.watch(billingModuleAllowedProvider),
      async: ref.watch(billingGuidesProvider),
      onRetry: () => ref.invalidate(billingGuidesProvider),
      emptyLabel: 'Nenhuma guia.',
      itemBuilder: (BillingGuide g) => ListTile(
        title: Text(g.procedureName.isEmpty ? g.type.name : g.procedureName),
        subtitle: Text('${g.status.name} · ${g.childId}'),
        trailing: Text('R\$ ${(g.amountCents / 100).toStringAsFixed(2)}'),
      ),
    );
  }
}

class BatchesScreen extends ConsumerWidget {
  const BatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BillingListScaffold(
      title: 'Lotes',
      allowed: BillingAccess.canManageBatches(
        user: ref.watch(currentUserProvider),
        clinicMembership: ref.watch(activeClinicMembershipProvider),
      ),
      async: ref.watch(billingBatchesProvider),
      onRetry: () => ref.invalidate(billingBatchesProvider),
      emptyLabel: 'Nenhum lote.',
      itemBuilder: (BillingBatch b) => ListTile(
        title: Text('Lote ${b.id.substring(0, 8)}…'),
        subtitle: Text(
          '${b.guideCount} guias · ${b.status.name}'
          '${b.protocol.isNotEmpty ? ' · ${b.protocol}' : ''}',
        ),
        trailing: Text('R\$ ${(b.totalCents / 100).toStringAsFixed(2)}'),
      ),
    );
  }
}

class GlosasScreen extends ConsumerWidget {
  const GlosasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _BillingListScaffold(
      title: 'Glosas',
      allowed: ref.watch(billingModuleAllowedProvider),
      async: ref.watch(billingGlosasProvider),
      onRetry: () => ref.invalidate(billingGlosasProvider),
      emptyLabel: 'Nenhuma glosa.',
      itemBuilder: (BillingGlosa g) => ListTile(
        title: Text(g.reason.isEmpty ? 'Glosa ${g.id}' : g.reason),
        subtitle: Text(
          '${g.status.firestoreName}'
          '${g.appealDeadline != null ? ' · prazo ${g.appealDeadline!.toLocal()}' : ''}',
        ),
        trailing: Text('R\$ ${(g.glosedCents / 100).toStringAsFixed(2)}'),
        onTap: () => _showAppealSheet(context, ref, g),
      ),
    );
  }

  void _showAppealSheet(BuildContext context, WidgetRef ref, BillingGlosa g) {
    final TextEditingController ctrl = TextEditingController(
      text: g.appealJustification,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Recurso / glosa', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Justificativa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () async {
                final String? uid = ref.read(currentUserProvider)?.uid;
                final membership = ref.read(activeClinicMembershipProvider);
                if (uid == null) return;
                if (membership == null || !membership.active) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Membership ativo obrigatorio para recurso de glosa.',
                      ),
                    ),
                  );
                  return;
                }
                await ref.read(billingRepositoryProvider).updateAppeal(
                      glosa: g,
                      status: BillingGlosaStatus.appealSent,
                      byUserId: uid,
                      justification: ctrl.text,
                      membership: membership,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(billingGlosasProvider);
              },
              child: const Text('Enviar recurso (registro interno)'),
            ),
          ],
        ),
      ),
    );
  }
}

class BillingReportsScreen extends ConsumerWidget {
  const BillingReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatorios faturamento')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Guias (CSV)'),
            onTap: () async {
              final list = ref.read(billingGuidesProvider).valueOrNull ??
                  const <BillingGuide>[];
              await Clipboard.setData(
                ClipboardData(text: BillingCsvExport.guidesCsv(list)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV de guias copiado.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Lotes (CSV)'),
            onTap: () async {
              final list = ref.read(billingBatchesProvider).valueOrNull ??
                  const <BillingBatch>[];
              await Clipboard.setData(
                ClipboardData(text: BillingCsvExport.batchesCsv(list)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV de lotes copiado.')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Glosas (CSV)'),
            onTap: () async {
              final list = ref.read(billingGlosasProvider).valueOrNull ??
                  const <BillingGlosa>[];
              await Clipboard.setData(
                ClipboardData(text: BillingCsvExport.glosasCsv(list)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV de glosas copiado.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class PatientInsuranceScreen extends ConsumerWidget {
  const PatientInsuranceScreen({this.childId, super.key});

  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PatientInsurance>> async = childId != null
        ? ref.watch(childBillingInsuranceProvider(childId!))
        : ref.watch(billingPatientInsurancesProvider);
    return _BillingListScaffold(
      title: 'Carteirinhas',
      allowed: ref.watch(billingModuleAllowedProvider),
      async: async,
      onRetry: () {
        if (childId != null) {
          ref.invalidate(childBillingInsuranceProvider(childId!));
        } else {
          ref.invalidate(billingPatientInsurancesProvider);
        }
      },
      emptyLabel: 'Nenhuma carteirinha estruturada.',
      itemBuilder: (PatientInsurance p) => ListTile(
        title: Text(p.cardNumber.isEmpty ? p.coverageType.label : p.cardNumber),
        subtitle: Text(
          'Paciente ${p.childId}'
          '${p.validUntil != null ? ' · val. ${p.validUntil!.toLocal()}' : ''}',
        ),
      ),
    );
  }
}

class _BillingListScaffold<T> extends StatelessWidget {
  const _BillingListScaffold({
    required this.title,
    required this.allowed,
    required this.async,
    required this.onRetry,
    required this.emptyLabel,
    required this.itemBuilder,
  });

  final String title;
  final bool allowed;
  final AsyncValue<List<T>> async;
  final VoidCallback onRetry;
  final String emptyLabel;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const ErrorState(
          failure: AuthFailure('Sem permissao.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => LoadingState(label: 'Carregando $title…'),
        error: (Object e, StackTrace _) => ErrorState(
          failure: ServerFailure(e.toString()),
          onRetry: onRetry,
        ),
        data: (List<T> list) {
          if (list.isEmpty) {
            return EmptyState(
              title: 'Vazio',
              message: emptyLabel,
              illustration: AppAssets.capiLupa,
              actionLabel: 'Atualizar',
              onAction: onRetry,
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) => itemBuilder(list[i]),
          );
        },
      ),
    );
  }
}
