import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/back_or_home_button.dart';
import '../../../../shared/domain/entities/pre_visit_questionnaire.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../telemedicine_screen.dart' show telemedicineRepositoryProvider;

/// Formulário de pré-consulta, preenchido pelo responsável antes do
/// atendimento — nunca substitui a anamnese que o profissional escreve.
///
/// Todo campo aqui é opcional: a família pode preencher só o que fizer
/// sentido para aquele motivo de consulta ("febre" não pergunta de sono
/// pra todo mundo — mas também não bloqueia quem quer registrar os dois).
/// A única validação é não deixar enviar um formulário totalmente vazio,
/// o que seria pior que não ter enviado nada.
class PreVisitQuestionnaireFormScreen extends ConsumerStatefulWidget {
  const PreVisitQuestionnaireFormScreen({
    required this.appointmentId,
    required this.childId,
    required this.professionalId,
    super.key,
  });

  final String appointmentId;
  final String childId;
  final String professionalId;

  @override
  ConsumerState<PreVisitQuestionnaireFormScreen> createState() =>
      _PreVisitQuestionnaireFormScreenState();
}

class _PreVisitQuestionnaireFormScreenState
    extends ConsumerState<PreVisitQuestionnaireFormScreen> {
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _symptoms = TextEditingController();
  final TextEditingController _feverTemperature = TextEditingController();
  final TextEditingController _feedingNotes = TextEditingController();
  final TextEditingController _sleepNotes = TextEditingController();
  final TextEditingController _eliminationNotes = TextEditingController();
  final TextEditingController _currentMedications = TextEditingController();
  final TextEditingController _allergies = TextEditingController();
  final TextEditingController _additionalNotes = TextEditingController();

  bool _hasFever = false;
  DateTime? _symptomsStartedAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Preenche com o que já existe, se a família estiver editando um
    // envio anterior — não obriga a digitar tudo de novo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  Future<void> _loadExisting() async {
    final PreVisitQuestionnaire? existing = await ref
        .read(telemedicineRepositoryProvider)
        .watchPreVisitQuestionnaire(widget.appointmentId)
        .first;
    if (existing == null || !mounted) return;

    setState(() {
      _reason.text = existing.reason;
      _symptoms.text = existing.symptoms.join(', ');
      _hasFever = existing.hasFever;
      if (existing.feverTemperatureC != null) {
        _feverTemperature.text = existing.feverTemperatureC!.toString();
      }
      _symptomsStartedAt = existing.symptomsStartedAt;
      _feedingNotes.text = existing.feedingNotes;
      _sleepNotes.text = existing.sleepNotes;
      _eliminationNotes.text = existing.eliminationNotes ?? '';
      _currentMedications.text = existing.currentMedications.join(', ');
      _allergies.text = existing.allergies.join(', ');
      _additionalNotes.text = existing.additionalNotes;
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _symptoms.dispose();
    _feverTemperature.dispose();
    _feedingNotes.dispose();
    _sleepNotes.dispose();
    _eliminationNotes.dispose();
    _currentMedications.dispose();
    _allergies.dispose();
    _additionalNotes.dispose();
    super.dispose();
  }

  List<String> _splitList(String raw) => raw
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);

  bool get _hasAnyContent =>
      _reason.text.trim().isNotEmpty ||
      _symptoms.text.trim().isNotEmpty ||
      _hasFever ||
      _feedingNotes.text.trim().isNotEmpty ||
      _sleepNotes.text.trim().isNotEmpty ||
      _eliminationNotes.text.trim().isNotEmpty ||
      _currentMedications.text.trim().isNotEmpty ||
      _allergies.text.trim().isNotEmpty ||
      _additionalNotes.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_hasAnyContent) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Preencha ao menos um campo.')),
        );
      return;
    }

    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);

    final double? fever = double.tryParse(
      _feverTemperature.text.trim().replaceAll(',', '.'),
    );

    final Result<void> result = await ref
        .read(telemedicineRepositoryProvider)
        .submitPreVisitQuestionnaire(
          appointmentId: widget.appointmentId,
          patientId: uid,
          childId: widget.childId,
          professionalId: widget.professionalId,
          reason: _reason.text.trim(),
          symptoms: _splitList(_symptoms.text),
          symptomsStartedAt: _symptomsStartedAt,
          hasFever: _hasFever,
          feverTemperatureC: _hasFever ? fever : null,
          feedingNotes: _feedingNotes.text.trim(),
          sleepNotes: _sleepNotes.text.trim(),
          eliminationNotes: _eliminationNotes.text.trim().isEmpty
              ? null
              : _eliminationNotes.text.trim(),
          currentMedications: _splitList(_currentMedications.text),
          allergies: _splitList(_allergies.text),
          additionalNotes: _additionalNotes.text.trim(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (_) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Enviado. Obrigado por preencher.')),
          );
        context.pop();
      },
      (Failure failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  Future<void> _pickSymptomsStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _symptomsStartedAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _symptomsStartedAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antes da consulta'),
        leading: IconButton(
          onPressed: () => context.popOrHome(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              'Estas informações vão direto para quem vai atender — não '
              'substituem o exame do profissional, mas ajudam a chegar mais '
              'preparado.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Motivo da consulta',
              controller: _reason,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Sintomas (separe por vírgula)',
              controller: _symptoms,
              hint: 'tosse, coriza, falta de apetite',
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _pickSymptomsStart,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _symptomsStartedAt == null
                    ? 'Quando os sintomas começaram'
                    : 'Começaram em ${Formatters.date(_symptomsStartedAt!)}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Teve febre'),
              value: _hasFever,
              onChanged: (bool v) => setState(() => _hasFever = v),
            ),
            if (_hasFever)
              AppTextField(
                label: 'Temperatura mais alta (°C)',
                controller: _feverTemperature,
                keyboardType: TextInputType.number,
                hint: '38,5',
              ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Alimentação',
              controller: _feedingNotes,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Sono',
              controller: _sleepNotes,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Eliminações (urina/fezes) — se for relevante',
              controller: _eliminationNotes,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Medicamentos em uso (separe por vírgula)',
              controller: _currentMedications,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Alergias (separe por vírgula)',
              controller: _allergies,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Outras observações',
              controller: _additionalNotes,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Enviar',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
