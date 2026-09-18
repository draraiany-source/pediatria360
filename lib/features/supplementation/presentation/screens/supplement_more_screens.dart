import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/lab_result.dart';
import '../../domain/supplement_ai.dart';
import '../../domain/supplement_catalog.dart';
import '../../domain/supplement_timeline.dart';
import '../providers/supplement_providers.dart';
import '../widgets/supplement_widgets.dart';

class SupplementProtocolsScreen extends StatelessWidget {
  const SupplementProtocolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Protocolos de suplementacao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(compact: true),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Protocolos nao prescrevem automaticamente. Use como checklist clinico.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...kSupplementProtocols.map((SupplementProtocolCard p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (BuildContext ctx) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(p.summary),
                            const SizedBox(height: AppSpacing.md),
                            const Text('Nutrientes a considerar:'),
                            const SizedBox(height: AppSpacing.xs),
                            if (p.nutrientsToConsider.isEmpty)
                              const Text(kSupplementContentPending)
                            else
                              Wrap(
                                spacing: 6,
                                children: p.nutrientsToConsider
                                    .map((String id) => Chip(label: Text(id)))
                                    .toList(),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            const Text('Avaliacao clinica / exames / alertas:'),
                            const Text(kSupplementContentPending),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton.tonal(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push(Routes.supplementCalculatorPath);
                              },
                              child: const Text('Abrir calculadora'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.playlist_add_check_rounded,
                        color: AppColors.moduleLibrary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        p.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class FoodLibraryScreen extends StatefulWidget {
  const FoodLibraryScreen({super.key});

  @override
  State<FoodLibraryScreen> createState() => _FoodLibraryScreenState();
}

class _FoodLibraryScreenState extends State<FoodLibraryScreen> {
  String _q = '';
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final List<FoodSourceCard> foods = kFoodSourceCatalog.where((FoodSourceCard f) {
      final bool qOk = _q.isEmpty ||
          f.foodName.toLowerCase().contains(_q.toLowerCase()) ||
          f.nutrientId.toLowerCase().contains(_q.toLowerCase());
      final bool tagOk = _tag == null || f.tags.contains(_tag);
      return qOk && tagOk;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Alimentos & Micronutrientes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                TextField(
                  onChanged: (String v) => setState(() => _q = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Ex.: fontes de ferro, calcio, B12...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  children: <String?>[
                    null,
                    'geral',
                    'leite',
                    'ovo',
                    'vegetariano',
                    'vegano',
                  ]
                      .map(
                        (String? t) => FilterChip(
                          label: Text(t ?? 'Todos'),
                          selected: _tag == t,
                          onSelected: (_) => setState(() => _tag = t),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: foods.isEmpty
                ? const SupplementEmptyState(
                    message:
                        'Nenhum alimento no catalogo local. Conteudo pendente de validacao medica / CMS.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
                    ),
                    itemCount: foods.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final FoodSourceCard f = foods[i];
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              f.foodName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Nutriente: ${f.nutrientId} · Grupo: ${f.group}'),
                            Text('Porcao: ${f.portion}'),
                            Text(f.notes),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ParentGuidanceScreen extends StatelessWidget {
  const ParentGuidanceScreen({this.micronutrientId, super.key});

  final String? micronutrientId;

  @override
  Widget build(BuildContext context) {
    final List<MicronutrientProfile> list = micronutrientId == null
        ? kMicronutrientCatalog
        : kMicronutrientCatalog
            .where((MicronutrientProfile m) => m.id == micronutrientId)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Orientacao para pais'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PDF de orientacao — estrutura pronta.'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Compartilhar — estrutura pronta.')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: list.length,
        itemBuilder: (BuildContext context, int i) {
          final MicronutrientProfile m = list[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    m.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Para que serve'),
                  const Text(kSupplementContentPending),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Como oferecer'),
                  const Text(kSupplementContentPending),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Principais alimentos'),
                  const Text(kSupplementContentPending),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Cuidados / armazenamento'),
                  const Text(kSupplementContentPending),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Quando procurar atendimento / retornar'),
                  const Text(kSupplementContentPending),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Perguntas frequentes'),
                  const Text(kSupplementContentPending),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SupplementAiScreen extends ConsumerStatefulWidget {
  const SupplementAiScreen({this.childId, super.key});

  final String? childId;

  @override
  ConsumerState<SupplementAiScreen> createState() => _SupplementAiScreenState();
}

class _SupplementAiScreenState extends ConsumerState<SupplementAiScreen> {
  final TextEditingController _input = TextEditingController();
  SupplementAiDraft? _draft;
  bool _saving = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _run() {
    setState(() {
      _draft = ref.read(supplementAiOrganizerProvider).organizeFromFreeText(
            _input.text,
          );
    });
  }

  Future<void> _saveNote() async {
    final SupplementAiDraft? draft = _draft;
    final String? uid = ref.read(currentUserProvider)?.uid;
    final String childId = widget.childId ?? '';
    if (draft == null || uid == null || childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vincule um paciente para salvar no prontuario.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final Result<String> res =
        await ref.read(supplementRepositoryProvider).saveClinicalNote(
              childId: childId,
              professionalId: uid,
              title: 'Nota IA — suplementacao (rascunho)',
              body: draft.clinicalSummary,
            );
    await ref.read(supplementRepositoryProvider).saveAiDraft(
          childId: childId,
          professionalId: uid,
          kind: 'micronutrient_assistant',
          payload: draft.toMap(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.isSuccess
              ? 'Rascunho adicionado ao acompanhamento.'
              : 'Falha ao salvar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Assistente IA — Micronutrientes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _input,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Ex.: Crianca de 3 anos, 14 kg, seletividade alimentar, Hb 10,5 e ferritina 8.',
              labelText: 'Caso clinico (texto livre)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: 'Organizar com IA',
                  onPressed: _run,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Voz (estrutura futura)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ditacao por voz — integrar STT no proximo ciclo.'),
                    ),
                  );
                },
                icon: const Icon(Icons.mic_none_rounded),
              ),
            ],
          ),
          if (_draft != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _AiBlock(title: 'DADOS DO PACIENTE', map: _draft!.patientBlock),
            _AiBlock(title: 'EXAMES', map: _draft!.examsBlock),
            _AiList(title: 'PONTOS DE ATENCAO', items: _draft!.attentionPoints),
            _AiList(title: 'POSSIVEIS PROXIMOS PASSOS', items: _draft!.nextSteps),
            const BrandSectionHeader(title: 'ATALHOS'),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ActionChip(
                  label: const Text('abrir ferro'),
                  onPressed: () => context.push(Routes.supplementMicronutrient('iron')),
                ),
                ActionChip(
                  label: const Text('abrir exames'),
                  onPressed: () => context.push(Routes.supplementLabsPath),
                ),
                ActionChip(
                  label: const Text('abrir calculadora'),
                  onPressed: () => context.push(Routes.supplementCalculatorPath),
                ),
                ActionChip(
                  label: const Text('gerar nota clinica'),
                  onPressed: _saving ? null : _saveNote,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _draft!.disclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class LabAiInterpretScreen extends ConsumerStatefulWidget {
  const LabAiInterpretScreen({this.childId, super.key});

  final String? childId;

  @override
  ConsumerState<LabAiInterpretScreen> createState() =>
      _LabAiInterpretScreenState();
}

class _LabAiInterpretScreenState extends ConsumerState<LabAiInterpretScreen> {
  final TextEditingController _input = TextEditingController();
  SupplementAiDraft? _draft;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('IA — Interpretar exames'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _input,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Resultados (digitar / colar)',
              hintText: 'Cole hemograma, ferritina, B12...',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Anexar PDF/imagem: estrutura reservada para ciclo futuro.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Interpretar (rascunho)',
            onPressed: () {
              setState(() {
                _draft = ref
                    .read(supplementAiOrganizerProvider)
                    .organizeFromFreeText(_input.text);
              });
            },
          ),
          if (_draft != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            _AiBlock(title: 'Resultados organizados', map: _draft!.examsBlock),
            _AiList(title: 'Alteracoes / atencao', items: _draft!.attentionPoints),
            _AiList(
              title: 'Exames complementares para CONSIDERACAO',
              items: _draft!.nextSteps,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Resumo clinico',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(_draft!.clinicalSummary),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () async {
                      final String? uid = ref.read(currentUserProvider)?.uid;
                      final String childId = widget.childId ?? '';
                      if (uid == null || childId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Abra com paciente vinculado.'),
                          ),
                        );
                        return;
                      }
                      await ref.read(supplementRepositoryProvider).saveClinicalNote(
                            childId: childId,
                            professionalId: uid,
                            title: 'Resumo IA — exames (rascunho)',
                            body: _draft!.clinicalSummary,
                          );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Resumo salvo como rascunho.')),
                      );
                    },
                    child: const Text('Adicionar resumo ao prontuario'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SupplementHistoryScreen extends ConsumerWidget {
  const SupplementHistoryScreen({this.childId, super.key});

  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? cid = childId;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Historico — suplementacao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: cid == null || cid.isEmpty
          ? const SupplementEmptyState(
              message: 'Selecione um paciente no Consultorio 360 para ver a timeline.',
            )
          : ref.watch(childSupplementTimelineProvider(cid)).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: SupplementSkeletonList(),
                ),
                error: (Object e, StackTrace _) => Center(child: Text('$e')),
                data: (List<SupplementTimelineEvent> events) {
                  if (events.isEmpty) {
                    return const SupplementEmptyState(
                      message: 'Nenhum evento de suplementacao ainda.',
                      icon: Icons.timeline_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: events.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int i) {
                      final SupplementTimelineEvent e = events[i];
                      return AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Column(
                              children: <Widget>[
                                Text(
                                  '${e.occurredAt.day.toString().padLeft(2, '0')}/'
                                  '${e.occurredAt.month.toString().padLeft(2, '0')}/'
                                  '${e.occurredAt.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                ),
                                Text(
                                  e.kind.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    e.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  if (e.detail.isNotEmpty) Text(e.detail),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

class SupplementChartsScreen extends ConsumerWidget {
  const SupplementChartsScreen({this.childId, super.key});

  final String? childId;

  static const List<String> _tracked = <String>[
    'hb',
    'ferritin',
    'b12',
    'vit_d_25oh',
    'zinc',
    'magnesium',
    'calcium',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? cid = childId;
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Graficos de evolucao'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: cid == null || cid.isEmpty
          ? const SupplementEmptyState(
              message: 'Vincule um paciente para ver evolucao laboratorial.',
            )
          : ref.watch(childLabResultsProvider(cid)).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: SupplementSkeletonList(),
                ),
                error: (Object e, StackTrace _) => Center(child: Text('$e')),
                data: (List<PatientLabResult> all) {
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: _tracked.map((String examId) {
                      final LabExamDefinition? def = labExamById(examId);
                      final List<PatientLabResult> series = all
                          .where((PatientLabResult r) => r.examId == examId)
                          .toList()
                        ..sort(
                          (PatientLabResult a, PatientLabResult b) =>
                              a.recordedAt.compareTo(b.recordedAt),
                        );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                def?.name ?? examId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (series.isEmpty)
                                const Text('Sem pontos registrados.')
                              else
                                SizedBox(
                                  height: 88,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: series.map((PatientLabResult r) {
                                      final double? n =
                                          double.tryParse(
                                        r.valueText.replaceAll(',', '.'),
                                      );
                                      final double h = n == null
                                          ? 24
                                          : (20 + (n % 50)).clamp(20, 72);
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Tooltip(
                                            message:
                                                '${r.valueText} (${r.recordedAt.toIso8601String().split('T').first})',
                                            child: Container(
                                              height: h,
                                              decoration: BoxDecoration(
                                                color: AppColors.brand
                                                    .withValues(alpha: 0.7),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
    );
  }
}

class SupplementFavoritesScreen extends ConsumerWidget {
  const SupplementFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Favoritos'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ref.watch(supplementFavoritesProvider).when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SupplementSkeletonList(),
            ),
            error: (Object e, StackTrace _) => Center(child: Text('$e')),
            data: (List<String> ids) {
              if (ids.isEmpty) {
                return const SupplementEmptyState(
                  message: 'Nenhum favorito salvo.',
                  icon: Icons.star_border_rounded,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: ids.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final MicronutrientProfile? m = micronutrientById(ids[i]);
                  return AppCard(
                    onTap: () => context.push(
                      Routes.supplementMicronutrient(ids[i]),
                    ),
                    child: Text(m?.name ?? ids[i]),
                  );
                },
              );
            },
          ),
    );
  }
}

class _AiBlock extends StatelessWidget {
  const _AiBlock({required this.title, required this.map});

  final String title;
  final Map<String, String> map;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            ...map.entries.map(
              (MapEntry<String, String> e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${e.key}: ${e.value}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiList extends StatelessWidget {
  const _AiList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((String t) => Text('• $t')),
          ],
        ),
      ),
    );
  }
}
