import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/clinical_ui.dart';
import '../../shared/clinical/clinical_documents.dart';
import '../../shared/previsit/pre_visit_guidance.dart';
import '../demo_session.dart';
import '../widgets/demo_widgets.dart';

const String preVisitGuidancePath = '/orientacoes-previas';

/// Orientações que a família recebe antes de cada tipo de consulta.
class DemoPreVisitGuidanceScreen extends StatefulWidget {
  const DemoPreVisitGuidanceScreen({super.key});

  @override
  State<DemoPreVisitGuidanceScreen> createState() =>
      _DemoPreVisitGuidanceScreenState();
}

class _DemoPreVisitGuidanceScreenState
    extends State<DemoPreVisitGuidanceScreen> {
  final TextEditingController _general = TextEditingController();
  final Map<VisitCategory, TextEditingController> _byCat =
      <VisitCategory, TextEditingController>{
        for (final VisitCategory c in VisitCategory.values)
          c: TextEditingController(),
      };
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    for (final TextEditingController c in <TextEditingController>[
      _general,
      ..._byCat.values,
    ]) {
      c.addListener(() {
        if (!_dirty) setState(() => _dirty = true);
      });
    }
  }

  void _load() {
    final PreVisitGuidance g = demoSession.preVisitGuidance;
    _general.text = g.general.join('\n');
    for (final VisitCategory c in VisitCategory.values) {
      _byCat[c]!.text = (g.byCategory[c] ?? const <String>[]).join('\n');
    }
    _dirty = false;
    _error = null;
  }

  @override
  void dispose() {
    _general.dispose();
    for (final TextEditingController c in _byCat.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _lines(TextEditingController c) => c.text.split('\n');

  void _save() {
    try {
      demoSession.savePreVisitGuidance(
        general: _lines(_general),
        byCategory: <VisitCategory, List<String>>{
          for (final VisitCategory c in VisitCategory.values)
            c: _lines(_byCat[c]!),
        },
      );
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
      return;
    } on StateError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(_load);
    showDemoSnack(
      context,
      'Orientações salvas. A família já vê a nova versão.',
    );
  }

  Future<void> _leave() async {
    if (!_dirty) {
      context.go('/inicio');
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text('As alterações não salvas serão perdidas.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.go('/inicio');
  }

  Widget _field(TextEditingController c, String label, String key) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      key: ValueKey<String>('orientacao-$key'),
      controller: c,
      minLines: 2,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Uma orientação por linha.',
        alignLabelWithHint: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final PreVisitGuidance g = demoSession.preVisitGuidance;
    final TextTheme t = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: const Text('Orientações antes da consulta'),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dirty ? () => setState(_load) : null,
                    child: const Text('Cancelar alterações'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(g.isReviewed ? 'Salvar' : 'Revisar e salvar'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: DemoContent(
          maxWidth: 820,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              const DemoNotice(
                icon: Icons.info_outline_rounded,
                text:
                    'Avisos administrativos para a família: o que levar, como '
                    'se preparar e quando chegar. Não coloque conduta, dose '
                    'nem diagnóstico. O aviso de urgência aparece sempre.',
              ),
              const SizedBox(height: AppSpacing.sm),
              PremiumCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  g.isReviewed
                      ? 'Revisado por ${g.reviewedBy} em '
                            '${formatDocDateTime(g.reviewedAt!)}.'
                      : PreVisitGuidanceRules.suggestedLabel,
                  style: t.bodyMedium,
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                DemoNotice(
                  icon: Icons.error_outline_rounded,
                  color: AppColors.danger,
                  text: _error!,
                ),
              ],
              const DemoSectionTitle('Para todas as consultas'),
              _field(_general, 'Orientações gerais', 'geral'),
              const DemoSectionTitle('Por tipo de consulta'),
              for (final VisitCategory c in VisitCategory.values)
                _field(_byCat[c]!, c.label, c.name),
              Text(
                'Aviso fixo: ${PreVisitGuidanceRules.safetyNotice}',
                style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
