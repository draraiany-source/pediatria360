import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/module_flags.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/router/route_access.dart';
import '../../../core/router/routes.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../management/presentation/management_common.dart';
import '../domain/tia_cris_intent.dart';

/// Arquivos da personagem. Nulo enquanto a ilustracao oficial nao for entregue.
class TiaCrisAssets {
  const TiaCrisAssets._();

  static const String? portrait = null;
}

class _ChatLine {
  const _ChatLine({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Aba da Tia Cris — recepcionista IA (M2), separada do assistente clinico.
class ReceptionistAiScreen extends ConsumerStatefulWidget {
  const ReceptionistAiScreen({super.key});

  @override
  ConsumerState<ReceptionistAiScreen> createState() =>
      _ReceptionistAiScreenState();
}

class _ReceptionistAiScreenState extends ConsumerState<ReceptionistAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final TiaCrisEngine _engine = const TiaCrisEngine();
  final List<_ChatLine> _lines = <_ChatLine>[];
  String? _whatsAppStatus;
  bool _loadingWa = false;
  static const bool _voiceArmed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadWhatsAppStatus() async {
    final clinic = ref.read(activeClinicProvider).valueOrNull;
    if (clinic == null) {
      setState(() => _whatsAppStatus = 'Nenhuma clinica ativa.');
      return;
    }
    setState(() {
      _loadingWa = true;
      _whatsAppStatus = null;
    });
    final result =
        await ref.read(managementRepositoryProvider).whatsAppStatus(clinic.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingWa = false;
      _whatsAppStatus = result.fold(
        (Map<String, dynamic> status) {
          final bool configured = status['configured'] == true ||
              status['ready'] == true ||
              status['connected'] == true;
          return configured
              ? 'WhatsApp configurado (status real do servidor).'
              : 'WhatsApp nao configurado ? nenhum envio sera simulado.';
        },
        (failure) =>
            'Nao foi possivel obter o status real do WhatsApp: ${failure.message}',
      );
    });
  }

  void _send() {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    final TiaCrisReply reply = _engine.reply(text);
    setState(() {
      _lines.add(_ChatLine(fromUser: true, text: text));
      _lines.add(_ChatLine(fromUser: false, text: reply.text));
      _controller.clear();
    });
    if (reply.suggestWhatsApp) {
      _loadWhatsAppStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RemoteConfigService remote = ref.watch(remoteConfigProvider);
    final bool runtimeOn = ModuleFlags.tiaCrisRuntimeEnabled(remote);
    final bool bookingOn = ModuleFlags.tiaCrisBookingEnabled(remote);
    final bool kidsOn = ModuleFlags.kidsSpaceEnabled(remote);
    final bool canOpenAgenda = canOpenRoute(ref, Routes.agendaPath);
    final bool canOpenReception = canOpenRoute(ref, Routes.clinicReceptionPath);
    final bool canOpenWa = canOpenRoute(ref, Routes.managementCommunicationPath);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ContentBounds(
        maxWidth: 1040,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const TiaCrisPortrait(size: 112),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tia Cris — Recepcionista IA',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Apoio a recepcao convencional: duvidas administrativas, '
                        'agenda real e encaminhamento humano. '
                        'Nao substitui a recepcao presencial.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            DataWarningBanner(
              text: runtimeOn
                  ? 'Runtime da Tia Cris ligado neste ambiente. '
                      'Respostas administrativas sao deterministicas; '
                      'agendamento so via backend oficial'
                      '${bookingOn ? '.' : ' (booking flag ainda off).'}'
                  : 'Atendimento automatico desligado '
                      '(tia_cris_enabled / TIA_CRIS_ENABLED). '
                      'A aba permanece para escopo, limites e encaminhamento.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const _ScopeCard(
              title: 'O que ela faz',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              items: <String>[
                'Informar que horarios/servicos vem do cadastro da clinica.',
                'Orientar agendamento/remarcacao/cancelamento via agenda real.',
                'Encaminhar para a recepcao humana.',
                'Apresentar o Espaco Kids (sem dados clinicos).',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _ScopeCard(
              title: 'O que ela nunca faz',
              icon: Icons.block_rounded,
              color: AppColors.danger,
              items: <String>[
                'Diagnosticar, prescrever ou interpretar exames.',
                'Inventar horarios, precos, profissionais ou servicos.',
                'Acessar prontuario infantil ou financeiro clinico.',
                'Marcar WhatsApp como enviado sem status real do provedor.',
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (canOpenAgenda)
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.agendaPath),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Abrir agenda'),
                  ),
                if (canOpenReception)
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.clinicReceptionPath),
                    icon: const Icon(Icons.how_to_reg_rounded),
                    label: const Text('Recepcao humana'),
                  ),
                if (kidsOn)
                  OutlinedButton.icon(
                    onPressed: () => context.go(Routes.kidsPath),
                    icon: const Icon(Icons.sports_esports_outlined),
                    label: const Text('Espaco Kids'),
                  ),
                if (canOpenWa)
                  OutlinedButton.icon(
                    onPressed: _loadingWa ? null : _loadWhatsAppStatus,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Status WhatsApp'),
                  ),
              ],
            ),
            if (_whatsAppStatus != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(_whatsAppStatus!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Atendimento por voz'),
              subtitle: const Text(
                'Reconhecimento de fala somente quando autorizado e configurado. '
                'Neste ambiente permanece desligado — sem simular STT.',
              ),
              value: _voiceArmed,
              onChanged: null,
            ),
            if (runtimeOn) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text('Conversa (texto)', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Container(
                height: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: ListView.builder(
                  itemCount: _lines.length,
                  itemBuilder: (BuildContext context, int i) {
                    final _ChatLine line = _lines[i];
                    return Align(
                      alignment: line.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: line.fromUser
                              ? AppColors.brandIndicator
                              : AppColors.lightSurfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(line.text),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ex.: quero remarcar minha consulta',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _send,
                    child: const Text('Enviar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TiaCrisPortrait extends StatelessWidget {
  const TiaCrisPortrait({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    final String? asset = TiaCrisAssets.portrait;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.brandIndicator,
          borderRadius: BorderRadius.circular(24),
        ),
        child: asset == null
            ? const Center(
                child: Text(
                  'Ilustracao pendente',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(asset, fit: BoxFit.cover),
              ),
      ),
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            for (final String item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item'),
              ),
          ],
        ),
      ),
    );
  }
}
