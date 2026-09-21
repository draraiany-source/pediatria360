# AUDITORIA FINAL — Pediatria360

| Campo | Valor |
|-------|-------|
| **Data** | 2026-09-21 |
| **Commit analisado** | `abbf607` |
| **Versão** | `1.0.0+1` (`pubspec.yaml`) |
| **Escopo** | Código, rotas, Firebase/Functions/rules, módulos clínicos, LGPD, UI/ícones, testes (inventário), build/publicação |
| **Método** | Somente evidência de código — **sem correções** nesta fase |
| **Classificação final** | **NÃO PRONTO PARA PUBLICAÇÃO** |

---

## 1. Resumo executivo

O Pediatria360 é um produto **funcional em núcleo clínico familiar + profissional** (Auth Firebase, crianças, vacinas, crescimento com matemática OMS, EMR com rascunho/assinatura por hash, agenda/telefluxo parcial, biblioteca/cursos, IA chat + voz draft, LGPD técnica export/delete, shell premium e ícones PNG).

**Não está pronto para loja/homologação clínica plena** porque:

1. Termos/Privacidade são **URLs placeholder** (`AppConfig`).
2. OMS LMS e PNI no repo são **aproximações** (avisos no código).
3. Vídeo e pagamento **desligados** (`videoConsultationEnabled` / `paymentGatewayEnabled` = false); `joinConsultation` retorna `unimplemented`.
4. Assinatura de encounter **não é ICP-Brasil**.
5. Multitenant (clínica) existe em modelo/UI, mas **dados clínicos ainda não isolam por `clinicId`**.
6. **Financeiro** e **Relatórios/BI** como produto SaaS **não existem** (só papéis/ícones/TODOs de faturamento zerados).
7. Neuropediatria/escalas (M-CHAT, SNAP-IV etc.) **não implementadas** como módulo.
8. Plataforma nativa incompleta neste checkout (`platform/android` parcial; sem `android/` Flutter padrão completo); release ainda **debug signing**.
9. Mensagens = **centro de notificações**, não chat clínico bilaterial completo.

### Contagens de severidade (itens distintos no inventário desta auditoria)

| Severidade | Qtd |
|------------|-----|
| **P0** | **8** |
| **P1** | **14** |
| **P2** | **18** |
| **P3** | **12** |
| **Estimativa de correções** | ~52 itens acionáveis (agrupáveis em ~12 épicos) |

---

## 2. Status geral do projeto

| Dimensão | Status |
|----------|--------|
| App abre / auth | FUNCIONANDO (Firebase real se options configurados) |
| Área família (crianças/vacinas/crescimento/biblioteca/IA) | PARCIAL → FUNCIONANDO com ressalvas clínicas |
| Área profissional (pacientes/EMR/agenda) | PARCIAL |
| Consultório 360 KPIs | PARCIAL / MOCK parcial (vários campos = 0 hardcoded) |
| Telemedicina vídeo | BLOQUEADO |
| Financeiro SaaS | NÃO IMPLEMENTADO |
| Relatórios BI | NÃO IMPLEMENTADO |
| Multitenant clínico | PARCIAL (UI + models; sem isolamento clínico) |
| Homologação / Store | BLOQUEADO |

---

## 3. Inventário de módulos (`lib/features/`)

| Módulo | Status | Evidência |
|--------|--------|-----------|
| auth | FUNCIONANDO | Login/registro/forgot/role setup Firebase |
| shell | FUNCIONANDO | Home, perfil, navegação premium |
| children | FUNCIONANDO | CRUD + subcoleções Firestore |
| vaccines | PARCIAL | PNI local + sync; validação gov.br pendente |
| growth | PARCIAL | LMS math OK; dados aproximados |
| emr | PARCIAL | Encounter completo + sign hash; CID só código manual |
| telemedicine | PARCIAL | Agenda real; vídeo OFF |
| clinic | PARCIAL | Dashboard/recepção/voz; KPIs stub |
| clinic_org | PARCIAL | Hub criar/selecionar clínica; sem migrate clinicId |
| supplementation | PARCIAL | Catálogo CMS-ready; conteúdo clínico pendente validação |
| library / courses | PARCIAL | Firestore + Bunny flags |
| shop | PARCIAL | Pedido/estoque; gateway OFF |
| ai | PARCIAL | `aiChat` CF; cotas |
| notifications | PARCIAL | Centro de avisos FCM-related |
| privacy | FUNCIONANDO (técnico) | Export/delete/consent CF |
| admin | PARCIAL | CMS conteúdo |
| tools / gamification | PARCIAL | Calculadoras / XP |
| financeiro feature | NÃO IMPLEMENTADO | Sem rotas/feature dedicada |
| neuropediatria escalas | NÃO IMPLEMENTADO | Só tags conteúdo/suplementação |

