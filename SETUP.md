# Colocando o Pediatria 360 no ar

Passo a passo até o app abrir no seu aparelho. Cada etapa tem uma forma de conferir se deu certo.

---

## 1. Gerar as pastas de plataforma ⚠️ obrigatório

**Este repositório não inclui `android/`, `ios/` e `web/` populados.** Elas são geradas pelo Flutter e dependem da sua versão instalada — versionar um scaffolding de outra versão causa erros de build difíceis de diagnosticar.

Na raiz do projeto:

```bash
flutter create --platforms=android,ios,web \
  --org app.pediatria360 \
  --project-name pediatria360 .
```

O comando **não sobrescreve** `lib/`, `test/`, `pubspec.yaml` nem `assets/`. Ele só cria o que falta.

**Confira:** `ls android ios web` deve mostrar arquivos.

Depois, aplique os ajustes de `platform/` automaticamente:

```bash
python3 tool/migrate_platforms.py
```

Isso substitui o `AndroidManifest.xml`, o `android/app/build.gradle.kts` e o
`web/index.html` pelas versões finais, e insere os fragmentos do
`Info.plist`, do `Podfile` e do `plugins {}` do Gradle raiz nos pontos
certos dos arquivos que o `flutter create` gerou — sem apagar o que o
comando já colocou lá (identificador do bundle, versão, storyboard etc.).

O script é seguro para repetir: cada inserção verifica se o conteúdo já
está presente antes de agir. Se algum arquivo tiver uma estrutura
inesperada (por exemplo, um `Podfile` de uma versão do Flutter que já traz
`post_install` próprio), ele **para e explica o que fazer manualmente**, em
vez de arriscar duplicar ou corromper o arquivo.

Depois de conferir que o build funciona, remova a pasta de origem:

```bash
python3 tool/migrate_platforms.py --clean
```

`--clean` só apaga `platform/` se todos os passos tiverem tido sucesso —
uma falha no meio interrompe antes de mexer em qualquer coisa.

---

## 2. Ajustes de plataforma — o que o script faz

`python3 tool/migrate_platforms.py` (passo anterior) já aplicou isto. A
tabela é só para quem quiser entender ou conferir manualmente:

| Arquivo em `platform/` | Como entra em `android/`, `ios/`, `web/` | Por que importa |
|---|---|---|
| `android/build.gradle.kts` | Inserido no bloco `plugins {}` (raiz ou `settings.gradle.kts`, o que existir) | Sem o plugin do Google Services, o `google-services.json` é ignorado |
| `android/app/build.gradle.kts` | Substitui o arquivo inteiro | `minSdk 23` (exigido pelo firebase_auth), multidex, desugaring |
| `android/app/src/main/AndroidManifest.xml` | Substitui o arquivo inteiro | Permissões, canal de notificação, deep links |
| `ios/Runner/Info.plist` | Chaves inseridas antes de `</dict></plist>` | Textos de permissão — genéricos fazem a App Store rejeitar |
| `ios/Podfile` | Linha de plataforma + `post_install` inseridos | iOS 13+ e macros do permission_handler |
| `web/index.html` | Substitui o arquivo inteiro | SDKs do Firebase e tela de carregamento |

Os três primeiros e o `index.html` **substituem** porque a versão em
`platform/` já é o arquivo final. `Info.plist` e `Podfile` recebem
**inserção**, porque o `flutter create` grava neles conteúdo que precisa
continuar lá (identificador do bundle, versão do app).

**Confira:** `flutter build apk --debug` compila sem erro.

---

