import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/unsaved_changes_guard.dart';
import '../../telemedicine/data/telemedicine_repository.dart';
import '../../telemedicine/presentation/telemedicine_screen.dart'
    show myAgendaProvider;
import 'management_common.dart';

/// Campo visível conforme `showIf` do modelo (pergunta condicional).
bool anamnesisFieldVisible(
  Map<String, dynamic> field,
  Map<String, dynamic> answers,
) {
  final Object? cond = field['showIf'];
  if (cond is! Map) return true;
  return answers[cond['field']] == cond['equals'];
}

/// Pré-consulta da família: modelo escolhido pelo servidor (especialidade e
/// idade), salvamento parcial para retomar depois e envio. Depois de enviada
/// a resposta não é sobrescrita: "atualizar" cria nova versão. Respostas
/// reaproveitadas de uma anamnese anterior mostram origem e data e só contam
/// se a família confirmar.
class FamilyAnamnesisScreen extends ConsumerStatefulWidget {
  const FamilyAnamnesisScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  ConsumerState<FamilyAnamnesisScreen> createState() =>
      _FamilyAnamnesisScreenState();
}

class _FamilyAnamnesisScreenState extends ConsumerState<FamilyAnamnesisScreen> {
  Map<String, dynamic>? _data;
  Failure? _failure;
  final Map<String, dynamic> _answers = <String, dynamic>{};
  final Set<String> _confirmedReuse = <String>{};
  bool _busy = false;
  bool _submitted = false;
  bool _dirty = false;
  List<String> _missing = const <String>[];

