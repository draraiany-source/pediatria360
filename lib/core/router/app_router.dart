import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/role_setup_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/clinic_org/presentation/providers/clinic_org_providers.dart';
import '../../features/workspace/presentation/providers/workspace_providers.dart';
import '../../features/clinic/presentation/screens/clinic_dashboard_screen.dart';
import '../../features/finance/presentation/screens/cash_flow_screen.dart';
import '../../features/finance/presentation/screens/delinquency_screen.dart';
import '../../features/finance/presentation/screens/dre_screen.dart';
import '../../features/finance/presentation/screens/finance_dashboard_screen.dart';
import '../../features/finance/presentation/screens/finance_reports_screen.dart';
import '../../features/finance/presentation/screens/payables_screen.dart';
import '../../features/finance/presentation/screens/production_screen.dart';
import '../../features/finance/presentation/screens/receivables_screen.dart';
import '../../features/billing/presentation/screens/billing_dashboard_screen.dart';
import '../../features/billing/presentation/screens/billing_list_screens.dart';
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/inventory/presentation/screens/inventory_list_screens.dart';
import '../../features/bi/presentation/screens/bi_admin_screen.dart';
import '../../features/bi/presentation/screens/bi_clinical_screen.dart';
import '../../features/bi/presentation/screens/bi_hub_screen.dart';
import '../../features/bi/presentation/screens/bi_ops_screen.dart';
import '../../features/bi/presentation/screens/bi_reception_screen.dart';
import '../../features/security/presentation/screens/audit_logs_screen.dart';
import '../../features/security/presentation/screens/permission_matrix_screen.dart';
import '../../features/clinic/presentation/screens/clinic_reception_screen.dart';
import '../../features/pending/domain/pending_item.dart';
import '../../features/pending/presentation/screens/crm_screen.dart';
import '../../features/pending/presentation/screens/pending_center_screen.dart';
import '../../features/clinic/presentation/screens/clinic_triage_screen.dart';
import '../../features/clinic/presentation/screens/patient_360_screen.dart';
import '../../features/clinic/presentation/screens/voice_consent_screen.dart';
import '../../features/clinic/presentation/screens/voice_final_review_screen.dart';
import '../../features/clinic/presentation/screens/voice_home_screen.dart';
import '../../features/clinic/presentation/screens/voice_live_screen.dart';
import '../../features/clinic/presentation/screens/voice_review_screen.dart';
import '../../features/clinic_org/presentation/screens/clinic_org_screens.dart';
import '../../features/supplementation/presentation/screens/calculator_prescription_screens.dart';
import '../../features/supplementation/presentation/screens/lab_screens.dart';
import '../../features/supplementation/presentation/screens/micronutrient_screens.dart';
import '../../features/supplementation/presentation/screens/supplement_dashboard_screen.dart';
import '../../features/supplementation/presentation/screens/supplement_more_screens.dart';
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
import '../widgets/feature_unavailable.dart';
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
        clinicMembership: ref.read(activeClinicMembershipProvider),
        workspace: ref.read(currentWorkspaceProvider),
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



      GoRoute(
        path: Routes.clinicOrgPath,
        name: Routes.clinicOrgName,
        builder: (BuildContext context, GoRouterState state) =>
            const ClinicOrgHubScreen(),
      ),
      GoRoute(
        path: Routes.clinicOrgCreatePath,
        name: Routes.clinicOrgCreateName,
        builder: (BuildContext context, GoRouterState state) =>
            const CreateClinicScreen(),
      ),

      // Suplementacao Pediatrica (profissional - fora do shell).
      GoRoute(
        path: Routes.supplementPath,
        name: Routes.supplementName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementDashboardScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementMicronutrientsPath,
        name: Routes.supplementMicronutrientsName,
        builder: (BuildContext context, GoRouterState state) =>
            const MicronutrientListScreen(),
      ),
      GoRoute(
        path: Routes.supplementMicronutrientPath,
        name: Routes.supplementMicronutrientName,
        builder: (BuildContext context, GoRouterState state) =>
            MicronutrientDetailScreen(
          micronutrientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.supplementLabRegisterPath,
        name: Routes.supplementLabRegisterName,
        builder: (BuildContext context, GoRouterState state) =>
            LabResultFormScreen(
          childId: state.uri.queryParameters['childId'],
          examId: state.uri.queryParameters['examId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementLabAiPath,
        name: Routes.supplementLabAiName,
        builder: (BuildContext context, GoRouterState state) =>
            LabAiInterpretScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementLabDetailPath,
        name: Routes.supplementLabDetailName,
        builder: (BuildContext context, GoRouterState state) =>
            LabExamDetailScreen(
          examId: state.pathParameters['examId']!,
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementLabsPath,
        name: Routes.supplementLabsName,
        builder: (BuildContext context, GoRouterState state) => LabExamsScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementCalculatorPath,
        name: Routes.supplementCalculatorName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementCalculatorScreen(
          micronutrientId: state.uri.queryParameters['micronutrientId'],
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementPrescriptionViewPath,
        name: Routes.supplementPrescriptionViewName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementPrescriptionViewScreen(
          prescriptionId: state.pathParameters['rxId']!,
        ),
      ),
      GoRoute(
        path: Routes.supplementPrescriptionPath,
        name: Routes.supplementPrescriptionName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementPrescriptionScreen(
          micronutrientId: state.uri.queryParameters['micronutrientId'],
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementProtocolsPath,
        name: Routes.supplementProtocolsName,
        builder: (BuildContext context, GoRouterState state) =>
            const SupplementProtocolsScreen(),
      ),
      GoRoute(
        path: Routes.supplementFoodsPath,
        name: Routes.supplementFoodsName,
        builder: (BuildContext context, GoRouterState state) =>
            const FoodLibraryScreen(),
      ),
      GoRoute(
        path: Routes.supplementParentPath,
        name: Routes.supplementParentName,
        builder: (BuildContext context, GoRouterState state) =>
            ParentGuidanceScreen(
          micronutrientId: state.uri.queryParameters['micronutrientId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementAiPath,
        name: Routes.supplementAiName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementAiScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementHistoryPath,
        name: Routes.supplementHistoryName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementHistoryScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementChartsPath,
        name: Routes.supplementChartsName,
        builder: (BuildContext context, GoRouterState state) =>
            SupplementChartsScreen(
          childId: state.uri.queryParameters['childId'],
        ),
      ),
      GoRoute(
        path: Routes.supplementFavoritesPath,
        name: Routes.supplementFavoritesName,
        builder: (BuildContext context, GoRouterState state) =>
            const SupplementFavoritesScreen(),
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
        path: Routes.clinicPendingPath,
        name: Routes.clinicPendingName,
        builder: (BuildContext context, GoRouterState state) {
          final String? focus = state.uri.queryParameters['focus'];
          PendingCenterFilter? initial;
          if (focus == 'vaccines' || focus == 'clinical') {
            initial = PendingCenterFilter.clinical;
          } else if (focus == 'messages') {
            initial = PendingCenterFilter.administrative;
          } else if (focus == 'returns') {
            initial = PendingCenterFilter.clinical;
          } else if (focus == 'exams') {
            initial = PendingCenterFilter.clinical;
          } else if (focus == 'financial') {
            initial = PendingCenterFilter.financial;
          }
          return PendingCenterScreen(initialFilter: initial);
        },
      ),
      GoRoute(
        path: Routes.clinicCrmPath,
        name: Routes.clinicCrmName,
        builder: (BuildContext context, GoRouterState state) =>
            const ClinicCrmScreen(),
      ),
      GoRoute(
        path: Routes.financePath,
        name: Routes.financeName,
        builder: (BuildContext context, GoRouterState state) =>
            FinanceDashboardScreen(initialTab: state.uri.queryParameters['tab']),
        routes: <RouteBase>[
          GoRoute(
            path: 'receber',
            name: Routes.financeReceivablesName,
            builder: (BuildContext context, GoRouterState state) =>
                ReceivablesScreen(
              highlightId: state.uri.queryParameters['receivableId'],
            ),
          ),
          GoRoute(
            path: 'pagar',
            name: Routes.financePayablesName,
            builder: (BuildContext context, GoRouterState state) =>
                const PayablesScreen(),
          ),
          GoRoute(
            path: 'fluxo',
            name: Routes.financeCashFlowName,
            builder: (BuildContext context, GoRouterState state) =>
                const CashFlowScreen(),
          ),
          GoRoute(
            path: 'dre',
            name: Routes.financeDreName,
            builder: (BuildContext context, GoRouterState state) =>
                const DreScreen(),
          ),
          GoRoute(
            path: 'inadimplencia',
            name: Routes.financeDelinquencyName,
            builder: (BuildContext context, GoRouterState state) =>
                const DelinquencyScreen(),
          ),
          GoRoute(
            path: 'producao',
            name: Routes.financeProductionName,
            builder: (BuildContext context, GoRouterState state) =>
                const ProductionScreen(),
          ),
          GoRoute(
            path: 'relatorios',
            name: Routes.financeReportsName,
            builder: (BuildContext context, GoRouterState state) =>
                const FinanceReportsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.billingPath,
        name: Routes.billingName,
        builder: (BuildContext context, GoRouterState state) =>
            const BillingDashboardScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'planos',
            name: Routes.billingPlansName,
            builder: (BuildContext context, GoRouterState state) =>
                const InsurancePlansScreen(),
          ),
          GoRoute(
            path: 'autorizacoes',
            name: Routes.billingAuthorizationsName,
            builder: (BuildContext context, GoRouterState state) =>
                const AuthorizationsScreen(),
          ),
          GoRoute(
            path: 'guias',
            name: Routes.billingGuidesName,
            builder: (BuildContext context, GoRouterState state) =>
                const GuidesScreen(),
          ),
          GoRoute(
            path: 'lotes',
            name: Routes.billingBatchesName,
            builder: (BuildContext context, GoRouterState state) =>
                const BatchesScreen(),
          ),
          GoRoute(
            path: 'glosas',
            name: Routes.billingGlosasName,
            builder: (BuildContext context, GoRouterState state) =>
                const GlosasScreen(),
          ),
          GoRoute(
            path: 'relatorios',
            name: Routes.billingReportsName,
            builder: (BuildContext context, GoRouterState state) =>
                const BillingReportsScreen(),
          ),
          GoRoute(
            path: 'carteirinhas',
            name: Routes.billingPatientInsuranceName,
            builder: (BuildContext context, GoRouterState state) =>
                PatientInsuranceScreen(
              childId: state.uri.queryParameters['childId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.inventoryPath,
        name: Routes.inventoryName,
        builder: (BuildContext context, GoRouterState state) =>
            const InventoryDashboardScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'itens',
            name: Routes.inventoryItemsName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventoryItemsScreen(),
          ),
          GoRoute(
            path: 'lotes',
            name: Routes.inventoryLotsName,
            builder: (BuildContext context, GoRouterState state) =>
                InventoryLotsScreen(itemId: state.uri.queryParameters['itemId']),
          ),
          GoRoute(
            path: 'movimentos',
            name: Routes.inventoryMovementsName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventoryMovementsScreen(),
          ),
          GoRoute(
            path: 'fornecedores',
            name: Routes.inventorySuppliersName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventorySuppliersScreen(),
          ),
          GoRoute(
            path: 'compras',
            name: Routes.inventoryPurchasesName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventoryPurchaseOrdersScreen(),
          ),
          GoRoute(
            path: 'inventario',
            name: Routes.inventoryCountName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventoryCountScreen(),
          ),
          GoRoute(
            path: 'relatorios',
            name: Routes.inventoryReportsName,
            builder: (BuildContext context, GoRouterState state) =>
                const InventoryReportsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.auditPath,
        name: Routes.auditName,
        builder: (BuildContext context, GoRouterState state) =>
            const AuditLogsScreen(),
      ),
      GoRoute(
        path: Routes.permissionsPath,
        name: Routes.permissionsName,
        builder: (BuildContext context, GoRouterState state) =>
            const PermissionMatrixScreen(),
      ),
      GoRoute(
        path: Routes.biPath,
        name: Routes.biName,
        builder: (BuildContext context, GoRouterState state) =>
            const BiHubScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'admin',
            name: Routes.biAdminName,
            builder: (BuildContext context, GoRouterState state) =>
                const BiAdminScreen(),
          ),
          GoRoute(
            path: 'clinico',
            name: Routes.biClinicalName,
            builder: (BuildContext context, GoRouterState state) =>
                const BiClinicalScreen(),
          ),
          GoRoute(
            path: 'recepcao',
            name: Routes.biReceptionName,
            builder: (BuildContext context, GoRouterState state) =>
                const BiReceptionScreen(),
          ),
          GoRoute(
            path: 'operacional',
            name: Routes.biOpsName,
            builder: (BuildContext context, GoRouterState state) =>
                const BiOpsScreen(),
          ),
        ],
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
        builder: (BuildContext context, GoRouterState state) {
          if (!AppConfig.voiceConsultationEnabled) {
            return const FeatureUnavailableScreen(
              title: 'Consulta com IA',
              message:
                  'A gravacao assistida e o prontuario por voz ainda nao '
                  'estao disponiveis nesta versao de teste. Use o prontuario '
                  'manual no editor de atendimento.',
            );
          }
          return const VoiceHomeScreen();
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'consentimento',
            name: Routes.clinicVoiceConsentName,
            builder: (BuildContext context, GoRouterState state) {
              if (!AppConfig.voiceConsultationEnabled) {
                return const FeatureUnavailableScreen(
                  title: 'Consulta com IA',
                  message:
                      'Funcao fora do escopo deste teste fechado.',
                );
              }
              return const VoiceConsentScreen();
            },
          ),
          GoRoute(
            path: 'sessao/:sessionId',
            name: Routes.clinicVoiceLiveName,
            builder: (BuildContext context, GoRouterState state) {
              if (!AppConfig.voiceConsultationEnabled) {
                return const FeatureUnavailableScreen(
                  title: 'Consulta com IA',
                  message:
                      'Funcao fora do escopo deste teste fechado.',
                );
              }
              return VoiceLiveScreen(
                sessionId: state.pathParameters['sessionId']!,
              );
            },
          ),
          GoRoute(
            path: 'revisao/:sessionId',
            name: Routes.clinicVoiceReviewName,
            builder: (BuildContext context, GoRouterState state) {
              if (!AppConfig.voiceConsultationEnabled) {
                return const FeatureUnavailableScreen(
                  title: 'Consulta com IA',
                  message:
                      'Funcao fora do escopo deste teste fechado.',
                );
              }
              return VoiceReviewScreen(
                sessionId: state.pathParameters['sessionId']!,
              );
            },
          ),
          GoRoute(
            path: 'final/:sessionId',
            name: Routes.clinicVoiceFinalName,
            builder: (BuildContext context, GoRouterState state) {
              if (!AppConfig.voiceConsultationEnabled) {
                return const FeatureUnavailableScreen(
                  title: 'Consulta com IA',
                  message:
                      'Funcao fora do escopo deste teste fechado.',
                );
              }
              return VoiceFinalReviewScreen(
                sessionId: state.pathParameters['sessionId']!,
              );
            },
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
