# ANTES_DE_COMPILAR.md — Pediatria 360

Revisão manual preventiva, categoria por categoria da sua lista. Nada aqui
substitui `flutter analyze`/`flutter test` reais — é o que consegui
verificar sem eles, para reduzir a chance de erro na primeira compilação de
verdade.

---

## 1. Comandos exatos, na ordem

```bash
# 1. Diagnóstico do ambiente
flutter doctor -v

# 2. Gera as pastas nativas — MAS VEJA O AVISO da seção 7 antes de rodar isto
flutter create --platforms=android,ios,web --org app.pediatria360 --project-name pediatria360 .
python3 tool/migrate_platforms.py

# 3. Dependências
flutter clean
flutter pub get

# 4. Verificações próprias do projeto (rápidas, sem Flutter)
python3 tool/check_syntax.py
python3 tool/check_references.py
python3 tool/check_imports.py
python3 tool/security_audit.py

# 5. Validação real
flutter analyze
flutter test

# 6. Cloud Functions
cd functions && npm ci && npm run lint && npx tsc --noEmit && npm test && cd ..

# 7. Regras do Firestore (exige firebase-tools + Java)
firebase emulators:exec --only firestore,storage "cd test/rules && npm ci && npm test"

# 8. Builds
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter build web --release
# macOS apenas:
flutter build ios --release --no-codesign
```

`tool/validate_release.sh` já executa 1–8 nesta ordem, com `set -e` (para
no primeiro erro).

---

## 2. Resultado esperado em cada etapa

| Comando | Esperado |
|---|---|
| `flutter doctor -v` | Sem `[✗]`. `[!]` em Android Studio/Xcode se você só for buildar um dos dois é aceitável. |
| `flutter pub get` | Resolve as 39 dependências diretas sem conflito. Ver seção 3 se travar. |
| `flutter analyze` | Meta: zero erro. Aviso (`info`) é aceitável, mas confira cada um — `flutter_lints` está ativo. |
| `flutter test` | 228 casos, todos verdes. Nenhum foi rodado neste ambiente — a asserção de cada um foi conferida manualmente, o que é diferente de o runner ter executado. |
| `npx tsc --noEmit` | Limpo — `strict: true` e `noUnusedLocals: true` estão ativos no `tsconfig.json`, então até uma variável declarada e não usada é erro aqui, não aviso. |
| Testes de regra | 82 casos verdes no emulador (69 Firestore + 13 Storage). |
| Builds | APK/AAB/Web geram sem erro. iOS exige macOS. |

---

## 3. Erros mais prováveis, e como corrigir cada um

### `flutter pub get` falha por conflito de versão

**Mais provável:** `intl` — `flutter_localizations` (do próprio SDK)
fixa uma versão específica de `intl` internamente, e `pubspec.yaml` declara
`intl: ^0.19.0` por caret, não fixo. Se a versão que o SDK do Flutter
instalado espera não bater:

```
Because pediatria360 depends on flutter_localizations from sdk which depends
on intl X.Y.Z, intl must be X.Y.Z.
```

**Correção:** rode `flutter pub get` uma vez para ver a versão exata que o
erro pede, ajuste `intl: ^X.Y.Z` em `pubspec.yaml` para bater, rode de novo.
Não tem como eu prever esse número aqui sem saber a versão exata do
Flutter instalado na sua máquina.

### `flutter analyze` acusando erro de tipo em arquivo que nunca rodou

Não vou fingir que sei quais — 34 mil linhas nunca passaram pelo analisador
neste ambiente. Cole a saída completa de volta; corrijo com base no erro
real, não em suposição.

### `flutter create` não gera nada, ou gera pela metade

**Achado nesta revisão:** as pastas `android/` e `ios/` já existem no
projeto, **vazias** (zero arquivo dentro — confirmado com `find`).
Provavelmente resíduo de teste anterior de ferramenta neste ambiente
sandboxed, não algo do seu checkout. Mas se `flutter create` perceber a
pasta já existente, algumas versões pulam a geração assumindo que já foi
feito, deixando a estrutura incompleta.

**Correção preventiva:** antes do passo 2 dos comandos acima, confira:
```bash
find android ios -type f | wc -l   # se der 0, apague as pastas antes de flutter create
rm -rf android ios                 # só se o comando acima confirmar que estão vazias
```

### `npm run lint`/`npx tsc --noEmit` falha nas Functions

`noUnusedLocals: true` está ativo — uma variável declarada e nunca lida é
erro de compilação ali, não aviso. Verifiquei manualmente os arquivos mais
recentemente editados (`clinical.ts`, `privacy.ts`) atrás de import ou
variável órfã e não achei nenhum, mas essa varredura foi por padrão de
texto, não pelo compilador real do TypeScript.

---

## 4. Configurações Firebase que dependem de você

- **Projeto Firebase real** — `firebase_options.dart` atual é placeholder
  que falha rápido de propósito (`isPlaceholder` check em `main.dart`).
  Rode `flutterfire configure` com o projeto real.
- **`google-services.json`** (Android) e **`GoogleService-Info.plist`**
  (iOS) — gerados pelo passo acima, específicos do seu projeto.
