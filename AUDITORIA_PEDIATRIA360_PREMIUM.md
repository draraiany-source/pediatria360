# AUDITORIA_PEDIATRIA360_PREMIUM.md

> **FASE 1 — Auditoria completa (sem implementação).**  
> Data: 2026-09-18  
> Escopo verificado: `lib/`, `functions/`, `firestore.rules`, `storage.rules`, `test/`, docs de produção.  
> Repositório GitHub: https://github.com/draraiany-source/pediatria360  
> Commit base auditado: `cbb0673` (main)

## Legenda

| Simbolo | Significado |
|---|---|
| JA EXISTE E FUNCIONA | Codigo + fluxo + backend/rules alinhados |
| EXISTE PARCIALMENTE | Ha base util, mas falta peca critica do escopo premium |
| NAO EXISTE | Sem feature/rota/function dedicada |
| EXISTE MAS PRECISA CORRIGIR | Existe, porem bloqueia uso clinico/producao |
| RISCO DE SEGURANCA | Exploravel ou frouxo demais para dado de saude |
| CODIGO DUPLICADO OU DESNECESSARIO | Morto, residual ou inconsistente |

---

## 0. Veredito executivo

O Pediatria360 **ja e um produto funcional** com arquitetura Clean (features), Firebase real, regras de Firestore cuidadas, EMR com assinatura por hash, IA no servidor, offline-first (outbox), LGPD (consent/export/delete) e home distinta para profissional vs familia.

**Nao e** ainda o ecossistema premium pedido: faltam Prontuario IA por voz, RBAC fino (clinica / especialidade / paciente), caderneta digital completa (diario, sono, alimentacao, marcos), modulos clinicos dedicados (puericultura, neuropediatria, emergencia), catalogo de medicamentos, chat clinico e fechamento de video/pagamento/OMS oficial.

**Regra desta auditoria:** nao duplicar o que ja funciona. Expandir sobre EMR, `clinicalAssist`, `DoseCalculator`, telemedicina/agenda e homes existentes.

---

## 1. Inventario tecnico

### 1.1 Frontend — features (`lib/features/`)

| Feature | Situacao |
|---|---|
| `auth` | JA EXISTE E FUNCIONA — login e-mail/Google, reset, onboarding, role setup, consentimento |
| `shell` | JA EXISTE E FUNCIONA — home pro/familia, app shell responsivo, perfil |
| `children` | JA EXISTE E FUNCIONA — cadastro, detalhe, offline |
| `growth` | EXISTE MAS PRECISA CORRIGIR — curvas + math OK; dados OMS aproximados |
| `vaccines` | EXISTE MAS PRECISA CORRIGIR — PNI estruturado; conteudo a conferir com gov.br |
| `emr` | JA EXISTE E FUNCIONA — encounters, timeline, documentos PDF, clinical assist |
| `ai` | JA EXISTE E FUNCIONA — chat pediatrico via Cloud Function |
| `tools` | JA EXISTE E FUNCIONA — calculadoras (Holliday-Segar, Mosteller, Apgar, dose generica) |
| `library` | JA EXISTE E FUNCIONA — artigos/protocolos |
| `courses` | JA EXISTE E FUNCIONA — cursos + Bunny |
| `shop` | EXISTE PARCIALMENTE — pedido/estoque; gateway off |
| `telemedicine` | EXISTE PARCIALMENTE — agenda/booking; video off |
| `admin` | JA EXISTE E FUNCIONA — painel + editor de conteudo |
| `gamification` | EXISTE PARCIALMENTE — XP diario/aulas; cobertura parcial |
| `notifications` | JA EXISTE E FUNCIONA — central + FCM |
| `privacy` | JA EXISTE E FUNCIONA — export/delete/consent UI |

**Ausentes como feature:** `voice_emr` / prontuario IA, `development` (marcos), `diary`, `feeding`, `sleep`, `puericulture`, `neuropediatrics`, `neonatology` (alem de calc), `emergency`, `medications` (catalogo), `first_aid`, `chat`, `reports` (gestao), `clinic` (multi-unidade).

