import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../domain/audit_log_service.dart';
import '../../domain/permission_matrix.dart';
import '../providers/security_providers.dart';

/// Exibido quando a funcao nao e permitida — registra [blockedAccess] (throttle).
class UnauthorizedAccessView extends ConsumerStatefulWidget {
  const UnauthorizedAccessView({
    super.key,
    required this.module,
    this.reason,
  });

  final PermissionModule module;
  final String? reason;

  @override
  ConsumerState<UnauthorizedAccessView> createState() =>
      _UnauthorizedAccessViewState();
}

class _UnauthorizedAccessViewState extends ConsumerState<UnauthorizedAccessView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _logDenied());
  }

  Future<void> _logDenied() async {
    final AuditLogService audit = ref.read(auditLogServiceProvider);
    await audit.logBlockedAccess(
      user: ref.read(currentUserProvider),
      membership: ref.read(activeClinicMembershipProvider),
      module: widget.module,
      reason: widget.reason,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.navy.withValues(alpha: 0.6)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Acesso nao autorizado para esta funcao.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (widget.reason != null && widget.reason!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.reason!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.65),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