- **`.firebaserc`** — confirmei que está vazio/ausente neste checkout;
  `firebase use --add` depois de configurar o projeto.
- **Segredos das Functions** — `firebase functions:secrets:set
  ANTHROPIC_API_KEY BUNNY_STREAM_API_KEY BUNNY_TOKEN_KEY`. Confirmado: zero
  ocorrência dessas chaves no código Dart (`grep -r "sk-ant-" lib/` vazio).
- **SHA-1/SHA-256** cadastrados no Firebase para o Login Google no Android
  funcionar.
- **Domínio autorizado** no Firebase Auth para a versão Web.

---

## 5. Arquivos/configurações Android já prontos no `platform/`

Aplicados automaticamente por `tool/migrate_platforms.py` depois do
`flutter create` — não precisam de ação, só conferência:

- `compileSdk = 35`, `minSdk = 23`, `targetSdk = 35`
- Permissões: `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`,
  `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `CAMERA`, `READ_MEDIA_IMAGES`,
  `RECORD_AUDIO`
- **As três últimas (câmera, mídia, áudio) já estão documentadas no
  próprio manifesto como não-essenciais** — verifiquei de novo nesta
  revisão que nada no código Dart usa câmera ou microfone hoje
  (`image_picker` foi removido, teleconsulta está desativada), e o
  comentário existente já explica isso. Deixei como está: é decisão já
  tomada e ainda correta, não pendência nova.
- `google-services` plugin já referenciado no Gradle — só falta o
  `google-services.json` real (seção 4)

**Ainda dependem de você:**
- Keystore de release + `key.properties` (fora do Git)
- `applicationId` definitivo (hoje `app.pediatria360.pediatria360`, do
  `flutter create` sugerido — confirme se é o nome final)

---

## 6. Arquivos/configurações iOS já prontos no `platform/`

- `Podfile` e `Info.plist` com os ajustes já testados por
  `migrate_platforms.py` (não sobrescreve o que o `flutter create` gera,
  faz merge)

**Ainda dependem de você:**
- Bundle ID definitivo
- `GoogleService-Info.plist` real
- Certificado e provisioning profile de distribuição
- Textos de permissão no `Info.plist` (câmera/microfone) — mesma ressalva
  da seção 5: hoje não usados, mantidos documentados como tal

---

## 7. Segredos que NÃO podem ficar no código

Confirmado ausente do cliente Dart nesta revisão — `grep -r` vazio para:

- Chave da Anthropic (`sk-ant-...`)
- Chaves Bunny Stream

Confirmado: as três chaves só existem como referência de nome
(`firebase functions:secrets:set ...`), nunca como valor literal em
nenhum arquivo `.dart`.

---

## 8. O que ainda impede uma build de produção

Lista completa e categorizada em `PENDENCIAS_PRODUCAO.md`. Os itens que
bloqueiam especificamente a **build**, não o produto:

- Nenhuma linha compilada ainda (este documento existe para reduzir, não
  eliminar, a chance de erro na primeira vez)
- `firebase_options.dart` de exemplo
- Keystore de release Android
- Certificado/provisioning iOS

---

## O que esta revisão verificou de fato, sem Flutter

- `pubspec.yaml`: YAML válido, todo asset/pasta declarado existe no disco
- Import: 130 arquivos (`lib/` + `test/`), todo caminho relativo e todo
  import de pacote próprio (`package:pediatria360/...`) resolve para
  arquivo real (`tool/check_imports.py`) — estendido nesta rodada para
  cobrir `test/`, que usa só import de pacote e nunca tinha sido varrida
- Sintaxe/balanceamento: 139 arquivos
- Referência cruzada: 390 classes, nenhuma quebrada
- Rotas: 33 rotas no `GoRouter`, zero `path` ou `name` duplicado; toda
  constante `Routes.*` usada está declarada
- **Redirecionamento por perfil** (rodada seguinte a esta revisão original):
  `/admin` já era bloqueado para não-admin, mas `/pacientes` e `/agenda`
  não tinham a mesma proteção no roteador — corrigido, mesmo padrão do
  admin, também bloqueia admin da área clínica (consistente com a regra já
  estabelecida de que administração não tem acesso irrestrito a dado
  clínico)
- `late` fields: os dois arquivos com mais campos `late` (9 e 5) —
  inicialização incondicional confirmada em `initState`, sem `late`
  potencialmente lido antes de atribuído
- Cast `.data() as Tipo` sem null-safety visível: zero ocorrência
- `firestore.indexes.json`: JSON válido
- `functions/tsconfig.json`: `outDir` bate com `main` do `package.json`
- Imports das Functions: nenhum import nomeado órfão encontrado
  (varredura por texto, não pelo compilador TS real)
- Segurança, dependências não usadas, código morto, vazamento de
  controller, acessibilidade: sem achado novo

## O que esta revisão não pôde verificar

Tudo que exige o compilador de verdade — erro de tipo específico, warning
do `flutter_lints`, resultado real dos 228 + 50 testes, e qualquer coisa
que só aparece depois que `flutter pub get` resolve as dependências pela
primeira vez.
