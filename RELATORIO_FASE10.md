# RELATORIO FASE 10 — Homologacao dos fluxos (staging Emulator)

| Campo | Valor |
|-------|-------|
| Data | 2026-09-24 |
| Base Git | `adb41e240d7dd6cd354be89c96e065ffc171b139` (FASE 9 closeout) |
| Ambiente | Firebase Auth+Firestore Emulator `pediatria360-app` + Flutter web-server `127.0.0.1:5180` |
| Dados | Somente ficticios (`tools/fase10-homolog/seed_fictitious.js`) |
| Deploy producao | **Nao realizado** |
| Fase 11 | **Nao iniciada** |

## Evidencia FASE 9 (isolamento entre clinicas) — NAO e prova de E2E do app

- Comando: `cd tools/firestore-rules-tests && npm run test:emulator`
- Resultado: **19 pass / 0 fail** (cross-clinic finance/billing/inventory/audit)
- Registro: evidencia de **regras** multiempresa. **Nao** substitui homologacao de fluxos UI/app.

## Resumo da matriz Auth/Firestore (`npm run matrix`)

| Resultado | Qtd |
|-----------|-----|
| PASSOU | 24 |
| FALHOU | 0 |
| NAO TESTADO | 3 |

Arquivo bruto: `tools/fase10-homolog/results_matrix.json`

### Cenarios PASSOU (servidor / persistencia / negativos)

- Login Auth Emulator: admin A/B, recepcao, medico, financeiro, responsavel A/B
- Financeiro: leitura cobranca clinica A; criacao+persistencia cobranca ficticia
- Negativo cross-clinic: admin B nao le finance nem auditoria da clinica A
- Negativo perfil: recepcao nao cria finance; parent nao le finance; medico sem grant nao le crianca; parent A nao le crianca familia B
- Medico: le proprio appointment; cria encounter draft; **prontuario assinado imutavel** (PATCH negado)
- Admin A: cria+le security_audit_logs da clinica
- Consentimento: parent le proprio doc
- Token invalido / falha de conexao

### NAO TESTADO (matriz)

- `signEncounter` Cloud Function (Functions Emulator nao iniciado)
- Android UI
- iOS UI

## UI Chrome / Edge (Windows)

| Cenario | Resultado | Evidencia |
|---------|-----------|-----------|
| Build/servir web com Emulator + `FORCE_REAL_AUTH=true` | **PASSOU** | `flutter run -d web-server --web-port=5180`; URL `http://127.0.0.1:5180`; banner Emulator; rota `#/onboarding` (sem convidado DevMode) |
| Login UI email/senha por perfil + navegar/voltar/sair | **NAO TESTADO** | Flutter web intercepta cliques (`Enable accessibility`); automacao browser nao concluiu formularios |
| Edge (dispositivo `edge`) fluxo completo | **NAO TESTADO** | Mesma barreira; roteiro em `ROTEIRO.md` |
| Android / iOS | **NAO TESTADO** | `flutter devices`: apenas windows/chrome/edge |

### Correcoes verificadas para destravar build web

- UTF-16 → UTF-8: `bi_hub_screen.dart`
- Import `FinancePeriod` em `production_screen.dart`
- `AppColors.error` → `danger` (audit/permissoes)
- `BiKpiTile.new` → `BiKpiTile(data:)`
- Imports BI aggregators + `AppCard` via `brand_ui`
- `FORCE_REAL_AUTH` dart-define em `dev_mode.dart`

## Fluxos por perfil (consolidado)

| Perfil | Login Auth | Persistencia/rules | UI ponta a ponta |
|--------|------------|--------------------|------------------|
| Administrador | PASSOU | PASSOU (audit) | NAO TESTADO (UI) |
| Recepcao | PASSOU | PASSOU (neg. finance); agenda clinica ampliada limitada pelas rules de appointments | NAO TESTADO (UI) |
| Medico | PASSOU | PASSOU (agenda propria, draft, imutabilidade); assinatura Function NAO TESTADO | NAO TESTADO (UI) |
| Financeiro | PASSOU | PASSOU (CRUD ficticio) | NAO TESTADO (UI) |
| Paciente/responsavel | PASSOU | PASSOU (crianca/consent + neg. familia) | NAO TESTADO (UI parcial: onboarding visto) |

### Funcoes ausentes / simuladas (clareza)

- Gateway de pagamento: `AppConfig.paymentGatewayEnabled = false` — **nao** processar pagamento real
- Videoconsulta: `videoConsultationEnabled = false`
- Assinatura clinica: **Cloud Function** `signEncounter` (nao so tela)
- Documentos clinicos: write client `allow write: if false` (Function)
- DevMode convidado: desligar com `--dart-define=FORCE_REAL_AUTH=true` na homologacao

## Bloqueios para Fase 11

1. **UI E2E por perfil incompleta** (login/navegar/voltar/sair nao executados de ponta a ponta no browser)
2. **Assinatura real** nao homologada (Functions Emulator)
3. **Android/iOS** sem dispositivo
4. **Agenda de recepcao clinic-wide**: rules de `appointments` so `patientId|professionalId` — recepcionista nao le agenda de outro profissional (esperado pelas rules; produto pode exigir mudanca futura **sem** afrouxar para passar teste)
5. Isolamento **unitId** nas rules continua app-layer (FASE 9)

## Roteiro Android/iOS (objetivo)

Ver `tools/fase10-homolog/ROTEIRO.md` secao Android/iOS. Em Android emulator usar `EMULATOR_HOST=10.0.2.2`.

## Como reproduzir

Ver `tools/fase10-homolog/README.md`.