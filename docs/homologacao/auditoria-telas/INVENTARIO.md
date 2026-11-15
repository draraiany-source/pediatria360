# Inventário de telas e rotas — Pediatria 360 (app Flutter)

> Auditoria estática de código (somente leitura). Nenhum código-fonte foi alterado.
> Escopo: `lib/` do app principal (`main.dart` + `lib/core/router/app_router.dart`). O app de demonstração em `lib/demo/**` (`main_demo.dart`, `demo_router.dart`) está **fora do escopo** e não foi inventariado.
> Data da auditoria: 28/10/2026.

## Convenções

- **Rota**: caminho do GoRouter, ou "sem rota (push)" quando a tela é aberta com `Navigator.push`/`MaterialPageRoute`.
- **Perfil (regra)**: perfil autorizado segundo `lib/core/router/route_authorization.dart` (abreviado `RA`), função `resolveRouteRedirect`. Quando a tela é push, ela herda o acesso da tela de origem (não passa pelo `redirect`).
- **Perfis**: `UserRole` (parent / professional / admin) + `ClinicRole` da membership ativa (clinicAdmin, receptionist, finance, physician, healthProfessional, nursing, technician, patient) + `WorkspaceProfile` calculado em `WorkspaceAccess.grantedProfiles` (admin / professional / receptionist / finance / patient).
- **DevMode**: com `DevMode.isEnabled`, `unlockAllRoles` ignora todas as checagens — o inventário considera produção (DevMode desligado).
- **Flags de produção** (`AppConfig`): `videoConsultationEnabled=false`, `voiceConsultationEnabled=false`, `paymentGatewayEnabled=false`, `tissOperatorEnabled=false`, `icpDigitalSignatureEnabled=false`.
- **Sair (logout)**: só existe em `/perfil` (com confirmação) e no menu lateral do `AppShell` (`lib/features/shell/presentation/app_shell.dart:825-830`). Rotas fora do ShellRoute (todas exceto `/inicio`, `/consultorio`, `/agenda`, `/pacientes`, `/avisos`, `/biblioteca`, `/ia`, `/ferramentas`, `/perfil`) **não** oferecem logout — apenas voltar (`popOrHome`/seta).
- **Estados**: **funcional** (fluxo completo com leitura/escrita real), **parcial** (funciona, mas com lacunas relevantes), **apenas visual** (UI sem operação real), **com erro** (comportamento incorreto confirmado no código).
- L = leitura, E = escrita, `fn:` = Cloud Function callable.

## Resumo quantitativo

| Área | Telas | Funcional | Parcial | Apenas visual | Com erro |
|---|---:|---:|---:|---:|---:|
| Entrada e conta | 13 | 10 | 3 | 0 | 0 |
| Família | 12 | 9 | 3 | 0 | 0 |
| Profissional/Consultório (inclui Voz e Suplementação) | 33 | 15 | 15 | 0 | 3 |
| Recepção | 4 | 1 | 3 | 0 | 0 |
| Financeiro | 8 | 4 | 2 | 0 | 2 |
| Faturamento | 8 | 2 | 5 | 0 | 1 |
| Estoque | 8 | 4 | 4 | 0 | 0 |
| BI | 5 | 5 | 0 | 0 | 0 |
| Gestão (inclui Minha clínica) | 13 | 7 | 6 | 0 | 0 |
| Conteúdo/Loja/Cursos | 14 | 13 | 1 | 0 | 0 |
| Admin | 6 | 4 | 1 | 1 | 0 |
| Erro | 2 | 2 | 0 | 0 | 0 |
| **Total** | **126** | **76** | **43** | **1** | **6** |

Observação: as telas de Conteúdo/Loja/Cursos e parte da Suplementação foram verificadas de forma mais superficial (ações, snackbars e chamadas de repositório), sem leitura linha a linha.

---

## 1. Entrada e conta

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| SplashScreen | `/` (splashPath) | Todos (RA: rotas públicas) | Abertura do app | Nenhuma (redireciona) | L: sessão Auth, `users/{uid}` | Redirect para `/onboarding`, `/login`, `/role-setup` ou `/inicio` | — / — | funcional — apenas roteia conforme estado da sessão |
| MaintenanceScreen | `/manutencao` | Todos (RA: pública) | Redirect quando app em manutenção | Tentar novamente | L: config remota | — | Sem voltar / sem sair | funcional — tela de bloqueio intencional |
| OnboardingScreen | `/onboarding` | Não autenticado (RA: pública) | Primeiro uso | Avançar páginas, Começar | — | `/login` | — / — | funcional |
| LoginScreen | `/login` | Não autenticado (RA: pública) | Onboarding, logout | Entrar (e-mail/senha), Google, Esqueci senha, Criar conta | E: Auth `signIn`; `fn:registerDevice` | `/inicio` (via redirect), `/esqueci-senha`, `/cadastro` | — / — | funcional |
| RegisterScreen | `/cadastro` | Não autenticado (RA: pública) | Login | Criar conta | E: Auth `signUp`, `users/{uid}` | `/role-setup` (redirect) | `popOrHome` / — | funcional |
| ForgotPasswordScreen | `/esqueci-senha` | Não autenticado (RA: pública) | Login | Enviar e-mail de redefinição | E: Auth `sendPasswordReset` | Volta ao login | Voltar / — | funcional |
| RoleSetupScreen | `/role-setup` | Autenticado sem onboarding (RA: passo de onboarding) | Redirect pós-cadastro | Escolher Família ou Profissional (CRM + especialidade), aceitar termos | E: `fn:recordConsent`, `completeOnboarding` em `users/{uid}` | `/inicio` | Botão "Sair" / sim | funcional — porém o CRM é autodeclarado e libera áreas de staff (ver Achados A1) |
| WorkspaceHomeScreen (HomeScreen) | `/inicio` (Shell) | Todo autenticado | Pós-login, menu "Início" | Atalhos por workspace (admin, profissional, recepção, financeiro, família); sino | L: agenda, membership, notificações | Admin: `/permissoes`, `/admin`, `/bi`, `/auditoria`; Profissional: `/agenda`, `/consultorio`, `/gestao`, `/pacientes`; Recepção: `/agenda`, `/consultorio/recepcao`, `/consultorio/solicitacoes`, `/consultorio/pendencias`; Financeiro: `/financeiro/*`, `/faturamento`; Família: `/criancas`, `/biblioteca`, `/ferramentas`, `/ia`, `/convite-clinica`; sino → `/avisos` | Shell / sim (menu lateral) | parcial — atalho "Prescrições" leva a `/pacientes` (`profile_homes.dart:405-411`); IA clínica só mostra snackbar com flag desligada |
| ProfileTab | `/perfil` (Shell) | Todo autenticado | Menu "Perfil" | Editar perfil, Notificações, Segurança, Minha clínica, Ajuda (mailto), Painel admin, Crianças, Sair (com confirmação) | L: `users/{uid}`, membership | push ProfileEditScreen, NotificationCenterScreen, PrivacyScreen; `/clinica`; `/admin`; `/criancas` | Shell / sim | parcial — dados falsos/errados: "Clínica" exibe `user.specialty` (`profile_tab.dart:202-205`), prefixo "Dra." forçado (`:140`), "Último acesso hoje" usa `DateTime.now()` (`:73-74`), "Senha, biometria" abre tela só de privacidade (`:281`) |
| ProfileEditScreen | sem rota (push) | Herda de `/perfil` | Perfil → Editar | Salvar nome/dados | E: `users/{uid}` | Volta ao perfil | Voltar / não | funcional |
| PrivacyScreen | sem rota (push) | Herda de `/perfil` | Perfil → Segurança | Exportar dados, solicitar/cancelar exclusão (com confirmação), revogar consentimentos | L: `fn:dataProcessingManifest`, `consents`; E: `fn:exportUserData`, `fn:requestDataDeletion`, `fn:cancelDataDeletion` | — | Voltar (`pop`/`go('/')`) / não | funcional — LGPD; não contém troca de senha nem biometria |
| NotificationCenterScreen | `/avisos` (Shell) | Todo autenticado | Sino, menu "Mensagens/Alertas", Perfil | Abrir aviso (marca lido e navega), configurações | L/E: `users/{uid}/notifications` | `context.push(route)` do aviso (`notification_center_screen.dart:220-240`); push NotificationSettingsScreen | Shell / sim | parcial — rotas vindas do backend podem não existir (ver Achados A6) |
| NotificationSettingsScreen | sem rota (push) | Herda de `/avisos` | Avisos → engrenagem | Ligar/desligar categorias, salvar | `fn:getNotificationSettings`, `fn:updateNotificationSettings` | — | Voltar sem confirmar alterações pendentes / não | funcional |