---

## 4. Arquitetura

- **Flutter** + **Riverpod** + **GoRouter** + Clean parcial por feature.
- Firebase: Auth, Firestore, Functions (`southamerica-east1` nas exports), Storage, Messaging, Remote Config, Crashlytics, Analytics.
- Offline: Hive/sqflite sync presente.
- Telas gigantes: `patient_timeline_screen` ~1675, `encounter_editor` ~1320, `home_screen` ~986.

---

## 5. Rotas (inventário resumido)

**Públicas:** `/`, `/login`, `/registro`, `/recuperar-senha`, `/onboarding`, `/404`, `/manutencao`.

**Autenticadas (família):** `/inicio`, `/biblioteca`, `/ia`, `/ferramentas`, `/perfil`, `/criancas...`, `/cursos`, `/loja`, `/avisos`, `/conquistas`, `/telemedicina` (parcial).

**Profissional (gate `UserRole.professional` em `route_authorization.dart`):** `/pacientes`, `/agenda`, `/consultorio...`, `/suplementacao...`, `/clinica...`.

**Admin:** `/admin...`.

**Não existem rotas:** `/financeiro`, `/relatorios` (produto).

Gate: profissional clínico **não** libera admin automaticamente (`role != professional` bloqueia admin em área clínica — evidência em `route_authorization.dart`).

Deep link / 404: `notFoundPath` / `maintenancePath` definidos.

---

## 6. Autenticação e RBAC

| Item | Status | Evidência |
|------|--------|-----------|
| Login / logout / forgot | FUNCIONANDO | Firebase Auth |
| Sessão | FUNCIONANDO | Firebase Auth persistence |
| UserRole parent/professional/admin | FUNCIONANDO | `app_user.dart` |
| ClinicRole (recepção/enfermagem/financeiro…) | PARCIAL | Modelo + membership; **não** governa rotas do app ainda |
| Isolamento tenant clínico | PARCIAL | Preferência `activeClinicId`; docs clínicos sem `clinicId` obrigatório |
| Bloqueio cross-user | FUNCIONANDO (owner) | `firestore.rules` `ownsChild` / signedIn |

---

## 7. Firebase / backend

**Functions (`functions/src`):** booking, commerce (`joinConsultation` unimplemented), clinical/AI, content, bunny, emr (`signEncounter`), privacy, notifications, gamification, voice.

**Rules:** deny-by-default posture; testes emulator em `test/rules/`.

**Índices:** `firestore.indexes.json` presente.

**Ambientes:** `AppConfig.environment` via `--dart-define ENV` (default `dev`); emulador opcional.

**Riscos custo:** vários `StreamProvider` sem autoDispose; snapshots sem `.limit()` em children/growth/vaccines/supplements.

---

## 8. Segurança

| Item | Status |
|------|--------|
| API keys de IA no client | OK — só CF |
| Bunny via dart-define | OK |
| firebase_options | Projeto real `pediatria360-app` (não SUBSTITUA) |
| Secrets no repo | Sem evidência de chave OpenAI hardcoded |
| App Check | NÃO IMPLEMENTADO (bloqueador doc) |
| Storage | rules presentes — deploy status não verificado nesta sessão |
| Assinatura clínica | Hash interno ≠ ICP |

---

## 9. LGPD

**Existe:** consentimentos por finalidade, export JSON, exclusão agendada 15 dias, cancel, revoke, tela Privacy, voice consent UI.

