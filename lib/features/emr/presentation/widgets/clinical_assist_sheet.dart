import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../shared/domain/entities/encounter.dart';

/// Tarefas que o assistente clínico executa.
///
/// A lista é fechada e espelha o que a Function `clinicalAssist` aceita. Não há
/// campo livre para "peça o que quiser" — cada tarefa tem um prompt calibrado,
/// e um modo aberto viraria a porta pela qual pedidos fora de escopo entram.
enum ClinicalTask {
  draftProgressNote,
  summarizeEncounter,
  summarizeHistory,
  differentialConsiderations,
  matchProtocol;

  String get label => switch (this) {
        ClinicalTask.draftProgressNote => 'Redigir evolução',
        ClinicalTask.summarizeEncounter => 'Resumir consulta',
        ClinicalTask.summarizeHistory => 'Resumir histórico',
        ClinicalTask.differentialConsiderations => 'Diferenciais a considerar',
        ClinicalTask.matchProtocol => 'Protocolo aplicável',
      };

  String get description => switch (this) {
        ClinicalTask.draftProgressNote =>
          'Organiza o que você registrou em subjetivo, objetivo, avaliação '
              'e conduta.',
        ClinicalTask.summarizeEncounter =>
          'Um parágrafo denso, do tipo que se lê antes do retorno.',
        ClinicalTask.summarizeHistory =>
          'Padrões que só aparecem no conjunto dos atendimentos.',
        ClinicalTask.differentialConsiderations =>
          'Hipóteses a considerar, com o que sustenta e o que enfraquece '
              'cada uma.',
        ClinicalTask.matchProtocol =>
          'Quais protocolos cadastrados se aplicam a este caso.',
      };

  IconData get icon => switch (this) {
        ClinicalTask.draftProgressNote => Icons.edit_note_rounded,
        ClinicalTask.summarizeEncounter => Icons.subject_rounded,
        ClinicalTask.summarizeHistory => Icons.history_rounded,
        ClinicalTask.differentialConsiderations => Icons.account_tree_outlined,
        ClinicalTask.matchProtocol => Icons.rule_folder_outlined,
      };

  /// Tarefas que só fazem sentido com histórico prévio.
  bool get needsHistory => this == ClinicalTask.summarizeHistory;
}

/// Resposta do assistente.
class ClinicalAssistResult {
  const ClinicalAssistResult({
    required this.text,
    required this.refused,
    this.disclaimer,
  });

  final String text;

  /// `true` quando o servidor recusou — pedido fora do que o assistente faz.
  final bool refused;

  final String? disclaimer;
}

