# Pediatria 360

Plataforma de acompanhamento pediátrico para **pais/responsáveis**, **profissionais de saúde** e **equipes clínicas**. Flutter + Firebase, offline-first, Android / iOS / Web / Tablet.

---

## Documentos deste projeto

Vários documentos se acumularam ao longo de muitas rodadas de auditoria.
Estes cinco são os atuais — os demais na raiz do projeto têm um aviso de
"histórico" no topo e apontam de volta para estes:

- **`README.md`** (este arquivo) — visão geral e estado dos módulos
- **`SETUP.md`** — passo a passo de configuração
- **`ANTES_DE_COMPILAR.md`** — o que verificar e rodar antes da primeira
  compilação real com Flutter
- **`BLOQUEADORES_PRODUCAO.md`** — o que falta para produção, categorizado
  (Firebase real, dados legais, OMS, PNI, CID, signing, telemedicina,
  pagamentos, ICP-Brasil)
- **`CHECKLIST_PUBLICACAO_FINAL.md`** — checklist de publicação nas lojas
- **`CHANGELOG_V40.md`** (ou o mais recente) — o que mudou, versão a versão

---

## Estado atual do projeto

| Módulo | Escopo | Situação |
|---|---|---|
| 1 | Fundação: tema, design system, erros, cache, SQLite, serviços Firebase, assets | ✅ concluído |
| 2 | Autenticação, entidades, roteador com guardas, sincronização offline, shell responsivo | ✅ concluído |
| 3 | Crianças, crescimento (curvas OMS), vacinas (PNI) | ✅ concluído |
| 4 | Biblioteca médica, IA pediátrica, calculadoras, Cloud Functions | ✅ concluído |
| 5 | Bunny.net, cursos, player com retomada | ✅ concluído |
| 6 | Marketplace, checkout, telemedicina | 🔶 parcial |
| 7 | Rules, índices, gamificação, painel admin | ✅ concluído |

**Pendências conhecidas** (documentadas no código, não escondidas):
- **Gateway de pagamento** não integrado. `createOrder` cria o pedido e baixa o estoque em transação; falta plugar Stripe/Mercado Pago/Pagar.me e o webhook que muda o status para `paid`. O status **nunca** deve ser alterado pelo cliente.
- **Sala de vídeo** não integrada. `joinConsultation` valida permissão e janela de horário, depois lança `unimplemented` com instruções. Videoconferência médica envolve consentimento de gravação, retenção e conformidade com LGPD e resoluções do CFM — é um produto à parte, e a escolha do provedor cabe a quem conhece os requisitos regulatórios.
- **Editor de cursos e produtos** ainda pelo console do Firebase. Artigos e protocolos já têm editor completo, com histórico de versões, comparação entre versões e restauração — publicar posologia errada é risco, não bug, então o caminho de volta nasceu junto.

**O que já funciona de ponta a ponta:** abrir o app → apresentação → criar conta ou entrar (e-mail/senha ou Google) → definir perfil → cadastrar uma criança → registrar peso/altura e ver a curva plotada contra a referência da OMS com percentil e classificação → acompanhar o calendário vacinal do PNI, marcando doses com data, lote e local → tudo funcionando **offline**, com a fila de envio visível.

---

## ⚠️ Dados clínicos: leia antes de publicar

Duas fontes de dados neste projeto precisam de conferência antes de qualquer uso real:

### 1. Tabela de referência da OMS (`assets/data/who_reference.json`)

Os valores que acompanham o repositório são **aproximações de desenvolvimento**, geradas por `tool/generate_who_reference.py`. Eles fazem o app funcionar e permitem testar a matemática, mas **não são as tabelas oficiais**.

