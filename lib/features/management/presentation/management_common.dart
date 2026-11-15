import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../data/management_repository.dart';

final Provider<ManagementRepository> managementRepositoryProvider =
    Provider<ManagementRepository>(
  (Ref ref) => ManagementRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

/// Vínculo ativo com a clínica (ou null). Toda a gestão parte daqui.
ClinicMembership? activeMembership(WidgetRef ref) {
  final ClinicMembership? m = ref.watch(activeClinicMembershipProvider);
  return (m != null && m.active && m.clinicId.isNotEmpty) ? m : null;
}

/// Nomes dos tipos de mensagem, iguais ao servidor (automationCore.ts).
const Map<String, String> messageKindLabels = <String, String>{
  'appointmentReminder': 'Confirmação e lembrete',
  'preVisitForm': 'Formulário de pré-consulta',
  'appointmentChange': 'Aviso de alteração',
  'waitlistOffer': 'Convite da lista de espera',
  'returnReminder': 'Lembrete de retorno',
  'noShowFollowUp': 'Acompanhamento de falta',
  'paymentReminder': 'Lembrete de pagamento',
  'satisfactionSurvey': 'Pesquisa de satisfação',
  'campaign': 'Campanha',
};

String brlFromCents(num cents) {
  final String v = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  return 'R\$ $v';
}

/// Executa uma chamada e mostra carregando / erro com nova tentativa /
/// conteúdo. Nada é simulado: sem resposta do servidor, a tela diz isso.
class CallView extends StatefulWidget {
  const CallView({
    required this.load,
    required this.builder,
    this.loadingLabel,
    super.key,
  });

  final Future<Result<Map<String, dynamic>>> Function() load;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> data,
    VoidCallback reload,
  ) builder;
  final String? loadingLabel;

  @override
  State<CallView> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  late Future<Result<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Result<Map<String, dynamic>>>(
        future: _future,
        builder: (BuildContext context,
            AsyncSnapshot<Result<Map<String, dynamic>>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return LoadingState(label: widget.loadingLabel);
          }
          final Result<Map<String, dynamic>>? r = snap.data;
          if (r == null) {
            return ErrorState(
              failure: const ServerFailure('Sem resposta do servidor.'),
              onRetry: _reload,
            );
          }
          return r.fold(
            (Map<String, dynamic> data) =>
                widget.builder(context, data, _reload),
            (Failure f) => ErrorState(failure: f, onRetry: _reload),
          );
        },
      );
}

/// Tela sem vínculo ativo com clínica (ou sem permissão para o módulo).
class ManagementUnavailable extends StatelessWidget {
  const ManagementUnavailable({required this.title, this.message, super.key});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: EmptyState(
          title: 'Indisponível para este perfil',
          message: message ??
              'Esta área depende de vínculo ativo com a clínica e do papel '
                  'correspondente.',
        ),
      );
}

/// Linha "rótulo: valor" usada nos painéis.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Cartão com título e conteúdo, largura limitada no desktop.
class PanelCard extends StatelessWidget {
  const PanelCard({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

/// Corpo rolável centralizado (até 900 px) para celular e desktop.
class ManagementBody extends StatelessWidget {
  const ManagementBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      );
}

void showResultSnack(
  BuildContext context,
  Result<Object?> r, {
  required String success,
}) {
  final String text = r.fold((_) => success, (Failure f) => f.message);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
