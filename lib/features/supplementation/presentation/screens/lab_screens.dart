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
import '../../domain/supplement_catalog.dart';
import '../providers/supplement_providers.dart';
import '../widgets/supplement_widgets.dart';

class LabExamsScreen extends ConsumerStatefulWidget {
  const LabExamsScreen({this.childId, super.key});

  final String? childId;

  @override
  ConsumerState<LabExamsScreen> createState() => _LabExamsScreenState();
}

class _LabExamsScreenState extends ConsumerState<LabExamsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final List<LabExamDefinition> exams = kLabExamCatalog
        .where(
          (LabExamDefinition e) =>
              _q.isEmpty || e.name.toLowerCase().contains(_q.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Exames laboratoriais'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
        actions: <Widget>[
          TextButton(
            onPressed: () => context.push(
              widget.childId == null || widget.childId!.isEmpty
                  ? Routes.supplementLabAiPath
                  : '${Routes.supplementLabAiPath}?childId=${widget.childId}',
            ),
            child: const Text('IA'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                const SupplementDisclaimerBanner(compact: true),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  onChanged: (String v) => setState(() => _q = v.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Buscar exame...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg,
              ),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int i) {
                final LabExamDefinition e = exams[i];
                return AppCard(
                  onTap: () => context.push(
                    Routes.supplementLabDetail(
                      e.id,
                      childId: widget.childId,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.biotech_outlined, color: AppColors.teal),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          e.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          Routes.supplementLabRegister(childId: widget.childId),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar resultado'),
      ),
    );
  }
}

class LabExamDetailScreen extends ConsumerWidget {
  const LabExamDetailScreen({
    required this.examId,
    this.childId,
    super.key,
  });

  final String examId;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LabExamDefinition? exam = labExamById(examId);
    if (exam == null) {
      return const Scaffold(body: Center(child: Text('Exame nao encontrado')));
    }

    final String? cid = childId;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(exam.name),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const PendingContentBox(title: 'Referencia / interpretacao'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'A classificacao Normal / Atencao / Alterado e informada pelo profissional — '
            'o sistema nao diagnostica automaticamente.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const BrandSectionHeader(title: 'Resultados do paciente'),
          const SizedBox(height: AppSpacing.sm),
          if (cid == null || cid.isEmpty)
            const SupplementEmptyState(
              message: 'Abra a partir de um paciente para ver resultados.',
            )
          else
            ref.watch(childLabResultsProvider(cid)).when(
              loading: () => const SupplementSkeletonList(),
              error: (Object e, StackTrace _) => Text('$e'),
              data: (List<PatientLabResult> all) {
                final List<PatientLabResult> filtered = all
                    .where((PatientLabResult r) => r.examId == examId)
                    .toList();
                if (filtered.isEmpty) {
                  return const SupplementEmptyState(
                    message: 'Nenhum resultado registrado para este exame.',
                  );
                }
                return Column(
                  children: filtered.map((PatientLabResult r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${r.valueText} ${r.unit}'.trim(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    r.recordedAt.toIso8601String().split('T').first,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            LabFlagChip(flag: r.flag),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          Routes.supplementLabRegister(childId: childId, examId: examId),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo resultado'),
      ),
    );
  }
}

class LabResultFormScreen extends ConsumerStatefulWidget {
  const LabResultFormScreen({this.childId, this.examId, super.key});

  final String? childId;
  final String? examId;

  @override
  ConsumerState<LabResultFormScreen> createState() => _LabResultFormScreenState();
}

class _LabResultFormScreenState extends ConsumerState<LabResultFormScreen> {
  late String _examId;
  final TextEditingController _value = TextEditingController();
  final TextEditingController _unit = TextEditingController();
  final TextEditingController _lab = TextEditingController();
  final TextEditingController _ref = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _child = TextEditingController();
  LabResultFlag _flag = LabResultFlag.unset;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _examId = widget.examId ?? kLabExamCatalog.first.id;
    _child.text = widget.childId ?? '';
  }

  @override
  void dispose() {
    _value.dispose();
    _unit.dispose();
    _lab.dispose();
    _ref.dispose();
    _notes.dispose();
    _child.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    final String childId = _child.text.trim();
    if (childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o ID do paciente.')),
      );
      return;
    }
    setState(() => _saving = true);
    final LabExamDefinition? exam = labExamById(_examId);
    final Result<PatientLabResult> res =
        await ref.read(supplementRepositoryProvider).saveLabResult(
              PatientLabResult(
                id: '',
                childId: childId,
                examId: _examId,
                examName: exam?.name ?? _examId,
                recordedBy: uid,
                recordedAt: DateTime.now(),
                valueText: _value.text.trim(),
                unit: _unit.text.trim(),
                labName: _lab.text.trim(),
                referenceText: _ref.text.trim(),
                notes: _notes.text.trim(),
                flag: _flag,
              ),
            );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.isSuccess ? 'Resultado registrado.' : 'Falha ao salvar.',
        ),
      ),
    );
    if (res.isSuccess) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Registrar resultado'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          const SupplementDisclaimerBanner(compact: true),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _child,
            decoration: const InputDecoration(labelText: 'ID do paciente'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            value: _examId,
            items: kLabExamCatalog
                .map(
                  (LabExamDefinition e) => DropdownMenuItem<String>(
                    value: e.id,
                    child: Text(e.name),
                  ),
                )
                .toList(),
            onChanged: (String? v) {
              if (v != null) setState(() => _examId = v);
            },
            decoration: const InputDecoration(labelText: 'Exame'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _value,
            decoration: const InputDecoration(labelText: 'Resultado'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _unit,
            decoration: const InputDecoration(labelText: 'Unidade'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _lab,
            decoration: const InputDecoration(labelText: 'Laboratorio'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ref,
            decoration: const InputDecoration(
              labelText: 'Referencia (texto livre / laboratorio)',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Observacao'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Classificacao visual (profissional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: LabResultFlag.values.map((LabResultFlag f) {
              return ChoiceChip(
                label: Text(f.label),
                selected: _flag == f,
                onSelected: (_) => setState(() => _flag = f),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Salvar resultado',
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