**Falta:** URLs legais reais; DPO/CNPJ/domínio; consentimento do responsável antes de grant profissional; voice consent atribuído ao profissional (`consentByUid: actor.uid`).

---

## 10. Auditoria das 10 telas principais

| # | Tela | Status | Evidência / problema |
|---|------|--------|----------------------|
| 1 | Início | PARCIAL | KPIs de home profissional usam `professionalPatientsProvider` + `myAgendaProvider` (reais). Consultório dashboard zera vários KPIs (TODO). |
| 2 | Pacientes | FUNCIONANDO/PARCIAL | Lista/busca/filtros Firestore; paginação server limitada; exclusão/avançado parcial |
| 3 | Prontuário | PARCIAL | Timeline + editor + docs PDF + assinatura hash; desenvolvimento motor detalhado limitado |
| 4 | Agenda | PARCIAL | Dia/7 dias, confirmar/cancelar/iniciar; sem visão mês completa / waitlist / encaixe formal |
| 5 | Vacinas | PARCIAL | Calendário PNI + status; lote/profissional/cobertura agregada limitada; validação PNI pendente |
| 6 | Telemedicina | BLOQUEADO/PARCIAL | UI + agenda; vídeo flag false; join unimplemented |
| 7 | Biblioteca | PARCIAL | Conteúdo Firestore/CMS; favoritos/downloads dependem content |
| 8 | Relatórios | NÃO IMPLEMENTADO | Sem módulo/rota |
| 9 | Financeiro | NÃO IMPLEMENTADO | ClinicRole.finance + icon; dashboard billing = 0 |
| 10 | Perfil | PARCIAL | Dados/tema/LGPD/clínica; “Ajuda em breve” |

Loading/empty/error: padrão `EmptyState`/`LoadingState` presente nas telas principais auditadas.

---

## 11. Consulta pediátrica (estrutura de dados)

`Anamnesis` em `clinical_record.dart` inclui: queixa, HDA, antecedentes, gestação, parto, desenvolvimento, alimentação, sono, eliminações, imunização, alergias, medicações, familiar, social, revisão sistemas. + vitals + exame físico + diagnósticos + conduta/plano.

**Falta como módulo dedicado:** escalas neuropediátricas; retorno estruturado além de campos de plano; CID por busca descritiva.

---

## 12. Crescimento / desenvolvimento / neuropediatria

| Item | Status |
|------|--------|
| Peso/altura/IMC/PC + Z-score math | FUNCIONANDO (math) |
| Tabelas LMS | PARCIAL / BLOQUEADO clínico — aproximadas |
| Gráficos | PARCIAL |
| Marcos desenvolvimento estruturados | PARCIAL / NÃO (timeline sem fake, sem escalas) |
| M-CHAT / SNAP-IV / Vanderbilt / CARS | NÃO IMPLEMENTADO |

---

## 13. Mensagens

Centro de notificações (`/avisos`) — **não** é WhatsApp/chat clínico completo com áudio/PDF/modelos.

---

## 14. Área do responsável

**Existe** (role `parent`): home família, crianças, vacinas, crescimento, biblioteca, IA, loja, telemedicina lado paciente parcial. Login único (não app separado).

---

## 15. IA clínica

| Capacidade | Status | Risco |
|------------|--------|-------|
| Chat IA pediátrica | PARCIAL | Conteúdo assistivo |
| clinicalAssist | PARCIAL | Draft |
| Voz → rascunho encounter | PARCIAL | STT/pipeline; **revisão humana** nas telas review |
| Diagnóstico/Rx automático fechado | NÃO | Flags/draft |
| Prescrição automática sem revisão | NÃO desejável — suplementação exige confirmação | |

Regra do produto: saídas como rascunho — manter e reforçar em UX.

---

## 16. UI/UX / Ícones / Responsividade / A11y

- Shell premium + `AppIcons`/`AppIcon`; **301 PNG** presentes neste checkout sob `assets/icons`.
- Material ainda em telas profundas (editor, admin, shop).
- Responsive: `ScreenSize` compact/medium/large no shell.
- A11y: sem auditoria automatizada Semantics completa nesta sessão — contraste/tokens brand presentes; Semântica parcial **P3**.

