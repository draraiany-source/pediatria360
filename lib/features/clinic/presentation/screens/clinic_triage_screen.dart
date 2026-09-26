import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/clinic_workflow.dart';
import '../../domain/triage_record.dart';
import '../providers/clinic_providers.dart';

/// Formulario de triagem pediatrica (sinais vitais + antropometria).
class ClinicTriageScreen extends ConsumerStatefulWidget {
  const ClinicTriageScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  ConsumerState<ClinicTriageScreen> createState() => _ClinicTriageScreenState();
}

class _ClinicTriageScreenState extends ConsumerState<ClinicTriageScreen> {
  final TextEditingController _weight = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _pc = TextEditingController();
  final TextEditingController _temp = TextEditingController();
  final TextEditingController _hr = TextEditingController();
  final TextEditingController _rr = TextEditingController();
  final TextEditingController _spo2 = TextEditingController();
  final TextEditingController _sys = TextEditingController();
  final TextEditingController _dia = TextEditingController();
  final TextEditingController _glucose = TextEditingController();
  final TextEditingController _pain = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _childId = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _weight, _height, _pc, _temp, _hr, _rr, _spo2, _sys, _dia, _glucose, _pain, _notes, _childId,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
  int? _i(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    if (_childId.text.trim().isEmpty) {
      setState(() => _error = 'Informe o ID da crianca vinculada.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final TriageRecord record = TriageRecord(
      id: '',
      appointmentId: widget.appointmentId,
      childId: _childId.text.trim(),
      professionalId: uid,
      recordedBy: uid,
      recordedAt: DateTime.now(),
      weightKg: _d(_weight),
      heightCm: _d(_height),
      headCircumferenceCm: _d(_pc),
      temperatureC: _d(_temp),
      heartRate: _i(_hr),
      respiratoryRate: _i(_rr),
      spo2: _i(_spo2),
      systolicBp: _i(_sys),
      diastolicBp: _i(_dia),
      glucoseMgDl: _d(_glucose),
      painScore: _i(_pain),
      notes: _notes.text.trim(),
    );
    final result = await ref.read(clinicRepositoryProvider).saveTriage(record);
    if (!mounted) return;
    await result.fold(
      (_) async {
        await ref.read(clinicRepositoryProvider).updateWorkflowStatus(
              widget.appointmentId,
              ClinicWorkflowStatus.waitingDoctor,
            );
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Triagem salva. Paciente aguardando medico.')),
        );
        await Navigator.of(context).maybePop();
      },
      (Failure f) async {
        setState(() {
          _saving = false;
          _error = f.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double? w = _d(_weight);
    final double? h = _d(_height);
    double? bmiPreview;
    if (w != null && h != null && h > 0) {
      final double m = h / 100.0;
      bmiPreview = w / (m * m);
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Triagem pediatrica'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            'Sinais vitais e antropometria. A interpretacao clinica e do profissional.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _childId,
            decoration: const InputDecoration(
              labelText: 'ID da crianca',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _num('Peso (kg)', _weight),
          _num('Altura (cm)', _height),
          if (bmiPreview != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'IMC calculado: ${bmiPreview.toStringAsFixed(1)}',
                style: theme.textTheme.titleSmall?.copyWith(color: AppColors.brand),
              ),
            ),
          _num('Perimetro cefalico (cm)', _pc),
          _num('Temperatura (C)', _temp),
          _num('FC (bpm)', _hr),
          _num('FR (rpm)', _rr),
          _num('SpO2 (%)', _spo2),
          _num('PA sistolica', _sys),
          _num('PA diastolica', _dia),
          _num('Glicemia (mg/dL)', _glucose),
          _num('Dor (0-10)', _pain),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observacoes',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.emergency)),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar triagem'),
          ),
        ],
      ),
    );
  }

  Widget _num(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
