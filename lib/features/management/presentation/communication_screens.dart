import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import 'management_common.dart';

/// Campos da regra aceitos pelo servidor (normalizeRule).
const List<String> _ruleFields = <String>[
  'paused',
  'channels',
  'allowedFromHour',
  'allowedToHour',
  'delayHours',
  'maxPerRecipientPerDay',
];

bool _isDesk(ClinicMembership? m) =>
    m != null &&
    (m.role == ClinicRole.clinicAdmin || m.role == ClinicRole.receptionist);

/// WhatsApp e comunicação: situação real do canal (o que falta configurar,
/// sem expor segredo) e caixa de entrada das respostas que precisam de
/// pessoa. Nenhuma mensagem é marcada como enviada sem o provedor confirmar.
class CommunicationScreen extends ConsumerWidget {
  const CommunicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? m = activeMembership(ref);
    if (!_isDesk(m)) {
      return const ManagementUnavailable(title: 'WhatsApp e comunicação');
    }
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp e comunicação')),
      body: ManagementBody(
        children: <Widget>[
          CallView(
            load: () => repo.whatsAppStatus(m!.clinicId),
            loadingLabel: 'Consultando o canal...',
            builder: (BuildContext context, Map<String, dynamic> d,
                VoidCallback reload) {
              final List<dynamic> missing =
                  (d['missing'] as List<dynamic>?) ?? const <dynamic>[];
              final List<dynamic> noTpl =
                  (d['kindsWithoutApprovedTemplate'] as List<dynamic>?) ??
                      const <dynamic>[];
              return PanelCard(
                title: d['ready'] == true
                    ? 'WhatsApp configurado'
                    : 'WhatsApp bloqueado',
                children: <Widget>[
                  if (missing.isNotEmpty) ...<Widget>[
                    const Text(
                      'Falta configurar (os envios por WhatsApp ficam '
                      'bloqueados e aparecem como bloqueados, não como '
                      'enviados):',
                    ),
                    for (final dynamic x in missing) Text('• $x'),
                  ],
                  if (noTpl.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    const Text('Tipos sem modelo aprovado no provedor:'),
                    for (final dynamic k in noTpl)
                      Text('• ${messageKindLabels[k] ?? k}'),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Avisos no aplicativo continuam funcionando. As mensagens '
                    'não levam conteúdo clínico.',
                  ),
                  TextButton.icon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Atualizar'),
                  ),
                ],
              );
            },
          ),
          PanelCard(
            title: 'Caixa de entrada (atendimento humano)',
            children: <Widget>[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.watchInbox(m!.clinicId),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> s) {
                  if (s.hasError) {
                    return const Text('Não foi possível carregar a caixa.');
                  }
                  if (!s.hasData) return const LoadingState();
                  final List<Map<String, dynamic>> items = s.data!;
                  if (items.isEmpty) {
                    return const Text('Nenhuma resposta aguardando a equipe.');
                  }
                  return Column(
                    children: <Widget>[
                      for (final Map<String, dynamic> i in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${i['reason'] ?? i['reply'] ?? ''}'),
                          subtitle: Text(
                            'De ${i['fromMasked'] ?? 'contato'} • ${i['status']}',
                          ),
                          trailing: i['status'] == 'closed'
                              ? null
                              : TextButton(
                                  onPressed: () async {
                                    final r = await repo.updateInboxItem(
                                      m.clinicId,
                                      '${i['id']}',
                                      'closed',
                                    );
                                    if (context.mounted) {
                                      showResultSnack(context, r,
                                          success: 'Marcado como resolvido.');
                                    }
                                  },
                                  child: const Text('Resolver'),
                                ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Automações: regras por tipo (gatilho, canal, horário, pausa), pausa geral
/// e execução manual da fila (gestão). Recepção só acompanha.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? m = activeMembership(ref);
    if (!_isDesk(m)) {
      return const ManagementUnavailable(title: 'Automações');
    }
    final bool admin = m!.role == ClinicRole.clinicAdmin;
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Automações')),
      body: ManagementBody(
        children: <Widget>[
          if (admin)
            PanelCard(
              title: 'Controle geral',
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Pausar todas'),
                      onPressed: () async {
                        final r = await repo.setAutomationsPaused(m.clinicId,
                            paused: true);
                        if (context.mounted) {
                          showResultSnack(context, r,
                              success: 'Automações pausadas.');
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Retomar'),
                      onPressed: () async {
                        final r = await repo.setAutomationsPaused(m.clinicId,
                            paused: false);
                        if (context.mounted) {
                          showResultSnack(context, r,
                              success: 'Automações retomadas.');
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Processar fila agora'),
                      onPressed: () async {
                        final r = await repo.processQueueNow(m.clinicId);
                        if (context.mounted) {
                          showResultSnack(
                            context,
                            r,
                            success: r.fold(
                              (Map<String, dynamic> s) =>
                                  'Enviadas ${s['sent']}, bloqueadas '
                                  '${s['blocked']}, canceladas '
                                  '${s['cancelled']}, adiadas ${s['deferred']}.',
                              (_) => '',
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          PanelCard(
            title: 'Regras',
            children: <Widget>[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.watchAutomations(m.clinicId),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> s) {
                  if (s.hasError) {
                    return const Text('Não foi possível carregar as regras.');
                  }
                  if (!s.hasData) return const LoadingState();
                  final Map<String, Map<String, dynamic>> saved =
                      <String, Map<String, dynamic>>{
                    for (final Map<String, dynamic> r in s.data!)
                      '${r['kind']}': r,
                  };
                  return Column(
                    children: <Widget>[
                      for (final MapEntry<String, String> k
                          in messageKindLabels.entries)
                        if (k.key != 'campaign')
                          _RuleTile(
                            kind: k.key,
                            label: k.value,
                            rule: saved[k.key],
                            editable: admin,
                            onToggle: (bool enabled) async {
                              final r = await repo.saveAutomationRule(
                                m.clinicId,
                                k.key,
                                <String, dynamic>{
                                  for (final String f in _ruleFields)
                                    if (saved[k.key]?[f] != null)
                                      f: saved[k.key]![f],
                                  'enabled': enabled,
                                },
                              );
                              if (context.mounted) {
                                showResultSnack(context, r,
                                    success: enabled
                                        ? 'Automação ativada.'
                                        : 'Automação desativada.');
                              }
                            },
                          ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Antes de cada envio o servidor confere de novo o status da '
                'consulta, o destinatário, as preferências e a autorização. '
                'Remarcar cancela os lembretes antigos.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.kind,
    required this.label,
    required this.rule,
    required this.editable,
    required this.onToggle,
  });

  final String kind;
  final String label;
  final Map<String, dynamic>? rule;
  final bool editable;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final bool enabled = rule?['enabled'] == true;
    final List<dynamic> channels =
        (rule?['channels'] as List<dynamic>?) ?? const <dynamic>['inApp'];
    final String hours = rule == null
        ? 'padrão do servidor'
        : 'das ${rule!['allowedFromHour'] ?? '?'}h às '
            '${rule!['allowedToHour'] ?? '?'}h';
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        rule == null
            ? 'Usando configuração padrão'
            : 'Canais: ${channels.join(', ')} • $hours'
                '${rule!['paused'] == true ? ' • pausada' : ''}',
      ),
      value: enabled,
      onChanged: editable ? onToggle : null,
    );
  }
}