Antes de publicar, baixe os arquivos LMS oficiais em [who.int/tools/child-growth-standards](https://www.who.int/tools/child-growth-standards/standards) e substitua o conteúdo do JSON. O formato já é o mesmo (`indicador → sexo → lista de {mes, L, M, S}`) — **nenhuma linha de Dart precisa mudar**.

A **matemática** (`WhoReference.zScore`, `valueForZ`, `percentileFromZ`) segue a fórmula publicada pela OMS e está coberta por 13 testes, incluindo round-trip z→valor→z e conferência dos percentis contra a distribuição normal.

### 2. Calendário do PNI (`lib/features/vaccines/domain/pni_calendar.dart`)

O Calendário Nacional de Vacinação é revisado periodicamente. Confira a versão vigente em [gov.br/saude/vacinacao/calendario](https://www.gov.br/saude/pt-br/vacinacao/calendario) e ajuste a lista se necessário. Ela é a fonte única: mudar ali atualiza a tela, os lembretes e o cálculo de atraso de uma vez.

### 3. O que deliberadamente **não** existe: banco de doses

Não há tabela de mg/kg de medicamentos no código. Uma posologia escrita de memória é o tipo de erro que machuca criança — a diferença entre 10 e 100 mg/kg de paracetamol é a diferença entre analgesia e falência hepática.

O cálculo de dose existe (`DoseCalculator`), mas é um **motor genérico**: recebe mg/kg, teto e concentração de um protocolo cadastrado no Firestore por um profissional identificado, e faz a aritmética. O app calcula; quem responde pela posologia é quem publicou o protocolo. Seções de posologia só aparecem para usuários com registro profissional **verificado**.

As calculadoras que existem são fórmulas publicadas e estáveis — Holliday-Segar, Mosteller, IMC, idade corrigida, APLS — cobertas por 23 testes.

---

## ⚠️ Antes de tudo: gere as pastas de plataforma

Este repositório **não inclui `android/`, `ios/` e `web/` populados** — elas dependem da sua versão do Flutter. Na raiz:

```bash
flutter create --platforms=android,ios,web --org app.pediatria360 --project-name pediatria360 .
```

Depois aplique os ajustes de `platform/` (minSdk, permissões, SDKs do Firebase na web). **O passo a passo completo está em [SETUP.md](SETUP.md).**

---

## Requisitos

- **Flutter 3.32 ou superior** (o tema usa `CardThemeData`, `TabBarThemeData` e `DialogThemeData`, introduzidos nessa faixa)
- Dart 3.8+
- Um projeto Firebase com Authentication, Firestore, Storage, Functions, Messaging, Analytics, Crashlytics e Remote Config habilitados

---

## Configuração

### 1. Dependências

```bash
flutter pub get
```

### 2. Firebase

O arquivo `lib/firebase_options.dart` vem com **chaves de exemplo propositalmente inválidas**. Substitua-o com a CLI oficial:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=SEU_PROJETO
```

O comando gera o `firebase_options.dart` real e coloca `google-services.json` (Android) e `GoogleService-Info.plist` (iOS) nos lugares certos. **Nenhuma linha de código precisa mudar.**

No console do Firebase, habilite os provedores de login **E-mail/senha** e **Google**.

### 3. Executar

```bash
flutter run
```

Com chaves do Bunny.net e ambiente de produção:

```bash
flutter run \
  --dart-define=ENV=prod \
  --dart-define=BUNNY_STREAM_LIBRARY_ID=123456 \
  --dart-define=BUNNY_CDN_HOSTNAME=vz-abc.b-cdn.net \
  --dart-define=BUNNY_STORAGE_ZONE=p360 \
  --dart-define=BUNNY_STORAGE_HOSTNAME=p360.b-cdn.net
```

Com emuladores locais:

```bash
firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

### 4. Regras e índices

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

**Faça isso antes de qualquer teste com dados reais.** Sem as regras publicadas, o Firestore fica no modo padrão — ou totalmente aberto, ou totalmente fechado. As regras em `firestore.rules` são a garantia real de isolamento: os filtros no app são conveniência de interface, e um cliente modificado os ignora.

### 5. Bunny.net

```bash
firebase functions:secrets:set BUNNY_STREAM_API_KEY
firebase functions:secrets:set BUNNY_TOKEN_KEY      # Token Authentication da pull zone
firebase functions:config:set bunny.library_id=123456 bunny.cdn_hostname=vz-abc.b-cdn.net
```

No painel do Bunny, aponte o webhook da biblioteca para a função `bunnyWebhook` — assim o app sabe quando um vídeo terminou de processar sem ficar consultando.

### 6. Cloud Functions

```bash
cd functions
npm install
firebase functions:secrets:set ANTHROPIC_API_KEY   # cole a chave quando pedir
npm run deploy
```

A chave da IA fica no Secret Manager e **nunca** entra no aplicativo. Ver "Por que tudo passa por Cloud Function" abaixo.

### 7. Testes

```bash
flutter test                 # 9 suítes: lógica clínica, comércio, gamificação
cd test/rules && npm test    # 82 casos de segurança, com emulador
```

Os testes de regras provam o que o parágrafo de segurança abaixo afirma: que o prontuário de uma criança é inacessível a terceiros — incluindo médico verificado e administrador.

---

## Arquitetura

Clean Architecture por feature, três camadas:

```
lib/
  core/            infraestrutura transversal
    config/        AppConfig, FirestorePaths, AppAssets
    error/         Failure (domínio) · Exception (dados) · ErrorMapper
    providers/     providers Riverpod de infraestrutura
    responsive/    breakpoints e layouts adaptativos
    router/        GoRouter + guardas
    services/      Firebase, cache, SQLite, sync, notificações
    theme/         cores, tipografia, tokens, ThemeData
    usecase/       contratos UseCase e paginação
    utils/         Result, validadores, formatadores
    widgets/       design system
  features/
    <feature>/
      domain/      entities · repositories (contratos) · usecases
      data/        datasources · models (mapeadores) · repositories (impl)
      presentation/ providers · screens · widgets
  shared/          entidades e mapeadores usados por várias features
```

### Decisões que valem explicar

**`Result<T>` em vez de `dartz`/`fpdart`.** Sealed class nativa: o compilador força tratar sucesso e falha no `switch`, sem trazer uma dependência inteira de programação funcional.

**Nenhuma tela conhece `FirebaseException`.** Data sources lançam exceções técnicas; repositórios chamam `guard()`, que passa tudo pelo `ErrorMapper` e devolve `Failure` com mensagem pronta em pt-BR.

**Hive e SQLite têm papéis distintos.** Hive (`CacheService`) é cache descartável de leitura, com TTL por entrada — feed, artigos, catálogos. SQLite (`LocalDatabase`) guarda dado do usuário que precisa sobreviver e ser consultado (crescimento, vacinas) e a **outbox** de escritas pendentes, que exige transação e ordem garantida. Na Web, onde `sqflite` não existe, o app opera com Hive + persistência nativa do Firestore.

**Por que uma outbox própria, se o Firestore já tem fila offline?** A fila do SDK é opaca: não dá para mostrar ao usuário quantas alterações faltam, nem reordenar, nem descartar um item envenenado. Para dado de saúde — *"registrei a vacina e não sei se salvou"* — essa visibilidade é requisito, não luxo. Conflito resolve por última escrita vence; funciona porque cada registro tem um dono único.

**Idade corrigida para prematuros — mas só onde é correto.** `Child.clinicalAgeInMonths` desconta as semanas que faltaram para as 40, até os 24 meses. É essa idade que alimenta as **curvas de crescimento**: usar a cronológica plotaria um bebê de 32 semanas fora do percentil sem motivo clínico.

O **calendário vacinal faz o oposto** e segue a idade cronológica. Vacinar pela idade corrigida atrasaria a proteção justamente em quem tem mais risco de infecção grave. Os dois comportamentos estão explicitados no código e sinalizados na tela para o responsável.

**Escrita local primeiro, sempre.** Salvar uma medição grava no SQLite com `dirty = 1`, enfileira na outbox e retorna sucesso imediatamente. A tela atualiza na hora; o envio acontece quando houver rede. O usuário nunca espera o servidor para ver o próprio dado. Snapshots do Firestore sobrescrevem a tabela local **exceto** nas linhas `dirty` — alteração não enviada não pode ser perdida por um snapshot que ainda não a contém.

**Sem `build_runner`.** Modelos e mapeadores escritos à mão. `flutter pub get` e o projeto compila, sem passo de geração de código.

**A IA roda inteiramente no servidor.** A chave do provedor nunca chega ao app — extrair uma chave embutida num APK publicado leva minutos. Além disso, o servidor é o único lugar onde cota por usuário é confiável, onde o prompt de sistema (com as regras de segurança clínica) é inviolável, e onde dá para injetar os protocolos revisados como contexto.

**Detecção de sinais de alarme antes da resposta.** A Cloud Function varre a pergunta por padrões de emergência — cianose, convulsão, engasgo, febre em lactente jovem, rigidez de nuca, sinais de desconforto respiratório — e prefixa a resposta com orientação de procurar atendimento. Um pai que pergunta sobre "bebê roxo" às 3h não pode receber três parágrafos educativos primeiro. A lista é propositalmente ampla: um falso positivo custa um aviso a mais; um falso negativo custa tempo numa emergência.

**A chave do Bunny também não entra no app.** Ela permite apagar a biblioteca inteira de vídeos. O app monta URLs públicas de reprodução (concatenação de hostname e GUID); criar vídeo, assinar upload e assinar reprodução de conteúdo pago passam por Cloud Function. O upload dos bytes vai direto do app para o Bunny — passar 500 MB por uma Function seria caro e lento.

**Retomada de posição a cada 10 segundos, não a cada frame.** Gravar continuamente queimaria a cota de escrita do Firestore sem ganho nenhum. A aula é marcada como concluída aos 92%: créditos finais fazem quase ninguém chegar aos 100%, e exigir isso deixaria cursos eternamente "quase completos".

**Cursos pagos aparecem no catálogo.** Esconder o que existe impede a pessoa de saber o que ganharia assinando. O bloqueio acontece na reprodução — e a primeira aula fica aberta como amostra, porque é o que converte.

**O app nunca envia quanto o pedido custa.** Ele envia ids e quantidades; a Function `createOrder` lê o preço de cada produto no Firestore, soma, aplica o cupom e devolve o total. Aceitar o valor calculado no cliente é o erro clássico de e-commerce: basta interceptar a requisição e comprar por um centavo. A baixa de estoque acontece na mesma transação, senão dois pedidos simultâneos vendem o último item duas vezes.

**Dinheiro em centavos, como inteiro.** `0.1 + 0.2` não dá `0.3` em `double`; num carrinho de dez itens o erro aparece no total.

**Cupons não são legíveis pelo cliente.** Listar a collection revelaria todos os códigos ativos. A validação roda no servidor.

**Toda publicação de conteúdo grava um instantâneo.** O snapshot e a atualização do documento acontecem na mesma transação: se fossem duas escritas, uma falha entre elas deixaria conteúdo no ar sem registro do que havia antes — exatamente quando o histórico seria necessário. Restaurar cria uma versão *nova* com o conteúdo antigo, em vez de apagar o histórico; o caminho de volta também precisa ser auditável.

**A Function recusa publicar protocolo sem sinais de alarme** e recusa posologia em conteúdo que não seja restrito a profissionais. Não é validação de formulário: é a regra clínica virando código.

**XP só é concedido pelo servidor.** Se o cliente pudesse escrever `xp`, liderar o ranking seria questão de alterar um número. Há teto diário por ação — sem ele, abrir e fechar um artigo cem vezes renderia 500 XP — e uma mesma referência não pontua duas vezes.

**A sequência de dias tolera uma falta por semana.** Um app de saúde infantil não pode punir quem passou a noite no pronto-socorro e esqueceu de abrir o aplicativo. Streak agressiva gera ansiedade, e ansiedade é o que menos falta na vida de quem cuida de criança doente. A tolerância é explicada na tela, não escondida.

**O ranking mostra só primeiro nome e inicial do sobrenome.** É uma lista pública dentro de um app de saúde — nome completo e e-mail não entram. É recalculado uma vez por dia, não sob demanda.

**Verificação de registro profissional é manual.** É o gate que libera posologias e telemedicina. Validar CRM automaticamente exigiria integração com o CFM, e um falso positivo dá acesso a conteúdo de prescrição a quem não deveria tê-lo. Toda decisão fica no `audit_log`.

**Exclusão de conta apaga em cascata.** `onUserDeleted` remove crianças, medições, vacinas e conversas com a IA. Sem isso, sobraria dado de saúde de menor sem dono — o que a LGPD não perdoa.

**Busca sem Algolia.** O Firestore não tem busca textual. Os termos normalizados (minúsculo, sem acento) são gerados na publicação por uma Cloud Function e consultados com `array-contains-any`. Resolve bem o caso real — buscar "febre", "bronquiolite" — sem manter um serviço de busca para um catálogo de algumas centenas de documentos.

**As duas formas da regra de Holliday-Segar são calculadas separadamente.** A regra 4-2-1 mL/kg/h é o *arredondamento* da 100-50-20 mL/kg/dia: para 10 kg dá 40 vs 41,7 mL/h. Derivar uma da outra faria o app contradizer o número que o profissional espera ver, então mostramos as duas e explicamos a diferença.

### Design

Paleta própria: **petróleo** (autoridade clínica) + **framboesa/mel** (calor infantil). O azul é reservado exclusivamente a dado clínico — curva de crescimento e sinais vitais nunca competem com a marca.

Três faces tipográficas com função distinta: **Fraunces** nos títulos (serifa com curvas quase manuscritas, tom humano), **Inter** no texto (legibilidade em posologias, onde ler errado tem consequência), **JetBrains Mono** nos números (tabular: doses e percentis alinham coluna a coluna).

Glassmorphism é usado só em camadas flutuantes (cartão de status, navegação). Texto clínico longo sempre em fundo opaco.

### Responsividade

| Largura | Navegação |
|---|---|
| < 600 | barra inferior (alcance do polegar) |
| 600–1279 | rail lateral (usa a largura sem roubar altura) |
| ≥ 1280 | sidebar com rótulos + largura de leitura limitada |

---

## Segurança e privacidade

- Chaves de API nunca no repositório: tudo via `--dart-define`.
- `google-services.json`, `GoogleService-Info.plist` e `.env` estão no `.gitignore`.
- Campos controlados pelo servidor (`plan`, `xp`, `professionalVerified`) não são enviados pelo cliente — serão gravados só por Cloud Functions, com as rules bloqueando escrita direta (Módulo 7).
- Logout apaga cache e banco local: dado clínico de uma família não pode sobrar em celular compartilhado.
- Crashlytics recebe ids, códigos e stack traces. **Nunca dado de prontuário.**
- Registro profissional (CRM/COREN) passa por conferência manual antes de liberar conteúdo de prescrição.

---

## Aviso clínico

O Pediatria 360 é ferramenta de **apoio e educação**. Não faz diagnóstico e não substitui avaliação de um pediatra. O texto do aviso da IA vem do Remote Config (`ai_disclaimer`) e pode ser ajustado sem publicar versão nova.
