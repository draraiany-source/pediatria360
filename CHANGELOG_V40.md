# CHANGELOG_V40.md — Pediatria 360

## Contexto

Rodada de estabilização, sem novo módulo, sem nova tela, sem mudança de
arquitetura. Três focos: remover permissão sem uso real, fechar a lacuna
de teste do roteador (sinalizada por mim mesmo desde a v39), e consolidar
a documentação que se acumulou em rodadas anteriores.

## O que foi corrigido

### `npm test` e `npm run lint` das Functions não existiam

`functions/package.json` não tinha nenhum dos dois scripts, nem framework
de teste ou lint instalado — só `tsc`. `tool/validate_release.sh` e o CI
já chamavam os dois; teriam falhado com "Missing script" na primeira
execução real, escondido até esta rodada porque nada nunca tinha rodado
de verdade.

Configurado Jest (`ts-jest`, sobre o `tsconfig.json` já existente) e
ESLint (`typescript-eslint`, config recomendada, sem regra inventada).
`npm test` e `npm run lint` agora existem e fazem algo real. Adicionados
ao job de Functions do CI, que também nunca rodava nenhum dos dois.

### Lógica de agendamento extraída e testada — um bug real encontrado no processo

`bookAppointment` decidia dupla reserva e horário passado inline, dentro
de uma transação do Firestore — não testável sem emulador. Extraído para
`functions/src/booking.ts`: `hasActiveBookingConflict` e
`isPastAppointmentTime`, funções puras, sem Firestore.

Ao escrever os testes, tracei cada caso manualmente contra a implementação
antes de confiar em qualquer um dos dois — e achei uma inconsistência
real: o comentário dizia "status indefinido conta como bloqueio, por
segurança", mas o código fazia o oposto (`status !== undefined && ...`
descartava silenciosamente um status ausente, tratando-o como livre em
vez de ocupado). Corrigido antes de qualquer teste rodar, não depois.
Reverifiquei numericamente os 14 casos (10 de conflito + 4 de horário)
contra a versão corrigida antes de aceitar como certo.

### Permissões Android/iOS reduzidas ao necessário

`CAMERA`, `READ_MEDIA_IMAGES`, `RECORD_AUDIO` (Android) e as descrições de
uso correspondentes no iOS (`NSCameraUsageDescription`,
`NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription`,
`NSFaceIDUsageDescription`) removidas. Confirmado de novo, antes de
remover: zero uso real no código — `image_picker` já tinha sido removido
em rodada anterior, teleconsulta continua desativada por flag, e
`local_auth` nem está no `pubspec.yaml`. Reintroduzir junto com a
funcionalidade que precisar delas, não antes.

### Autorização de rota extraída para função pura e testada

O `redirect` do `GoRouter` decidia tudo inline, lendo `BuildContext` e
`ref` diretamente — impossível de testar sem simular o framework inteiro.
Extraído para `resolveRouteRedirect` em
`lib/core/router/route_authorization.dart`: mesma lógica, exatamente,
agora recebendo só valores simples (`AppUser?`, `String`, `bool`) e
devolvendo a decisão. O `GoRouter.redirect` virou uma casca fina que
coleta o estado e delega.

25 testes novos, cobrindo exatamente a matriz pedida — responsável não
acessa `/admin`/`/pacientes`/`/agenda`; profissional acessa as duas
últimas mas não a primeira; admin acessa `/admin` mas **não** ganha
acesso automático à área clínica só por ser admin — mais os casos de
manutenção, carregamento, onboarding e fluxo de tela pública que a função
já cobria e nunca tinham teste nenhum. Cada asserção foi conferida
manualmente contra a lógica real antes de ser escrita, não assumida.

### Documentação consolidada

14 documentos na raiz do projeto haviam se acumulado em rodadas
anteriores. Mantidos como atuais: `README.md`, `SETUP.md`,
`ANTES_DE_COMPILAR.md`, `BLOQUEADORES_PRODUCAO.md`,
`CHECKLIST_PUBLICACAO_FINAL.md`, `CHANGELOG_V40.md` (este). Os outros 8
(`AUDITORIA_FINAL.md`, `BLOQUEADORES_COMPILACAO.md`, `CHANGELOG_V35.md`,
`CHANGELOG_V40.md`, `CHECKLIST_PUBLICACAO.md`,
`LISTA_ARQUIVOS_ALTERADOS.md`, `PENDENCIAS_PRODUCAO.md`,
`PENDENCIAS_V37.md`, `RELATORIO_CONSOLIDADO.md`) ganharam aviso de
histórico no topo, apontando de volta para os atuais — não apagados,
porque registram decisão e contexto que ainda importa, só deixaram de ser
a fonte de verdade. `README.md` ganhou uma seção no topo mapeando qual
documento é qual.

## Arquivos modificados

| Arquivo | Mudança |
|---|---|
| `platform/android/app/src/main/AndroidManifest.xml` | 3 permissões removidas |
| `platform/ios/Runner/Info.plist` | 4 descrições de permissão removidas |
| `lib/core/router/app_router.dart` | Lógica de redirect delegada para função pura |
| `functions/src/commerce.ts` | Usa as funções extraídas em vez da lógica inline |
| `functions/package.json` | Scripts `lint`/`test` e devDependencies correspondentes |
| `functions/tsconfig.json` | Exclui `*.test.ts` da compilação de produção |
| `.github/workflows/ci.yml` | Job de Functions ganhou passo de lint e de teste |
| `README.md` | Seção de mapa de documentos adicionada |
| 8 documentos históricos | Aviso de histórico adicionado no topo |

## Arquivos criados

| Arquivo | Propósito |
|---|---|
| `lib/core/router/route_authorization.dart` | Política de autorização de rota, função pura |
| `test/route_authorization_test.dart` | 25 testes cobrindo a matriz de autorização |
| `functions/src/booking.ts` | Lógica pura de dupla reserva e horário passado |
| `functions/src/booking.test.ts` | 14 testes — primeiro teste real de Cloud Function do projeto |
| `functions/jest.config.js` | Configuração do Jest para as Functions |
| `functions/eslint.config.js` | Configuração mínima do ESLint (flat config, regra recomendada) |
| `CHANGELOG_V40.md` | Este arquivo |

## Testes

253 casos Dart (era 228) + 63 de regra — sem mudança nos de regra nesta
rodada. Os 25 novos Dart cobrem a decisão de autorização do roteador, não
só as constantes de rota.

**14 testes de Cloud Function, os primeiros do projeto** — `npm test`
nunca tinha rodado nada, porque não existia. Cobrem dupla reserva (10
casos) e horário passado (4 casos), incluindo o bug de `undefined` que a
própria escrita do teste revelou antes de qualquer execução real.

## Pendências reais (sem mudança desde a v39)

Ver `BLOQUEADORES_PRODUCAO.md` — nada resolvido nem descoberto de novo
nesta rodada nessa frente.

## Não afirmado nesta versão

- Não digo "compilou" — nenhuma linha rodou em Flutter real
- Não digo "100% pronto"
- Não digo "todos os testes passaram" — os 253 + 63 foram escritos e as
  asserções verificadas manualmente; execução real continua pendente
- Nenhum dado clínico inventado
- Nenhuma integração falsa
- Nenhuma funcionalidade nova além do pedido desta rodada
