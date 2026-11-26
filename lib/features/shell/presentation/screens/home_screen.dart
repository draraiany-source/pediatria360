import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../crismed/presentation/crismed_dashboard.dart';
import '../../../kids/presentation/family_portal.dart';
import '../../../../shared/domain/entities/app_user.dart';

/// Home. Profissional vê o dashboard; a família vê o portal da Tia Cris.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    final bool isPro = user?.role.isProfessional ?? false;
    if (isPro) return const CrismedDashboard();
    return const FamilyHomePortal();
  }
}
