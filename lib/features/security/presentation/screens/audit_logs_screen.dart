import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/permission_matrix.dart';
import '../../domain/security_access.dart';
import '../../domain/security_audit_models.dart';
import '../providers/security_providers.dart';
import '../widgets/unauthorized_access_view.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membership = ref.watch(activeClinicMembershipProvider);
    final bool allowed = SecurityAccess.canAdministerAudit(
      user: user,
      clinicMembership: membership,
    );

    if (!allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auditoria')),
        body: UnauthorizedAccessView(
          module: PermissionModule.audit,
          reason: 'Somente administrador da clinica ou plataforma.',
        ),
      );
    }

    final AsyncValue<List<SecurityAuditEvent>> logsAsync =
        ref.watch(securityAuditLogsProvider);
    final AuditLogFilterState filter = ref.watch(auditLogFilterProvider);
    final bool canExport = SecurityAccess.canExportAuditLogs(
      user: user,
      clinicMembership: membership,
    );

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Auditoria'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        actions: <Widget>[
          if (canExport)
            IconButton(
              tooltip: 'Exportar CSV',
              icon: const Icon(Icons.download_outlined),
              onPressed: () async {
                final List<SecurityAuditEvent>? logs = logsAsync.valueOrNull;
                if (logs == null || logs.isEmpty) return;
                final StringBuffer buf = StringBuffer(
                  'at,severity,actor,action,module,entityId,reason\n',
                );
                for (final SecurityAuditEvent e in logs) {
                  buf.writeln(
                    '${e.at.toIso8601String()},${e.severity.name},'
                    '${_csvEscape(e.actorName)},${e.action},${e.module},'
                    '${_csvEscape(e.entityId)},${_csvEscape(e.reason ?? '')}',
                  );
                }
                await Clipboard.setData(ClipboardData(text: buf.toString()));
                await ref.read(auditLogServiceProvider).logExport(
                      user: user,
                      membership: membership,
                      module: PermissionModule.audit,
                      entityType: 'security_audit_logs',
                      exportKind: 'csv',
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copiado para a area de transferencia.')),
                  );
                }
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _FilterBar(filter: filter),
          Expanded(
            child: logsAsync.when(
              loading: () => const LoadingState(label: 'Carregando logs…'),
              error: (Object e, StackTrace _) => ErrorState(
                failure: ServerFailure(e.toString()),
                onRetry: () => ref.invalidate(securityAuditLogsProvider),
              ),
              data: (List<SecurityAuditEvent> logs) {
                if (logs.isEmpty) {
                  return const EmptyState(
                    title: 'Nenhum evento',
                    message: 'Ajuste os filtros ou aguarde novas acoes.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final SecurityAuditEvent e = logs[index];
                    return _AuditTile(event: e);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter});

  final AuditLogFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 160,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'entityId',
                  isDense: true,
                ),
                onChanged: (String v) => ref.read(auditLogFilterProvider.notifier).state =
                    filter.copyWith(entityIdSearch: v),
              ),
            ),
            DropdownButton<String?>(
              value: filter.module,
              hint: const Text('Modulo'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                ...PermissionModule.values.map(
                  (PermissionModule m) => DropdownMenuItem<String?>(
                    value: m.name,
                    child: Text(m.name),
                  ),
                ),
              ],
              onChanged: (String? v) => ref.read(auditLogFilterProvider.notifier).state =
                  filter.copyWith(module: v, clearModule: v == null),
            ),
            DropdownButton<SecurityAuditSeverity?>(
              value: filter.severity,
              hint: const Text('Severidade'),
              items: <DropdownMenuItem<SecurityAuditSeverity?>>[
                const DropdownMenuItem<SecurityAuditSeverity?>(
                  value: null,
                  child: Text('Todas'),
                ),
                ...SecurityAuditSeverity.values.map(
                  (SecurityAuditSeverity s) => DropdownMenuItem<SecurityAuditSeverity?>(
                    value: s,
                    child: Text(s.name),
                  ),
                ),
              ],
              onChanged: (SecurityAuditSeverity? v) =>
                  ref.read(auditLogFilterProvider.notifier).state =
                      filter.copyWith(severity: v, clearSeverity: v == null),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.event});

  final SecurityAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final Color severityColor = switch (event.severity) {
      SecurityAuditSeverity.critical => AppColors.danger,
      SecurityAuditSeverity.warning => AppColors.warning,
      SecurityAuditSeverity.info => AppColors.teal,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withValues(alpha: 0.15),
          child: Icon(Icons.shield_outlined, color: severityColor, size: 20),
        ),
        title: Text('${event.action} · ${event.module}'),
        subtitle: Text(
          '${event.actorName} · ${event.at.toLocal()}\n'
          '${event.entityId.isNotEmpty ? 'Entidade: ${event.entityId}' : ''}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