---

## 17. Performance

Listeners long-lived; queries sem limit em vários repos; telas >1000 LOC — risco rebuild/custo Firestore **P2**.

---

## 18. Testes (inventário — execução completa não concluída nesta sessão)

~27 arquivos Dart em `test/` + `test/rules/rules.test.js` + `functions/.../booking.test.ts`. Cobertura: domínio clínico, rotas, sync, suplementação, clinic org, smoke UI. **Sem** pasta `integration_test/` device e2e.

Comando recomendado (não executado end-to-end aqui por tempo): `flutter test` + `firebase emulators:exec --only firestore "npm test"`.

---

## 19. Build / publicação

| Item | Status |
|------|--------|
| applicationId | `app.pediatria360` em `platform/android/...` |
| Signing release | debug (bloqueador) |
| Splash/launcher nativos | incompletos neste layout |
| Privacy/Terms URLs | placeholder |
| Vídeo/pagamento | OFF |
| OMS/PNI | não homologados |

Checklist alinhado a `BLOQUEADORES_PRODUCAO.md`.

---

## 20. Tabela mestra (amostra crítica)

| ITEM | MÓDULO | STATUS | EVIDÊNCIA | PROBLEMA | IMPACTO | SEV | AÇÃO |
|------|--------|--------|-----------|----------|---------|-----|------|
| Termos/Privacidade | Legal | BLOQUEADO | `app_config.dart` L23-26 | URLs fictícias | Store/LGPD | P0 | Publicar docs reais |
| OMS LMS | Growth | BLOQUEADO | `who_reference.dart` L142-146 | Dados aproximados | Erro clínico | P0 | Substituir LMS oficial |
| PNI | Vacinas | BLOQUEADO | `BLOQUEADORES` + `pni_calendar.dart` | Não conferido gov.br | Erro clínico | P0 | Validação médica |
| Vídeo tele | Tele | BLOQUEADO | `joinConsultation` unimplemented; flag false | Sem consulta online | Produto | P0 | Contratar provedor ou manter OFF com copy clara |
| Pagamento | Shop | BLOQUEADO | flag false | Sem monetização loja | Receita | P1 | Gateway |
| ICP | EMR | PARCIAL | `signEncounter` hash | Não é ICP | Compliance | P1 | Integrar ICP ou disclaimer |
| Multitenant clínico | Clinic org | PARCIAL | FASE1B; sem clinicId docs | Vazamento entre clínicas futuro | Segurança SaaS | P0 | Migrar clinicId + rules |
| Financeiro | Gestão | NÃO IMPL | Sem feature | Gap SaaS | Comercial | P1 | Escopo FASE financeira |
| Relatórios | Gestão | NÃO IMPL | Sem rotas | Gap SaaS | Comercial | P1 | Escopo BI |
| Neuropediatria escalas | Clínico | NÃO IMPL | Sem código escalas | Gap premium | Produto | P2 | Módulo escalas |
| KPIs consultório | Clinic | MOCK parcial | `clinic_repository.dart` L209-229 | Zeros hardcoded | Dashboard mentiroso | P1 | Implementar queries |
| Ajuda | Perfil | PARCIAL | SnackBar em breve | Botão sem destino | UX | P3 | Conteúdo ajuda |
| App Check | Seg | NÃO IMPL | Docs | Abuso API | Segurança | P0 | Ativar App Check |
| Keystore | Build | BLOQUEADO | debug signing | Não publica | Store | P0 | Keystore release |
| Chat clínico | Msgs | NÃO IMPL | Só notifications | Expectativa “Mensagens” | UX | P2 | Chat ou renomear |
| CID busca | EMR | PARCIAL | Docs bloqueadores | Só código manual | UX clínico | P2 | Base CID licenciada |
| Consent parental grant | LGPD | PARCIAL | Functions grant | Sem Art.14 guardian | Legal | P0 | Fluxo consentimento |
| Ícones premium | UI | FUNCIONANDO | 301 PNG + AppIcons | Wire incompleto telas profundas | Visual | P3 | Wave 3 wire |
| Testes e2e device | QA | NÃO IMPL | sem integration_test | Regressão store | Qualidade | P2 | Smoke device |
| Listeners unbounded | Perf | PARCIAL | children/growth snaps | Custo | Ops | P2 | limits + autoDispose |

