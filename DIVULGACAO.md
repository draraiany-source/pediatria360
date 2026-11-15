# Divulgacao Pediatria360 — o que esta pronto e o que NAO esta

## Pronto para divulgar (demo / homologacao)

| Canal | Link / artefato |
|-------|-----------------|
| Web publica | https://pediatria360-app--homolog-orcamento-a9dstse4.web.app |
| GitHub | https://github.com/draraiany-source/pediatria360 |
| Android | Scaffold gerado + merge Firebase; APK debug quando o build concluir |

Modo da web/APK de demo: `ENV=staging` + `SKIP_AUTH=true` (convidado UI). **Sem dados reais de pacientes.**

## NAO pronto (nao diga o contrario na divulgacao)

- Uso clinico com pacientes reais (OMS/PNI oficiais, juridico LGPD)
- Play Store / App Store (keystore release, App Check, listagens)
- Video consulta e pagamentos (flags OFF)
- Assinatura ICP-Brasil
- iOS build nesta maquina Windows (precisa macOS)

## Correcoes tecnicas feitas nesta rodada

1. `flutter create` Android + iOS
2. `tool/migrate_platforms.py` (Manifest, Gradle Firebase, web)
3. MainActivity no package `app.pediatria360`
4. Podfile iOS corrigido
5. `build.gradle.kts` compatível com Kotlin compilerOptions / AGP atual

## Mensagem sugerida para divulgacao

"Homologacao aberta para avaliacao de interface e fluxos. Nao e versao clinica nem de loja. Feedback bem-vindo."