## 2. Família

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| ChildrenListScreen | `/criancas` | Qualquer autenticado — **sem guarda** em RA | Home família, Perfil, menu "Vacinas" do profissional, tiles do dashboard da clínica | Abrir criança, Nova criança | L: `users/{uid}/children`, `linked_children`, vacinas | `/criancas/nova`, `/criancas/:id` | `popOrHome` / não | funcional (para o próprio usuário) |
| ChildFormScreen | `/criancas/nova?id=` | Sem guarda | Lista, detalhe, timeline do profissional | Salvar | E: `children`, `users/{uid}/children`, `change_log` | `pop` | Voltar sem PopScope / não | parcial — ao editar paciente vindo da timeline do profissional usa `ownerId ''` (`child_form_screen.dart:123-130,173-175`) |
| ChildDetailScreen | `/criancas/:childId` | Sem guarda | Lista | Editar, excluir (confirma), Crescimento, Vacinas, Responsáveis, Acessos, Resumos de consulta | L: `children`; E: exclusão | `/criancas/nova?id=`, `.../crescimento`, `.../vacinas`; push ChildGuardiansScreen, ChildAccessScreen, VisitSummariesScreen | Voltar / não | funcional |
| GrowthScreen | `/criancas/:childId/crescimento` | Sem guarda | Detalhe da criança, Patient 360, Timeline | Registrar medida, ver curvas | L/E: `.../growth` (escopo do **usuário atual**) | — | Voltar / não | funcional para família; com erro quando aberta pelo profissional (ver A7) |
| VaccinesScreen | `/criancas/:childId/vacinas` | Sem guarda | Detalhe, push FCM (`notifications.ts:254`) | Marcar dose aplicada | L/E: `.../vaccines` | — | Voltar / não | funcional para família; com erro via profissional (A7) |
| ChildGuardiansScreen | sem rota (push) | Herda | Detalhe → Responsáveis | Adicionar/remover responsável | L/E: `guardians` | — | Voltar / não | funcional |
| ChildAccessScreen | sem rota (push) | Herda | Detalhe → Acessos | Conceder (nível, clínica, validade 90 d, confirma), revogar (confirma), renovar | `fn:lookupProfessional`; L/E: `authorized_professionals` | — | Voltar / não | funcional |
| VisitSummariesScreen | sem rota (push) | Herda | Detalhe → Resumos | Abrir resumo (bottom sheet) | L: `visit_summaries` liberados | — | Voltar (`Navigator.pop`) / não | funcional — somente leitura |
| TelemedicineScreen | `/telemedicina` | Sem guarda | Menu profissional, timeline, push FCM | Entrar na consulta, cancelar, confirmar presença, pré-consulta | `fn:joinConsultation`, `fn:setAppointmentStatus`; L: `appointments` | `/pre-consulta/:id`; push PreVisitQuestionnaireFormScreen | `popOrHome` / não | parcial — "Agendar" desativado/sem ação (`telemedicine_screen.dart:637-646`); controles de chamada "integração futura" (`:680-690`); vídeo é placeholder |
| PreVisitQuestionnaireFormScreen | sem rota (push) | Herda | Telemedicina (consulta não-clínica) | Enviar questionário | E: `pre_visit_questionnaires` | `pop` | Voltar sem PopScope / não | funcional |
| AcceptInviteScreen | `/convite-clinica?code=` | Sem guarda | Home família, link de convite | Pré-visualizar convite, escolher criança, escopo e dias, aceitar | `fn:previewClinicIntake`, `fn:acceptClinicIntake` | `/inicio` | Voltar / não | funcional — mas orienta "Perfil > Confirmar e-mail", opção inexistente (`accept_invite_screen.dart:165`) |
| FamilyAnamnesisScreen | `/pre-consulta/:appointmentId` | Sem guarda | Telemedicina (consulta de clínica) | Iniciar, salvar rascunho, enviar | `fn:startAnamnesis`, `fn:saveAnamnesisDraft`, `fn:submitAnamnesis` | — | Voltar sem PopScope / não | parcial — campo de anexos é só informativo (`anamnesis_screens.dart:268-275`) |

