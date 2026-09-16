import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_assets.dart';
import '../../../../core/config/dev_mode.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Marca que a apresentacao inicial ja foi vista. O roteador le esta chave
/// para decidir entre `/onboarding` e `/login`.
class OnboardingPrefs {
  const OnboardingPrefs._();

  static const String key = 'onboarding_seen';

  static Future<bool> seen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> markSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

/// Provider que o roteador observa para saber se deve mostrar a apresentacao.
final FutureProvider<bool> onboardingSeenProvider = FutureProvider<bool>(
  (Ref ref) async {
    if (DevMode.isEnabled) return true;
    return OnboardingPrefs.seen();
  },
);

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.body,
  });

  final String image;
  final String title;
  final String body;
}

/// Tres telas, tres promessas concretas. Nada de "bem-vindo ao app".
const List<_Slide> _slides = <_Slide>[
  _Slide(
    image: AppAssets.onboarding1,
    title: 'Acompanhe cada fase',
    body: 'Peso, altura e perimetro cefalico plotados nas curvas da OMS, '
        'com idade corrigida para prematuros.',
  ),
  _Slide(
    image: AppAssets.onboarding2,
    title: 'Respostas com base clinica',
    body: 'A IA responde a partir de protocolos pediatricos e sempre mostra '
        'a fonte. Nao substitui o pediatra — prepara a conversa com ele.',
  ),
  _Slide(
    image: AppAssets.onboarding3,
    title: 'Nunca perca uma vacina',
    body: 'Calendario do PNI com lembrete no dia certo e comprovante '
        'guardado junto.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingPrefs.markSeen();
    ref.invalidate(onboardingSeenProvider);
    if (mounted) context.goNamed(Routes.loginName);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppMotion.normal,
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ContentBounds(
          maxWidth: 560,
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Pular'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (int index) => setState(() => _page = index),
                  itemBuilder: (BuildContext context, int index) {
                    final _Slide slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: AppRadius.xlAll,
                            child: Image.asset(
                              slide.image,
                              width: 260,
                              height: 260,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            slide.title,
                            style: theme.textTheme.displaySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            slide.body,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(
                  _slides.length,
                  (int index) => AnimatedContainer(
                    duration: AppMotion.fast,
                    // 3px: gap entre os pontos do carrossel (6px de altura). Metade do
                    // menor valor da escala (xxs=2) seria justo demais para o
                    // tamanho do ponto; o próximo (xs=4) alargaria 33%.
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: index == _page ? 24 : 6,
                    decoration: BoxDecoration(
                      color: index == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: AppRadius.pillAll,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AppButton(
                  label: _isLast ? 'Começar agora' : 'Continuar',
                  onPressed: _next,
                ),
              ),
              if (_isLast)
                TextButton(
                  onPressed: _finish,
                  child: const Text('Já tem uma conta? Entrar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