---

## 21. P0 — Críticos (8)

1. URLs legais placeholder  
2. OMS aproximada em uso clínico potencial  
3. PNI não homologado  
4. Isolamento tenant clínico incompleto (risco futuro SaaS)  
5. App Check ausente  
6. Signing release ausente / plataforma nativa incompleta  
7. Consentimento parental para compartilhamento profissional incompleto  
8. Vídeo tele “parece pronto” mas `unimplemented` (risco expectativa/segurança UX) — tratar como P0 de produto se anunciado

## 22. P1 — Altos (14)

KPIs stub consultório; financeiro inexistente; relatórios inexistentes; ICP vs hash; gateway OFF; waitlist/mês agenda; cobertura vacinal/lote incompletos; CID; STT voz robustez; deploy rules produção; FCM produção; DPO/CNPJ; screenshots store; migração clinicId patients/agenda.

## 23. P2 — Médios (18)

Neuropediatria; chat real; wire ícones restantes; queries limit; telas gigantes; favoritos biblioteca; shop UX; gamificação; suplementação conteúdo médico; empty/ajuda; Semantics a11y; testes device; Remote Config defaults; multiunidade UI; encaixe; exams pendentes KPI; sync edge cases; performance PNG pack.

## 24. P3 — Baixos (12)

Copy “em breve”; prefer_const; doc drift applicationId; chevrons Material; alternativas icons pasta; tipografia fine-tune; empty illustrations; onboarding polish; ranking; badge; noise assets; README drift.

---

## 25. Mocks / stubs evidentes

- `ClinicDashboardStats` campos 0 + TODO (`clinic_repository.dart`)  
- `videoConsultationEnabled = false` / UI desabilitada  
- `paymentGatewayEnabled = false`  
- OMS JSON aproximado  
- Legal URLs fictícias  
- `joinConsultation` → `unimplemented`  

## 26. Botões sem função / parciais

| Tela | Label | Comportamento |
|------|-------|---------------|
| Perfil | Ajuda | SnackBar “em breve” |
| Tele | Entrar/controles vídeo | Desabilitados se flag false |
| Shop | Checkout pagar | null onPressed se gateway OFF |
| Consultório KPIs | Vários cards | Mostram 0 sem backend |

## 27. Plano de correção (após autorização)

### Épico A — Homologação clínica (P0)
OMS oficial + PNI validado + disclaimers.

### Épico B — Legal/Store (P0)
Docs hospedados, DPO, keystore, App Check, ícones/splash nativos, `flutter create` merge.

### Épico C — Tele/pagamento (P0/P1)
Provedor vídeo OU copy “em breve” sem falsa prontidão; gateway.

### Épico D — Multitenant (P0/P1)
`clinicId` em patients/agenda/encounters + rules.

### Épico E — SaaS gaps (P1)
Financeiro mínimo + relatórios básicos.

### Épico F — Produto premium (P2)
Escalas neuropediatria; chat; wire ícones; KPI reais.

**Não** reconstruir Firebase/auth; **não** remover features.

---

## 28. Conclusão

### **NÃO PRONTO PARA PUBLICAÇÃO**

Motivo: bloqueadores legais (URLs), clínicos (OMS/PNI), assinatura ≠ ICP, vídeo/pagamento incompletos, tenant clínico incompleto, ausência de financeiro/BI SaaS anunciáveis, e preparação de store/signing incompleta. O núcleo técnico é **sólido para continuar evolução**, não para loja nem para uso clínico sem ressalvas explícitas.

---

## 29. Aguardando autorização

Nenhuma correção crítica foi aplicada nesta auditoria. Aguardar autorização do proprietário para iniciar épicos A–F.