## 3. Profissional / Consultório

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| ClinicDashboardScreen | `/consultorio` (Shell) | `UserRole.professional` (RA:95-122); não-profissional sem acesso (RA:175-201) | Home, menu "Consultório" | Tiles | L: agenda, membership | `/consultorio/recepcao`, `/agenda`, `/pacientes`, `/consultorio/pendencias`, `/consultorio/crm`, `/bi`, `/financeiro`, `/faturamento`, `/estoque`, `/criancas` (x2), `/auditoria`, `/permissoes` | Shell / sim | parcial — tiles sem `canOpenRoute`; "Crescimento" e "Vacinas" levam a `/criancas` do próprio profissional (`clinic_dashboard_screen.dart:177,187`) |
| ProfessionalAgendaScreen | `/agenda` (Shell) | Profissional; workspace recepção (RA:175-201) | Home, menu | Confirmar, cancelar (motivo), remarcar, iniciar atendimento, ver pré-consulta, disponibilidade semanal | L: `myAgendaProvider` (`professional_agenda_screen.dart:185,298`); `fn:setAppointmentStatus`, `fn:rescheduleAppointment`; E: `encounters` | push EncounterEditorScreen | Shell / sim | parcial — "+ Novo atendimento" abre disponibilidade (`:343`, `:429-430`); confirmar sem feedback (`:93-97`); recepção vê só agenda própria |
| ProfessionalPatientsScreen | `/pacientes` (Shell) | Profissional com permissão de prontuário (RA passo 8) | Menu "Pacientes/Prontuário" | Buscar, filtrar, novo paciente, abrir timeline | L: `linked_children`, `children` | push NewIntakeScreen, PatientTimelineScreen | Shell / sim | funcional |
| NewIntakeScreen | sem rota (push) | Herda de `/pacientes` | "+ Novo paciente" | Criar solicitação/convite | `fn:createClinicIntake` | — | Voltar sem PopScope / não | parcial — envio por WhatsApp "simulado" (`clinic_intakes_screen.dart:56`); data/hora livre sem slots |
| PatientTimelineScreen | sem rota (push) | Herda (também aberta por pendências, sem guarda) | Pacientes, Patient 360, pendências | Ver eventos, abrir crescimento/vacinas/editar, telemedicina | L: `encounters`, `visit_summaries`, `lab_results` | `/criancas/:id/crescimento`, `/vacinas`, `/criancas/nova?id=` (`patient_timeline_screen.dart:169-172,346,357,938,1580,1598`); `/telemedicina` (`:391`) | Voltar / não | com erro — links leem dados do escopo do profissional (A7); card Desenvolvimento "próxima etapa" (`:359-367`) |
| Patient360Screen | `/consultorio/paciente/:childId/360` | Profissional (RA:95-122) — não bloqueado para workspace recepção/financeiro (RA:140-165) | Recepção (botão 360), busca | Ver resumo, abrir timeline | L: `children`, `appointments`, `encounters` | push PatientTimelineScreen (`patient_360_screen.dart:193-221`); crescimento/vacinas (`:752,762`) | Voltar / não | com erro — links de crescimento/vacinas leem escopo errado (A7) |
| ClinicTriageScreen | `/consultorio/triagem/:id` | Profissional (RA:95-122) — sem bloqueio por workspace | Recepção → "Triagem" | Registrar sinais vitais | E: `triage_records`; `updateWorkflowStatus` | — | Voltar / não | com erro — exige digitar "ID da criança" (`clinic_triage_screen.dart:55,134`); resultado ignorado antes do snackbar de sucesso (`:87-95`) |
| EncounterEditorScreen | sem rota (push) | Herda (agenda/pendências) | Agenda → Iniciar; pendências | Autosave, assinar (confirma), assistente, resumo, documentos | E: `encounters`; `fn:signEncounter`, `fn:clinicalAssist` | push VisitSummaryEditorScreen, DocumentEditorScreen | Voltar / não | funcional — retificação (`amendEncounter`, `encounter_repository.dart:254`) sem UI |
| DocumentEditorScreen | sem rota (push) | Herda | Encounter → Documentos | "Emitir e imprimir" | `fn:issueClinicalDocument`; E: `clinical_documents` | push DocumentViewerScreen | X descarta sem confirmar / não | parcial — emite sem rascunho/prévia; nome da clínica fixo "Pediatria 360" (`document_editor_screen.dart:179`) |
| DocumentViewerScreen | sem rota (push) | Herda | Editor, timeline | Cancelar documento, compartilhar/imprimir, copiar código | `fn:cancelClinicalDocument`; Printing | — | Voltar / não | funcional |
| VisitSummaryEditorScreen | sem rota (push) | Herda | Encounter | Salvar rascunho, finalizar, liberar à família | E: `visit_summaries` | — | Voltar / não | funcional — `amendVisitSummary` sem UI |
| VoiceHomeScreen | `/consultorio/ia` | Profissional + permissão prontuário (RA passo 8) | Home "IA clínica", Gestão "Transcrever consulta" | — | — | — | Voltar / não | parcial — com `voiceConsultationEnabled=false` o router devolve FeatureUnavailableScreen (`app_router.dart:819-831`) |
| VoiceConsentScreen | `/consultorio/ia/consentimento` | Idem | VoiceHome | Consentimento | `fn:startVoiceConsultation` | `sessao/:id` | Voltar / não | parcial — desativada por flag |
| VoiceLiveScreen | `/consultorio/ia/sessao/:sessionId` | Idem | Consentimento | Gravar/finalizar | `fn:finalizeVoiceRecording`, `fn:updateVoiceSession` | `revisao/:id` | Voltar / não | parcial — desativada por flag |
| VoiceReviewScreen | `/consultorio/ia/revisao/:sessionId` | Idem | Live | Estruturar rascunho, descartar | `fn:structureVoiceDraft`, `fn:discardVoiceSession` | `final/:id` | Voltar / não | parcial — desativada por flag |
| VoiceFinalReviewScreen | `/consultorio/ia/final/:sessionId` | Idem | Revisão | Aplicar ao prontuário | `fn:applyVoiceDraftToEncounter` | — | Voltar / não | parcial — desativada por flag |
| SupplementDashboardScreen | `/suplementacao` | Profissional (RA:95-122) | Menu lateral profissional | Atalhos, micronutrientes recentes | L: `SupplementPaths` (recentes, favoritos) | subrotas de `/suplementacao/*` | Voltar / não | funcional |
| MicronutrientListScreen | `/suplementacao/micronutrientes` | Idem | Dashboard | Buscar, abrir | L: catálogo local | `/suplementacao/micronutrientes/:id` | Voltar / não | funcional |
| MicronutrientDetailScreen | `/suplementacao/micronutrientes/:id` | Idem | Lista, IA | Favoritar, calculadora, exames, orientação | E: recentes/favoritos | calculadora, exames, `/suplementacao/orientacao` | Voltar / não | funcional |
| LabResultFormScreen | `/suplementacao/exames/novo` | Idem | Exames | Salvar exame | E: `labResults` | — | Voltar sem PopScope / não | parcial — exige digitar ID do paciente (`lab_screens.dart:270-275`) |
| LabAiInterpretScreen | `/suplementacao/exames/ia` | Idem | Detalhe do exame | Interpretar, salvar resumo como rascunho | E: `clinicalNotes` | — | Voltar / não | parcial — interpretação local; só salva rascunho |
| LabExamDetailScreen | `/suplementacao/exames/:id` | Idem | Lista de exames | Interpretar com IA | L: `labResults` | `/suplementacao/exames/ia` | Voltar / não | funcional |
| LabExamsScreen | `/suplementacao/exames` | Idem | Dashboard | Novo exame, abrir | L: `labResults` | novo / detalhe | Voltar / não | funcional |
| SupplementCalculatorScreen | `/suplementacao/calculadora` | Idem | Dashboard, protocolos | Calcular dose, gerar prescrição | Cálculo local | `/suplementacao/prescricao?…` | Voltar / não | funcional |
| SupplementPrescriptionViewScreen | `/suplementacao/prescricao/:id` | Idem | Após confirmar prescrição | PDF, Compartilhar, nova prescrição | L: `prescriptions` | `/suplementacao/prescricao` | Voltar / não | parcial — PDF e Compartilhar só mostram snackbar (`calculator_prescription_screens.dart:517-535`) |
| SupplementPrescriptionScreen | `/suplementacao/prescricao` | Idem | Calculadora | Salvar rascunho, confirmar | E: `prescriptions`, `auditLogs` | view da prescrição | Voltar sem PopScope / não | funcional |
| SupplementProtocolsScreen | `/suplementacao/protocolos` | Idem | Dashboard | Abrir calculadora | Conteúdo local | calculadora | Voltar / não | funcional |
| FoodLibraryScreen | `/suplementacao/alimentos` | Idem | Dashboard | Buscar alimentos | Conteúdo local | — | Voltar / não | funcional |
| ParentGuidanceScreen | `/suplementacao/orientacao` | Idem | Micronutriente | PDF, Compartilhar | Conteúdo local | — | Voltar / não | parcial — PDF/Compartilhar "estrutura pronta" (`supplement_more_screens.dart:250-268`) |
| SupplementAiScreen | `/suplementacao/ia` | Idem | Dashboard | Organizar texto livre, salvar nota/rascunho | E: `clinicalNotes`, `aiDrafts` | micronutriente, exames, calculadora | Voltar / não | parcial — organizador local (sem modelo de IA remoto) |
| SupplementHistoryScreen | `/suplementacao/historico` | Idem | Dashboard | Ver histórico | L: `timeline` | — | Voltar / não | funcional |
| SupplementChartsScreen | `/suplementacao/graficos` | Idem | Dashboard | Ver gráficos | L: `labResults` | — | Voltar / não | funcional |
| SupplementFavoritesScreen | `/suplementacao/favoritos` | Idem | Dashboard | Abrir favorito | L: favoritos | micronutriente | Voltar / não | funcional |