### 1.2 Backend — Cloud Functions (`functions/src/`)

| Grupo | Functions | Status |
|---|---|---|
| IA | `aiChat`, `deleteConversation`, `clinicalAssist`, `parseLabText` | JA EXISTE (parseLabText sem UI) |
| EMR | `signEncounter`, `amendEncounter`, `issueClinicalDocument`, `cancelClinicalDocument`, `verifyDocument`, `grantChildSummaryAccess` | JA EXISTE / RISCO no grant |
| Privacy | `recordConsent`, `revokeConsent`, `exportUserData`, `requestDataDeletion`, `cancelDataDeletion`, `processScheduledDeletions`, `dataProcessingManifest` | JA EXISTE |
| Commerce | `quoteOrder`, `createOrder`, `getAvailability`, `bookAppointment`, `joinConsultation` | PARCIAL — video unimplemented |
| Bunny | create/get/sign/delete + webhook | JA EXISTE (config externa) |
| Content | `saveContent`, `restoreContentVersion` | JA EXISTE |
| Gamification | `awardXp`, `registerDailyActivity`, `rebuildLeaderboard`, `verifyProfessional`, `adminDashboard`, `onUserDeleted` | JA EXISTE |
| Notifications | reminders, settings, registerDevice | JA EXISTE |

**Ausentes:** SpeechToText / estruturacao de voz, retencao de audio, revisao inteligente dedicada, catalogo de medicamentos, chat seguro, relatorios de gestao, App Check.

### 1.3 Firebase / banco

| Item | Status | Evidencia |
|---|---|---|
| Projeto `pediatria360-app` | JA EXISTE | `.firebaserc`, `firebase_options.dart` |
| Firestore rules (deny-by-default) | JA EXISTE | `firestore.rules` |
| Storage rules (dono + public read-only) | JA EXISTE | `storage.rules` |
| Indices | JA EXISTE | `firestore.indexes.json` |
| `google-services.json` versionado | Protegido | `.gitignore` |
| Collections clinicas | JA EXISTE | users/children, encounters, clinical_documents, appointments |
| Collections voz/diario/marcos/meds | NAO EXISTE | — |

### 1.4 Autenticacao e navegacao

| Item | Status | Arquivos |
|---|---|---|
| E-mail/senha + Google | JA EXISTE | `auth_remote_data_source.dart` |
| Reset senha | JA EXISTE | `forgot_password_screen.dart` |
| Onboarding + role | JA EXISTE | `onboarding_screen.dart`, `role_setup_screen.dart` |
| Consentimento LGPD | JA EXISTE | `consent_sheet.dart` -> `recordConsent` |
| Guardas de rota | JA EXISTE | `route_authorization.dart` (+ testes) |
| DevMode (so debug) | PARCIAL | `dev_mode.dart` — `_flag = true` em debug |
| Biometria / 2FA | NAO EXISTE | removido de proposito |

### 1.5 Testes

| Camada | Status |
|---|---|
| ~286 testes Dart (23 arquivos) | JA EXISTE — logica clinica/sync/rotas |
| `test/rules/rules.test.js` (~105 casos) | JA EXISTE — isolamento de prontuario |
| Functions Jest (`booking.test.ts`) | PARCIAL — cobertura estreita |
| CI (analyze/test/rules/functions/build) | JA EXISTE — `.github/workflows/ci.yml` |
| Testes de voz / RBAC fino / meds | NAO EXISTE |

---

## 2. Matriz do ecossistema pedido (20 areas)

