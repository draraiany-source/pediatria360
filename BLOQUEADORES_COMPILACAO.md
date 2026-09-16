> **HISTÓRICO — não é o documento atual.**
>
> Bloqueadores de compilação por dependência — conteúdo já coberto por ANTES_DE_COMPILAR.md.
>
> Para o estado atual do projeto, use:
> - `README.md` — visão geral
> - `ANTES_DE_COMPILAR.md` — o que verificar/rodar antes da primeira compilação real
> - `BLOQUEADORES_PRODUCAO.md` — o que falta para produção, categorizado
> - `CHECKLIST_PUBLICACAO_FINAL.md` — checklist de publicação
> - `CHANGELOG_V40.md` (ou o mais recente) — o que mudou, versão a versão
>
> Este arquivo fica como registro do que foi decidido e por quê — não é
> atualizado desde que virou histórico, então números e status aqui podem
> estar desatualizados.

---

# BLOQUEADORES_COMPILACAO.md — Pediatria 360

Separado exatamente como pedido: bloqueadores conhecidos, e depois por
dependência (Flutter, Firebase, Android, iOS).

---

## Bloqueadores conhecidos

- **Nenhuma linha foi compilada com Flutter real.** Este é o maior risco
  deste documento inteiro — 34.543 linhas Dart nunca passaram por
  `flutter analyze`. Todas as verificações deste projeto (sintaxe,
  referência cruzada, import, segurança) foram feitas por ferramenta
  própria em Python, que não é um compilador e não pega erro de tipo,
  `await` esquecido, ou incompatibilidade de null-safety.
- **`android/`/`ios/` existem vazios** neste checkout — confirmado com
  `find`, zero arquivo dentro. Se `flutter create .` perceber a pasta já
  existindo, algumas versões pulam a geração. Apague as pastas vazias
  antes de rodar `flutter create`, se confirmar que estão realmente vazias.
- **Possível ajuste de `intl`** na primeira tentativa de `flutter pub get`
  — `flutter_localizations` fixa uma versão específica internamente, e
  `pubspec.yaml` declara `intl: ^0.19.0` por caret. Se não bater com o que
  o SDK instalado espera, o erro aponta a versão exata a usar.

## Dependentes de Flutter

- `flutter pub get` — resolve as 39 dependências diretas; sem forma de
  confirmar sem rodar
- `flutter analyze` — zero execução até agora
- `flutter test` — 228 casos escritos, asserções verificadas manualmente,
  nunca rodados pelo `flutter test` de verdade
- `flutter run` — depende de tudo acima já estar limpo

## Dependentes de Firebase

- `firebase_options.dart` é placeholder que falha rápido de propósito
  (`isPlaceholder` check em `main.dart`) — sem `flutterfire configure`
  com projeto real, o app abre numa tela de erro clara, não crasha
  silenciosamente, mas também não funciona
- Segredos das Functions (`ANTHROPIC_API_KEY`, `BUNNY_STREAM_API_KEY`,
  `BUNNY_TOKEN_KEY`) precisam estar configurados via
  `firebase functions:secrets:set` antes de `firebase deploy` funcionar
  para as Functions que os usam

## Dependentes de Android

- `compileSdk = 35`, `minSdk = 23`, `targetSdk = 35` já configurados em
  `platform/android/app/build.gradle.kts` — aplicados por
  `tool/migrate_platforms.py` depois do `flutter create`
- `google-services.json` real — sem ele, o plugin do Google Services falha
  o build Android inteiro, não só o Firebase
- Permissões já declaradas: `INTERNET`, `ACCESS_NETWORK_STATE`,
  `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `CAMERA`,
  `READ_MEDIA_IMAGES`, `RECORD_AUDIO` — as três últimas documentadas no
  próprio manifesto como não-essenciais (confirmado: zero uso de
  câmera/microfone no código Dart atual)

## Dependentes de iOS

- `Podfile`/`Info.plist` com ajustes já testados em `platform/ios/`,
  aplicados por `migrate_platforms.py`
- `GoogleService-Info.plist` real — mesmo bloqueio do Android
- Bundle ID definitivo — hoje segue o padrão `app.pediatria360.*` sugerido
  em todos os documentos do projeto, mas nunca confirmado como o nome
  final de publicação

---

Comandos exatos e ordem de execução: `ANTES_DE_COMPILAR.md` e
`tool/validate_release.sh`.
