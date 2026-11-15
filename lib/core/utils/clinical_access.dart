import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/dev_mode.dart';
import '../error/error_mapper.dart';
import '../error/failures.dart';
import '../providers/core_providers.dart';
import '../router/routes.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../shared/domain/entities/app_user.dart';

/// Há sessão Firebase Auth (não apenas convidado DevMode).
bool hasFirebaseAuthSession(WidgetRef ref) =>
    ref.read(firebaseAuthProvider).currentUser != null;

bool hasFirebaseAuthSessionFrom(Ref ref) =>
    ref.read(firebaseAuthProvider).currentUser != null;

/// Código da recusa feita pelo próprio app na sessão de demonstração
/// (convidado sem Firebase Auth): nenhum dado clínico real é pedido.
const String guestSessionFailureCode = 'guest-session';

/// Recusa da sessão de demonstração, com o motivo real para o usuário.
PermissionFailure guestSessionFailure(String what) => PermissionFailure(
      'Você está no modo demonstração, sem login. $what só aparecem depois '
      'de entrar com uma conta profissional verificada.',
      guestSessionFailureCode,
    );

/// Mensagem de erro amigável a partir de falha de stream/provider.
///
/// Recusas geradas pelo app (demonstração, autorização do responsável
/// ausente ou vencida) já trazem o motivo e são mostradas como vieram; só a
/// recusa das regras do servidor recebe a orientação genérica.
String clinicalLoadErrorMessage(Object error) {
  final Failure failure = ErrorMapper.map(error);
  if (failure is PermissionFailure) {
    final String? code = failure.code;
    if (code == null || code == guestSessionFailureCode) {
      return failure.message;
    }
    return 'O servidor recusou o acesso a estes dados. Confira se entrou com '
        'a conta certa, se o seu registro profissional já foi verificado e se '
        'o seu vínculo com a clínica está ativo. Se acabou de receber o '
        'acesso, saia e entre de novo.';
  }
  final String raw = error.toString();
  if (raw.contains('failed-precondition') || raw.contains('requires an index')) {
    return 'Índice do Firestore ainda não está pronto. '
        'Aguarde alguns minutos ou peça ao admin para publicar os índices.';
  }
  return failure.message.isNotEmpty
      ? failure.message
      : 'Tente novamente em alguns instantes.';
}

/// Bloqueia sheet/formulário clínico antes de abrir — evita preencher à toa.
Future<bool> ensureClinicalAccessBeforeForm(
  BuildContext context,
  WidgetRef ref, {
  required String actionLabel,
}) async {
  if (!hasFirebaseAuthSession(ref)) {
    final bool? goLogin = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Conta profissional necessária'),
        content: Text(
          'Para $actionLabel é preciso entrar com uma conta profissional '
          'verificada. O modo demonstração só permite navegar a interface.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    if (goLogin == true && context.mounted) {
      DevMode.requireRealAuth = true;
      await ref.read(authRepositoryProvider).signOut();
      ref.invalidate(authStateProvider);
      if (context.mounted) context.go(Routes.loginPath);
    }
    return false;
  }

  final AppUser? user = ref.read(currentUserProvider);
  if (!(user?.canPrescribe ?? false)) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Registro não verificado'),
        content: const Text(
          'O prontuário e o cadastro de pacientes só liberam depois que a '
          'equipe confere seu CRM. Você recebe um aviso quando isso acontecer.',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
    return false;
  }

  return true;
}