## 3. Conectar o Firebase

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=SEU_PROJETO
```

Isso sobrescreve `lib/firebase_options.dart` (que vem com chaves inválidas de propósito) e posiciona `google-services.json` e `GoogleService-Info.plist`.

No console do Firebase, habilite:
- **Authentication** → provedores **E-mail/senha** e **Google**
- **Firestore**, **Storage**, **Functions**, **Messaging**, **Analytics**, **Crashlytics**, **Remote Config**

**Confira:** `DefaultFirebaseOptions.isPlaceholder` deve retornar `false`.

---

## 4. Publicar as regras ⚠️ antes de qualquer dado real

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

Sem isso o Firestore fica no modo padrão — aberto ou fechado, nenhum dos dois serve. As regras são a garantia real de isolamento; os filtros no app são conveniência de interface e um cliente modificado os ignora.

**Confira:** rode os testes das regras — eles provam o isolamento sem tocar em projeto real:

```bash
cd test/rules
npm install
npm test
```

São 82 casos: prontuário da criança inacessível a terceiros (inclusive médico e admin), profissional não se autoverifica, cliente não cria pedido nem forja resposta da IA, receita só para paciente e prescritor, arquivo de um usuário inacessível a outro no Storage, isolamento entre famílias em encounters/documentos/exames, concessão de acesso ao resumo de segurança da criança.

---

## 5. Publicar as Functions

```bash
cd functions
npm install

firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set BUNNY_STREAM_API_KEY
firebase functions:secrets:set BUNNY_TOKEN_KEY

npm run deploy
```

**Confira:** `firebase functions:list` mostra `aiChat`, `createOrder`, `awardXp` e as demais.

---

## 6. Popular com conteúdo inicial

O app abre em telas vazias enquanto o Firestore estiver vazio — é o comportamento correto, mas atrapalha o teste.

```bash
cd tool/seed
npm install firebase-admin
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node seed.js
```

Cria 3 artigos, 6 medalhas, 1 cupom e 2 produtos.

> Os artigos são **exemplos de estrutura**, em linguagem conservadora e sem posologia. Substitua por conteúdo revisado por pediatra e preencha `reviewedBy` — a tela sinaliza ao leitor quando esse campo está vazio.

---

## 7. Rodar

```bash
flutter pub get
flutter run
```

Com Bunny.net configurado:

```bash
flutter run \
  --dart-define=BUNNY_STREAM_LIBRARY_ID=123456 \
  --dart-define=BUNNY_CDN_HOSTNAME=vz-abc.b-cdn.net
```

---

## 8. Virar admin

O painel administrativo exige `role: "admin"`. Depois de criar sua conta pelo app, no console do Firestore:

```
users/{seu_uid}  →  role: "admin"
```

O campo é bloqueado para escrita pelo cliente nas regras — só pelo console ou por outra Function de admin.

---

## Quando algo falhar

| Sintoma | Causa provável |
|---|---|
| Trava no splash | `firebase_options.dart` ainda com chaves de exemplo |
| `PERMISSION_DENIED` em tudo | Regras não publicadas (passo 4) |
| Build Android falha em `minSdk` | Passo 2 não aplicado |
| `pod install` falha | iOS deployment target abaixo de 13 |
| Telas vazias mas sem erro | Firestore sem dados (passo 6) |
| IA responde erro | `ANTHROPIC_API_KEY` não definido |
| Vídeo não toca | `BUNNY_CDN_HOSTNAME` ausente no `--dart-define` |
| Web em branco | SDKs do Firebase fora do `index.html` |

---

## Verificação final

```bash
python3 tool/check_references.py   # referências cruzadas (roda sem SDK)
flutter analyze                    # não deve acusar erro
flutter test                       # 10 suítes Dart
cd test/rules && npm test          # 82 casos de segurança
cd functions && npx tsc --noEmit   # tipagem das Functions
```

O `check_references.py` é um verificador que escrevi porque não tive `flutter analyze` neste ambiente. Ele cruza símbolos entre arquivos e acusa referências que não existem em lugar nenhum: providers não declarados, constantes de `Routes` ausentes, parâmetros nomeados que o construtor não aceita, classes inexistentes.

**Ele não substitui o compilador** — não entende tipos, generics nem inferência. Mas cobre a classe de erro mais provável em código escrito sem compilar, e passa limpo em 293 classes, 23 enums e 85 providers.

**Não consegui rodar nenhum destes três durante o desenvolvimento** — o ambiente não tinha SDK do Flutter nem acesso à rede. Verifiquei imports, balanceamento sintático e conferi numericamente cada fórmula clínica e financeira, mas a validação do compilador é sua. Se algo acusar, o erro tende a ser pontual (um import, uma assinatura de API que mudou de versão).
