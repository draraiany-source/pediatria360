# AUDITORIA FINAL PARA ORCAMENTO — Pediatria360

| Campo | Valor |
|-------|-------|
| Documento | Auditoria atualizada para programador avaliar e orcar |
| Data da auditoria | 2026-09-25 |
| Base da auditoria anterior | AUDITORIA_PUBLICACAO_COMPLETA.md (25/09/2026) |
| Repositorio | https://github.com/draraiany-source/pediatria360 |
| Branch | main |
| Commit pre-auditoria (sincronizado) | a580fd6 |
| Checkpoint de seguranca | c0c0322 |
| Commit desta entrega | `c2fbec2` |
| Versao app | 1.0.0+1 (pubspec.yaml) |
| Classificacao | **NAO PRONTO para pacientes reais nem lojas** |
| FASE 2 no GitHub | **SIM** (desde a580fd6) — auditoria anterior estava desatualizada neste ponto |

---

## 0. Como o programador deve usar este documento

1. Clonar o repositorio no commit indicado.
2. Abrir a URL publica de homologacao (secao 9) para ver a UI.
3. Usar o inventario (secao 3) e o backlog P0/P1 (secao 7) para orcar.
4. Nao assumir que tela = fluxo completo; ler coluna "Estado real".

---

## 1. Etapa 1 — Versao preservada

| Item | Resultado |
|------|-----------|
| Repo local | `C:/Users/Lenovo/Desktop/pediatria360/pediatria360` |
| Remote | `https://github.com/draraiany-source/pediatria360.git` |
| Branch | `main` |
| Local == remoto (inicio) | `a580fd6` |
| FASE 2 no remoto | Confirmado (guardians, agenda_scheduling, FASE2_CONCLUIDA.md) |
| Pendencias locais | so log `tools/fase2_test_out.txt` (agora no .gitignore) |
| Commit de seguranca | `c0c0322` — checkpoint antes das correcoes |
| Perda de dados / conflito | Nenhum |

---

## 2. Etapa 2 — Inventario de modulos (estado no codigo atual)

Legenda: **F** funcional ponta a ponta no ambiente configurado | **P** parcial (UI+dados, falta integracao/config) | **V** so visual / stub | **OFF** desligado por flag | **N** ausente

| Modulo | Estado | Evidencia / arquivos | Risco | Prioridade |
|--------|--------|----------------------|-------|------------|
| Auth (login/cadastro/recuperar) | F | `lib/features/auth/` | URLs legais placeholder | P0 legal |
| Shell / navegacao / voltar | F/P | `app_shell.dart`, GoRouter | Deep links OK; alguns fluxos usam push | P2 |
| Criancas | F | `children/` | Deduplicacao CPF parcial | P2 |
| Responsaveis (FASE 2) | F/P | `child_guardian*`, rules | UI criar via UID; sem dedupe | P1 |
| Agenda consultorio | F/P | `telemedicine_repository`, `agenda_scheduling` | UI criar agendamento recepcao incompleta | P1 |
| Salas/bloqueios | F | `clinic_schedule_*` | So admin clinica | P2 |
| Consultorio / recepcao | P | `clinic/` | KPIs zerados em parte | P2 |
| Prontuario / EMR | P | `emr/` | Hash != ICP; CID manual | P0 clinico comunicacao |
| Crescimento | P | `growth/`, `who_reference.json` | JSON aproximado OMS | P0 clinico |
| Vacinas | P | `vaccines/`, `pni_calendar.dart` | Validar gov.br | P0 clinico |
| IA chat | P | `ai/` + CF `aiChat` | Depende Anthropic secret | P1 |
| Voz / prontuario IA | P | `clinic/voice_*`, CF voice | Nao marcar como concluido | P1 |
| Telemedicina video | OFF | `AppConfig.videoConsultationEnabled=false`; CF unimplemented | Nao prometer | P0 listing |
| Cursos / biblioteca | P | `courses/`, `library/` | Bunny dart-defines | P1 |
| Notificacoes | P | `notifications/` | FCM config dispositivo | P2 |
| Financeiro | P | `finance/` | Rules tenant; sem gateway | P1 |
| Faturamento | P | `billing/` | Sem operador TISS real | P1 |
| Estoque | P | `inventory/` | Integracao vacinas parcial | P2 |
| BI | P | `bi/` | Depende dados reais | P2 |
| Admin CMS | P | `admin/` | Papel UserRole.admin | P2 |
| Permissoes / auditoria | F/P | `permission_matrix`, `security/` | unitId app-layer | P1 |
| LGPD tecnica | F/P | `privacy/` + CF privacy | Textos juridicos pendentes | P0 legal |
| Loja / pagamento | OFF/P | `shop/`; `paymentGatewayEnabled=false` | paymentUrl null | P0 listing |
| Clinic org multitenant | P | `clinic_org/` | unitId rules incompleto | P1 |
| Suplementacao | P | `supplementation/` | Textos clinicos placeholder | P1 medico |
| Android loja | N/P | `android/` parcial; templates `platform/` | Impede AAB | P0 |
| iOS loja | N/P | sem xcodeproj | Impede IPA | P0 |
| Web | F/P | `web/` + hosting | Homologacao | — |

