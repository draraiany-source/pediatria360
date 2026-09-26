# RELATORIO FINAL — Preparacao para publicacao (2026-09-26)

| Campo | Valor |
|-------|-------|
| Repo | https://github.com/draraiany-source/pediatria360 |
| Branch base | main (pre-push: 988de4d) |
| Branch backup | `backup/pre-publish-20260926` @ 988de4d |
| FASE 2 no GitHub | **SIM** desde `a580fd6` — a auditoria 25/09 estava desatualizada neste ponto |

## 1. O que ja estava pronto no remoto
- FASE 2 (responsaveis, agenda, RBAC) e indices relacionados
- Auditoria de orcamento + homolog web publica
- Guard de timeline sem chart (`c2fbec2`)
- Flags `paymentGatewayEnabled` / `videoConsultationEnabled` = false
- Avisos clinicos OMS/PNI embutidos no codigo (`WhoReference.warning`, `PniCalendar.warning`, `DataWarningBanner`)

## 2. Correcoes feitas nesta rodada (codigo)
| Item | Status |
|------|--------|
| Scaffold Android/iOS (`flutter create` + migrate) | Feito e versionado |
| Gradle pin AGP 8.9.1 + minSdk >= 23 + Firebase plugins | Feito |
| DevMode desligado com `ENV=prod` | Feito (`lib/core/config/dev_mode.dart`) |
| Video / pagamento / ICP / TISS / voz IA | **Mantidos OFF / nao concluidos** |
| Termos/Privacidade/CNPJ | Placeholders em `AppConfig` — **aguardando dados seus** |
| OMS / PNI | Sem substituicao de dados — **validacao clinica pendente** |
| App Check | **Nao implementado** |
| Keystore release | Release ainda assina com debug — **pendente sua keystore** |

## 3. Testes (evidencia)
| Comando | Resultado |
|---------|-----------|
| `flutter test` (dev_mode + permission_matrix + route_authorization + fase2) | **52 passed**, exit 0 — `tools/publish_unit_tests.txt` |
| `flutter analyze` | Ver secao atualizada no commit de evidencia / abaixo apos execucao |
| Functions / rules emulator | **Nao reexecutados** nesta rodada (sem tempo/ambiente garantido) |
| APK debug `--dart-define=ENV=prod` | Em andamento ou resultado em `tools/publish_apk_build.txt` |
| iOS release / IPA | **Impedido** — Windows sem Xcode |
| AAB assinada | **Impedido** — sem keystore de producao |
| Fluxos E2E UI tres perfis em dispositivo | **Nao executados** nesta maquina |

## 4. Builds
- Web homolog (ja publicada): https://pediatria360-app--homolog-orcamento-a9dstse4.web.app
- APK: caminho sera `build/app/outputs/flutter-apk/app-debug.apk` se o build concluir
- Artefatos locais de log (`tools/publish_*.txt`) **nao** entram no Git

## 5. Pendencias que dependem de voce
1. Textos finais Termos + Privacidade + URLs reais (trocar placeholders em `AppConfig`)
2. CNPJ, DPO, e-mail de suporte definitivo
3. Tabelas OMS LMS oficiais em `assets/data/who_reference.json` + conferencia PNI em gov.br
4. Conta Google Play + keystore; Apple Developer + macOS/Xcode
5. Ativar App Check no Firebase Console + integração no app
6. Confirmar deploy de rules/indices no projeto Firebase de producao
7. Dominio autenticado no Firebase Auth / Hosting de producao

## 6. O que ainda impede publicacao nas lojas / pacientes reais
Itens da secao 5 + ausencia de E2E em dispositivo com Auth real e dados de homologacao (nunca pacientes reais ate legal + OMS/PNI + App Check).

## 7. Como buildar producao (quando liberado)
```
flutter build appbundle --release --dart-define=ENV=prod
flutter build web --release --dart-define=ENV=prod --no-wasm-dry-run
```
Nunca use `SKIP_AUTH` com `ENV=prod`. DevMode retorna `false` quando `AppConfig.isProduction`.
