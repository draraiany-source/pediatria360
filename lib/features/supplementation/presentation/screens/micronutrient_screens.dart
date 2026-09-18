import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/supplement_catalog.dart';
import '../providers/supplement_providers.dart';
import '../widgets/supplement_widgets.dart';

class MicronutrientListScreen extends ConsumerStatefulWidget {
  const MicronutrientListScreen({super.key});

  @override
  ConsumerState<MicronutrientListScreen> createState() =>
      _MicronutrientListScreenState();
}

class _MicronutrientListScreenState
    extends ConsumerState<MicronutrientListScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<MicronutrientProfile> list = kMicronutrientCatalog
        .where(
          (MicronutrientProfile m) =>
              _q.isEmpty ||
              m.name.toLowerCase().contains(_q.toLowerCase()) ||
              m.shortCode.toLowerCase().contains(_q.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Micronutrientes'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              onChanged: (String v) => setState(() => _q = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Buscar micronutriente...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int i) {
                final MicronutrientProfile m = list[i];
                return AppCard(
                  onTap: () => context.push(Routes.supplementMicronutrient(m.id)),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: AppColors.softBlue,
                        child: Text(
                          m.shortCode,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            Text(
                              kSupplementContentPending,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkMuted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
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

class MicronutrientDetailScreen extends ConsumerStatefulWidget {
  const MicronutrientDetailScreen({required this.micronutrientId, super.key});

  final String micronutrientId;

  @override
  ConsumerState<MicronutrientDetailScreen> createState() =>
      _MicronutrientDetailScreenState();
}

class _MicronutrientDetailScreenState
    extends ConsumerState<MicronutrientDetailScreen> {
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final MicronutrientProfile? m = micronutrientById(widget.micronutrientId);
      final String? uid = ref.read(currentUserProvider)?.uid;
      if (m != null && uid != null) {
        ref.read(supplementRepositoryProvider).trackRecent(
              professionalId: uid,
              itemType: 'micronutrient',
              itemId: m.id,
              label: m.name,
            );
      }
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MicronutrientProfile? m = micronutrientById(widget.micronutrientId);
    if (m == null) {
      return const Scaffold(body: Center(child: Text('Micronutriente nao encontrado')));
    }
    final String? uid = ref.watch(currentUserProvider)?.uid;
    final List<String> favs =
        ref.watch(supplementFavoritesProvider).valueOrNull ?? <String>[];
    final bool isFav = favs.contains(m.id);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(m.name),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            tooltip: isFav ? 'Remover favorito' : 'Salvar nos favoritos',
            icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: uid == null
                ? null
                : () async {
                    await ref.read(supplementRepositoryProvider).toggleFavorite(
                          professionalId: uid,
                          micronutrientId: m.id,
                        );
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(compact: true),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${Routes.supplementCalculatorPath}?micronutrientId=${m.id}',
                ),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calcular dose'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.push(
                  '${Routes.supplementPrescriptionPath}?micronutrientId=${m.id}',
                ),
                icon: const Icon(Icons.medication_outlined),
                label: const Text('Gerar prescricao'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.supplementParentPath),
                icon: const Icon(Icons.family_restroom_outlined),
                label: const Text('Orientacao aos pais'),
              ),
              OutlinedButton.icon(
                onPressed: uid == null
                    ? null
                    : () async {
                        final String text = _note.text.trim().isEmpty
                            ? 'Anotacao sobre ${m.name}'
                            : _note.text.trim();
                        final Result<String> res =
                            await ref.read(supplementRepositoryProvider).saveClinicalNote(
                                  childId: 'pending_patient',
                                  professionalId: uid,
                                  title: 'Nota — ${m.name}',
                                  body: text,
                                );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.isSuccess
                                  ? 'Nota preparada para prontuario (vincule o paciente).'
                                  : 'Falha ao salvar nota.',
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Adicionar ao prontuario'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...m.sections.map(
            (MicronutrientSection s) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                ),
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                title: Text(
                  s.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                children: <Widget>[
                  Text(s.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const BrandSectionHeader(title: 'Anotacao medica'),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Registro livre do pediatra (nao substitui prontuario)...',
            ),
          ),
        ],
      ),
    );
  }
}