class ClinicalAssistController extends AutoDisposeNotifier<AsyncValue<
    ClinicalAssistResult?>> {
  @override
  AsyncValue<ClinicalAssistResult?> build() =>
      const AsyncValue<ClinicalAssistResult?>.data(null);

  Future<void> run({
    required ClinicalTask task,
    required String encounterId,
    required String patientId,
    String? note,
  }) async {
    state = const AsyncValue<ClinicalAssistResult?>.loading();

    final Result<ClinicalAssistResult> result = await guard(() async {
      final HttpsCallableResult<dynamic> response = await ref
          .read(firebaseFunctionsProvider)
          .httpsCallable(
            'clinicalAssist',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call(<String, dynamic>{
        'task': task.name,
        'encounterId': encounterId,
        'patientId': patientId,
        if (note != null && note.trim().isNotEmpty) 'freeText': note.trim(),
      });

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(response.data as Map<dynamic, dynamic>);

      return ClinicalAssistResult(
        text: (data['text'] as String?) ?? '',
        refused: (data['refused'] as bool?) ?? false,
        disclaimer: data['disclaimer'] as String?,
      );
    });

    state = result.fold(
      (ClinicalAssistResult r) =>
          AsyncValue<ClinicalAssistResult?>.data(r),
      (Failure f) => AsyncValue<ClinicalAssistResult?>.error(
        f,
        StackTrace.current,
      ),
    );
  }

  void clear() =>
      state = const AsyncValue<ClinicalAssistResult?>.data(null);
}

final AutoDisposeNotifierProvider<ClinicalAssistController,
        AsyncValue<ClinicalAssistResult?>> clinicalAssistProvider =
    NotifierProvider.autoDispose<ClinicalAssistController,
        AsyncValue<ClinicalAssistResult?>>(ClinicalAssistController.new);

/// Painel do assistente clínico, aberto a partir do editor de atendimento.
///
/// ## O texto nunca entra sozinho no prontuário
///
/// O resultado aparece em um painel separado, com dois botões: copiar e
/// inserir. Inserir **acrescenta** ao campo, não substitui — se o médico já
/// escreveu alguma coisa, o texto da IA vai depois, e ele decide o que fica.
///
/// Um assistente que sobrescreve o que o médico digitou seria um assistente
/// que apaga observação clínica.
class ClinicalAssistSheet extends ConsumerStatefulWidget {
  const ClinicalAssistSheet({
    required this.encounter,
    required this.hasHistory,
    this.onInsertToAssessment,
    this.onInsertToPlan,
    super.key,
  });

  final Encounter encounter;

  /// Se o paciente já tem atendimentos anteriores assinados.
  final bool hasHistory;

  final ValueChanged<String>? onInsertToAssessment;
  final ValueChanged<String>? onInsertToPlan;

  @override
  ConsumerState<ClinicalAssistSheet> createState() =>
      _ClinicalAssistSheetState();
}

class _ClinicalAssistSheetState extends ConsumerState<ClinicalAssistSheet> {
  final TextEditingController _note = TextEditingController();
  ClinicalTask? _running;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(ClinicalTask task) async {
    setState(() => _running = task);

    await ref.read(clinicalAssistProvider.notifier).run(
          task: task,
          encounterId: widget.encounter.id,
          patientId: widget.encounter.patientId,
          note: _note.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ClinicalAssistResult?> state =
        ref.watch(clinicalAssistProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController scroll) => Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Assistente clínico',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Trabalha sobre o que você registrou neste atendimento.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                for (final ClinicalTask task in ClinicalTask.values)
                  _TaskTile(
                    task: task,
                    enabled: !state.isLoading &&
                        (!task.needsHistory || widget.hasHistory),
                    running: state.isLoading && _running == task,
                    onTap: () => _run(task),
                  ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Observação para o assistente',
                  controller: _note,
                  hint: 'Ex.: o radiologista laudou consolidação em base '
                      'direita',
                  maxLines: 3,
                  helper: 'Opcional. Some ao que já está no prontuário.',
                ),
                const SizedBox(height: AppSpacing.xl),
                state.when(
                  loading: () => const _Thinking(),
                  error: (Object e, StackTrace s) => _ErrorBox(
                    message: e is Failure
                        ? e.message
                        : 'Não foi possível gerar o texto.',
                  ),
                  data: (ClinicalAssistResult? result) => result == null
                      ? const SizedBox.shrink()
                      : _ResultPanel(
                          result: result,
                          onInsertToAssessment: widget.onInsertToAssessment,
                          onInsertToPlan: widget.onInsertToPlan,
                        ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.enabled,
    required this.running,
    required this.onTap,
  });

  final ClinicalTask task;
  final bool enabled;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          leading: running
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(task.icon, size: 20),
          title: Text(task.label, style: theme.textTheme.titleSmall),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              enabled
                  ? task.description
                  : 'Precisa de atendimentos anteriores.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          trailing: enabled
              ? const Icon(Icons.arrow_forward_rounded, size: 16)
              : null,
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 72,
              child: Lottie.asset(
                AppAssets.lottieAiThinking,
                repeat: true,
                errorBuilder: (BuildContext context, Object error, _) =>
                    const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Lendo o prontuário...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: AppRadius.lgAll,
      ),
      child: Text(message, style: theme.textTheme.bodySmall),
    );
  }
}

/// Resultado, com as ações de aproveitamento.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    this.onInsertToAssessment,
    this.onInsertToPlan,
  });

  final ClinicalAssistResult result;
  final ValueChanged<String>? onInsertToAssessment;
  final ValueChanged<String>? onInsertToPlan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Recusa do servidor: pedido fora do que o assistente faz. Aparece com
    // aparência distinta do resultado normal, para não ser lido como conteúdo.
    if (result.refused) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                result.text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.lgAll,
          ),
          child: SelectableText(
            result.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (result.disclaimer != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.gpp_maybe_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    result.disclaimer!,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Copiado.')),
                    );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar'),
            ),
            if (onInsertToAssessment != null)
              FilledButton.tonalIcon(
                onPressed: () {
                  onInsertToAssessment!(result.text);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Acrescentar à avaliação'),
              ),
            if (onInsertToPlan != null)
              FilledButton.tonalIcon(
                onPressed: () {
                  onInsertToPlan!(result.text);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Acrescentar à conduta'),
              ),
          ],
        ),
      ],
    );
  }
}
