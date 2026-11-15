import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/state_views.dart';
import '../../../shared/domain/entities/clinic_organization.dart';
import 'management_common.dart';

const Map<String, String> _campaignStatus = <String, String>{
  'draft': 'Rascunho',
  'pendingApproval': 'Aguardando aprovação',
  'scheduled': 'Agendada',
  'cancelled': 'Cancelada',
};

/// Marketing: rascunho → prévia (quantos recebem e por que outros ficam de
/// fora) → aprovação por outra pessoa da gestão. Respeita consentimento,
/// descadastro e limite de frequência; segmentação nunca usa dado clínico.
class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _preview(String clinicId, String campaignId) async {
    final r = await ref
        .read(managementRepositoryProvider)
        .previewCampaign(clinicId, campaignId);
    if (!mounted) return;
    r.fold(
      (Map<String, dynamic> p) {
        final Map<String, dynamic> excluded =
            (p['excluded'] as Map<String, dynamic>?) ??
                const <String, dynamic>{};
        showDialog<void>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Prévia da campanha'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InfoRow('No segmento', '${p['inSegment']}'),
                InfoRow('Receberiam', '${p['eligible']}'),
                for (final MapEntry<String, dynamic> e in excluded.entries)
                  InfoRow('Fora: ${e.key}', '${e.value}'),
                const Divider(),
                Text('${(p['rendered'] as Map?)?['title'] ?? ''}',
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${(p['rendered'] as Map?)?['body'] ?? ''}'),
                const SizedBox(height: 8),
                const Text(
                  'A aprovação precisa ser feita por outra pessoa da gestão.',
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClinicMembership? m = activeMembership(ref);
    if (m == null || m.role != ClinicRole.clinicAdmin) {
      return const ManagementUnavailable(title: 'Marketing');
    }
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketing')),
      body: ManagementBody(
        children: <Widget>[
          PanelCard(
            title: 'Nova campanha (rascunho)',
            children: <Widget>[
              TextField(
                controller: _title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _body,
                maxLength: 600,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Texto',
                  helperText: 'Sem depoimentos, resultados ou credenciais '
                      'inventados; sem dados clínicos.',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  final r = await repo.saveCampaignDraft(
                    m.clinicId,
                    title: _title.text.trim(),
                    body: _body.text.trim(),
                  );
                  if (!context.mounted) return;
                  showResultSnack(context, r, success: 'Rascunho salvo.');
                  r.fold((_) {
                    _title.clear();
                    _body.clear();
                  }, (_) {});
                },
                child: const Text('Salvar rascunho'),
              ),
            ],
          ),
          PanelCard(
            title: 'Campanhas',
            children: <Widget>[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.watchCampaigns(m.clinicId),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> s) {
                  if (s.hasError) {
                    return const Text('Não foi possível carregar.');
                  }
                  if (!s.hasData) return const LoadingState();
                  if (s.data!.isEmpty) {
                    return const Text('Nenhuma campanha ainda.');
                  }
                  return Column(
                    children: <Widget>[
                      for (final Map<String, dynamic> c in s.data!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${c['title'] ?? ''}'),
                          subtitle: Text(
                            _campaignStatus[c['status']] ?? '${c['status']}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: <Widget>[
                              if (c['status'] == 'draft' ||
                                  c['status'] == 'pendingApproval')
                                TextButton(
                                  onPressed: () =>
                                      _preview(m.clinicId, '${c['id']}'),
                                  child: const Text('Prévia'),
                                ),
                              if (c['status'] == 'pendingApproval')
                                TextButton(
                                  onPressed: () async {
                                    final r = await repo.approveCampaign(
                                        m.clinicId, '${c['id']}');
                                    if (context.mounted) {
                                      showResultSnack(context, r,
                                          success: 'Campanha aprovada.');
                                    }
                                  },
                                  child: const Text('Aprovar'),
                                ),
                              if (c['status'] != 'cancelled')
                                TextButton(
                                  onPressed: () async {
                                    final r = await repo.cancelCampaign(
                                        m.clinicId, '${c['id']}');
                                    if (context.mounted) {
                                      showResultSnack(context, r,
                                          success: 'Campanha cancelada.');
                                    }
                                  },
                                  child: const Text('Cancelar'),
                                ),
                            ],
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

/// CRM administrativo (recepção e gestão): indicadores, contatos e
/// possíveis duplicidades. Nada clínico aparece aqui.
class ManagementCrmScreen extends ConsumerWidget {
  const ManagementCrmScreen({super.key});

  static const Map<String, String> _stages = <String, String>{
    'novoContato': 'Novo contato',
    'agendamentoSolicitado': 'Agendamento solicitado',
    'agendado': 'Agendado',
    'atendido': 'Atendido',
    'acompanhamento': 'Acompanhamento',
  };

  static const Map<String, String> _indicators = <String, String>{
    'total': 'Contatos',
    'frequent': 'Frequentes',
    'inactive': 'Inativos',
    'noShow': 'Com faltas',
    'returnPending': 'Retorno pendente',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? m = activeMembership(ref);
    if (m == null ||
        (m.role != ClinicRole.clinicAdmin &&
            m.role != ClinicRole.receptionist)) {
      return const ManagementUnavailable(title: 'Pacientes e CRM');
    }
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes e CRM')),
      body: ManagementBody(
        children: <Widget>[
          CallView(
            load: () => repo.crmIndicators(m.clinicId),
            builder: (BuildContext context, Map<String, dynamic> d, _) {
              final Map<String, dynamic> byStage =
                  (d['byStage'] as Map<String, dynamic>?) ??
                      const <String, dynamic>{};
              return PanelCard(
                title: 'Indicadores',
                children: <Widget>[
                  for (final MapEntry<String, String> e in _indicators.entries)
                    if (d[e.key] is num) InfoRow(e.value, '${d[e.key]}'),
                  for (final MapEntry<String, dynamic> e in byStage.entries)
                    InfoRow(_stages[e.key] ?? e.key, '${e.value}'),
                ],
              );
            },
          ),
          PanelCard(
            title: 'Contatos',
            children: <Widget>[
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: repo.watchCrmContacts(m.clinicId),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> s) {
                  if (s.hasError) {
                    return const Text('Não foi possível carregar.');
                  }
                  if (!s.hasData) return const LoadingState();
                  if (s.data!.isEmpty) {
                    return const Text(
                      'Os contatos aparecem conforme as consultas são marcadas.',
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final Map<String, dynamic> c in s.data!)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${c['childName'] ?? 'Paciente'}'),
                          subtitle: Text(
                            '${_stages[c['stage']] ?? c['stage'] ?? ''}'
                            '${(c['flags'] as Map?)?['noShow'] == true ? ' • faltas recorrentes' : ''}'
                            '${(c['flags'] as Map?)?['inactive'] == true ? ' • inativo' : ''}',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          CallView(
            load: () => repo.crmDuplicates(m.clinicId),
            builder: (BuildContext context, Map<String, dynamic> d, _) {
              final List<dynamic> pairs =
                  (d['pairs'] as List<dynamic>?) ?? const <dynamic>[];
              return PanelCard(
                title: 'Possíveis duplicidades',
                children: <Widget>[
                  if (pairs.isEmpty)
                    const Text('Nenhuma encontrada.')
                  else
                    for (final dynamic p in pairs)
                      Text('• ${(p as Map)['reason'] ?? 'semelhança'}: '
                          '${p['a']} / ${p['b']}'),
                  const SizedBox(height: 4),
                  const Text(
                    'Mesclar exige revisão de outra pessoa da gestão e mantém '
                    'o histórico; nada é apagado.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Configurações e custos: uso do mês, limites e custo estimado, com os
/// preços unitários usados na conta.
class ManagementSettingsScreen extends ConsumerWidget {
  const ManagementSettingsScreen({super.key});

  static const Map<String, String> _kinds = <String, String>{
    'aiRequests': 'Pedidos à IA',
    'audioMinutes': 'Minutos de áudio transcritos',
    'attachmentsMb': 'Anexos (MB)',
    'messages': 'Mensagens enviadas',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ClinicMembership? m = activeMembership(ref);
    if (m == null || m.role != ClinicRole.clinicAdmin) {
      return const ManagementUnavailable(title: 'Configurações e permissões');
    }
    final repo = ref.watch(managementRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações e permissões')),
      body: ManagementBody(
        children: <Widget>[
          CallView(
            load: () => repo.usageDashboard(m.clinicId),
            builder: (BuildContext context, Map<String, dynamic> d, _) {
              final List<dynamic> rows =
                  (d['rows'] as List<dynamic>?) ?? const <dynamic>[];
              return PanelCard(
                title: 'Uso e custo estimado (${d['month'] ?? ''})',
                children: <Widget>[
                  for (final dynamic r in rows)
                    InfoRow(
                      _kinds[(r as Map)['kind']] ?? '${r['kind']}',
                      '${r['used']} de ${r['limit']} • '
                          '${brlFromCents((r['estimatedCostCents'] as num?) ?? 0)}',
                    ),
                  const Divider(),
                  InfoRow(
                    'Total estimado',
                    brlFromCents((d['totalEstimatedCostCents'] as num?) ?? 0),
                  ),
                  const SizedBox(height: 8),
                  Text('${d['note'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
          ),
          PanelCard(
            title: 'Equipe e permissões',
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.group_outlined),
                title: const Text('Equipe da clínica'),
                onTap: () => context.push(Routes.clinicTeamPath),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Matriz de permissões'),
                onTap: () => context.push(Routes.permissionsPath),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Usado quando a lista vem vazia de um painel sem permissão.
class ManagementEmpty extends StatelessWidget {
  const ManagementEmpty({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
        title: 'Nada por aqui',
        message: 'Sem registros para mostrar.',
      );
}
