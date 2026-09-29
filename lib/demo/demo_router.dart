import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/clinical/clinical_documents.dart';
import 'demo_session.dart';
import 'screens/agenda_screens.dart';
import 'screens/brand_screens.dart';
import 'screens/business_screens.dart';
import 'screens/care_screens.dart';
import 'screens/consultation_screen.dart';
import 'screens/documents_screens.dart';
import 'screens/family_guidance_screens.dart';
import 'screens/dose_screens.dart';
import 'screens/growth_screens.dart';
import 'screens/home_screen.dart';
import 'screens/lab_screens.dart';
import 'screens/patient_supplement_screens.dart';
import 'screens/patients_screens.dart';
import 'screens/pre_visit_screens.dart';
import 'screens/record_screens.dart';
import 'screens/restricted_screen.dart';
import 'screens/routine_forms.dart';
import 'screens/routine_screens.dart';
import 'screens/routine_summary_screens.dart';
import 'screens/rx_template_screens.dart';
import 'screens/supplement_screens.dart';
import 'screens/welcome_screen.dart';
import 'screens/well_child_screen.dart';
import 'widgets/demo_shell.dart';
import 'widgets/demo_widgets.dart';

/// Libera o modulo para o perfil atual ou mostra "Acesso restrito".
Widget _guard(DemoModule module, Widget child) =>
    demoSession.canOpen(module) ? child : DemoRestrictedScreen(module: module);

/// Consulta, documentos e calculadora: so o profissional de saude.
/// O ScaffoldMessenger proprio faz os avisos aparecerem acima da barra de
/// acoes do fluxo, e nao sobre ela.
Widget _clinical(String title, Widget child) => demoSession.canUseClinicalTools
    ? ScaffoldMessenger(child: child)
    : DemoRestrictedScreen(module: DemoModule.pacientes, title: title);

/// Curvas: profissional (detalhe) e responsável (visão simples, só das
/// crianças vinculadas). Recepção, financeiro e administração não veem.
Widget _growth(Widget child) => demoSession.canSeeGrowth
    ? ScaffoldMessenger(child: child)
    : const DemoRestrictedScreen(
        module: DemoModule.pacientes,
        title: 'Crescimento',
      );

/// Rotina da criança: o responsável (só as crianças dele) edita; o
/// profissional só lê, e só se a família autorizou o compartilhamento.
Widget _routine(
  String patientId,
  Widget child, {
  bool edit = false,
  bool messenger = true,
}) {
  if (!demoSession.canUseRoutine || (edit && !demoSession.canEditRoutine)) {
    return const DemoRestrictedScreen(
      module: DemoModule.rotina,
      title: 'Rotina da criança',
    );
  }
  if (demoSession.routinePatient(patientId) == null) {
    return DemoRoutineUnavailableScreen(patientId: patientId);
  }
  return messenger ? ScaffoldMessenger(child: child) : child;
}

/// Pré-consulta da família: só o responsável (a tela confere o vínculo com
/// a criança).
Widget _familyPreVisit(Widget child) =>
    demoSession.profile == DemoProfile.responsavel
    ? ScaffoldMessenger(child: child)
    : const DemoRestrictedScreen(
        module: DemoModule.pacientes,
        title: 'Pré-consulta da família',
      );

/// Respostas e anexos enviados: só o profissional da clínica que atende.
Widget _preVisitReview(Widget child) {
  if (demoSession.canReviewPreVisits) return ScaffoldMessenger(child: child);
  return DemoRestrictedScreen(
    module: DemoModule.pacientes,
    title: 'Pré-consulta',
    reason: demoSession.canSeeClinicalRecord
        ? 'Os anexos da pré-consulta ficam com a equipe da clínica que '
              'atende a criança. Esta conta é de outra clínica.'
        : null,
  );
}

Widget _flow(DemoModule module, Widget child) =>
    _guard(module, ScaffoldMessenger(child: child));

Page<void> _tab(GoRouterState state, DemoModule module, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: _guard(module, child));

