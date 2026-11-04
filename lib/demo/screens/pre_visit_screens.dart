import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/file_input.dart';
import '../../shared/previsit/pre_visit.dart';
import '../../shared/previsit/pre_visit_summary.dart';
import '../../shared/routine/child_routine.dart' show parseDmy;
import '../demo_data.dart';
import '../demo_session.dart';
import '../widgets/ai_label.dart';
import '../widgets/demo_widgets.dart';
import 'family_health_screens.dart';

String preVisitFamilyUrl(String appointmentId, {String? from}) =>
    '/pre-consulta/$appointmentId${from == null ? '' : '?de=$from'}';

String preVisitReviewUrl(String patientId, {String? consultationId}) =>
    '/pacientes/$patientId/pre-consulta'
    '${consultationId == null ? '' : '?consulta=$consultationId'}';

String _files(int n) => n == 1 ? '1 anexo' : '$n anexos';

String _when(DateTime d) => '${demoDate(d)} às ${demoTime(d)}';

String _kind(DemoAppointmentKind k) =>
    k == DemoAppointmentKind.teleconsulta ? 'Teleconsulta' : 'Presencial';

/// Situação vista pela família.
(String, Color) familyPreVisitStatus(PreVisit? v) {
  if (v == null || (!v.isSent && !v.hasContent)) {
    return ('Não preenchida', AppColors.inkMuted);
  }
  if (!v.isSent) return ('Rascunho: a clínica ainda não vê', AppColors.warning);
  if (v.hasUnsentChanges) return ('Alterações não enviadas', AppColors.warning);
  return ('Enviada em ${_when(v.sentAt!)}', AppColors.success);
}

const List<(String, String)> _answerLabels = <(String, String)>[
  ('reason', 'Motivo da consulta'),
  ('symptoms', 'Sintomas e quando começaram'),
  ('medications', 'Medicamentos em uso'),
  ('notes', 'Outras observações'),
];

String _answer(PreVisitAnswers a, String key) => switch (key) {
  'reason' => a.reason,
  'symptoms' => a.symptoms,
  'medications' => a.medications,
  _ => a.notes,
};

// ------------------------------------------------------------ Família

class DemoPreVisitScreen extends StatefulWidget {
  const DemoPreVisitScreen({required this.appointmentId, super.key, this.from});

  final String appointmentId;

  /// `paciente` volta para a ficha da criança; senão, para o início.
  final String? from;

  @override
  State<DemoPreVisitScreen> createState() => _DemoPreVisitScreenState();
}

class _DemoPreVisitScreenState extends State<DemoPreVisitScreen> {
  late final Map<String, TextEditingController> _fields;
  bool _consent = false;
  bool _consentMissing = false;

  String get _id => widget.appointmentId;

  @override
  void initState() {
    super.initState();
    final PreVisitAnswers a =
        demoSession.preVisitForFamily(_id)?.answers ?? const PreVisitAnswers();
    _fields = <String, TextEditingController>{
      for (final (String key, String _) in _answerLabels)
        key: TextEditingController(text: _answer(a, key)),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _back {
    final DemoAppointment? a = demoSession.appointmentById(_id);
    if (widget.from == 'paciente' && a != null) {
      return '/pacientes/${a.patientId}';
    }
    if (widget.from == 'agendar') return '/agendar';
    if (widget.from == 'saude' && a != null) {
      return '/rotina/${a.patientId}/saude';
    }
    return '/inicio';
  }

  void _saveAnswers() {
    demoSession.updatePreVisitAnswers(
      _id,
      PreVisitAnswers(
        reason: _fields['reason']!.text,
        symptoms: _fields['symptoms']!.text,
        medications: _fields['medications']!.text,
        notes: _fields['notes']!.text,
      ),
    );
  }

  Future<void> _error(String message) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
      title: const Text('Arquivo não anexado'),
      content: Text(message),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );

  Future<void> _add({required bool photo}) async {
    final PickedFile? f = await pickFile(
      accept: photo ? 'image/*' : PreVisitRules.accept,
    );
    if (f == null || !mounted) return;
    final PreVisit? v = demoSession.preVisitForFamily(_id);
    if (v == null) return;
    final PreVisitFileCheck check = PreVisitRules.check(
      name: f.name,
      bytes: f.bytes,
      existing: v.attachments,
    );
    if (!check.ok) {
      await _error(check.error!);
      return;
    }
    final _Review? r = await showDialog<_Review>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _ReviewDialog(
        file: f,
        check: check,
        photo: photo,
        birth: demoSession.patientById(v.patientId)?.birthDate,
      ),
    );
    if (r == null || !mounted) return;
    try {
      demoSession.addPreVisitAttachment(
        _id,
        name: f.name,
        bytes: f.bytes,
        type: r.type,
        date: r.date,
        description: r.description,
      );
    } on StateError catch (e) {
      await _error(e.message);
      return;
    }
    if (!mounted) return;
    showDemoSnack(
      context,
      'Anexo incluído. Toque em "Enviar à clínica" para a equipe ver.',
    );
  }