| # | Area | Status | O que ja ha | Lacuna principal |
|---|---|---|---|---|
| 1 | Pediatria360 Profissional | PARCIAL | Home pro, pacientes, EMR, agenda, tools | Hub premium + modulos clinicos |
| 2 | Pediatria360 Familia | PARCIAL | Home familia, criancas, crescimento, vacinas | Caderneta digital / diario / marcos |
| 3 | Prontuario IA | NAO EXISTE | `clinicalAssist` texto no EMR | Voz, STT, fluxo completo revisao |
| 4 | Puericultura | NAO EXISTE | Campos anamnese gerais | Consulta guiada por idade |
| 5 | Neuropediatria | NAO EXISTE | Label de especialidade | Modulo + escalas licenciadas |
| 6 | Neonatologia | PARCIAL | Apgar, idade corrigida, TIG | Fluxo clinico neonatal |
| 7 | Emergencia pediatrica | PARCIAL | APLS peso; red flags IA | Cartao emergencia por peso |
| 8 | Calculadoras | JA EXISTE | `tools/` + testes | Expandir (Glasgow, diluicao) |
| 9 | Medicamentos | PARCIAL | `DoseCalculator` generico | Catalogo + diluicao + amamentacao |
| 10 | Desenvolvimento | NAO EXISTE | Campo texto anamnese; icone orfao | Marcos + timeline |
| 11 | Vacinas | PRECISA CORRIGIR | PNI + doses + reminders | Conferir calendario oficial |
| 12 | Alimentacao | PARCIAL | Campos livres (EMR/pre-consulta) | Modulo estruturado |
| 13 | Sono | PARCIAL | Campos livres | Modulo + graficos |
| 14 | Telemedicina | PARCIAL | Agenda/booking/pre-visita | Video + integracao sala |
| 15 | Agenda | JA EXISTE | Profissional + paciente | Encaixe/bloqueio avancados |
| 16 | Relatorios | PARCIAL | Doc tipo `report` | Dashboards export CSV/PDF |
| 17 | Documentos | JA EXISTE | Receita, atestado, PDF, hash | ICP-Brasil (fora do codigo) |
| 18 | Conteudos | JA EXISTE | Biblioteca + cursos + admin editor | Primeiros socorros dedicado |
| 19 | Comunicacao | NAO EXISTE | So chat com IA | Chat clinico autorizado |
| 20 | Administracao | JA EXISTE | Admin, verify CRM, conteudo | Editor cursos/produtos; clinica |

---

## 3. Perfis e RBAC

| Perfil pedido | Status | Notas |
|---|---|---|
| Administrador | JA EXISTE | `UserRole.admin`; nao le encounters (rules) |
| Medico / Pediatra | PARCIAL | Colapsado em `professional` + specialty string |
| Neuropediatra | PARCIAL | So string em `professionalSpecialties` |
| Outros profissionais | PARCIAL | Specialty list; mesmo papel |
| Paciente | NAO EXISTE | Nao ha role paciente (so responsavel/`parent`) |
| Responsavel / Pai/Mae | JA EXISTE | `UserRole.parent` |
| Clinica | NAO EXISTE | Sem multi-tenant / equipe / unidade |

| Controle | Status |
|---|---|
| Admin != acesso clinico automatico (router) | JA EXISTE — `route_authorization.dart` |
| Campos server-only (plan, xp, role, verified) | JA EXISTE — rules |
| Verificacao CRM manual | JA EXISTE — `verifyProfessional` |
| RBAC por especialidade / clinica / vinculo | NAO EXISTE |
| Consentimento de acesso do profissional a crianca | RISCO — profissional pode auto-conceder resumo |

Evidencias do risco:
- `functions/src/emr.ts` — `grantChildSummaryAccess`
- `firestore.rules` — `authorized_professionals/{profId}` allow write se uid == profId
- `test/rules/rules.test.js` — teste confirma self-write com sucesso

---

## 4. Prontuario IA por voz (requisito central)