### Tres perfis

| Perfil | O que funciona | Limitacao comprovada |
|--------|----------------|----------------------|
| Responsavel (parent) | Criancas, crescimento, vacinas, biblioteca, IA (com cota) | Sem area profissional |
| Profissional / medico | Agenda, pacientes, EMR, consultorio | Video OFF; ICP nao |
| Recepcao (ClinicRole) | Agenda, cadastro admin; chart negado na matriz + rota + **timeline** | Isolamento unitId parcial |

---

## 3. Etapa 3 — Correcoes feitas nesta rodada

| Correcao | Arquivo | Status |
|----------|---------|--------|
| Checkpoint + gitignore log | `CHECKPOINT_AUDITORIA_PROGRAMADOR.md`, `.gitignore` | Feito (`c0c0322`) |
| Bypass RBAC: timeline via Navigator.push (home/360/pendencias) | `patient_timeline_screen.dart` | Feito — bloqueio na propria tela |

### Nao corrigido (depende de voce / externo)

- Termos/Privacidade reais (juridico)
- OMS LMS oficial / PNI gov.br (validacao clinica)
- Android/iOS scaffolding + signing + icones
- App Check, deploy rules em producao
- Provedor video / gateway pagamento / ICP-Brasil
- Conta Apple/Google Play

---

## 4. Etapa 4 — Testes e evidencias

| Teste | Resultado | Ambiente |
|-------|-----------|----------|
| `flutter test` permission_matrix + route_authorization + fase2_agenda_guardians | **46 passed** (2026-09-25) | Windows local |
| flutter analyze completo | Nao concluido nesta sessao (historico de hang) | — |
| Functions npm test | Nao executado nesta sessao | — |
| Rules emulator suite completa | Nao reexecutado (FASE 9: 19 pass; FASE 10: 24 pass — historico) | Emulator |
| Build Android AAB | **Nao testado** — plataforma incompleta | — |
| Build iOS | **Nao testado** — sem Xcodeproj / macOS | — |
| Build web release homolog | **OK** `flutter build web --release --no-wasm-dry-run` + SKIP_AUTH staging | Windows |
| UI E2E 3 perfis no browser publico | Parcial / convidado SKIP_AUTH | Homolog web |
| Login real Emulator no link publico | **Nao aplicavel** — Emulator nao e publico | — |

**Nao declarar "testado"** o que so compilou: APK/AAB/IPA nao gerados.

---

## 5. Bloqueios que ainda impedem pacientes reais / lojas