  Future<void> _remove(PreVisitAttachment att) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remover anexo?'),
        content: Text(
          att.isSent
              ? '"${att.name}" já foi enviado. Ao remover, a clínica deixa de '
                    'ver este arquivo e o histórico registra a remoção.'
              : '"${att.name}" ainda não foi enviado e será descartado.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    demoSession.removePreVisitAttachment(_id, att.id);
    showDemoSnack(context, 'Anexo removido.');
  }

  void _submit() {
    _saveAnswers();
    if (!_consent) {
      setState(() => _consentMissing = true);
      return;
    }
    try {
      final int n = demoSession.submitPreVisit(_id, consent: _consent);
      setState(() => _consent = false);
      showDemoSnack(
        context,
        n == 0
            ? 'Pré-consulta enviada à clínica.'
            : 'Pré-consulta enviada à clínica com ${_files(n)}.',
      );
    } on StateError catch (e) {
      showDemoSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoAppointment? a = demoSession.appointmentById(_id);
        final PreVisit? v = demoSession.preVisitForFamily(_id);
        final DemoPatient? p = a == null
            ? null
            : demoSession.patientById(a.patientId);
        if (a == null || v == null || p == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.go('/inicio')),
              title: const Text('Pré-consulta'),
            ),
            body: const DemoEmpty(
              title: 'Pré-consulta indisponível',
              message:
                  'Este agendamento não existe ou não é de uma criança '
                  'vinculada a você.',
            ),
          );
        }
        final bool editable = demoSession.canEditPreVisit(a);
        final TextTheme t = Theme.of(context).textTheme;
        final (String status, Color statusColor) = familyPreVisitStatus(v);
        final List<PreVisitAttachment> photos = v.attachments
            .where((PreVisitAttachment x) => x.type.isPhoto)
            .toList();
        final List<PreVisitAttachment> docs = v.attachments
            .where((PreVisitAttachment x) => !x.type.isPhoto)
            .toList();
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(_back)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Pré-consulta'),
                Text(
                  p.name,
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          body: DemoContent(
            maxWidth: 820,
            child: ListView(
              key: const ValueKey<String>('pre-consulta-lista'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                PremiumCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Consulta de ${p.name}',
                        style: t.titleMedium?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('${_when(a.start)} - ${_kind(a.kind)}'),
                      const SizedBox(height: AppSpacing.sm),
                      _Status(status, color: statusColor),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const DemoNotice(
                  icon: Icons.health_and_safety_outlined,
                  color: Color(0xFF0B6B8A),
                  text: PreVisitRules.notDiagnosis,
                ),
                if (!editable) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const DemoNotice(
                    icon: Icons.lock_outline_rounded,
                    text:
                        'Consulta concluída: a pré-consulta fica apenas para '
                        'leitura.',
                  ),
                ],
                const DemoSectionTitle('Sobre a consulta'),
                for (final (String key, String label) in _answerLabels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TextField(
                      controller: _fields[key],
                      enabled: editable,
                      minLines: key == 'reason' ? 1 : 2,
                      maxLines: 5,
                      maxLength: 600,
                      decoration: InputDecoration(
                        labelText: label,
                        counterText: '',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (_) => _saveAnswers(),
                    ),
                  ),
                DemoSectionTitle(
                  'Anexos',
                  trailing: Text(
                    '${v.attachments.length}/${PreVisitRules.maxFiles} - '
                    '${PreVisitRules.sizeLabel(v.totalBytes)}',
                    style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ),
                Text(
                  PreVisitRules.summary,
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (editable)
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _add(photo: true),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Adicionar foto da queixa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _add(photo: false),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text(
                          'Adicionar exame, laudo ou relatório',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (v.attachments.isEmpty)
                  Text(
                    'Nenhum anexo. Fotos de lesões de pele ou alterações '
                    'visíveis e exames recentes ajudam a preparar a consulta.',
                    style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                if (photos.isNotEmpty) ...<Widget>[
                  _GroupLabel('Fotos da queixa (${photos.length})'),
                  for (final PreVisitAttachment x in photos)
                    _AttachmentTile(
                      att: x,
                      showStatus: true,
                      onView: () => showPreVisitAttachment(context, x),
                      onRemove: editable ? () => _remove(x) : null,
                    ),
                ],
                if (docs.isNotEmpty) ...<Widget>[
                  _GroupLabel('Exames, laudos e relatórios (${docs.length})'),
                  for (final PreVisitAttachment x in docs)
                    _AttachmentTile(
                      att: x,
                      showStatus: true,
                      onView: () => showPreVisitAttachment(context, x),
                      onRemove: editable ? () => _remove(x) : null,
                    ),
                ],
                if (editable) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (bool? on) => setState(() {
                      _consent = on ?? false;
                      if (_consent) _consentMissing = false;
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Autorizo o envio destas informações e anexos à equipe '
                      'da clínica que atende ${p.name}.',
                    ),
                  ),
                  if (_consentMissing)
                    Text(
                      'Confirme que as informações e os anexos podem ser '
                      'enviados à equipe da clínica, marcando a autorização '
                      'acima.',
                      style: t.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: v.hasUnsentChanges ? _submit : null,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      v.isSent ? 'Enviar alterações' : 'Enviar à clínica',
                    ),
                  ),
                  if (!v.hasUnsentChanges && v.isSent)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Tudo enviado. Se algo mudar, edite e envie de novo.',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                ],
                if (editable) ...<Widget>[
                  const DemoSectionTitle('Orientações da clínica'),
                  DemoVisitGuidance(appointment: a),
                ],
                if (v.history.isNotEmpty) ...<Widget>[
                  const DemoSectionTitle('Histórico'),
                  _History(v.history),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Review {
  const _Review(this.type, this.date, this.description);

  final PreVisitDocType type;
  final DateTime? date;
  final String description;
}

/// Conferência do arquivo antes de incluir: prévia, tipo e data.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({
    required this.file,
    required this.check,
    required this.photo,
    this.birth,
  });

  final PickedFile file;
  final PreVisitFileCheck check;
  final bool photo;
  final DateTime? birth;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  PreVisitDocType? _type;
  final TextEditingController _date = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String? _typeError;
  String? _dateError;

  PreVisitFormat get _format => widget.check.format!;

  @override
  void initState() {
    super.initState();
    if (widget.photo && _format.isImage) _type = PreVisitDocType.fotoQueixa;
  }

  @override
  void dispose() {
    _date.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = demoSession.now;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime first = widget.birth ?? DateTime(now.year - 18);
    DateTime initial = parseDmy(_date.text) ?? today;
    if (initial.isAfter(today)) initial = today;
    if (initial.isBefore(first)) initial = first;
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      helpText: _type?.dateLabel ?? 'Data',
    );
    if (d == null) return;
    setState(() {
      _date.text = demoDate(d);
      _dateError = null;
    });
  }

  void _submit() {
    final PreVisitDocType? type = _type;
    final String? typeError = type == null
        ? 'Escolha o tipo do documento.'
        : PreVisitRules.typeError(type, _format);
    DateTime? date;
    String? dateError;
    if (_date.text.trim().isNotEmpty) {
      date = parseDmy(_date.text);
      if (date == null) dateError = 'Data inválida. Use dd/mm/aaaa.';
    }
    if (dateError == null && type != null) {
      dateError = PreVisitRules.dateError(
        type,
        date,
        today: demoSession.now,
        birth: widget.birth,
      );
    }
    setState(() {
      _typeError = typeError;
      _dateError = dateError;
    });
    if (typeError != null || dateError != null) return;
    Navigator.of(context).pop(_Review(type!, date, _description.text));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final PreVisitDocType? type = _type;
    final String size = PreVisitRules.sizeLabel(widget.file.bytes.length);
    return AlertDialog(
      scrollable: true,
      title: const Text('Conferir anexo antes de incluir'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Preview(
              name: widget.file.name,
              format: _format,
              bytes: widget.file.bytes,
              pages: widget.check.pages,
              height: 220,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.file.name} - ${_format.label} - $size',
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Tipo de documento *', style: t.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final PreVisitDocType k in PreVisitDocType.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: type == k,
                    onSelected: k.isPhoto && !_format.isImage
                        ? null
                        : (_) => setState(() {
                            _type = k;
                            _typeError = null;
                            _dateError = null;
                          }),
                  ),
              ],
            ),
            if (type != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  type.hint,
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ),
            if (_typeError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _typeError!,
                  style: t.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _date,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: type == null
                    ? 'Data do exame'
                    : '${type.dateLabel}${type.dateRequired ? ' *' : ' (opcional)'}',
                hintText: 'dd/mm/aaaa',
                errorText: _dateError,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Escolher no calendário',
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              onChanged: (_) {
                if (_dateError != null) setState(() => _dateError = null);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _description,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex.: mancha no braço, hemograma',
                border: OutlineInputBorder(),
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
        FilledButton(onPressed: _submit, child: const Text('Incluir anexo')),
      ],
    );
  }
}

/// Imagem ampliável ou, para PDF, o botão que abre o arquivo original.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.name,
    required this.format,
    required this.bytes,
    required this.height,
    this.pages,
  });

  final String name;
  final PreVisitFormat format;
  final Uint8List bytes;
  final double height;
  final int? pages;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    if (format.isImage) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FA),
          borderRadius: AppRadius.smAll,
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            semanticLabel: 'Prévia de $name',
            errorBuilder: (BuildContext context, Object e, StackTrace? s) =>
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Não foi possível mostrar esta imagem. Confira se o '
                      'arquivo abre no aparelho ou escolha outro.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          ),
        ),
      );
    }
    final String pageText = pages == null
        ? 'PDF'
        : 'PDF com $pages página${pages == 1 ? '' : 's'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.picture_as_pdf_outlined,
            size: 48,
            color: AppColors.danger,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(pageText, style: t.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () {
              final bool ok = openFileInNewTab(bytes, format.mimeType);
              if (!ok) {
                showDemoSnack(
                  context,
                  'O navegador bloqueou a nova aba. Permita pop-ups para '
                  'conferir o PDF.',
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Abrir PDF para conferir'),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Resumo por regras, com a etiqueta de texto de assistente.
class _OrganizedSummary extends StatelessWidget {
  const _OrganizedSummary({required this.summary});

  final PreVisitSummary summary;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey<String>('resumo-organizado'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.honey.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.honey.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Resumo organizado', style: t.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          const DemoAiLabel(detail: false),
          const SizedBox(height: AppSpacing.xs),
          Text(
            PreVisitSummary.notice,
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          if (summary.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm),
              child: Text('A família enviou sem respostas nem anexos.'),
            ),
          for (final PreVisitSummarySection s in summary.sections) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.title,
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final String i in s.items) Text('•  $i', style: t.bodyMedium),
          ],
          if (summary.attachmentLine.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Anexos: ${summary.attachmentLine}',
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (summary.checks.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Para conferir',
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final String c in summary.checks)
              Text('•  $c', style: t.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.att,
    required this.onView,
    this.onRemove,
    this.showStatus = false,
  });

  final PreVisitAttachment att;
  final VoidCallback onView;
  final VoidCallback? onRemove;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final DateTime? d = att.date;
    final String title = att.description.isEmpty
        ? att.type.label
        : att.description;
    final String pages = att.pages == null ? '' : ', ${att.pages} pág.';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Thumb(att: att),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: t.titleSmall),
                      Text(
                        '${att.type.label} - ${att.type.dateLabel}: '
                        '${d == null ? 'não informada' : demoDate(d)}',
                        style: t.bodySmall,
                      ),
                      Text(
                        '${att.name} (${att.format.label}$pages, '
                        '${att.sizeLabel})',
                        style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                      ),
                      if (showStatus)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: _Status(
                            att.isSent
                                ? 'Enviado em ${_when(att.sentAt!)}'
                                : 'Ainda não enviado',
                            color: att.isSent
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('Ver', semanticsLabel: 'Ver ${att.name}'),
                  ),
                  if (onRemove != null)
                    TextButton.icon(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        'Remover',
                        semanticsLabel: 'Remover ${att.name}',
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.att});

  final PreVisitAttachment att;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: Container(
        width: 56,
        height: 56,
        color: const Color(0xFFF4F6FA),
        child: att.format.isImage
            ? Image.memory(
                att.bytes,
                fit: BoxFit.cover,
                cacheWidth: 112,
                excludeFromSemantics: true,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    const Icon(Icons.broken_image_outlined),
              )
            : const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
                size: 32,
              ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History(this.events);

  final List<PreVisitEvent> events;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final PreVisitEvent e in events.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${_when(e.at)} - ${e.text}',
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }
}

/// Visualização do anexo (família e profissional autorizado).
Future<void> showPreVisitAttachment(
  BuildContext context,
  PreVisitAttachment att,
) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final TextTheme t = Theme.of(context).textTheme;
      final DateTime? d = att.date;
      return AlertDialog(
        scrollable: true,
        title: Text(att.description.isEmpty ? att.type.label : att.description),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Preview(
                name: att.name,
                format: att.format,
                bytes: att.bytes,
                pages: att.pages,
                height: 420,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${att.type.label} - ${att.type.dateLabel}: '
                '${d == null ? 'não informada' : demoDate(d)}\n'
                '${att.name} (${att.format.label}, ${att.sizeLabel})',
                style: t.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              const DemoNotice(
                icon: Icons.info_outline_rounded,
                text:
                    'Arquivo enviado pela família. Não é diagnóstico nem '
                    'resultado validado.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      );
    },
  );
}

/// Próximas consultas das crianças do responsável, no início.
class DemoFamilyUpcomingVisits extends StatelessWidget {
  const DemoFamilyUpcomingVisits({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final List<(DemoPatient, DemoAppointment)> items =
        <(DemoPatient, DemoAppointment)>[
          for (final DemoPatient p in demoSession.visiblePatients)
            for (final DemoAppointment a in demoSession.upcomingAppointmentsFor(
              p.id,
            ))
              (p, a),
        ]..sort(
          (
            (DemoPatient, DemoAppointment) x,
            (DemoPatient, DemoAppointment) y,
          ) => x.$2.start.compareTo(y.$2.start),
        );
    if (items.isEmpty) {
      return Text(
        'Nenhuma consulta marcada.',
        style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
      );
    }
    return Column(
      children: <Widget>[
        for (final (DemoPatient p, DemoAppointment a) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PremiumCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Builder(
                builder: (BuildContext context) {
                  final PreVisit? v = demoSession.preVisits[a.id];
                  final (String status, Color color) = familyPreVisitStatus(v);
                  final bool started = v != null && (v.isSent || v.hasContent);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${p.name} - ${_when(a.start)}',
                        style: t.titleSmall,
                      ),
                      Text(_kind(a.kind), style: t.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      _Status('Pré-consulta: $status', color: color),
                      const SizedBox(height: AppSpacing.sm),
                      DemoVisitGuidance(appointment: a),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            context.go(preVisitFamilyUrl(a.id, from: 'inicio')),
                        icon: const Icon(Icons.assignment_outlined),
                        label: Text(
                          started
                              ? 'Abrir pré-consulta de ${demoDate(a.start)}'
                              : 'Preencher pré-consulta de ${demoDate(a.start)}',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Clínica

/// Resumo na consulta e na ficha: só o profissional autorizado.
class DemoPreVisitCard extends StatelessWidget {
  const DemoPreVisitCard({
    required this.patientId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String? consultationId;

  @override
  Widget build(BuildContext context) {
    if (!demoSession.canReviewPreVisits) return const SizedBox.shrink();
    final TextTheme t = Theme.of(context).textTheme;
    final List<(DemoAppointment, PreVisit)> sent = demoSession.sentPreVisitsFor(
      patientId,
    );
    if (sent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Text(
          'A família não enviou pré-consulta para esta criança.',
          style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      );
    }
    final (DemoAppointment a, PreVisit v) = sent.first;
    final int photos = v.sentAttachments
        .where((PreVisitAttachment x) => x.type.isPhoto)
        .length;
    final int docs = v.sentAttachments.length - photos;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PremiumCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.assignment_outlined, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Pré-consulta enviada pela família',
                    style: t.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Consulta de ${_when(a.start)}. Enviada em ${_when(v.sentAt!)}. '
              '$photos foto(s) da queixa e $docs exame(s), laudo(s) ou '
              'relatório(s).',
              style: t.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.go(
                preVisitReviewUrl(patientId, consultationId: consultationId),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Ver pré-consulta'),
            ),
          ],
        ),
      ),
    );
  }
}

/// No agendamento: profissional abre; recepção vê só a situação.
class DemoPreVisitAppointmentInfo extends StatelessWidget {
  const DemoPreVisitAppointmentInfo({required this.appointment, super.key});

  final DemoAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final ({bool sent, int files, DateTime? at})? s = demoSession
        .preVisitStatus(appointment.id);
    if (s == null) return const SizedBox.shrink();
    final String text = s.sent
        ? 'Pré-consulta enviada em ${_when(s.at!)} com ${_files(s.files)}.'
        : 'A família ainda não enviou a pré-consulta.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DemoNotice(icon: Icons.assignment_outlined, text: text),
          if (s.sent && demoSession.canReviewPreVisits)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.go(preVisitReviewUrl(appointment.patientId)),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Ver pré-consulta'),
              ),
            )
          else if (s.sent)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Respostas e anexos só o profissional abre.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pré-consultas enviadas, organizadas por consulta e por tipo de anexo.
class DemoPreVisitReviewScreen extends StatelessWidget {
  const DemoPreVisitReviewScreen({
    required this.patientId,
    super.key,
    this.consultationId,
  });

  final String patientId;
  final String? consultationId;

  String get _back => consultationId == null
      ? '/pacientes/$patientId'
      : '/pacientes/$patientId/consulta/$consultationId';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoSession,
      builder: (BuildContext context, _) {
        final DemoPatient? p = demoSession.patientById(patientId);
        final List<(DemoAppointment, PreVisit)> sent = demoSession
            .sentPreVisitsFor(patientId);
        final TextTheme t = Theme.of(context).textTheme;
        return Scaffold(
          backgroundColor: AppColors.lightBackground,
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(_back)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Pré-consulta'),
                if (p != null)
                  Text(
                    p.name,
                    style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
              ],
            ),
          ),
          body: DemoContent(
            maxWidth: 900,
            child: ListView(
              key: const ValueKey<String>('pre-consulta-lista'),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                const DemoNotice(
                  icon: Icons.health_and_safety_outlined,
                  color: Color(0xFF0B6B8A),
                  text:
                      'Informado pela família para preparar a consulta. Os '
                      'anexos não são diagnóstico nem resultado validado: '
                      'confira cada um e registre sua avaliação no '
                      'prontuário.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (sent.isEmpty)
                  const SizedBox(
                    height: 280,
                    child: DemoEmpty(
                      title: 'Nenhuma pré-consulta enviada',
                      message:
                          'Quando a família enviar respostas ou anexos, eles '
                          'aparecem aqui.',
                    ),
                  )
                else
                  for (final (DemoAppointment a, PreVisit v) in sent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Consulta de ${_when(a.start)}',
                              style: t.titleMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Enviada pela família em ${_when(v.sentAt!)}',
                              style: t.bodySmall,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _OrganizedSummary(
                              summary: PreVisitSummary.of(
                                v,
                                visitDate: a.start,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const _GroupLabel('Respostas originais da família'),
                            for (final (String key, String label)
                                in _answerLabels)
                              if (_answer(
                                v.sentAnswers!,
                                key,
                              ).trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: <InlineSpan>[
                                        TextSpan(
                                          text: '$label: ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _answer(v.sentAnswers!, key),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            for (final (
                                  String group,
                                  List<PreVisitAttachment> items,
                                )
                                in groupSentAttachments(v)) ...<Widget>[
                              _GroupLabel('$group (${items.length})'),
                              for (final PreVisitAttachment x in items)
                                _AttachmentTile(
                                  att: x,
                                  onView: () =>
                                      showPreVisitAttachment(context, x),
                                ),
                            ],
                            if (v.sentAttachments.isEmpty)
                              Text(
                                'Sem anexos.',
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            if (v.history.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              _History(v.history),
                            ],
                          ],
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