| Capacidade | Status | Evidencia |
|---|---|---|
| EMR estruturado (anamnese, exame, vitais) | JA EXISTE | `encounter_editor_screen.dart`, entities |
| Assistente clinico por texto | JA EXISTE | `clinical_assist_sheet.dart` + `clinicalAssist` |
| "Iniciar consulta com IA" (gravacao) | NAO EXISTE | — |
| Consentimento de gravacao | NAO EXISTE | LGPD geral existe; nao de audio |
| Speech-to-text tempo real | NAO EXISTE | sem pacote STT |
| Transcricao ao vivo / diarizacao | NAO EXISTE | — |
| Extracao automatica -> campos | NAO EXISTE | — |
| Gaps / "NAO INFORMADO" | NAO EXISTE | — |
| Evolucao por modelo (SOAP, PA...) | NAO EXISTE | — |
| Revisao inteligente Aceitar/Editar/Ignorar | NAO EXISTE | — |
| Suporte decisao (sugestao, nunca auto-salvar) | PARCIAL | clinicalAssist; falta UI formal |
| Assinatura apos revisao humana | JA EXISTE | `signEncounter` (hash; != ICP) |
| Retencao/exclusao de audio | NAO EXISTE | — |
| Camada AIService / providers abstratos | NAO EXISTE | chamadas diretas CF |

**Conclusao:** implementar **sobre** o EMR existente — nao criar segundo prontuario paralelo.

---

## 5. Telas Prontuario IA (pedido 1-15)

| Tela | Status |
|---|---|
| 1 Home Prontuario IA | NAO EXISTE |
| 2 Selecionar paciente | JA EXISTE (reusar pacientes/EMR) |
| 3 Consentimento (audio) | NAO EXISTE |
| 4 Consulta em andamento | NAO EXISTE |
| 5 Transcricao ao vivo | NAO EXISTE |
| 6 Prontuario preenchendo | PARCIAL (editor manual) |
| 7 Informacoes faltantes | NAO EXISTE |
| 8 Revisao da IA | NAO EXISTE |
| 9 Evolucao gerada | NAO EXISTE |
| 10 Conduta | PARCIAL (campo conduta no EMR) |
| 11 Sugestoes para revisao | PARCIAL (clinical assist) |
| 12 Revisao final | PARCIAL (antes de assinar) |
| 13 Assinatura | JA EXISTE |
| 14 Historico | JA EXISTE (timeline) |
| 15 Auditoria e versoes | PARCIAL (amend/sign; falta trilha de voz) |

---

## 6. Seguranca (detalhe)

| Achado | Status | Acao na FASE 2-3 |
|---|---|---|
| `grantChildSummaryAccess` + write client em `authorized_professionals` | RISCO | Exigir consentimento do responsavel; remover self-write client |
| Chaves Anthropic/Bunny no servidor | OK | Manter |
| Firebase client keys no app | Esperado | Restringir API key no console + App Check |
| DevMode so `kDebugMode` | OK | Confirmar `_flag` antes de release |
| Pagamento/video desligados | Deliberado | Nao reativar sem provedor |
| OMS aproximada | PRECISA CORRIGIR | Substituir LMS oficial |
| URLs legais / e-mail suporte placeholder | PRECISA CORRIGIR | Dado do proprietario |
| Assinatura != ICP-Brasil | Documentado | Nao apresentar como juridica |
| Storage publico so `/public` | OK | Manter |
| Catch-all Firestore deny | OK | Manter |
| Colecao `prescriptions` residual | DESNECESSARIO | Remover ou documentar morta |

---

## 7. Codigo morto / inconsistencias / duplicacao

| Item | Status | Arquivo |
|---|---|---|
| Rota `primeiros-socorros` sem screen | DUPLICADO/QUEBRADO | `routes.dart` vs `app_router.dart` |
| Atalho "Cuidados" -> Ferramentas | PRECISA CORRIGIR | `home_screen.dart` |
| Copy "marcos do desenvolvimento" sem modulo | PRECISA CORRIGIR | `children_list_screen.dart` |
| "Central de ajuda em breve" | PARCIAL | `profile_tab.dart` |
| `joinConsultation` -> unimplemented | PARCIAL | `commerce.ts` |
| `parseLabText` sem tela | PARCIAL | `clinical.ts` |
| Icone `development` sem feature | DESNECESSARIO | assets |
| Docs historicos desatualizados | DESNECESSARIO | ja marcados historico no topo |

