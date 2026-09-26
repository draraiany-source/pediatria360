# RELATORIO FINAL — Preparacao para publicacao (2026-09-26)

| Campo | Valor |
|-------|-------|
| Repo | https://github.com/draraiany-source/pediatria360 |
| Branch enviada | `publish/prep-20260926` |
| PR | https://github.com/draraiany-source/pediatria360/pull/1 |
| Commit enviado | `2dd7aa7a033c78e8bc15c2646b7d477a5255c60e` |
| Backup | `backup/pre-publish-20260926` @ `988de4d` |
| `origin/main` (antes do merge) | `988de4d` |
| FASE 2 no GitHub | **SIM** desde `a580fd6` — auditoria 25/09 estava desatualizada neste ponto |

## 1. Ja estava pronto no remoto
- FASE 2 (responsaveis, agenda, RBAC) e testes relacionados
- Homolog web: https://pediatria360-app--homolog-orcamento-a9dstse4.web.app
- Guard de timeline sem chart (`c2fbec2`)
- Flags `paymentGatewayEnabled` / `videoConsultationEnabled` = **false**
- Avisos clinicos OMS/PNI na UI (`WhoReference.warning`, `PniCalendar.warning`, `DataWarningBanner`)
- Termos/Privacidade: URLs placeholder em `AppConfig` (nao inventados)

## 2. Corrigido nesta rodada (codigo enviado)
| Item | Status |
|------|--------|
| Scaffold Android/iOS + Gradle AGP 8.9.1, minSdk>=23, compileSdk 36 | Feito |
| DevMode off com `ENV=prod` | Feito (`lib/core/config/dev_mode.dart`) |
| Auditoria atualizada (FASE 2 / plataformas) | Feito (`AUDITORIA_PUBLICACAO_COMPLETA.md`) |
| Video / pagamento / ICP / TISS / voz | **Mantidos OFF / nao concluidos** |
| App Check | **Ausente** (sem codigo / dependencia) |
| OMS / PNI dados oficiais | **Nao substituidos** — validacao clinica pendente |
| Keystore release | Release ainda assina com debug |

## 3. Testes — evidencias

| Comando | Resultado | Evidencia |
|---------|-----------|-----------|
| `flutter test` (dev_mode, permission_matrix, route_authorization, fase2) | **52 passed**, exit 0 | `tools/publish_unit_tests.txt` |
| `flutter analyze --no-fatal-infos` | **158 issues (estilo/info)**, exit 0; **0 `error •`** | `tools/publish_analyze3.txt` |
| Functions (`npm test`) | **Nao executado** (sem `node_modules` / disco) | — |
| Rules emulator | **Nao reexecutado** nesta rodada | — |
| E2E UI tres perfis em dispositivo | **Nao executado** | Impedimento: sem dispositivo/sessao E2E nesta maquina |
| Fluxos clinicos com pacientes reais | **Proibido / nao feito** | Politica de publicacao |

## 4. Builds

| Build | Resultado | Caminho / nota |
|-------|-----------|----------------|
| Web release `ENV=prod` | **OK** | `build/web` (ex.: `build/web/main.dart.js`) |
| APK debug `ENV=prod` | **FALHOU** | Gradle: `IOException: Espaco insuficiente no disco` (~1,3 GB livres). Log: `tools/publish_apk3.txt` |
| AAB release assinada | **Impedido** | Sem keystore de producao + disco |
| iOS / IPA | **Impedido** | Windows sem Xcode |

Homolog ja publicada (nao e build desta sessao):  
https://pediatria360-app--homolog-orcamento-a9dstse4.web.app

## 5. Pendencias que dependem de voce
1. Textos finais Termos + Privacidade + URLs reais (trocar placeholders em `AppConfig`)
2. CNPJ, DPO, e-mail de suporte definitivo
3. Tabelas OMS LMS oficiais (`assets/data/who_reference.json`) + conferencia PNI em gov.br
4. Conta Google Play + keystore; Apple Developer + macOS/Xcode
5. Liberar espaco em disco nesta maquina (recomendado >10 GB) para gerar APK/AAB
6. Ativar App Check no Firebase Console + integrar no app
7. Deploy consciente de rules/indices no Firebase de producao
8. Dominio Auth/Hosting de producao
9. Revisar/merge do PR #1 em `main` (branch protegida — nao houve force push)

## 6. O que ainda impede publicacao nas lojas / pacientes reais
Itens da secao 5 + ausencia de E2E com Auth real; video/pagamento/ICP/TISS/voz **nao** devem constar como prontos na listagem das lojas.

## 7. Como buildar producao (quando liberado)
```
flutter build appbundle --release --dart-define=ENV=prod
flutter build web --release --dart-define=ENV=prod --no-wasm-dry-run
```
Nunca use `SKIP_AUTH` com `ENV=prod`.
