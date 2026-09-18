import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_setup_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/clinic/presentation/screens/clinic_dashboard_screen.dart';
import '../../features/clinic/presentation/screens/clinic_reception_screen.dart';
import '../../features/clinic/presentation/screens/clinic_triage_screen.dart';
import '../../features/clinic/presentation/screens/patient_360_screen.dart';
import '../../features/clinic/presentation/screens/voice_consent_screen.dart';
import '../../features/clinic/presentation/screens/voice_final_review_screen.dart';
import '../../features/clinic/presentation/screens/voice_home_screen.dart';
import '../../features/clinic/presentation/screens/voice_live_screen.dart';
import '../../features/clinic/presentation/screens/voice_review_screen.dart';
import '../../features/emr/presentation/screens/professional_patients_screen.dart';
import '../../features/gamification/presentation/gamification_screen.dart';
import '../../features/children/presentation/screens/child_detail_screen.dart';
import '../../features/children/presentation/screens/child_form_screen.dart';
import '../../features/children/presentation/screens/children_list_screen.dart';
import '../../features/courses/presentation/screens/courses_screens.dart';
import '../../features/growth/presentation/screens/growth_screen.dart';
import '../../features/vaccines/presentation/screens/vaccines_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/shell/presentation/screens/home_screen.dart';
import '../../features/shell/presentation/screens/maintenance_screen.dart';
import '../../features/shell/presentation/screens/not_found_screen.dart';
import '../../features/ai/presentation/screens/ai_chat_screen.dart';
import '../../features/library/presentation/screens/content_detail_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/shop/presentation/screens/shop_screens.dart';
import '../../features/telemedicine/presentation/professional_agenda_screen.dart';
import '../../features/telemedicine/presentation/telemedicine_screen.dart';
import '../../features/shell/presentation/screens/profile_tab.dart';
import '../../features/tools/presentation/screens/tools_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../shared/domain/entities/app_user.dart';
import '../config/dev_mode.dart';
import '../providers/core_providers.dart';
import '../services/app_logger.dart';
import '../services/remote_config_service.dart';
import 'route_authorization.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Faz o GoRouter reavaliar o `redirect` quando um provider muda.
///
/// O GoRouter aceita um `Listenable`; o Riverpod fala em streams. Esta ponte
/// converte um para o outro sem que o roteador precise conhecer o Riverpod.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (AsyncValue<AppUser?>? _, AsyncValue<AppUser?> __) => notifyListeners(),
    );
    ref.listen<AsyncValue<bool>>(
      onboardingSeenProvider,
      (AsyncValue<bool>? _, AsyncValue<bool> __) => notifyListeners(),
    );
  }
}

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefresh refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splashPath,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    observers: <NavigatorObserver>[
      ref.watch(analyticsProvider).observer,
      _BreadcrumbObserver(),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        NotFoundScreen(location: state.uri.toString()),

    // ------------------------------------------------------------- Guarda
    redirect: (BuildContext context, GoRouterState state) {
      final RemoteConfigService config = ref.read(remoteConfigProvider);
      final AsyncValue<AppUser?> auth = ref.read(authStateProvider);
      final AsyncValue<bool> onboarding = ref.read(onboardingSeenProvider);

      // A decisão em si mora em resolveRouteRedirect — testável sem
      // BuildContext nem GoRouterState. Aqui só coleta o estado atual.
      return resolveRouteRedirect(
        maintenanceMode: config.maintenanceMode,
        location: state.matchedLocation,
        authLoading: auth.isLoading,
        onboardingLoading: onboarding.isLoading,
        user: auth.valueOrNull,
        seenOnboarding: onboarding.valueOrNull ?? false,
        unlockAllRoles: DevMode.isEnabled,
      );
    },

    // -------------------------------------------------------------- Rotas
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splashPath,
        name: Routes.splashName,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: Routes.maintenancePath,
        name: Routes.maintenanceName,
        builder: (BuildContext context, GoRouterState state) =>
            const MaintenanceScreen(),
      ),
      GoRoute(
        path: Routes.onboardingPath,
        name: Routes.onboardingName,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.loginPath,
        name: Routes.loginName,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: Routes.registerPath,
        name: Routes.registerName,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.forgotPasswordPath,
        name: Routes.forgotPasswordName,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.roleSetupPath,
        name: Routes.roleSetupName,
        builder: (BuildContext context, GoRouterState state) =>
            const RoleSetupScreen(),
      ),

      // Crianças, crescimento e vacinas: rotas de tela cheia, empilhadas
      // sobre o shell. Ficam fora do ShellRoute de propósito — são fluxos de
      // foco, onde a barra de navegação só distrairia.
      GoRoute(
        path: Routes.childrenPath,
        name: Routes.childrenName,
        builder: (BuildContext context, GoRouterState state) =>
            const ChildrenListScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.childFormPath,
            name: Routes.childFormName,
            builder: (BuildContext context, GoRouterState state) =>
                ChildFormScreen(childId: state.uri.queryParameters['id']),
          ),
          GoRoute(
            path: Routes.childDetailPath,
            name: Routes.childDetailName,
            builder: (BuildContext context, GoRouterState state) =>
                ChildDetailScreen(
              childId: state.pathParameters['childId']!,
            ),
            routes: <RouteBase>[
              GoRoute(
                path: Routes.growthPath,
                name: Routes.growthName,
                builder: (BuildContext context, GoRouterState state) =>
                    GrowthScreen(
                  childId: state.pathParameters['childId']!,
                ),
              ),
              GoRoute(
                path: Routes.vaccinesPath,
                name: Routes.vaccinesName,
                builder: (BuildContext context, GoRouterState state) =>
                    VaccinesScreen(
                  childId: state.pathParameters['childId']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // Cursos: catálogo, detalhe e aula.
      GoRoute(
        path: Routes.coursesPath,
        name: Routes.coursesName,
        builder: (BuildContext context, GoRouterState state) =>
            const CoursesScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.courseDetailPath,
            name: Routes.courseDetailName,
            builder: (BuildContext context, GoRouterState state) =>
                CourseDetailScreen(
              courseId: state.pathParameters['courseId']!,
            ),
            routes: <RouteBase>[
              GoRoute(
                path: 'aula/:lessonId',
                name: Routes.lessonName,
                builder: (BuildContext context, GoRouterState state) =>
                    LessonScreen(
                  courseId: state.pathParameters['courseId']!,
                  lessonId: state.pathParameters['lessonId']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // Gamificação.
      GoRoute(
        path: Routes.gamificationPath,
        name: Routes.gamificationName,
        builder: (BuildContext context, GoRouterState state) =>
            const GamificationScreen(),
      ),
      GoRoute(
        path: Routes.leaderboardPath,
        name: Routes.leaderboardName,
        builder: (BuildContext context, GoRouterState state) =>
            const LeaderboardScreen(),
      ),

      // Administração. O guarda do roteador já barra quem não é admin.
      GoRoute(
        path: Routes.adminPath,
        name: Routes.adminName,
        builder: (BuildContext context, GoRouterState state) =>
            const AdminScreen(),
      ),

      // Marketplace.
      GoRoute(
        path: Routes.shopPath,
        name: Routes.shopName,
        builder: (BuildContext context, GoRouterState state) =>
            const ShopScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.productDetailPath,
            name: Routes.productDetailName,
            builder: (BuildContext context, GoRouterState state) =>
                ProductDetailScreen(
              productId: state.pathParameters['productId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.cartPath,
        name: Routes.cartName,
        builder: (BuildContext context, GoRouterState state) =>
            const CartScreen(),
      ),
      GoRoute(
        path: Routes.checkoutPath,
        name: Routes.checkoutName,
        builder: (BuildContext context, GoRouterState state) =>
            const CheckoutScreen(),
      ),
      GoRoute(
        path: Routes.ordersPath,
        name: Routes.ordersName,
        builder: (BuildContext context, GoRouterState state) =>
            const OrdersScreen(),
      ),

      // Telemedicina.
      GoRoute(
        path: Routes.telemedicinePath,
        name: Routes.telemedicineName,
        builder: (BuildContext context, GoRouterState state) =>
            const TelemedicineScreen(),
      ),

      // Consultorio 360 — fluxos de foco (tela cheia, fora do shell).
      // O dashboard vive DENTRO do ShellRoute; estes caminhos empilham
      // sobre ele, como /biblioteca/artigo/:id sobre a aba Biblioteca.
      GoRoute(
        path: Routes.clinicReceptionPath,
        name: Routes.clinicReceptionName,
        builder: (BuildContext context, GoRouterState state) =>
            const ClinicReceptionScreen(),
      ),
      GoRoute(
        path: Routes.clinicTriagePath,
        name: Routes.clinicTriageName,
        builder: (BuildContext context, GoRouterState state) =>
            ClinicTriageScreen(
          appointmentId: state.pathParameters['appointmentId']!,
        ),
      ),
      GoRoute(
        path: Routes.clinicPatient360Path,
        name: Routes.clinicPatient360Name,
        builder: (BuildContext context, GoRouterState state) =>
            Patient360Screen(
          childId: state.pathParameters['childId']!,
        ),
      ),
      GoRoute(
        path: Routes.clinicVoicePath,
        name: Routes.clinicVoiceName,
        builder: (BuildContext context, GoRouterState state) =>
            const VoiceHomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'consentimento',
            name: Routes.clinicVoiceConsentName,
            builder: (BuildContext context, GoRouterState state) =>
                const VoiceConsentScreen(),
          ),
          GoRoute(
            path: 'sessao/:sessionId',
            name: Routes.clinicVoiceLiveName,
            builder: (BuildContext context, GoRouterState state) =>
                VoiceLiveScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'revisao/:sessionId',
            name: Routes.clinicVoiceReviewName,
            builder: (BuildContext context, GoRouterState state) =>
                VoiceReviewScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'final/:sessionId',
            name: Routes.clinicVoiceFinalName,
            builder: (BuildContext context, GoRouterState state) =>
                VoiceFinalReviewScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
      ),

      // Leitura de conteúdo e conversa da IA: tela cheia, sobre o shell.
      GoRoute(
        path: '/biblioteca/artigo/:articleId',
        name: Routes.articleDetailName,
        builder: (BuildContext context, GoRouterState state) =>
            ContentDetailScreen(
          contentId: state.pathParameters['articleId']!,
        ),
      ),
      GoRoute(
        path: '/ia/conversa/:conversationId',
        name: Routes.aiChatName,
        builder: (BuildContext context, GoRouterState state) => AiChatScreen(
          conversationId: state.pathParameters['conversationId'],
        ),
      ),

      // Shell com navegacao persistente (barra inferior / rail / sidebar).
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: Routes.homePath,
            name: Routes.homeName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: HomeScreen()),
          ),
          GoRoute(
            path: Routes.clinicPath,
            name: Routes.clinicName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(
              child: ClinicDashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.agendaPath,
            name: Routes.agendaName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(
              child: ProfessionalAgendaScreen(),
            ),
          ),
          GoRoute(
            path: Routes.patientsPath,
            name: Routes.patientsName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(
              child: ProfessionalPatientsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.notificationsPath,
            name: Routes.notificationsName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(
              child: NotificationCenterScreen(),
            ),
          ),
          GoRoute(
            path: Routes.libraryPath,
            name: Routes.libraryName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: LibraryScreen()),
          ),
          GoRoute(
            path: Routes.aiPath,
            name: Routes.aiName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: AiChatScreen()),
          ),
          GoRoute(
            path: Routes.toolsPath,
            name: Routes.toolsName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: ToolsScreen()),
          ),
          GoRoute(
            path: Routes.profilePath,
            name: Routes.profileName,
            pageBuilder: (BuildContext context, GoRouterState state) =>
                const NoTransitionPage<void>(child: ProfileTab()),
          ),
        ],
      ),
    ],
  );
});

/// Registra a rota atual no Crashlytics, para reconstruir o caminho ate a falha.
class _BreadcrumbObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final String? name = route.settings.name;
    if (name != null) AppLogger.breadcrumb(name);
  }
}
