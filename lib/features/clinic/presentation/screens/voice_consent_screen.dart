import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/brand_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/voice_consultation.dart';
import '../providers/clinic_providers.dart';
import '../widgets/ai_medical_disclaimer_banner.dart';

/// Checklist de consentimento LGPD / gravacao antes de iniciar.
class VoiceConsentScreen extends ConsumerStatefulWidget {
  const VoiceConsentScreen({super.key});

  @override
  ConsumerState<VoiceConsentScreen> createState() => _VoiceConsentScreenState();
}

class _VoiceConsentScreenState extends ConsumerState<VoiceConsentScreen> {
  bool _informed = false;
  bool _purpose = false;
  bool _retention = false;
  bool _draftOnly = false;
  bool _busy = false;

  bool get _allChecked =>
      _informed && _purpose && _retention && _draftOnly;

  Future<void> _authorize() async {
    if (!_allChecked) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final String? childId =
        GoRouterState.of(context).uri.queryParameters['childId'];
    final String childName =
        GoRouterState.of(context).uri.queryParameters['childName'] ??
            'Paciente';

    if (childId == null || childId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um paciente (childId) antes de gravar.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final Result<VoiceConsultationSession> result = await ref
        .read(voiceConsultationRepositoryProvider)
        .startSession(
          childId: childId,
          childName: childName,
          professionalName: user.name,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (VoiceConsultationSession session) {
        context.pushReplacement(Routes.clinicVoiceLive(session.id));
      },
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Consentimento'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          const AiMedicalDisclaimerBanner(compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                Text(
                  'Antes de gravar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                _check(
                  value: _informed,
                  onChanged: (bool? v) =>
                      setState(() => _informed = v ?? false),
                  label:
                      'Paciente/responsavel foi informado sobre a gravacao.',
                ),
                _check(
                  value: _purpose,
                  onChanged: (bool? v) =>
                      setState(() => _purpose = v ?? false),
                  label:
                      'O audio sera usado apenas para gerar rascunho clinico.',
                ),
                _check(
                  value: _retention,
                  onChanged: (bool? v) =>
                      setState(() => _retention = v ?? false),
                  label:
                      'Politica de retencao de audio foi explicada e aceita.',
                ),
                _check(
                  value: _draftOnly,
                  onChanged: (bool? v) =>
                      setState(() => _draftOnly = v ?? false),
                  label:
                      'Entendo que a IA so gera RASCUNHO — eu reviso e confirmo.',
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _busy ? 'Autorizando…' : 'Autorizar e iniciar',
                  icon: Icons.verified_user_outlined,
                  isLoading: _busy,
                  onPressed: _allChecked && !_busy ? _authorize : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.brand,
      title: Text(label, style: const TextStyle(color: AppColors.navy)),
    );
  }
}