## 4. Recepção

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| ClinicReceptionScreen | `/consultorio/recepcao` | Profissional; workspace recepção (RA:175-201) | Home recepção "Check-in", menu "Recepção" | Quadro, fila, check-in, mudar status, copiar link de check-in | L: `appointments` (clínica toda se `usesClinicWideAgenda`); `clinicRepository.checkIn`; `fn:setAppointmentStatus` | `/consultorio/triagem/:id` (`clinic_reception_screen.dart:627`), `/consultorio/paciente/:id/360` (`:655`) | Voltar / não | parcial — Triagem/360 devolvem recepcionista conta família para o início; deep link `pediatria360://checkin/{id}` só é copiado |
| ClinicIntakesScreen | `/consultorio/solicitacoes` | Profissional; workspace recepção | Home "Paciente novo" | Cancelar, renovar código | `fn:cancelClinicIntake`, `fn:renewClinicIntake`; L: `clinic_intakes` | — | Voltar / não | funcional |
| PendingCenterScreen | `/consultorio/pendencias?focus=` | Profissional; workspace recepção (bloqueado p/ financeiro, RA:140-165) | Home, dashboard | Ações de pendência (abrir atendimento, timeline, registrar pagamento) | L/E: `pending_tracking` | push EncounterEditor/Timeline sem passar pelo guard (`pending_actions.dart:79-91,127-130`); `/financeiro/receber?appointmentId=` (query ignorada, `:104-106`) | Voltar / não | parcial — contorna autorização e perde contexto do pagamento |
| CrmScreen | `/consultorio/crm` | Profissional (RA:95-122) | Dashboard | Ver segmentos | L: contatos/segmentos | — | Voltar / não | parcial — catálogo de automações estático com ícones `link_off` (`crm_screen.dart:133-148`) |

## 5. Financeiro

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| FinanceDashboardScreen | `/financeiro` | Profissional (sem membership!) ou workspace financeiro (RA:95-122,175-201) | Home financeiro, dashboard clínica, Gestão | KPIs, 7 módulos | L: `finance_receivables`, `finance_payables` | `receber`, `pagar`, `fluxo`, `dre`, `inadimplencia`, `producao`, `relatorios` | Voltar / sim (só no menu do Shell, não aqui) | funcional — `initialTab` recebido e nunca usado (`app_router.dart:608`) |
| ReceivablesScreen | `/financeiro/receber?receivableId=` | Idem | Dashboard, inadimplência, pendências | Registrar pagamento, editar valor, cancelar, recibo PDF, abrir consulta | `fn:recordPayment`; E: `finance_receivables`, `finance_audit_logs` | `/agenda` (`receivables_screen.dart:170`) | Voltar / não | com erro — método fixo pix e resultado ignorado sem feedback (`:126-135`); editar valor sem permissão e resultado ignorado (`:75-78,136-142`); cancelar sem confirmação/motivo (`:143-148`); recibo é PREVIEW não persistido com clínica "Consultorio" (`:150-167`); mojibake (`:60`); erro bruto `$e` |
| PayablesScreen | `/financeiro/pagar` | Idem | Dashboard | Nova conta, marcar paga | E: `finance_payables` | — | Voltar / não | com erro — dropdown de categoria sem `StatefulBuilder` (`payables_screen.dart:77-90`); vencimento fixo +30 d (`:111`); toque na linha marca como paga sem confirmação (`:48,123-135`); mojibake (`:46`) |
| CashFlowScreen | `/financeiro/fluxo` | Idem | Dashboard | Ver fluxo | L: recebidos/pagos | — | Voltar / não | parcial — só realizado, sem previsto x realizado; mojibake (`cash_flow_screen.dart:53`) |
| DreScreen | `/financeiro/dre` | Idem | Dashboard | Ver DRE | L | — | Voltar / não | funcional — leitura |
| DelinquencyScreen | `/financeiro/inadimplencia` | Idem | Dashboard | Abrir recebível | L | `/financeiro/receber?receivableId=` | Voltar / não | funcional — leitura |
| ProductionScreen | `/financeiro/producao` | Idem | Dashboard | Ver produção | L | — | Voltar / não | funcional — leitura |
| FinanceReportsScreen | `/financeiro/relatorios` | Idem | Dashboard, Home financeiro | Copiar CSV, "Recibo exemplo (PDF)" | L | — | Voltar / não | parcial — CSV só para área de transferência; recibo é amostra do 1º recebível (`finance_reports_screen.dart:85-107`) |

## 6. Faturamento

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| BillingDashboardScreen | `/faturamento` | Profissional ou workspace financeiro (RA:95-122,175-201) | Dashboard clínica, Home financeiro | Módulos | L: `billing_*` | 7 subrotas | Voltar / não | funcional — hub |
| Planos (lista) | `/faturamento/planos` | Idem | Hub | Listar | L: `insurance_plans` | — | Voltar / não | parcial — somente leitura, sem cadastro |
| Autorizações (lista) | `/faturamento/autorizacoes` | Idem | Hub | Listar | L: `insurance_authorizations` | — | Voltar / não | parcial — leitura; exibe enums e IDs crus |
| Guias (lista) | `/faturamento/guias` | Idem | Hub | Listar | L: `billing_guides` | — | Voltar / não | parcial — sem criação de guia |
| Lotes (lista) | `/faturamento/lotes` | Idem | Hub | Listar | L: `billing_batches` | — | Voltar / não | parcial — sem envio (TISS desligado) |
| Glosas | `/faturamento/glosas` | Idem | Hub | Recurso de glosa (sheet) | E: `billing_glosas`, `billing_audit_logs` | — | Voltar / não | com erro — resultado de `updateAppeal` ignorado, sem snackbar (`billing_list_screens.dart:190-198`) |
| Relatórios de faturamento | `/faturamento/relatorios` | Idem | Hub | Copiar CSV | L | — | Voltar / não | funcional |
| Carteirinhas | `/faturamento/carteirinhas` | Idem | Hub | Listar | L: `patient_insurances` | — | Voltar / não | parcial — leitura, IDs de criança crus |