1. OMS/PNI nao validados como oficiais
2. Termos/Privacidade / DPO / CNPJ
3. Android/iOS incompletos + signing debug
4. App Check ausente
5. Confirmacao de deploy rules/indices no projeto de producao
6. Video e pagamento OFF (nao prometer na loja)
7. Assinatura encounter != ICP-Brasil
8. Homologacao UI E2E incompleta (FASE 10)
9. SKIP_AUTH so para homologacao staging — nunca `ENV=prod` com skip

---

## 6. Trabalho restante para orcamento (criterios objetivos)

### P0 — bloquear loja / uso clinico
| Item | Criterio de pronto |
|------|-------------------|
| Scaffold Android/iOS + icones | `flutter build appbundle` e build iOS sem erro |
| Keystore / certificados | AAB/IPA assinados release |
| Juridico Termos/Privacidade | URLs reais no AppConfig + aceite |
| OMS + PNI oficiais | Arquivos substituidos + aviso removido ou atualizado |
| App Check + rules deploy prod | App inicia com App Check; rules ativas no console |
| Store listing honesto | Sem video/pagamento/ICP se nao integrados |

### P1 — produto clinico / operacao
| Item | Criterio de pronto |
|------|-------------------|
| UI criar agendamento recepcao | Fluxo E2E sem API so |
| unitId nas rules | Teste cross-unit falha no emulator |
| Bunny + secrets IA | Aula toca; aiChat responde em staging |
| Fechar lacunas patient 360 RBAC | Rota 360 tambem gated (parcialmente coberto pela timeline) |
| Testes E2E 3 perfis | Roteiro FASE 10 UI completo |

### P2 — qualidade
KPIs consultorio reais; CID busca; dedupe criancas; gamification data layer; analyze CI.

---

## 7. Dependencias e decisoes do contratante

- Textos Termos/Privacidade e dados do controlador (LGPD)
- Tabelas OMS oficiais e conferencia PNI
- Contas Google Play / Apple Developer
- Keystore e certificados
- Contratar video (Daily/Twilio…) e/ou pagamento (Stripe/MP…)
- Secrets Firebase (Anthropic, Bunny)
- Autorizar `firebase deploy` hosting/rules no projeto `pediatria360-app`
- Escopo: soft launch web vs lojas nativas

---

## 8. Arquivos alterados nesta entrega (apos checkpoint)

- `lib/features/emr/presentation/screens/patient_timeline_screen.dart` — guarda chart
- Documentos de auditoria final (este arquivo + HTML/PDF)
- (atualizar lista no commit final)

---

## 9. Homologacao publica e GitHub

| Item | Valor |
|------|-------|
| GitHub | https://github.com/draraiany-source/pediatria360 |
| Commit auditado | `c2fbec2` — https://github.com/draraiany-source/pediatria360/commit/c2fbec2 |
| URL publica | https://pediatria360-app--homolog-orcamento-a9dstse4.web.app (expira ~2026-10-25) |
| Perfis no link publico | Convidado DevMode (SKIP_AUTH) — UI profissional local; **sem dados reais de pacientes** |
| Localhost | **Nao** e o link publico; so desenvolvimento |
| APK / AAB | **Nao gerados** (plataforma Android incompleta) |

### O que o programador consegue testar no link publico
- Navegacao shell, telas de agenda/consultorio/financeiro (UI)
- Estados vazios / loading quando Firestore nega convidado

### O que NAO testa no link publico
- Login Auth real por perfil
- Persistencia clinica real
- Video, pagamento, ICP
- Isolamento multi-clinica com memberships reais

---

## 10. Conclusao

O Pediatria360 evoluiu desde a auditoria de 25/09: **FASE 2 esta no GitHub**, finance/billing/BI/inventory existem como modulos, e foi corrigido o bypass de prontuario via push. Continua **nao publicavel** nas lojas nem apto a pacientes reais pelos bloqueios P0 acima.

Este documento e a base para orcamento do trabalho restante.

---

*Fim — auditoria programador Pediatria360 — 2026-09-25*