  Future<void> _saveAndLeave() async {
    await _save();
    if (mounted && !_dirty) await Navigator.of(context).maybePop();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failure = null;
      _data = null;
    });
    final r = await ref
        .read(managementRepositoryProvider)
        .startAnamnesis(widget.appointmentId);
    if (!mounted) return;
    r.fold(
      (Map<String, dynamic> d) => setState(() {
        _data = d;
        _answers
          ..clear()
          ..addAll((d['answers'] as Map<String, dynamic>?) ??
              const <String, dynamic>{});
      }),
      (Failure f) => setState(() => _failure = f),
    );
  }

  Future<void> _save({bool submit = false}) async {
    final String? id = _data?['responseId'] as String?;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    final repo = ref.read(managementRepositoryProvider);
    final saved = await repo.saveAnamnesisDraft(
      id,
      _answers,
      confirmedReuse: _confirmedReuse.toList(),
    );
    if (!mounted) return;
    final bool ok = saved.fold((Map<String, dynamic> s) {
      _missing = ((s['missingRequired'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => '$e')
          .toList();
      return true;
    }, (_) => false);
    if (ok) _dirty = false;
    if (ok && submit) {
      final sent = await repo.submitAnamnesis(id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _submitted = sent.fold((_) => true, (_) => false);
      });
      showResultSnack(context, sent, success: 'Pré-consulta enviada.');
      return;
    }
    setState(() => _busy = false);
    showResultSnack(context, saved,
        success: _missing.isEmpty
            ? 'Rascunho salvo.'
            : 'Rascunho salvo. Faltam ${_missing.length} obrigatório(s).');
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pré-consulta')),
        body: ErrorState(failure: _failure!, onRetry: _load),
      );
    }
    if (_data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pré-consulta')),
        body: const LoadingState(label: 'Abrindo o formulário...'),
      );
    }
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pré-consulta')),
        body: const EmptyState(
          title: 'Enviada',
          message: 'O profissional da consulta verá suas respostas como '
              'relato da família. Para corrigir, abra de novo e atualize: '
              'a versão anterior fica guardada.',
        ),
      );
    }
    final Map<String, dynamic> tpl =
        (_data!['template'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final List<dynamic> sections =
        (tpl['sections'] as List<dynamic>?) ?? const <dynamic>[];
    final Map<String, Map<String, dynamic>> reuse =
        <String, Map<String, dynamic>>{
      for (final dynamic s
          in (_data!['reuseSuggestions'] as List<dynamic>?) ?? const <dynamic>[])
        '${(s as Map)['field']}': Map<String, dynamic>.from(s),
    };
    return UnsavedChangesGuard(
      isDirty: () => _dirty,
      onSave: _saveAndLeave,
      child: Scaffold(
      appBar: AppBar(title: Text('${tpl['name'] ?? 'Pré-consulta'}')),
      body: ManagementBody(
        children: <Widget>[
          const DataWarningBanner(
            text: 'Suas respostas são um relato para o profissional da '
                'consulta e não substituem o atendimento. Em sinais de '
                'urgência, procure atendimento imediatamente.',
          ),
          const SizedBox(height: 8),
          for (final dynamic sec in sections)
            PanelCard(
              title: '${(sec as Map)['title']}',
              children: <Widget>[
                for (final dynamic f
                    in (sec['fields'] as List<dynamic>?) ?? const <dynamic>[])
                  if (anamnesisFieldVisible(
                      Map<String, dynamic>.from(f as Map), _answers))
                    _FieldInput(
                      field: Map<String, dynamic>.from(f),
                      value: _answers[f['id']],
                      missing: _missing.contains(f['id']),
                      suggestion: reuse[f['id']],
                      reuseConfirmed: _confirmedReuse.contains(f['id']),
                      onChanged: (Object? v) => setState(() {
                        _answers['${f['id']}'] = v;
                        _confirmedReuse.remove(f['id']);
                        _dirty = true;
                      }),
                      onUseSuggestion: () => setState(() {
                        _answers['${f['id']}'] = reuse[f['id']]!['value'];
                        _confirmedReuse.add('${f['id']}');
                        _dirty = true;
                      }),
                    ),
              ],
            ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: _busy ? null : () => _save(),
                child: const Text('Salvar e continuar depois'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _save(submit: true),
                child: const Text('Enviar ao profissional'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({
    required this.field,
    required this.value,
    required this.missing,
    required this.suggestion,
    required this.reuseConfirmed,
    required this.onChanged,
    required this.onUseSuggestion,
  });

  final Map<String, dynamic> field;
  final Object? value;
  final bool missing;
  final Map<String, dynamic>? suggestion;
  final bool reuseConfirmed;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final String label =
        '${field['label']}${field['required'] == true ? ' *' : ''}';
    final String type = '${field['type']}';
    final List<String> options =
        ((field['options'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) => '$e')
            .toList();
    final Object? current = value;
    final List<String> selectedOptions = current is List
        ? current.map((dynamic e) => '$e').toList()
        : <String>[];
    final Widget input = switch (type) {
      'boolean' => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: value == true,
          onChanged: onChanged,
        ),
      'choice' => DropdownButtonFormField<String>(
          initialValue: options.contains(value) ? value as String : null,
          decoration: InputDecoration(labelText: label),
          items: <DropdownMenuItem<String>>[
            for (final String o in options)
              DropdownMenuItem<String>(value: o, child: Text(o)),
          ],
          onChanged: onChanged,
        ),
      'multiChoice' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label),
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final String o in options)
                  FilterChip(
                    label: Text(o),
                    selected: selectedOptions.contains(o),
                    onSelected: (bool sel) {
                      final List<String> cur =
                          List<String>.of(selectedOptions);
                      sel ? cur.add(o) : cur.remove(o);
                      onChanged(cur);
                    },
                  ),
              ],
            ),
          ],
        ),
      'attachments' => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: const Text(
            'Anexos podem ser levados à consulta; envio de arquivos por '
            'aqui depende do armazenamento configurado.',
          ),
        ),
      _ => TextFormField(
          key: ValueKey<String>('${field['id']}_${reuseConfirmed ? 'r' : ''}'),
          initialValue: value == null ? '' : '$value',
          maxLines: type == 'longText' ? 4 : 1,
          keyboardType:
              type == 'number' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            helperText: field['help'] as String?,
            hintText: type == 'date' ? 'AAAA-MM-DD' : null,
          ),
          onChanged: (String v) => onChanged(
            type == 'number' ? num.tryParse(v.replaceAll(',', '.')) : v,
          ),
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          input,
          if (missing)
            const Text('Obrigatório', style: TextStyle(color: Colors.red)),
          if (suggestion != null && !reuseConfirmed)
            TextButton(
              onPressed: onUseSuggestion,
              child: Text(
                'Usar resposta anterior (${_date(suggestion!['sourceSubmittedAt'])}): '
                '${suggestion!['value']}',
              ),
            ),
          if (reuseConfirmed && suggestion != null)
            Text(
              'Reaproveitado da pré-consulta de '
              '${_date(suggestion!['sourceSubmittedAt'])}, confirmado por você.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  static String _date(Object? iso) {
    final DateTime? d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return 'data desconhecida';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

/// Revisão do profissional: lista as próximas consultas e abre a
/// pré-consulta enviada pela família para aquela consulta. O servidor só
/// entrega ao profissional da consulta; a revisão anota, não altera o relato.
class AnamnesisReviewScreen extends ConsumerWidget {
  const AnamnesisReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Appointment>> agenda = ref.watch(myAgendaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Anamnese e pré-consulta')),
      body: agenda.when(
        loading: () => const LoadingState(),
        error: (Object e, _) => ErrorState(
          failure: e is Failure ? e : const ServerFailure(),
          onRetry: () => ref.invalidate(myAgendaProvider),
        ),
        data: (List<Appointment> list) {
          final DateTime from =
              DateTime.now().subtract(const Duration(days: 1));
          final List<Appointment> upcoming = list
              .where((Appointment a) =>
                  a.startsAt.isAfter(from) && a.status.isActive)
              .toList();
          if (upcoming.isEmpty) {
            return const EmptyState(
              title: 'Sem consultas próximas',
              message: 'As pré-consultas aparecem junto das consultas.',
            );
          }
          return ManagementBody(
            children: <Widget>[
              for (final Appointment a in upcoming)
                Card(
                  child: ListTile(
                    title: Text(a.childName ?? 'Paciente'),
                    subtitle: Text(
                      '${a.startsAt.day.toString().padLeft(2, '0')}/'
                      '${a.startsAt.month.toString().padLeft(2, '0')} '
                      '${a.startsAt.hour.toString().padLeft(2, '0')}:'
                      '${a.startsAt.minute.toString().padLeft(2, '0')} • '
                      '${a.status.label}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _VisitAnamnesis(appointment: a),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Resumo preliminar: rascunho para revisão, com o que falta explícito.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final List<dynamic> sections =
        (summary['sections'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> missing =
        (summary['missing'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> notAnswered =
        (summary['notAnswered'] as List<dynamic>?) ?? const <dynamic>[];
    return PanelCard(
      title: 'Resumo preliminar (rascunho para revisão)',
      children: <Widget>[
        Text('${summary['header'] ?? ''}',
            style: Theme.of(context).textTheme.bodySmall),
        for (final dynamic s in sections) ...<Widget>[
          const SizedBox(height: 6),
          Text('${(s as Map)['title']}',
              style: Theme.of(context).textTheme.titleSmall),
          for (final dynamic l in (s['lines'] as List<dynamic>?) ?? const <dynamic>[])
            Text('• $l'),
        ],
        if (missing.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('Obrigatórios sem resposta: ${missing.join(', ')}'),
        ],
        if (notAnswered.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('Não respondido: ${notAnswered.join(', ')}'),
        ],
      ],
    );
  }
}

class _VisitAnamnesis extends ConsumerStatefulWidget {
  const _VisitAnamnesis({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_VisitAnamnesis> createState() => _VisitAnamnesisState();
}

class _VisitAnamnesisState extends ConsumerState<_VisitAnamnesis> {
  final TextEditingController _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment.childName ?? 'Pré-consulta'),
      ),
      body: CallView(
        load: () => repo.anamnesisForVisit(widget.appointment.id),
        builder: (BuildContext context, Map<String, dynamic> d,
            VoidCallback reload) {
          if (d['available'] != true) {
            return EmptyState(
              title: 'Pré-consulta não enviada',
              message: '${d['reason'] ?? ''}',
            );
          }
          final Map<String, dynamic> tpl =
              (d['template'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{};
          final Map<String, dynamic> answers =
              (d['answers'] as Map<String, dynamic>?) ??
                  const <String, dynamic>{};
          final Map<String, dynamic>? review =
              d['review'] as Map<String, dynamic>?;
          return ManagementBody(
            children: <Widget>[
              DataWarningBanner(
                text: 'Relatado pela família em '
                    '${DateTime.tryParse('${d['submittedAt']}')?.toLocal() ?? '-'} '
                    '(${d['answeredBy'] ?? ''}). Não é dado verificado.',
              ),
              if (d['summary'] is Map)
                _SummaryCard(summary: d['summary'] as Map<String, dynamic>),
              for (final dynamic sec
                  in (tpl['sections'] as List<dynamic>?) ?? const <dynamic>[])
                PanelCard(
                  title: '${(sec as Map)['title']}',
                  children: <Widget>[
                    for (final dynamic f
                        in (sec['fields'] as List<dynamic>?) ?? const <dynamic>[])
                      InfoRow(
                        '${(f as Map)['label']}',
                        answers.containsKey(f['id'])
                            ? '${answers[f['id']]}'
                            : 'não informado',
                      ),
                  ],
                ),
              PanelCard(
                title: review == null ? 'Revisão' : 'Revisada',
                children: <Widget>[
                  if (review != null) Text('${review['notes'] ?? ''}'),
                  TextField(
                    controller: _notes,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Anotações da revisão (não alteram o relato)',
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final r = await repo.reviewAnamnesis(
                        '${d['responseId']}',
                        _notes.text.trim(),
                      );
                      if (!context.mounted) return;
                      showResultSnack(context, r, success: 'Revisão registrada.');
                      reload();
                    },
                    child: const Text('Registrar revisão'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