## 7. Estoque

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| InventoryDashboardScreen | `/estoque` | `UserRole.professional` (RA:95-122) — sem workspace dedicado | Dashboard clínica | Módulos | L: `inventory_*` | 7 subrotas | Voltar / não | funcional — hub |
| Itens | `/estoque/itens` | Idem | Hub | Listar | L | — | Voltar / não | parcial — sem cadastro de item |
| Lotes | `/estoque/lotes` | Idem | Hub | Transferir entre unidades | E: `inventory_*` | — | Voltar / não | funcional |
| Movimentos | `/estoque/movimentos` | Idem | Hub | Registrar movimento | E | — | Voltar / não | funcional |
| Fornecedores | `/estoque/fornecedores` | Idem | Hub | Listar | L | — | Voltar / não | parcial — sem cadastro |
| Compras | `/estoque/compras` | Idem | Hub | Listar | L | — | Voltar / não | parcial — sem criação de pedido |
| Inventário (contagem) | `/estoque/inventario` | Idem | Hub | Iniciar contagem | E | — | Voltar / não | parcial — não há como concluir a contagem |
| Relatórios de estoque | `/estoque/relatorios` | Idem | Hub | CSV | L | — | Voltar / não | funcional |

## 8. BI

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| BiHubScreen | `/bi` | Profissional ou admin (RA:95-122); sem bloqueio por workspace | Home admin, dashboard clínica | KPIs, exportar CSV | L: agregados; E: `logExport` | `/bi/admin`, `/bi/clinico`, `/bi/recepcao`, `/bi/operacional` | Voltar / não | funcional |
| BI administrativo | `/bi/admin` | Idem | Hub | Drill-down (com `canOpenRoute`) | L | rotas de origem | Voltar / não | funcional |
| BI clínico | `/bi/clinico` | Idem | Hub | Drill-down | L | — | Voltar / não | funcional |
| BI recepção | `/bi/recepcao` | Idem | Hub | Drill-down | L | — | Voltar / não | funcional |
| BI operacional | `/bi/operacional` | Idem | Hub | Drill-down | L | — | Voltar / não | funcional |

## 9. Gestão (inclui Minha clínica)

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| ManagementHubScreen | `/gestao` | `managementRouteAllowed` (RA:76-82; bloco duplicado 84-92) | Home (profissional, recepção, financeiro) | Tiles de módulos, "Transcrever consulta" | L: membership | `/agenda`, `/consultorio`, `/financeiro`, `/gestao/*`, `/consultorio/ia/consentimento` | Voltar / não | parcial — tiles sem `canOpenRoute` (`management_hub_screen.dart:74-75,95`); clinicAdmin conta família é devolvido ao início |
| ManagementCrmScreen | `/gestao/crm` | Idem | Hub | Indicadores, contatos, duplicados | `fn:getCrmIndicators`, `fn:findCrmDuplicates`; L: `crm_contacts` | — | Voltar / não | parcial — texto fala em mesclar, sem botão (`marketing_crm_settings_screens.dart:303-306`) |
| AnamnesisReviewScreen | `/gestao/anamnese` | Idem (clínico; inclui clinicAdmin, `management_modules.dart:95-99`) | Hub | Abrir anamnese da consulta | L: `myAgendaProvider`; `fn:getAnamnesisForVisit` | push `_VisitAnamnesis` (`anamnesis_screens.dart:371`) | Voltar / não | funcional |
| _VisitAnamnesis | sem rota (push) | Herda | Revisão | Registrar revisão | `fn:reviewAnamnesis` | — | Voltar / não | funcional — `amendAnamnesis` sem UI |
| CommunicationScreen | `/gestao/comunicacao` | clinicAdmin/receptionist | Hub, Home recepção "Mensagens" | Status WhatsApp, resolver item da caixa | `fn:getWhatsAppStatus`, `fn:updateInboxItem`; L: `whatsapp_inbox` | — | Voltar / não | parcial — não há envio/resposta de mensagens |
| AutomationsScreen | `/gestao/automacoes` | clinicAdmin | Hub | Pausar/retomar, processar fila, ligar regra | `fn:setClinicAutomationsPaused`, `fn:processMessageQueueNow`, `fn:saveAutomationRule`; L: `automations` | — | Voltar / não | parcial — sem edição de canal/horário, sem histórico; `cancelQueuedMessage` sem UI |
| MarketingScreen | `/gestao/marketing` | clinicAdmin | Hub | Salvar rascunho, pré-visualizar, aprovar, cancelar | `fn:saveCampaignDraft`, `fn:previewCampaign`, `fn:approveCampaign`, `fn:cancelCampaign`; L: `campaigns` | — | Voltar sem PopScope / não | parcial — sem validação cliente, sem edição de rascunho, cancelar sem confirmação |
| AiHubScreen | `/gestao/ia` | clinicAdmin/finance | Hub | Insights, perguntar ao assistente | `fn:getManagementInsights`, `fn:askManagementAssistant` | — | Voltar / não | parcial — histórico só em memória (`ai_hub_screen.dart:30`) |
| ManagementSettingsScreen | `/gestao/configuracoes` | clinicAdmin | Hub | Ver uso/limites/custos | `fn:getUsageDashboard` | `/clinica/equipe`, `/permissoes` (`marketing_crm_settings_screens.dart:380`) | Voltar / não | funcional — link `/permissoes` devolve clinicAdmin conta família |
| ClinicOrgHubScreen | `/clinica` | Profissional, admin ou clinicAdmin ativo (RA:95-122,175-201) | Perfil "Minha clínica", menu | Nova clínica, Equipe, Salas e bloqueios, selecionar clínica ativa | L: `memberships`, `clinics` | `/clinica/nova`, `/clinica/equipe`; push ClinicScheduleConfigScreen | Voltar / não | funcional |
| CreateClinicScreen | `/clinica/nova` | Idem | Hub | Criar | `fn:createClinic` | — | Voltar / não | funcional |
| ClinicTeamScreen | `/clinica/equipe` | Idem | Hub, configurações | Adicionar membro, ativar/desativar | `fn:addClinicMember`, `fn:setClinicMemberStatus` | — | Voltar / não | funcional |
| ClinicScheduleConfigScreen | sem rota (push) | Herda | Hub → Salas e bloqueios | Criar/editar salas e bloqueios | E: `rooms`, `schedule_blocks` | — | Voltar / não | funcional |

