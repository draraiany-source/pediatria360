import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/branding/brand_logo.dart';
import '../../shared/branding/brand_pdf.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/clinical/clinical_pdf.dart';
import '../../shared/clinical/file_input.dart';
import '../../shared/clinical/pdf_output.dart';
import '../demo_clinical.dart';
import '../demo_session.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/demo_widgets.dart';

/// Configuração da logomarca da conta em uso: enviar, visualizar, trocar e
/// remover, com a prévia do cabeçalho dos documentos.
class DemoLogoScreen extends StatefulWidget {
  const DemoLogoScreen({super.key});

  @override
  State<DemoLogoScreen> createState() => _DemoLogoScreenState();
}

class _DemoLogoScreenState extends State<DemoLogoScreen> {
  List<String> _problems = const <String>[];
  bool _busy = false;

  Future<void> _pick() async {
    final bool replacing = demoSession.myLogo != null;
    final PickedFile? f = await pickFile(accept: BrandLogoRules.accept);
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final LogoInspection check = BrandLogoRules.inspect(f.bytes);
      List<String> problems = check.problems;
      if (problems.isEmpty && !await BrandPdf.canEmbed(f.bytes)) {
        problems = const <String>[
          'A imagem não pôde ser usada no PDF; o arquivo parece corrompido.',
        ];
      }
      if (!mounted) return;
      if (problems.isNotEmpty) {
        setState(() => _problems = problems);
        showDemoSnack(context, 'Imagem não aceita. Veja o motivo na tela.');
        return;
      }
      setState(() => _problems = const <String>[]);
      final BrandLogo preview = BrandLogo(
        id: 'previa',
        ownerId: demoSession.account.id,
        bytes: f.bytes,
        format: check.format!,
        width: check.width!,
        height: check.height!,
        fileName: f.name,
        uploadedAt: DateTime.now(),
        uploadedBy: demoSession.account.name,
      );
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext c) =>
            _ConfirmLogoDialog(preview: preview, replacing: replacing),
      );
      if (ok != true || !mounted) return;
      demoSession.uploadLogo(bytes: f.bytes, fileName: f.name);
      showDemoSnack(
        context,
        replacing
            ? 'Logomarca trocada. Documentos já emitidos mantêm a anterior.'
            : 'Logomarca salva. Ela já aparece no painel e nos próximos '
                  'documentos.',
      );
    } on BrandingException catch (e) {
      if (mounted) setState(() => _problems = e.problems);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _view(BrandLogo logo) => showDialog<void>(
    context: context,
    builder: (BuildContext c) => AlertDialog(
      title: const Text('Logomarca atual'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 220,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: AppColors.line),
              ),
              child: Image.memory(
                logo.bytes,
                fit: BoxFit.contain,
                semanticLabel: 'Logomarca da conta em tamanho ampliado',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(_details(logo)),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  Future<void> _remove() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Remover logomarca?'),
        content: const Text(
          'O painel e os próximos documentos voltam a usar a identidade '
          'padrão do Pediatria360. Documentos já emitidos continuam como '
          'foram entregues.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey<String>('logo-remover-confirmar'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    demoSession.removeLogo();
    showDemoSnack(
      context,
      'Logomarca removida. Usando a identidade padrão do Pediatria360.',
    );
  }

  Future<void> _samplePdf() async {
    setState(() => _busy = true);
    try {
      final DateTime now = DateTime.now();
      final DocContext ctx = DocContext(
        patientName: 'Paciente Exemplo (fictício)',
        professionalName: demoSession.account.name,
        professionalRegistry: demoSession.account.registry,
        professionalSpecialty: demoSession.account.specialty,
        clinicName: demoSession.account.clinic,
        clinicAddress: demoSession.account.address,
        city: demoSession.account.city,
        date: DateTime(now.year, now.month, now.day),
      );
      final ClinicalDocRecord doc = ClinicalDocRecord.createDraft(
        id: 'previa',
        kind: DocKind.orientacoes,
        patientId: 'previa',
        author: demoSession.account.name,
        context: ctx,
        now: now,
        fields: const <String, String>{
          'titulo': 'Prévia do cabeçalho',
          'texto':
              'Documento de exemplo para conferir a logomarca no PDF e na '
              'impressão. Não contém dados de paciente.',
        },
      );
      final Uint8List bytes = await ClinicalPdf.build(
        doc: doc,
        context: ctx,
        now: now,
        logo: demoSession.myLogo?.bytes,
        demo: true,
      );
      const String name = 'previa-cabecalho.pdf';
      final String? how = await deliverPdf(
        bytes,
        fileName: name,
        delivery: PdfDelivery.view,
      );
      demoSession.recordPdf(name, bytes, PdfDelivery.view.name);
      if (!mounted) return;
      showDemoSnack(
        context,
        how == null
            ? 'PDF de exemplo gerado. Saída disponível na versão web.'
            : 'PDF de exemplo aberto para visualizar.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _details(BrandLogo l) =>
      'Arquivo: ${l.fileName} · ${l.format.label} · ${l.width} x ${l.height} '
      'px · ${l.sizeLabel} · enviada em ${formatDocDateTime(l.uploadedAt)} '
      'por ${l.uploadedBy}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final BrandLogo? logo = demoSession.myLogo;
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/perfil'),
            ),
            title: const Text('Logomarca'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              DemoContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    DemoNotice(
                      icon: Icons.verified_user_outlined,
                      text:
                          'A logomarca aparece no seu painel e no cabeçalho dos '
                          'documentos que você emite (receitas, atestados, '
                          'encaminhamentos, orientações e relatórios), na tela, '
                          'no PDF e na impressão. Fica vinculada só à conta '
                          '${demoSession.account.name}; outras contas não a '
                          'veem. As telas gerais continuam com a identidade do '
                          'Pediatria360.',
                    ),
                    const DemoSectionTitle('Logomarca atual'),
                    PremiumCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            height: 140,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadius.mdAll,
                              border: Border.all(color: AppColors.line),
                            ),
                            child: DemoBrandMark(logo: logo, height: 96),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            logo == null
                                ? 'Nenhuma logomarca cadastrada. O painel e os '
                                      'documentos usam a identidade padrão do '
                                      'Pediatria360.'
                                : _details(logo),
                            style: t.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              FilledButton.icon(
                                key: const ValueKey<String>('logo-enviar'),
                                onPressed: _busy ? null : _pick,
                                icon: Icon(
                                  logo == null
                                      ? Icons.upload_outlined
                                      : Icons.swap_horiz_rounded,
                                ),
                                label: Text(
                                  logo == null
                                      ? 'Enviar logomarca'
                                      : 'Trocar logomarca',
                                ),
                              ),
                              if (logo != null) ...<Widget>[
                                OutlinedButton.icon(
                                  key: const ValueKey<String>(
                                    'logo-visualizar',
                                  ),
                                  onPressed: () => _view(logo),
                                  icon: const Icon(Icons.zoom_in_rounded),
                                  label: const Text('Visualizar'),
                                ),
                                OutlinedButton.icon(
                                  key: const ValueKey<String>('logo-remover'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  onPressed: _busy ? null : _remove,
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remover'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(BrandLogoRules.summary, style: t.bodySmall),
                        ],
                      ),
                    ),
                    if (_problems.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      DemoNotice(
                        key: const ValueKey<String>('logo-erro'),
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        text: 'Imagem não aceita: ${_problems.join(' ')}',
                      ),
                    ],
                    const DemoSectionTitle(
                      'Prévia do cabeçalho dos documentos',
                    ),
                    DemoDocHeader(
                      account: demoSession.account,
                      logo: logo,
                      kindLabel: 'Receituário',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('logo-pdf-exemplo'),
                        onPressed: _busy ? null : _samplePdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Ver PDF de exemplo'),
                      ),
                    ),
                    const DemoSectionTitle('Dados profissionais nos documentos'),
                    _ProfessionalDataCard(account: demoSession.account),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Nome, registro, especialidade e endereço que saem no cabeçalho e na
/// assinatura dos documentos.
class _ProfessionalDataCard extends StatelessWidget {
  const _ProfessionalDataCard({required this.account});

  final DemoAccount account;

  Future<void> _edit(BuildContext context) async {
    final DemoAccount? next = await showDialog<DemoAccount>(
      context: context,
      builder: (BuildContext c) => _ProfessionalDataDialog(account: account),
    );
    if (next == null || !context.mounted) return;
    demoSession.updateProfessionalData(next);
    showDemoSnack(
      context,
      'Dados profissionais atualizados. Valem para os próximos documentos; '
      'os já emitidos mantêm os dados da emissão.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 120, child: Text(k, style: t.labelMedium)),
          Expanded(child: Text(v.isEmpty ? '-' : v)),
        ],
      ),
    );
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          row('Nome', account.name),
          row('Registro', account.registry),
          row('Especialidade', account.specialty),
          row('Clínica', account.clinic),
          row('Endereço', account.address),
          row('Cidade', account.city),
          row('Telefone', account.phone),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('dados-profissionais-editar'),
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar dados profissionais'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Documentos já emitidos guardam os dados da emissão e não mudam.',
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ProfessionalDataDialog extends StatefulWidget {
  const _ProfessionalDataDialog({required this.account});

  final DemoAccount account;

  @override
  State<_ProfessionalDataDialog> createState() =>
      _ProfessionalDataDialogState();
}

class _ProfessionalDataDialogState extends State<_ProfessionalDataDialog> {
  late final Map<String, TextEditingController> _c =
      <String, TextEditingController>{
        'name': TextEditingController(text: widget.account.name),
        'registry': TextEditingController(text: widget.account.registry),
        'specialty': TextEditingController(text: widget.account.specialty),
        'clinic': TextEditingController(text: widget.account.clinic),
        'address': TextEditingController(text: widget.account.address),
        'city': TextEditingController(text: widget.account.city),
        'phone': TextEditingController(text: widget.account.phone),
      };
  bool _tried = false;

  static const Map<String, String> _labels = <String, String>{
    'name': 'Nome *',
    'registry': 'Registro profissional (CRM/UF) *',
    'specialty': 'Especialidade',
    'clinic': 'Clínica ou consultório',
    'address': 'Endereço',
    'city': 'Cidade/UF',
    'phone': 'Telefone',
  };

  @override
  void dispose() {
    for (final TextEditingController c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String k) => _c[k]!.text.trim();

  bool get _valid => _v('name').length >= 3 && _v('registry').length >= 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dados profissionais'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String k in _labels.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  key: ValueKey<String>('dados-$k'),
                  controller: _c[k],
                  decoration: InputDecoration(
                    labelText: _labels[k],
                    errorText:
                        _tried &&
                            (k == 'name' || k == 'registry') &&
                            _v(k).length < 3
                        ? 'Campo obrigatório.'
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey<String>('dados-salvar'),
          onPressed: () {
            if (!_valid) {
              setState(() => _tried = true);
              return;
            }
            Navigator.of(context).pop(
              widget.account.copyWith(
                name: _v('name'),
                registry: _v('registry'),
                specialty: _v('specialty'),
                clinic: _v('clinic'),
                address: _v('address'),
                city: _v('city'),
                phone: _v('phone'),
              ),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ConfirmLogoDialog extends StatelessWidget {
  const _ConfirmLogoDialog({required this.preview, required this.replacing});

  final BrandLogo preview;
  final bool replacing;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(replacing ? 'Trocar a logomarca?' : 'Usar esta logomarca?'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                height: 150,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.line),
                ),
                child: Image.memory(
                  preview.bytes,
                  fit: BoxFit.contain,
                  semanticLabel: 'Imagem escolhida',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${preview.fileName} · ${preview.format.label} · '
                '${preview.width} x ${preview.height} px · ${preview.sizeLabel}',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Como fica no cabeçalho:',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              DemoDocHeader(
                account: demoSession.account,
                logo: preview,
                kindLabel: 'Receituário',
              ),
              if (replacing) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Documentos já emitidos continuam com a logomarca anterior.',
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey<String>('logo-confirmar'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Salvar logomarca'),
        ),
      ],
    );
  }
}
