import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import 'management_common.dart';

/// Central de IA da gestão: painel determinístico + perguntas da lista
/// suportada. Toda resposta mostra período, filtros e fonte; quando faltam
/// dados, o servidor diz que é insuficiente. Sem conteúdo clínico.
class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _ChatEntry {
  const _ChatEntry({required this.question, this.answer, this.failure});

  final String question;
  final Map<String, dynamic>? answer;
  final String? failure;
}

class _AiHubScreenState extends ConsumerState<AiHubScreen> {
  final TextEditingController _q = TextEditingController();
  final List<_ChatEntry> _history = <_ChatEntry>[];
  bool _busy = false;

  static const List<String> _examples = <String>[
    'Quantos pacientes faltaram este mês?',
    'Quais retornos estão pendentes?',
    'Quanto recebemos nesta semana?',
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _requestId() {
    final Random r = Random.secure();
    return List<String>.generate(16, (_) => r.nextInt(36).toRadixString(36))
        .join();
  }

  Future<void> _ask(String clinicId, String question) async {
    final String text = question.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(managementRepositoryProvider)
        .ask(clinicId, text, requestId: _requestId());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _q.clear();
      _history.insert(
        0,
        result.fold(
          (Map<String, dynamic> a) => _ChatEntry(question: text, answer: a),
          (Failure f) => _ChatEntry(question: text, failure: f.message),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ClinicMembership? m = activeMembership(ref);
    if (m == null ||
        (m.role != ClinicRole.clinicAdmin && m.role != ClinicRole.finance)) {
      return const ManagementUnavailable(title: 'Central de IA');
    }
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Central de IA')),
      body: ManagementBody(
        children: <Widget>[
          CallView(
            load: () => repo.insights(m.clinicId),
            loadingLabel: 'Calculando indicadores...',
            builder: (BuildContext context, Map<String, dynamic> d, _) =>
                _InsightsPanel(data: d),
          ),
          PanelCard(
            title: 'Pergunte à Central',
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String e in _examples)
                    ActionChip(
                      label: Text(e),
                      onPressed: _busy ? null : () => _ask(m.clinicId, e),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q,
                maxLength: 500,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Pergunta sobre agenda, retornos ou financeiro',
                  suffixIcon: IconButton(
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _busy ? null : () => _ask(m.clinicId, _q.text),
                  ),
                ),
                onSubmitted: (String v) => _ask(m.clinicId, v),
              ),
              const Text(
                'Respostas agregadas, calculadas no servidor a partir dos '
                'registros da clínica. A Central não lê prontuários.',
              ),
            ],
          ),
          for (final _ChatEntry e in _history) _AnswerCard(entry: e),
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> period =
        (data['period'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> agenda =
        (data['agenda'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> fin =
        (data['finance'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> ret =
        (data['returns'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final List<dynamic> tips =
        (data['suggestions'] as List<dynamic>?) ?? const <dynamic>[];
    return PanelCard(
      title: 'Resumo (${period['label'] ?? 'período'})',
      children: <Widget>[
        if (agenda['unavailable'] == null) ...<Widget>[
          InfoRow('Consultas na agenda', '${agenda['total'] ?? 0}'),
          InfoRow('Faltas', '${agenda['noShow'] ?? 0}'),
          InfoRow('Cancelamentos', '${agenda['cancelled'] ?? 0}'),
          InfoRow('Fonte', '${agenda['source'] ?? '-'}'),
        ] else
          Text('Agenda: ${agenda['unavailable']}'),
        const Divider(),
        InfoRow('Recebido', brlFromCents((fin['receivedCents'] as num?) ?? 0)),
        InfoRow('Pendente', brlFromCents((fin['pendingCents'] as num?) ?? 0)),
        InfoRow('Previsto', brlFromCents((fin['forecastCents'] as num?) ?? 0)),
        InfoRow('Fonte', '${fin['source'] ?? '-'}'),
        if (ret['unavailable'] == null) ...<Widget>[
          const Divider(),
          InfoRow('Retornos pendentes', '${ret['count'] ?? 0}'),
        ],
        if (tips.isNotEmpty) ...<Widget>[
          const Divider(),
          for (final dynamic t in tips) Text('• $t'),
        ],
        const SizedBox(height: 8),
        Text(
          '${data['note'] ?? ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.entry});

  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? a = entry.answer;
    final Map<String, dynamic> period =
        (a?['period'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final Map<String, dynamic> filters =
        (a?['filters'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final List<dynamic> supported =
        (a?['supported'] as List<dynamic>?) ?? const <dynamic>[];
    final String filterText = filters.entries
        .where((MapEntry<String, dynamic> e) => e.value != null)
        .map((MapEntry<String, dynamic> e) => '${e.key}: ${e.value}')
        .join(', ');
    return PanelCard(
      title: entry.question,
      children: <Widget>[
        if (entry.failure != null)
          Text(entry.failure!, style: const TextStyle(color: Colors.red))
        else ...<Widget>[
          Text('${a?['answer'] ?? ''}'),
          for (final dynamic s in supported) Text('• $s'),
          const SizedBox(height: 8),
          Text(
            'Período: ${period['label'] ?? '-'}  •  '
            'Filtros: ${filterText.isEmpty ? 'nenhum' : filterText}  •  '
            'Fonte: ${a?['source'] ?? '-'}'
            '${a?['sufficient'] == false ? '  •  Dados insuficientes' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