## 10. Conteúdo / Loja / Cursos

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| LibraryScreen | `/biblioteca` (Shell) | Todo autenticado | Menu "Conteúdos/Biblioteca" | Buscar, filtrar, abrir artigo | L: `articles` | `/biblioteca/artigo/:id` | Shell / sim | funcional |
| ContentDetailScreen | `/biblioteca/artigo/:articleId` | Todo autenticado | Biblioteca | Ler | L: `articles` | — | `popOrHome` / não | funcional |
| AiChatScreen | `/ia` (Shell) e `/ia/conversa/:id` | Todo autenticado | Menu, Home família | Conversar, excluir conversa | L/E: `ai_conversations`, `messages`, `ai_usage`; `fn:deleteConversation` | — | Shell / sim (no `/ia`) | funcional |
| ToolsScreen | `/ferramentas` (Shell) | Todo autenticado | Home família, menu | Calculadoras locais, seletor de data | Local | — | Shell / sim | funcional — subrotas `calculadoras/:id` e `primeiros-socorros` declaradas mas não registradas |
| CoursesScreen | `/cursos` | Sem guarda | Home/menu | Abrir curso | L: `courses` | `/cursos/:id` | Voltar / não | funcional |
| CourseDetailScreen | `/cursos/:courseId` | Sem guarda | Cursos | Abrir aula (respeita bloqueio) | L: `lessons`, `progress` | `/cursos/:id/aula/:lessonId` | Voltar / não | funcional |
| LessonScreen | `/cursos/:courseId/aula/:lessonId` | Sem guarda | Detalhe do curso | Assistir, concluir | E: `progress`; `fn:awardXp`; vídeo `fn:signBunnyPlayback` | — | Voltar / não | funcional |
| GamificationScreen | `/conquistas` | Sem guarda | Menu/perfil | Ver conquistas | L: `badges`, `earned_badges` | `/ranking` | Voltar / não | funcional |
| LeaderboardScreen | `/ranking` | Sem guarda | Conquistas | Ver ranking | L: `leaderboard` | — | Voltar / não | funcional |
| ShopScreen | `/loja` | Sem guarda | Menu | Ver produtos | L: `products` | `/loja/:productId`, `/carrinho` | Voltar / não | funcional |
| ProductDetailScreen | `/loja/:productId` | Sem guarda | Loja | Adicionar ao carrinho | L: `products` | `/carrinho` | Voltar / não | funcional |
| CartScreen | `/carrinho` | Sem guarda | Loja | Alterar quantidades, finalizar | `fn:quoteOrder` | `/checkout` | Voltar / não | funcional |
| CheckoutScreen | `/checkout` | Sem guarda | Carrinho | Endereço, pagamento, confirmar | `fn:createOrder` | `/pedidos` | Voltar / não | parcial — botão desativado com `paymentGatewayEnabled=false` (`shop_screens.dart:959-999`), aviso "Pagamento indisponível" (`:985`) |
| OrdersScreen | `/pedidos` | Sem guarda | Checkout, menu | Ver pedidos | L: `orders` | — | Voltar / não | funcional |

## 11. Admin

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| AdminScreen | `/admin` | `UserRole.admin` (RA: admin só `/admin`, `/permissoes`, `/auditoria`, `/bi`, `/clinica`) | Home admin, Perfil | Fila de verificação (aprovar/rejeitar), Conteúdo, Cursos, Produtos | `fn:adminDashboard`, `fn:verifyProfessional`; L: `users` | push AdminContentListScreen | Voltar / sim (menu) | parcial — "Cursos e aulas" e "Produtos e estoque" só exibem "Edite pelo console do Firebase" (`admin_screen.dart:222-234,505-512`) |
| AdminContentListScreen | sem rota (push) | Herda | Admin → Conteúdo | Novo/editar conteúdo | L: `articles` | push ContentEditorScreen, VersionHistoryScreen | Voltar / não | funcional — rota `/admin/conteudo` declarada e não registrada |
| ContentEditorScreen | sem rota (push) | Herda | Lista de conteúdo | Salvar, publicar | `fn:saveContent` | — | Voltar sem PopScope / não | funcional |
| VersionHistoryScreen | sem rota (push) | Herda | Lista de conteúdo | Restaurar versão | `fn:restoreContentVersion`; L: `versions` | — | Voltar / não | funcional |
| AuditLogsScreen | `/auditoria` | Profissional ou admin (RA:95-122) | Home admin, dashboard | Filtrar, exportar CSV | L: `security_audit_logs`; E: `logExport` | — | Voltar / não | funcional |
| PermissionMatrixScreen | `/permissoes` | Profissional ou admin (RA:95-122) | Home admin, configurações de gestão | Visualizar matriz | Matriz estática | — | Voltar / não | apenas visual — não permite alterar permissões |

## 12. Erro

| Tela (classe) | Rota | Perfil (regra) | Como chega | Ações | Dados L/E | Destinos dos botões | Voltar / Sair | Estado |
|---|---|---|---|---|---|---|---|---|
| NotFoundScreen | `errorBuilder` (qualquer rota não registrada; `/404` declarada mas não registrada) | Todos | URL/rota inválida, notificações com rota errada | Ir para início | — | `/inicio` | Botão início / não | funcional |
| FeatureUnavailableScreen | Retornada pelos builders de `/consultorio/ia/*` com flag desligada | Herda | Fluxo de voz | Voltar | — | — | Voltar / não | funcional |

---

## Achados prioritários

Caminhos relativos a `p360-demo/lib/` (exceto `functions/`).

### A. Brechas de autorização e redirect

1. **Qualquer `UserRole.professional` entra em todas as áreas de staff sem membership de clínica nem verificação** — `/financeiro`, `/faturamento`, `/estoque`, `/bi`, `/auditoria`, `/permissoes`, `/clinica`, `/suplementacao`, `/consultorio/*`: `core/router/route_authorization.dart:95-122`. O papel profissional é obtido no onboarding com CRM autodeclarado (`RoleSetupScreen`).
2. **Workspace recepção/financeiro (conta profissional) não bloqueia dados clínicos**: as regras do passo 9 não cobrem `/consultorio/paciente/:id/360`, `/consultorio/triagem/:id`, `/consultorio` e `/bi` — `core/router/route_authorization.dart:140-165`. Um recepcionista com conta profissional abre o Patient 360 e a triagem pelos botões da recepção (`features/clinic/presentation/.../clinic_reception_screen.dart:627,655`).
3. **Bloco `/gestao` duplicado** (o segundo é código morto): `core/router/route_authorization.dart:76-82` e `:84-92`.
4. **clinicAdmin recebe acesso clínico** contrariando o comentário de que gestão não concede clínica: `features/management/domain/management_modules.dart:95-99` (expõe `/gestao/anamnese` e o módulo Atendimento).
5. **Rotas de família sem guarda nenhuma**: `/criancas`, `/telemedicina`, `/pre-consulta/:id`, `/convite-clinica`, `/loja`, `/cursos` etc. não aparecem em `resolveRouteRedirect` (`core/router/route_authorization.dart`). Não existe gate de e-mail verificado em lugar algum.
6. **Navegação por `Navigator.push` contorna o guard**: pendências abrem EncounterEditor/PatientTimeline direto — `features/pending/.../pending_actions.dart:79-91,127-130`. O mesmo vale para PatientTimeline aberto a partir do Patient 360 (`patient_360_screen.dart:193-221`).

### B. Rotas não registradas / inalcançáveis / incorretas

