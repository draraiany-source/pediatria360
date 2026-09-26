import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../../shared/domain/entities/visit_summary.dart';
import 'patient_timeline_screen.dart' show encounterRepositoryProvider;

/// Editor do resumo pós-consulta — rascunho até o profissional revisar e
/// liberar explicitamente. A família nunca vê o que está sendo escrito
/// aqui até o toque em "Liberar para a família".
///
/// Linguagem simples, de propósito: isto não é o prontuário técnico, é o
/// que a família vai ler em casa. Evite jargão que já foi usado na
/// anamnese/prescrição — se precisa repetir uma informação técnica aqui,
/// reescreva em linguagem comum, não copie o termo clínico.
class VisitSummaryEditorScreen extends ConsumerStatefulWidget {
  const VisitSummaryEditorScreen({
    required this.encounterId,
    required this.patientId,
    required this.professionalId,
    super.key,
  });

  final String encounterId;
  final String patientId;
  final String professionalId;

  @override
  ConsumerState<VisitSummaryEditorScreen> createState() =>
      _VisitSummaryEditorScreenState();
}

class _VisitSummaryEditorScreenState
    extends ConsumerState<VisitSummaryEditorScreen> {
  final TextEditingController _guidance = TextEditingController();
  final TextEditingController _careInstructions = TextEditingController();
  final TextEditingController _warningSigns = TextEditingController();
  final TextEditingController _followUpNotes = TextEditingController();

  DateTime? _followUpDate;
  final Set<String> _selectedDocumentIds = <String>{};
  bool _loaded = false;
  bool _saving = false;
  VisitSummaryStatus _status = VisitSummaryStatus.draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final VisitSummary? existing = await ref
        .read(encounterRepositoryProvider)
        .watchVisitSummary(widget.encounterId)
        .first;
    if (!mounted) return;

    setState(() {
      _loaded = true;
      if (existing != null) {
        _guidance.text = existing.guidance;
        _careInstructions.text = existing.careInstructions;
        _warningSigns.text = existing.warningSigns.join(', ');
        _followUpNotes.text = existing.followUpNotes;
        _followUpDate = existing.followUpDate;
        _selectedDocumentIds.addAll(existing.releasedDocumentIds);
        _status = existing.status;
      }
    });
  }

  @override
  void dispose() {
    _guidance.dispose();
    _careInstructions.dispose();
    _warningSigns.dispose();
    _followUpNotes.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);

  Future<void> _pickFollowUpDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);

    final Result<void> result = await ref
        .read(encounterRepositoryProvider)
        .saveVisitSummaryDraft(
          encounterId: widget.encounterId,
          patientId: widget.patientId,
          professionalId: widget.professionalId,
          guidance: _guidance.text.trim(),
          careInstructions: _careInstructions.text.trim(),
          warningSigns: _splitList(_warningSigns.text),
          followUpNotes: _followUpNotes.text.trim(),
          followUpDate: _followUpDate,
          releasedDocumentIds: _selectedDocumentIds.toList(growable: false),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      (_) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Rascunho salvo.'))),
      (Failure failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _finalize() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Finalizar resumo?'),
        content: const Text(
          'O conteúdo trava depois de finalizado — para mudar algo, você '
          'ainda consegue enquanto não tiver liberado para a família. '
          'Isto ainda não libera nada, só confirma que está pronto.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    // Salva o conteúdo atual antes de travar — finalizar uma versão que
    // não foi salva perderia a última edição.
    final Result<void> saveResult = await ref
        .read(encounterRepositoryProvider)
        .saveVisitSummaryDraft(
          encounterId: widget.encounterId,
          patientId: widget.patientId,
          professionalId: widget.professionalId,
          guidance: _guidance.text.trim(),
          careInstructions: _careInstructions.text.trim(),
          warningSigns: _splitList(_warningSigns.text),
          followUpNotes: _followUpNotes.text.trim(),
          followUpDate: _followUpDate,
          releasedDocumentIds: _selectedDocumentIds.toList(growable: false),
        );

    if (!mounted) return;
    final bool savedOk = saveResult.fold((_) => true, (_) => false);
    if (!savedOk) {
      setState(() => _saving = false);
      saveResult.fold(
        (_) {},
        (Failure failure) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message))),
      );
      return;
    }

    final Result<void> finalizeResult = await ref
        .read(encounterRepositoryProvider)
        .finalizeVisitSummary(widget.encounterId);

    if (!mounted) return;
    setState(() => _saving = false);

    finalizeResult.fold(
      (_) {
        setState(() => _status = VisitSummaryStatus.finalized);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Finalizado.')));
      },
      (Failure failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _release() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Liberar para a família?'),
        content: const Text(
          'A família vai poder ver este resumo a partir de agora. Depois '
          'de liberado, o conteúdo não é mais editável — uma correção '
          'passa a exigir retificação, registrada como tal.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ainda não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Liberar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    final Result<void> releaseResult = await ref
        .read(encounterRepositoryProvider)
        .releaseVisitSummary(widget.encounterId);

    if (!mounted) return;
    setState(() => _saving = false);

    releaseResult.fold(
      (_) {
        setState(() => _status = VisitSummaryStatus.released);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Liberado para a família.')),
          );
      },
      (Failure failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ClinicalDocument>> documents = ref.watch(
      _encounterDocumentsProvider(widget.encounterId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo para a família'),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  if (_status == VisitSummaryStatus.released)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 18, color: AppColors.success),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Já liberado para a família. Editar e salvar '
                              'atualiza o que a família vê.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Linguagem simples — a família vai ler isto em casa, sem '
                    'você por perto para explicar.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Orientação geral',
                    controller: _guidance,
                    enabled: _status == VisitSummaryStatus.draft,
                    maxLines: 3,
                    hint: 'O que fazer a partir de agora',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Cuidados específicos',
                    controller: _careInstructions,
                    enabled: _status == VisitSummaryStatus.draft,
                    maxLines: 3,
                    hint: 'Curativo, dieta, repouso...',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Sinais de alerta (separe por vírgula)',
                    controller: _warningSigns,
                    enabled: _status == VisitSummaryStatus.draft,
                    hint: 'febre acima de 38,5°, recusa alimentar, sonolência',
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Retorno — instruções',
                    controller: _followUpNotes,
                    enabled: _status == VisitSummaryStatus.draft,
                    maxLines: 2,
                    hint: 'Retornar se não melhorar em 3 dias',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _status == VisitSummaryStatus.draft
                        ? _pickFollowUpDate
                        : null,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _followUpDate == null
                          ? 'Data de retorno (opcional)'
                          : 'Retorno em ${Formatters.date(_followUpDate!)}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: 'Documentos a incluir',
                    eyebrow: documents.valueOrNull?.isEmpty ?? true
                        ? 'Nenhum emitido nesta consulta'
                        : 'Emitidos nesta consulta',
                  ),
                  ...?documents.valueOrNull?.map(
                    (ClinicalDocument d) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selectedDocumentIds.contains(d.id),
                      title: Text(_documentLabel(d.type)),
                      subtitle: Text(Formatters.dateTime(d.issuedAt)),
                      onChanged: _status != VisitSummaryStatus.draft
                          ? null
                          : (bool? checked) => setState(() {
                              if (checked ?? false) {
                                _selectedDocumentIds.add(d.id);
                              } else {
                                _selectedDocumentIds.remove(d.id);
                              }
                            }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (_status == VisitSummaryStatus.draft) ...<Widget>[
                    AppButton(
                      label: 'Salvar rascunho',
                      isLoading: _saving,
                      onPressed: _saveDraft,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _saving ? null : _finalize,
                      child: const Text('Finalizar'),
                    ),
                  ] else if (_status == VisitSummaryStatus.finalized)
                    AppButton(
                      label: 'Liberar para a família',
                      isLoading: _saving,
                      onPressed: _release,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.lock_outline_rounded,
                              size: 18, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Liberado — não é mais editável diretamente. '
                              'Correções precisam de retificação.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  String _documentLabel(ClinicalDocumentType type) => switch (type) {
        ClinicalDocumentType.prescription => 'Receita',
        ClinicalDocumentType.certificate => 'Atestado',
        ClinicalDocumentType.referral => 'Encaminhamento',
        ClinicalDocumentType.report => 'Relatório',
        ClinicalDocumentType.dischargeSummary => 'Resumo de alta',
        ClinicalDocumentType.examRequest => 'Pedido de exame',
      };
}

final StreamProviderFamily<List<ClinicalDocument>, String>
    _encounterDocumentsProvider =
    StreamProvider.family<List<ClinicalDocument>, String>(
  (Ref ref, String encounterId) =>
      ref.watch(encounterRepositoryProvider).watchDocuments(encounterId),
);
