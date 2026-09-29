import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/branding/brand_logo.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/clinical_pdf.dart';
import '../../shared/clinical/pdf_output.dart';
import '../../shared/routine/child_routine.dart';
import '../demo_clinical.dart';
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/routine_widgets.dart';

String _backTo(String patientId, String? from) =>
    routineUrl(patientId, view: from == 'calendario' ? 'calendario' : 'sono');

/// Orientações que a clínica emitiu para a criança. Só versões emitidas:
/// rascunhos e textos em revisão não chegam à família.
class DemoFamilyOrientationsScreen extends StatelessWidget {
  const DemoFamilyOrientationsScreen({
    required this.patientId,
    super.key,
    this.from,
  });

  final String patientId;
  final String? from;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(patientId);
        final List<ClinicalDocRecord> docs = p == null
            ? const <ClinicalDocRecord>[]
            : demoSession.familyOrientations(p.id);
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => context.go(_backTo(patientId, from)),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Orientações da clínica'),
                if (p != null)
                  Text(
                    p.name,
                    style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          body: DemoContent(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.verified_outlined,
                  color: Color(0xFF0B6B8A),
                  text:
                      'Aqui ficam as orientações revisadas, emitidas e '
                      'liberadas pelo profissional para esta criança. Em caso '
                      'de dúvida, fale com a clínica.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (docs.isEmpty)
                  const SizedBox(
                    height: 280,
                    child: DemoEmpty(
                      title: 'Nenhuma orientação emitida',
                      message:
                          'Quando o profissional emitir uma orientação para '
                          'esta criança, ela aparece aqui.',
                    ),
                  )
                else
                  for (final ClinicalDocRecord d in docs)
                    Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        leading: const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.brand,
                        ),
                        title: Text(d.current.fields['titulo'] ?? d.title),
                        subtitle: Text(
                          'Emitida em ${formatDmy(d.current.issuedAt!)} por '
                          '${demoSession.documentAccount(d).name}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(
                          '/rotina/$patientId/orientacoes/${d.id}'
                          '${from == null ? '' : '?de=$from'}',
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Documento liberado para a família. Nas orientações abre pela lista de
/// orientações; com [anyKind], pela lista de documentos da consulta.
class DemoFamilyOrientationScreen extends StatefulWidget {
  const DemoFamilyOrientationScreen({
    required this.patientId,
    required this.docId,
    super.key,
    this.from,
    this.anyKind = false,
  });

  final String patientId;
  final String docId;
  final String? from;
  final bool anyKind;

  @override
  State<DemoFamilyOrientationScreen> createState() =>
      _DemoFamilyOrientationScreenState();
}

class _DemoFamilyOrientationScreenState
    extends State<DemoFamilyOrientationScreen> {
  bool _busy = false;

  String get _list =>
      '/rotina/${widget.patientId}/'
      '${widget.anyKind ? 'documentos' : 'orientacoes'}'
      '${widget.from == null ? '' : '?de=${widget.from}'}';

  Future<void> _pdf(
    DemoPatient p,
    ClinicalDocRecord d,
    PdfDelivery delivery,
  ) async {
    setState(() => _busy = true);
    try {
      final DateTime issued = d.current.issuedAt!;
      final DocContext ctx = DemoClinicalSeed.contextFor(
        p,
        date: DateTime(issued.year, issued.month, issued.day),
        account: demoSession.documentAccount(d),
      );
      final Uint8List bytes = await ClinicalPdf.build(
        doc: d,
        context: ctx,
        now: DateTime.now(),
        logo: demoSession.familyDocumentLogo(d)?.bytes,
        demo: true,
      );
      final String name = ClinicalPdf.fileName(d, p.name);
      final String? how = await deliverPdf(
        bytes,
        fileName: name,
        delivery: delivery,
      );
      demoSession.recordPdf(name, bytes, delivery.name);
      if (!mounted) return;
      showDemoSnack(
        context,
        how == null
            ? 'PDF gerado ($name). Saída disponível na versão web.'
            : 'PDF gerado: $name',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.routinePatient(widget.patientId);
        final ClinicalDocRecord? d = p == null
            ? null
            : widget.anyKind
            ? demoSession.familyDocumentById(p.id, widget.docId)
            : demoSession.familyOrientationById(p.id, widget.docId);
        final TextTheme t = Theme.of(context).textTheme;
        if (p == null || d == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.go(_list)),
              title: Text(widget.anyKind ? 'Documento' : 'Orientação'),
            ),
            body: widget.anyKind
                ? DemoEmpty(
                    title: 'Documento não encontrado',
                    message:
                        'Este documento não existe ou não foi liberado para '
                        'esta criança.',
                    actionLabel: 'Ver documentos',
                    onAction: () => context.go(_list),
                  )
                : DemoEmpty(
                    title: 'Orientação não encontrada',
                    message:
                        'Esta orientação não existe ou não foi emitida para '
                        'esta criança.',
                    actionLabel: 'Ver orientações',
                    onAction: () => context.go(_list),
                  ),
          );
        }
        final bool orientation = d.kind == DocKind.orientacoes;
        final String title = orientation
            ? (d.current.fields['titulo'] ?? d.title)
            : d.title;
        final DemoAccount who = demoSession.documentAccount(d);
        final BrandLogo? logo = demoSession.familyDocumentLogo(d);
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(_list)),
            title: Text(title),
          ),
          body: DemoContent(
            maxWidth: 820,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      DemoBrandMark(logo: logo, height: 44),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        title,
                        style: t.titleLarge?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${who.name} - ${who.clinic}\n'
                        '${orientation ? 'Emitida' : 'Emitido'} em '
                        '${formatDmy(d.current.issuedAt!)}',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                      const Divider(height: AppSpacing.lg),
                      SelectableText(
                        orientation
                            ? d.current.fields['texto'] ?? ''
                            : d.current.body,
                        style: t.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pdf(p, d, PdfDelivery.download),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Baixar PDF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _pdf(p, d, PdfDelivery.print),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