7. **Rotas declaradas em `core/router/routes.dart` e ausentes no `app_router.dart`** (caem no NotFound): `protocolDetailPath` (`:72`), `calculatorsPath` (`:79`), `calculatorDetailPath` (`:81`), `firstAidPath` (`:87`), `appointmentDetailPath` (`:127`), `consultationRoomPath` (`:129`), `settingsPath /ajustes` (`:348`), `subscriptionPath /assinatura` (`:350`), `adminContentPath /admin/conteudo` (`:358`), `notFoundPath /404` (`:362`).
8. **Rotas de notificação geradas pelo backend inválidas** — `functions/src/automations.ts:56-66`: `preVisitForm → "/pre-consulta"` sem `appointmentId` (NotFound); `satisfactionSurvey` e `campaign → "/notificacoes"` (rota real é `/avisos`, NotFound); `paymentReminder → "/financeiro"` (família é redirecionada ao início). O tile do aviso faz `context.push(route)` sem validar (`features/notifications/presentation/notification_center_screen.dart:220-240`).
9. **Parâmetros de rota ignorados**: `FinanceDashboardScreen(initialTab)` nunca usado (`core/router/app_router.dart:608`); `/financeiro/receber` só lê `receivableId` (`app_router.dart:614-616`), então o `appointmentId` enviado por pendências se perde (`pending_actions.dart:104-106`).
10. **Tiles que levam a rotas bloqueadas (bounce silencioso para o início)**: Gestão sem `canOpenRoute` (`features/management/presentation/management_hub_screen.dart:74-75,95`); link `/permissoes` em configurações (`marketing_crm_settings_screens.dart:380`); dashboard da clínica sem filtro (`clinic_dashboard_screen.dart`); Triagem/360 na recepção para conta família (`clinic_reception_screen.dart:627,655`).

### C. Botões mortos ou enganosos

11. Admin "Cursos e aulas" e "Produtos e estoque" → snackbar "Edite pelo console do Firebase": `features/admin/presentation/admin_screen.dart:222-234,505-512`.
12. Orientação aos pais — PDF e Compartilhar "estrutura pronta": `features/supplementation/presentation/screens/supplement_more_screens.dart:250-268`.
13. Prescrição de suplementação — PDF e Compartilhar só exibem snackbar: `features/supplementation/presentation/screens/calculator_prescription_screens.dart:517-535`.
14. Telemedicina — "Agendar" só mostra "Abrindo agenda..." (`features/telemedicine/presentation/telemedicine_screen.dart:637-646`); controles de chamada "integração futura" (`:680-690`).
15. Agenda — "+ Novo atendimento" e a ação do estado vazio abrem a disponibilidade semanal, não criam atendimento: `features/telemedicine/presentation/professional_agenda_screen.dart:343,429-430`.
16. Home profissional — "Prescrições" leva para `/pacientes`: `features/shell/.../profile_homes.dart:405-411`.
17. CRM do consultório — catálogo de automações estático com ícones `link_off`: `features/pending/.../crm_screen.dart:133-148`.
18. CRM de gestão — texto menciona mesclar duplicados, mas não há botão: `features/management/presentation/marketing_crm_settings_screens.dart:303-306`.
19. Perfil — "Senha, biometria e privacidade" abre só a tela de privacidade/LGPD (sem senha nem biometria): `features/shell/presentation/screens/profile_tab.dart:281-284`.
20. Convite de clínica orienta "Perfil > Confirmar e-mail", opção inexistente (o repositório tem `sendEmailVerification`, sem UI): `features/clinic_intake/.../accept_invite_screen.dart:165`.

### D. Mensagens de sucesso sem operação confirmada / resultados ignorados

21. Triagem — resultado de `updateWorkflowStatus` ignorado antes do snackbar de sucesso: `features/clinic/.../clinic_triage_screen.dart:87-95`.
22. Recebíveis — pagamento com método fixo pix e `Result` ignorado, sem feedback: `features/finance/.../receivables_screen.dart:126-135`; "Editar valor" sem checagem de permissão e resultado ignorado (`:75-78,136-142`); cancelar sem confirmação nem motivo (`:143-148`).
23. Recibo "PDF" do recebível é PREVIEW não persistido, com clínica "Consultorio": `receivables_screen.dart:150-167`; "Recibo exemplo (PDF)" dos relatórios usa o primeiro recebível como amostra: `finance_reports_screen.dart:85-107`.
24. Contas a pagar — tocar na linha marca como paga sem confirmação: `features/finance/.../payables_screen.dart:48,123-135`; dropdown de categoria não reflete seleção (sem `StatefulBuilder`, `:77-90`); vencimento fixo +30 dias (`:111`).
25. Glosas — `updateAppeal` com resultado ignorado e sem snackbar: `features/billing/presentation/screens/billing_list_screens.dart:190-198`.
26. Nova solicitação — convite por WhatsApp declarado "simulado": `features/clinic_intake/.../clinic_intakes_screen.dart:56`.
27. Documento clínico — emitido imediatamente sem rascunho/prévia, nome da clínica fixo "Pediatria 360": `features/emr/.../document_editor_screen.dart:179`.
28. Agenda — confirmar consulta sem feedback de sucesso/erro: `professional_agenda_screen.dart:93-97`.

### E. Dados lidos do escopo errado (erro funcional grave)

29. `watchChild`/`watchGrowth` usam o uid do usuário atual: `features/children/data/.../children_repository_impl.dart:116-122,219-220`. Consequência: crescimento, vacinas e edição de paciente abertos pelo profissional mostram vazio/"não encontrado" — links em `patient_360_screen.dart:752,762` e `patient_timeline_screen.dart:169-172,346,357,938,1580,1598`; tiles "Crescimento"/"Vacinas" do dashboard levam ao `/criancas` do próprio profissional (`clinic_dashboard_screen.dart:177,187`); edição via timeline grava com `ownerId ''` (`child_form_screen.dart:123-130,173-175`).
30. Agenda usa `myAgendaProvider` (agenda própria) — recepção e clinicAdmin não veem a agenda da clínica: `professional_agenda_screen.dart:185,298`.
31. Triagem e cadastro de exame exigem digitar o ID da criança: `clinic_triage_screen.dart:55,134`; `supplementation/presentation/screens/lab_screens.dart:270-275`.
32. Perfil exibe dados falsos: "Clínica" mostra `user.specialty` (`profile_tab.dart:202-205`); prefixo "Dra." forçado (`:140`); "Último acesso hoje às" usa `DateTime.now()` (`:73-74`).

### F. Formulários sem PopScope / telas sem saída

33. **Zero ocorrências de `PopScope`/`WillPopScope` em `lib/features`** (só existem em `lib/demo/**`). Nenhum formulário confirma descarte: ChildFormScreen, FamilyAnamnesisScreen, PreVisitQuestionnaireFormScreen, NewIntakeScreen, EncounterEditorScreen (mitigado por autosave), DocumentEditorScreen (X descarta direto), VisitSummaryEditorScreen, LabResultFormScreen, SupplementPrescriptionScreen, MarketingScreen, ContentEditorScreen, ProfileEditScreen, NotificationSettingsScreen.
34. **Logout indisponível fora do Shell**: todas as rotas top-level (financeiro, faturamento, estoque, BI, gestão, clínica, suplementação, família) só oferecem "voltar"; logout apenas em `/perfil` e no menu lateral (`features/shell/presentation/app_shell.dart:825-830`). MaintenanceScreen não tem voltar nem sair (intencional). Não foi confirmada nenhuma outra tela totalmente sem saída.

