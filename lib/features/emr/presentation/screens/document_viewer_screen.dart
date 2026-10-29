import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../shared/domain/entities/encounter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../services/clinical_pdf_service.dart';
import 'patient_timeline_screen.dart';

/// Visualização de um documento clínico emitido.
///
/// ## Por que pré-visualizar antes de imprimir
///
/// Emitir manda direto para o diálogo de impressão do sistema, que é o fluxo
/// certo no momento da consulta. Mas quem abre um documento pela linha do
/// tempo — dias depois, para reenviar à escola ou conferir uma dose — precisa
/// **ver** antes de decidir o que fazer com ele.
///
/// O PDF é renderizado localmente, a partir dos dados do Firestore. Não há
/// arquivo armazenado: o documento é reconstruído a cada abertura, sempre
/// coerente com o registro. Um PDF salvo poderia divergir do dado depois de um
/// cancelamento.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({required this.document, super.key});

  final ClinicalDocument document;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState
    extends ConsumerState<DocumentViewerScreen> {
  bool _busy = false;

  ClinicalDocument get _doc => widget.document;

  Future<Uint8List> _render(_) => ClinicalPdfService.build(
        document: _doc,
        clinicName: 'Pediatria 360',
        patientBirthDateLabel: null,
      );

  Future<void> _share() async {
    setState(() => _busy = true);
    await ClinicalPdfService.share(
      document: _doc,
      clinicName: 'Pediatria 360',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    final TextEditingController reason = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Cancelar ${_doc.type.label.toLowerCase()}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'O documento continua legível, marcado como cancelado. '
              'Um documento que circulou não deixa de ter circulado — quem '
              'o receber precisa poder conferir que foi anulado.',
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: reason,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ex.: dose corrigida em nova receita',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (reason.text.trim().length < 5) return;
              Navigator.of(context).pop(true);
            },
            child: const Text('Cancelar documento'),
          ),
        ],
      ),
    );

    // O controller só existe para o campo dentro do diálogo — descarta
    // assim que ele fecha, antes de qualquer caminho de saída do método.
    final String reasonText = reason.text.trim();
    reason.dispose();

    if (!(confirmed ?? false) || !mounted) return;

    setState(() => _busy = true);

    final Result<void> result =
        await ref.read(encounterRepositoryProvider).cancelDocument(
              documentId: _doc.id,
              reason: reasonText,
            );

    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento cancelado.')),
        );
        Navigator.of(context).pop();
      },
      (Failure failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.danger,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isIssuer =
        ref.watch(currentUserProvider)?.uid == _doc.professionalId;

    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.type.label),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
        ),
        actions: <Widget>[
          if (isIssuer && !_doc.cancelled)
            IconButton(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.block_rounded),
              tooltip: 'Cancelar documento',
            ),
          IconButton(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartilhar',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatusBar(document: _doc),
          Expanded(
            child: PdfPreview(
              build: _render,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: false, // já está na barra superior
              pdfFileName:
                  '${_doc.type.label.toLowerCase().replaceAll(' ', '_')}.pdf',
              loadingWidget: const LoadingState(label: 'Montando documento...'),
              onError: (BuildContext context, Object error) => EmptyState(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Não foi possível montar o PDF',
                message: 'Tente novamente em instantes.',
              ),
            ),
          ),
          if (_doc.verificationCode != null)
            _VerificationBar(code: _doc.verificationCode!),
        ],
      ),
    );
  }
}

/// Faixa de estado: validade, cancelamento, vencimento.
///
/// Fica acima da pré-visualização porque é a primeira coisa que importa. Um
/// atestado vencido ou uma receita cancelada precisam ser identificados antes
/// de o usuário rolar o documento.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.document});

  final ClinicalDocument document;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final (Color color, IconData icon, String title, String detail) state =
        document.cancelled
            ? (
                AppColors.danger,
                Icons.block_rounded,
                'Documento cancelado',
                document.cancellationReason ?? 'Sem motivo registrado.',
              )
            : document.isExpired
                ? (
                    AppColors.inkMuted,
                    Icons.schedule_rounded,
                    'Prazo de validade encerrado',
                    'Venceu em ${Formatters.date(document.validUntil!)}.',
                  )
                : (
                    AppColors.success,
                    Icons.verified_outlined,
                    'Documento válido',
                    document.validUntil == null
                        ? 'Emitido em ${Formatters.date(document.issuedAt)}.'
                        : 'Válido até ${Formatters.date(document.validUntil!)}.',
                  );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: state.$1.withValues(alpha: 0.10),
      child: ContentBounds(
        maxWidth: 760,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(state.$2, size: 18, color: state.$1),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(state.$3, style: theme.textTheme.titleSmall),
                  Text(state.$4, style: theme.textTheme.bodySmall),
                  if (document.professionalName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        '${document.professionalName}'
                        '${document.professionalCrm != null ? ' · CRM ${document.professionalCrm}' : ''}',
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
}

/// Código de conferência, com cópia rápida.
///
/// É por ele que farmácia, escola ou empregador validam o documento sem
/// precisar de acesso ao prontuário.
class _VerificationBar extends StatelessWidget {
  const _VerificationBar({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ContentBounds(
            maxWidth: 760,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Código de conferência',
                        style: theme.textTheme.bodySmall,
                      ),
                      DataValue(value: code, size: 16),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Código copiado.')),
                        );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