/// Rotas da demonstracao. Cada tela tem endereco proprio (`/#/agenda`),
/// entao voltar do navegador, gesto do iPhone e voltar do Android seguem o
/// historico normal.
final GoRouter demoRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: demoSession,
  redirect: (BuildContext context, GoRouterState state) {
    // `?perfil=recepcao` permite compartilhar um link ja no perfil certo.
    final DemoProfile? fromLink = DemoProfile.fromSlug(
      state.uri.queryParameters['perfil'],
    );
    if (fromLink != null) demoSession.enterSilently(fromLink);

    final bool atWelcome = state.matchedLocation == '/';
    if (demoSession.profile == null && !atWelcome) return '/';
    return null;
  },
  errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
    appBar: AppBar(title: const Text('Página não encontrada')),
    body: DemoEmpty(
      title: 'Endereço inexistente',
      message: 'Esta página não existe na demonstração.',
      actionLabel: 'Ir para o início',
      onAction: () => context.go(demoSession.profile == null ? '/' : '/inicio'),
    ),
  ),
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const DemoWelcomeScreen(),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) =>
          DemoShell(location: state.matchedLocation, child: child),
      routes: <RouteBase>[
        GoRoute(
          path: '/inicio',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.inicio, const DemoHomeScreen()),
        ),
        GoRoute(
          path: '/pacientes',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.pacientes, const DemoPatientsScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: 'novo',
              builder: (BuildContext context, GoRouterState state) =>
                  _guard(DemoModule.pacientes, const DemoPatientFormScreen()),
            ),
            GoRoute(
              path: ':id',
              builder: (BuildContext context, GoRouterState state) => _guard(
                DemoModule.pacientes,
                DemoPatientDetailScreen(patientId: state.pathParameters['id']!),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: 'prontuario',
                  builder: (BuildContext context, GoRouterState state) =>
                      demoSession.canSeeClinicalRecord
                      ? DemoRecordScreen(patientId: state.pathParameters['id']!)
                      : const DemoRestrictedScreen(
                          module: DemoModule.pacientes,
                          title: 'Prontuário',
                        ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'nova',
                      builder: (BuildContext context, GoRouterState state) =>
                          demoSession.canSeeClinicalRecord
                          ? DemoEncounterEditorScreen(
                              patientId: state.pathParameters['id']!,
                            )
                          : const DemoRestrictedScreen(
                              module: DemoModule.pacientes,
                              title: 'Prontuário',
                            ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'pre-consulta',
                  builder: (BuildContext context, GoRouterState state) =>
                      _preVisitReview(
                        DemoPreVisitReviewScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['id']!,
                          consultationId: state.uri.queryParameters['consulta'],
                        ),
                      ),
                ),
                GoRoute(
                  path: 'crescimento',
                  builder: (BuildContext context, GoRouterState state) =>
                      _growth(
                        DemoGrowthScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['id']!,
                          consultationId: state.uri.queryParameters['consulta'],
                        ),
                      ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'nova',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Crescimento',
                            DemoGrowthEntryScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                    ),
                    GoRoute(
                      path: ':mid/corrigir',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Crescimento',
                            DemoGrowthEntryScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              measurementId: state.pathParameters['mid'],
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'exames',
                  builder: (BuildContext context, GoRouterState state) =>
                      _clinical(
                        'Exames',
                        DemoLabScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['id']!,
                          consultationId: state.uri.queryParameters['consulta'],
                        ),
                      ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'novo',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Exames',
                            DemoLabEntryScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                    ),
                    GoRoute(
                      path: ':lid',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Exames',
                            DemoLabDetailScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              labId: state.pathParameters['lid']!,
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                      routes: <RouteBase>[
                        GoRoute(
                          path: 'editar',
                          builder:
                              (BuildContext context, GoRouterState state) =>
                                  _clinical(
                                    'Exames',
                                    DemoLabEntryScreen(
                                      key: ValueKey<String>(
                                        state.uri.toString(),
                                      ),
                                      patientId: state.pathParameters['id']!,
                                      labId: state.pathParameters['lid'],
                                      consultationId:
                                          state.uri.queryParameters['consulta'],
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'suplementacao',
                  builder: (BuildContext context, GoRouterState state) =>
                      _clinical(
                        'Suplementação',
                        DemoPatientSupplementScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['id']!,
                          consultationId: state.uri.queryParameters['consulta'],
                        ),
                      ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: ':sid',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Suplementação',
                            DemoSupplementDecisionScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              topicId: state.pathParameters['sid']!,
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'consulta/:cid',
                  builder: (BuildContext context, GoRouterState state) =>
                      _clinical(
                        'Consulta',
                        demoSession
                                    .consultationById(
                                      state.pathParameters['cid']!,
                                    )
                                    ?.isWellChild ==
                                true
                            ? DemoWellChildScreen(
                                key: ValueKey<String>(state.uri.toString()),
                                patientId: state.pathParameters['id']!,
                                consultationId: state.pathParameters['cid']!,
                                initialStep: state.uri.queryParameters['etapa'],
                              )
                            : DemoConsultationScreen(
                                key: ValueKey<String>(state.uri.toString()),
                                patientId: state.pathParameters['id']!,
                                consultationId: state.pathParameters['cid']!,
                                initialStep: state.uri.queryParameters['etapa'],
                              ),
                      ),
                ),
                GoRoute(
                  path: 'documentos',
                  builder: (BuildContext context, GoRouterState state) =>
                      _clinical(
                        'Documentos',
                        DemoDocumentsScreen(
                          patientId: state.pathParameters['id']!,
                        ),
                      ),
                  routes: <RouteBase>[
                    GoRoute(
                      path: 'novo',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Documentos',
                            DemoDocumentEditorScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              kind: DocKind.fromSlug(
                                state.uri.queryParameters['tipo'],
                              ),
                              consultationId:
                                  state.uri.queryParameters['consulta'],
                            ),
                          ),
                    ),
                    GoRoute(
                      path: ':docId',
                      builder: (BuildContext context, GoRouterState state) =>
                          _clinical(
                            'Documentos',
                            DemoDocumentViewerScreen(
                              key: ValueKey<String>(state.uri.toString()),
                              patientId: state.pathParameters['id']!,
                              docId: state.pathParameters['docId']!,
                            ),
                          ),
                      routes: <RouteBase>[
                        GoRoute(
                          path: 'editar',
                          builder:
                              (BuildContext context, GoRouterState state) =>
                                  _clinical(
                                    'Documentos',
                                    DemoDocumentEditorScreen(
                                      key: ValueKey<String>(
                                        state.uri.toString(),
                                      ),
                                      patientId: state.pathParameters['id']!,
                                      docId: state.pathParameters['docId'],
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/rotina',
          pageBuilder: (BuildContext context, GoRouterState state) => _tab(
            state,
            DemoModule.rotina,
            DemoRoutineScreen(
              key: ValueKey<String>(state.uri.toString()),
              view: state.uri.queryParameters['vista'],
              mode: state.uri.queryParameters['modo'],
              day: state.uri.queryParameters['dia'],
            ),
          ),
        ),
        GoRoute(
          path: '/rotina/:pid',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              NoTransitionPage<void>(
                key: state.pageKey,
                child: _routine(
                  state.pathParameters['pid']!,
                  DemoRoutineScreen(
                    key: ValueKey<String>(state.uri.toString()),
                    patientId: state.pathParameters['pid'],
                    view: state.uri.queryParameters['vista'],
                    mode: state.uri.queryParameters['modo'],
                    day: state.uri.queryParameters['dia'],
                    consultationId: state.uri.queryParameters['consulta'],
                    from: state.uri.queryParameters['de'],
                  ),
                  messenger: false,
                ),
              ),
          routes: <RouteBase>[
            GoRoute(
              path: 'evento/novo',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoRoutineEventFormScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  patientId: state.pathParameters['pid']!,
                  day: state.uri.queryParameters['dia'],
                  vaccineName: state.uri.queryParameters['vacina'],
                  vaccineDose: state.uri.queryParameters['dose'],
                ),
                edit: true,
              ),
            ),
            GoRoute(
              path: 'evento/:eid/editar',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoRoutineEventFormScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  patientId: state.pathParameters['pid']!,
                  eventId: state.pathParameters['eid'],
                ),
                edit: true,
              ),
            ),
            GoRoute(
              path: 'registro/:rid',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoDiaryEntryScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  patientId: state.pathParameters['pid']!,
                  entryId: state.pathParameters['rid']!,
                  from: state.uri.queryParameters['de'],
                  consultationId: state.uri.queryParameters['consulta'],
                ),
              ),
            ),
            GoRoute(
              path: 'medicamento/:docId/:item',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoMedicationPlanScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  patientId: state.pathParameters['pid']!,
                  docId: state.pathParameters['docId']!,
                  index: int.tryParse(state.pathParameters['item']!) ?? -1,
                ),
              ),
            ),
            GoRoute(
              path: 'resumo',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoRoutineSummaryScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  patientId: state.pathParameters['pid']!,
                ),
                edit: true,
              ),
            ),
            GoRoute(
              path: 'orientacoes',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoFamilyOrientationsScreen(
                  patientId: state.pathParameters['pid']!,
                  from: state.uri.queryParameters['de'],
                ),
                edit: true,
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: ':docId',
                  builder: (BuildContext context, GoRouterState state) =>
                      _routine(
                        state.pathParameters['pid']!,
                        DemoFamilyOrientationScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['pid']!,
                          docId: state.pathParameters['docId']!,
                          from: state.uri.queryParameters['de'],
                        ),
                        edit: true,
                      ),
                ),
              ],
            ),
            GoRoute(
              path: 'resumos',
              builder: (BuildContext context, GoRouterState state) => _routine(
                state.pathParameters['pid']!,
                DemoSharedSummariesScreen(
                  patientId: state.pathParameters['pid']!,
                ),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: ':sid',
                  builder: (BuildContext context, GoRouterState state) =>
                      _routine(
                        state.pathParameters['pid']!,
                        DemoSharedSummaryScreen(
                          key: ValueKey<String>(state.uri.toString()),
                          patientId: state.pathParameters['pid']!,
                          summaryId: state.pathParameters['sid']!,
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/pre-consulta/:aid',
          builder: (BuildContext context, GoRouterState state) =>
              _familyPreVisit(
                DemoPreVisitScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  appointmentId: state.pathParameters['aid']!,
                  from: state.uri.queryParameters['de'],
                ),
              ),
        ),
        GoRoute(
          path: rxTemplatesPath,
          builder: (BuildContext context, GoRouterState state) => _clinical(
            'Modelos de receita',
            DemoRxTemplatesScreen(
              key: ValueKey<String>(state.uri.toString()),
              patientId: state.uri.queryParameters['paciente'],
              consultationId: state.uri.queryParameters['consulta'],
            ),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: 'novo',
              builder: (BuildContext context, GoRouterState state) => _clinical(
                'Modelos de receita',
                const DemoRxTemplateEditorScreen(),
              ),
            ),
            GoRoute(
              path: ':tid/editar',
              builder: (BuildContext context, GoRouterState state) => _clinical(
                'Modelos de receita',
                DemoRxTemplateEditorScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  templateId: state.pathParameters['tid'],
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/calculadora',
          pageBuilder: (BuildContext context, GoRouterState state) => _tab(
            state,
            DemoModule.calculadora,
            DemoCalculatorScreen(
              key: ValueKey<String?>(state.uri.queryParameters['paciente']),
              initialPatientId: state.uri.queryParameters['paciente'],
            ),
          ),
        ),
        GoRoute(
          path: '/suplementacao',
          pageBuilder: (BuildContext context, GoRouterState state) => _tab(
            state,
            DemoModule.suplementacao,
            const DemoSupplementsScreen(),
          ),
          routes: <RouteBase>[
            GoRoute(
              path: ':sid',
              builder: (BuildContext context, GoRouterState state) => _flow(
                DemoModule.suplementacao,
                DemoSupplementDetailScreen(
                  sheetId: state.pathParameters['sid']!,
                ),
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: 'editar',
                  builder: (BuildContext context, GoRouterState state) => _flow(
                    DemoModule.suplementacao,
                    DemoSupplementEditScreen(
                      key: ValueKey<String>(state.uri.toString()),
                      sheetId: state.pathParameters['sid']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/agenda',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.agenda, const DemoAgendaScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: ':id',
              builder: (BuildContext context, GoRouterState state) => _guard(
                DemoModule.agenda,
                DemoAppointmentDetailScreen(
                  appointmentId: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/vacinacao',
          pageBuilder: (BuildContext context, GoRouterState state) => _tab(
            state,
            DemoModule.vacinacao,
            DemoVaccinesScreen(
              key: ValueKey<String?>(state.uri.queryParameters['paciente']),
              initialPatientId: state.uri.queryParameters['paciente'],
            ),
          ),
        ),
        GoRoute(
          path: '/telemedicina',
          pageBuilder: (BuildContext context, GoRouterState state) => _tab(
            state,
            DemoModule.telemedicina,
            const DemoTelemedicineScreen(),
          ),
        ),
        GoRoute(
          path: '/biblioteca',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.biblioteca, const DemoLibraryScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: ':id',
              builder: (BuildContext context, GoRouterState state) => _guard(
                DemoModule.biblioteca,
                DemoArticleScreen(articleId: state.pathParameters['id']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/relatorios',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.relatorios, const DemoReportsScreen()),
        ),
        GoRoute(
          path: '/financeiro',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.financeiro, const DemoFinanceScreen()),
        ),
        GoRoute(
          path: '/perfil',
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _tab(state, DemoModule.perfil, const DemoProfileScreen()),
          routes: <RouteBase>[
            GoRoute(
              path: 'logomarca',
              builder: (BuildContext context, GoRouterState state) =>
                  demoSession.canBrand
                  ? const ScaffoldMessenger(child: DemoLogoScreen())
                  : const DemoRestrictedScreen(
                      module: DemoModule.perfil,
                      title: 'Logomarca',
                    ),
            ),
          ],
        ),
      ],
    ),
  ],
);