### G. Funcionalidade de backend sem UI

35. Callables/métodos sem tela: `amendEncounter` (`features/emr/data/encounter_repository.dart:254`), `amendVisitSummary`, `amendAnamnesis`, `cancelQueuedMessage`, `refundReceivable`, `markNegotiation`, `sendEmailVerification`.
36. Mojibake ("뿯½") em textos visíveis: `receivables_screen.dart:60`, `payables_screen.dart:46`, `cash_flow_screen.dart:53`.

---

## Telas ausentes (comparação com as jornadas)

Legenda: **existe** = tela e operação presentes; **parcial** = tela existe com lacunas; **ausente** = não encontrada no código do app principal.

### Família

| Jornada | Situação | Evidência |
|---|---|---|
| Cadastro, login, recuperação de senha | existe | Register/Login/ForgotPassword |
| Confirmação de e-mail | ausente | `sendEmailVerification` sem UI; referência inexistente em `accept_invite_screen.dart:165` |
| Cadastro e edição de criança | existe | ChildForm/ChildDetail |
| Crescimento e vacinas | existe | Growth/Vaccines |
| Responsáveis e compartilhamento com profissional | existe | ChildGuardians/ChildAccess |
| Aceitar convite da clínica | existe | AcceptInviteScreen |
| Agendar consulta pelo app | ausente | botão "Agendar" sem ação (`telemedicine_screen.dart:637-646`) |
| Pré-consulta / anamnese | parcial | FamilyAnamnesis sem anexos; questionário não-clínico existe |
| Teleconsulta por vídeo | ausente (apenas placeholder) | flag `videoConsultationEnabled=false`; controles "integração futura" |
| Resumo pós-consulta | existe | VisitSummariesScreen |
| Receitas/documentos clínicos recebidos | ausente | nenhuma tela de documentos para família encontrada |
| Conversa com a clínica (mensagens bidirecionais) | ausente | "Mensagens" leva a `/avisos` (somente avisos) |
| Pagamento de consulta/loja | ausente | `paymentGatewayEnabled=false` |
| LGPD (exportar, excluir, consentimentos) | existe | PrivacyScreen |
| Troca de senha / biometria | ausente | rótulo em `profile_tab.dart:281` sem implementação |

### Recepção

| Jornada | Situação | Evidência |
|---|---|---|
| Agenda da clínica (todos os profissionais) | parcial | recepção usa `ClinicReceptionScreen` (clínica toda); `/agenda` usa `myAgendaProvider` |
| Criar agendamento manual | parcial | só via NewIntakeScreen (data/hora livre, sem slots) |
| Check-in e fila | existe | ClinicReceptionScreen |
| Cadastro de paciente novo / convite | parcial | NewIntake/ClinicIntakes; WhatsApp simulado |
| Pendências | parcial | PendingCenter (contorna guard, perde query) |
| Confirmação/lembretes por WhatsApp | parcial | Communication/Automations sem envio direto |
| Cobrança no balcão | ausente para workspace recepção | `/financeiro` bloqueado para recepção (RA:140-165, 175-201) |
| Triagem | parcial / com erro | ID manual, resultado ignorado |

### Profissional

| Jornada | Situação | Evidência |
|---|---|---|
| Agenda própria, confirmar/remarcar/cancelar | existe | ProfessionalAgendaScreen |
| Disponibilidade semanal | existe | sheet na agenda |
| Lista de pacientes e timeline | existe (timeline com erro de escopo) | ProfessionalPatients/PatientTimeline |
| Atendimento (prontuário), autosave, assinatura | existe | EncounterEditorScreen |
| Retificação de prontuário assinado | ausente | `amendEncounter` sem UI |
| Documentos clínicos (receita/atestado) | parcial | emissão direta, sem rascunho; ICP desligada |
| Curvas de crescimento/vacinas do paciente | com erro | escopo do usuário atual (achado 29) |
| Suplementação (cálculo, prescrição, exames) | existe / parcial | PDF/compartilhar não implementados |
| Teleconsulta | ausente (placeholder) | flag de vídeo |
| Transcrição por voz | parcial (desativada) | flag de voz → FeatureUnavailable |
| Desenvolvimento neuropsicomotor | ausente | card "próxima etapa" (`patient_timeline_screen.dart:359-367`) |

### Financeiro

| Jornada | Situação | Evidência |
|---|---|---|
| Contas a receber / registrar pagamento | parcial / com erro | método fixo, resultado ignorado |
| Contas a pagar | parcial / com erro | categoria, vencimento fixo, baixa por toque |
| Fluxo de caixa previsto x realizado | parcial | só realizado |
| DRE, inadimplência, produção | existe | telas de leitura |
| Recibo oficial persistido | ausente | apenas PREVIEW/amostra |
| Estorno, negociação, desconto | ausente | `refundReceivable`/`markNegotiation` sem UI; desconto não encontrado |
| Conciliação bancária | ausente | não encontrada |
| Emissão de NFS-e | ausente | não encontrada |
| Exportação de relatórios | parcial | CSV só para área de transferência |

### Faturamento (convênios)

| Jornada | Situação | Evidência |
|---|---|---|
| Cadastro de planos e carteirinhas | ausente | listas somente leitura |
| Autorizações e guias (criação) | ausente | listas somente leitura |
| Lotes e envio TISS | ausente | `tissOperatorEnabled=false`, sem criação |
| Recurso de glosa | parcial | registro interno, resultado ignorado |
| Relatórios | existe | CSV |

### Estoque

| Jornada | Situação | Evidência |
|---|---|---|
| Cadastro de itens e fornecedores | ausente | listas somente leitura |
| Movimentações e transferências | existe | Movimentos/Lotes |
| Pedidos de compra (criação) | ausente | lista somente leitura |
| Inventário (contagem completa) | parcial | apenas iniciar |
| Relatórios | existe | CSV |

### Gestão / Admin

| Jornada | Situação | Evidência |
|---|---|---|
| Criar clínica, equipe, salas e bloqueios | existe | ClinicOrg* |
| Editar permissões | ausente | PermissionMatrix é somente visual |
| Auditoria | existe | AuditLogsScreen |
| BI (admin, clínico, recepção, operacional) | existe | BiHub + 4 |
| BI neuropediátrico | ausente | `features/bi/domain/bi_models.dart:63-68` |
| Campanhas de marketing | parcial | sem edição de rascunho/validação |
| Automações | parcial | sem edição de canais/horários e histórico |
| Assistente de IA de gestão | parcial | histórico não persistido |
| Verificação de profissionais | existe | AdminScreen |
| Gestão de conteúdo (artigos) | existe | AdminContentList/ContentEditor/VersionHistory |
| Gestão de cursos e produtos | ausente | tiles mortos (`admin_screen.dart:222-234,505-512`) |
| Configurações gerais / assinatura do app | ausente | `/ajustes` e `/assinatura` não registradas |
