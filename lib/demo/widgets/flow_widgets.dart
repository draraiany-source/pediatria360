import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/dose_calculator.dart';
import '../demo_data.dart';

/// Barra de ações dos fluxos clínicos: Voltar, Cancelar, Salvar rascunho e a
/// ação principal. Em telas estreitas vira uma grade 2x2.
class DemoFlowActions extends StatelessWidget {
  const DemoFlowActions({
    super.key,
    this.onBack,
    this.onCancel,
    this.onSaveDraft,
    this.primaryLabel,
    this.onPrimary,
    this.primaryIcon,
    this.backLabel = 'Voltar',
  });

  final VoidCallback? onBack;
  final VoidCallback? onCancel;
  final VoidCallback? onSaveDraft;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final Widget back = OutlinedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(backLabel),
    );
    final Widget cancel = TextButton.icon(
      onPressed: onCancel,
      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('Cancelar'),
    );
    final Widget save = OutlinedButton.icon(
      onPressed: onSaveDraft,
      icon: const Icon(Icons.save_outlined, size: 18),
      label: const Text('Salvar rascunho'),
    );
    final Widget? primary = primaryLabel == null
        ? null
        : FilledButton.icon(
            onPressed: onPrimary,
            icon: Icon(primaryIcon ?? Icons.arrow_forward_rounded, size: 18),
            label: Text(primaryLabel!),
          );

    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                if (c.maxWidth >= 720) {
                  return Row(
                    children: <Widget>[
                      back,
                      const SizedBox(width: AppSpacing.sm),
                      if (onCancel != null) cancel,
                      const Spacer(),
                      if (onSaveDraft != null) save,
                      if (primary != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        primary,
                      ],
                    ],
                  );
                }
                Widget cell(Widget w) => Expanded(child: w);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        cell(back),
                        if (onCancel != null) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          cell(cancel),
                        ],
                      ],
                    ),
                    if (onSaveDraft != null || primary != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          if (onSaveDraft != null) cell(save),
                          if (onSaveDraft != null && primary != null)
                            const SizedBox(width: AppSpacing.sm),
                          if (primary != null) cell(primary),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Atalho "Voltar ao prontuário" para a barra do topo.
class DemoRecordShortcut extends StatelessWidget {
  const DemoRecordShortcut({required this.patientId, super.key, this.onLeave});

  final String patientId;

  /// Quando há alterações, a tela decide se pode sair.
  final Future<bool> Function()? onLeave;

  Future<void> _go(BuildContext context) async {
    if (onLeave != null && !await onLeave!()) return;
    if (context.mounted) context.go('/pacientes/$patientId/prontuario');
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 720) {
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: TextButton.icon(
          onPressed: () => _go(context),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: const Text('Voltar ao prontuário'),
        ),
      );
    }
    return IconButton(
      tooltip: 'Voltar ao prontuário',
      onPressed: () => _go(context),
      icon: const Icon(Icons.assignment_ind_outlined),
    );
  }
}

Future<bool> confirmDiscard(
  BuildContext context, {
  String title = 'Descartar alterações?',
  String message = 'O que não foi salvo como rascunho será perdido.',
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Continuar editando'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Descartar'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Faixa de identificação do paciente em alto contraste, repetida no topo
/// dos fluxos clínicos (consulta, documentos, calculadora).
class DemoPatientStrip extends StatelessWidget {
  const DemoPatientStrip({required this.patient, super.key, this.now});

  final DemoPatient patient;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime today = now ?? DateTime.now();
    final TextTheme t = Theme.of(context).textTheme;
    final String weight = patient.weightKg == null
        ? 'Peso não registrado'
        : '${formatDoseNumber(patient.weightKg!)} kg em '
              '${formatDocDate(patient.weighedAt!)}';
    const TextStyle onDark = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: AppRadius.lgAll,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.teal,
            child: Text(
              patient.name.characters.first,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  patient.name,
                  style: t.titleMedium
                      ?.merge(onDark)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${formatAgeMonths(ageInMonths(patient.birthDate, today))} · '
                  '$weight',
                  style: t.bodySmall?.copyWith(color: const Color(0xFFD7E1F5)),
                ),
              ],
            ),
          ),
          if (patient.allergies.isNotEmpty)
            Semantics(
              container: true,
              child: Tooltip(
                message: 'Alergias: ${patient.allergies.join(', ')}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE1E5),
                    borderRadius: AppRadius.pillAll,
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: Text(
                    'Alergia',
                    style: t.labelMedium?.copyWith(
                      color: const Color(0xFF9E1026),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip de status do documento.
class DocStatusChip extends StatelessWidget {
  const DocStatusChip(this.status, {super.key});

  final DocStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      DocStatus.draft => (const Color(0xFFFFEBD6), const Color(0xFF8A3A00)),
      DocStatus.reviewed => (const Color(0xFFDDE6FF), AppColors.navy),
      DocStatus.issued => (const Color(0xFFD5F2EC), const Color(0xFF0B5F55)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.pillAll),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Estado da assinatura: nunca mostra "assinado" sem registro.
class SignatureChip extends StatelessWidget {
  const SignatureChip(this.signature, {super.key});

  final SignatureInfo signature;

  @override
  Widget build(BuildContext context) {
    final bool signed = signature.isSigned;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          signed ? Icons.verified_outlined : Icons.edit_off_outlined,
          size: 16,
          color: signed ? AppColors.success : AppColors.inkMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            signature.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: signed ? AppColors.success : AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}