---

## 8. Dependencias e qualidade arquitetural

| Aspecto | Avaliacao |
|---|---|
| Clean Architecture por feature | Solida |
| Riverpod + GoRouter | OK |
| Offline SQLite outbox + Hive cache | OK |
| Erros -> Failure pt-BR | OK |
| Secrets via Secret Manager / dart-define | OK |
| Sem `build_runner` (mapas manuais) | Consciente |
| Design system (cores/tokens/widgets) | Base premium presente |
| Multiplataforma | Android/Web/Windows presentes; iOS precisa generate+signing |

---

## 9. Prioridades pos-auditoria (nao implementar nesta fase)

### FASE 2 — Erros criticos de produto
1. Fechar rota orfa primeiros-socorros **ou** criar tela minima honesta.
2. Remover copy enganosa de marcos / ajuda.
3. Documentar `parseLabText` como desativado na UI.

### FASE 3 — Seguranca
1. Consentimento do responsavel para acesso profissional ao resumo da crianca.
2. Remover write direto do cliente em `authorized_professionals`.
3. Planejar App Check + restricao de API keys.

### FASE 4 — Arquitetura para premium
1. Estender RBAC (`specialty`-aware + futura `clinicId`) sem quebrar `parent/professional/admin`.
2. Abstracao `AIService` / `SpeechToTextProvider` / `ClinicalStructuringService`.
3. Colecoes Firestore novas so com rules + testes.

### FASE 5 — Prontuario IA (maior entrega)
Sobre EMR existente: consentimento audio -> gravacao -> STT -> estruturacao -> gaps -> revisao humana -> `signEncounter`.

### FASES 6-15
Profissional hub -> Familia/caderneta -> Puericultura -> Meds/calculadoras -> Neuro -> Neo -> Emergencia -> Telemedicina video -> Conteudo/primeiros socorros -> Relatorios -> Polimento -> Testes -> Docs finais.

---

## 10. O que NAO fazer (confirmado pela auditoria)

- Nao criar segundo EMR paralelo ao de `lib/features/emr/`.
- Nao inventar banco de mg/kg sem fonte licenciada.
- Nao ligar video/pagamento com UI falsa.
- Nao versionar audio clinico sem retencao e rules.
- Nao colocar API key de LLM no Flutter.
- Nao usar escalas protegidas (M-CHAT, Vanderbilt...) sem licenca.
- Nao tratar hash de assinatura como ICP-Brasil.

---

## 11. Mapa rapido: pedido vs codigo existente (reuso)

| Pedido premium | Reusar |
|---|---|
| Consulta com IA | `Encounter` + `clinicalAssist` + novo pipeline voz |
| Home profissional | `_ProfessionalHome` em `home_screen.dart` |
| Home familia | `_FamilyHome` |
| Calculadoras / dose | `PediatricCalculators`, `DoseCalculator` |
| Documentos / assinatura | `clinical_pdf_service`, `signEncounter` |
| Agenda | `professional_agenda_screen`, `bookAppointment` |
| Vacinas / crescimento | `vaccines/`, `growth/` (trocar dados oficiais) |
| LGPD | `privacy/` + functions privacy |
| Conteudo | `library/`, `courses/`, admin editor |

---

## 12. Criterios de saida da FASE 1

- [x] Inventario de features, functions, rules, testes
- [x] Classificacao em todos os eixos pedidos
- [x] Riscos de seguranca nomeados com evidencia
- [x] Lacunas vs escopo premium
- [x] Ordem de fases preservada (sem implementacao nesta entrega)
- [x] Arquivo `AUDITORIA_PEDIATRIA360_PREMIUM.md` criado na raiz do app

---

## 13. Proximo passo recomendado

**FASE 2 + 3** (correcoes criticas + seguranca do grant de acesso) **antes** de abrir o epico de Prontuario IA (FASE 5).

Aguardando confirmacao para iniciar FASE 2.
