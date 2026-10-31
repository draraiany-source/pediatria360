# Preparação para publicação — 29/10/2026

Versão `pediatria360 1.0.0+1`. Ponto de partida: branch `feat/fluxo-atendimento`
em `1159b1c` (4 commits locais nunca enviados: Etapas 1, 2, 3 e auditoria tela
por tela). Ambiente: Windows 10, Flutter 3.44.4, Node 24, Firebase CLI 15.28.1.
Nada foi publicado em produção e nenhum dado real foi usado.

## 1. Estado encontrado e preservação

| Item | Situação |
| --- | --- |
| Repositório | `github.com/draraiany-source/pediatria360`, duas worktrees: `p360-demo` (`feat/fluxo-atendimento`) e `pediatria360/pediatria360` (`handoff/final-20260926`) |
| Fase 2 (responsáveis, permissões, agenda) | Já em `origin/main` desde `a580fd6`; o achado de 25/09 estava desatualizado |
| 33 arquivos "modificados" em `p360-demo` | Só fim de linha (LF/CRLF); conteúdo idêntico ao commit |
| Arquivo novo `lib/shared/scheduling/schedule_config.dart` | Rascunho incompleto (não compila: `VisitType.specialty` inexistente), sem uso. Movido para `tools/wip/schedule_config.dart.wip` e guardado no backup |
| Worktree `handoff/final-20260926` | 68 arquivos alterados (730+/2572−), aparenta estado antigo copiado por cima; preservado sem mesclar |
| `index.lock` de 25/10 na worktree antiga | Obsoleto; renomeado para `index.lock.stale-20261025` |

Backups criados antes de qualquer alteração (enviados ao GitHub):

- `backup/wip-fluxo-atendimento-20261029` → `1225de3` (alterações locais + arquivos não rastreados)
- `backup/wip-handoff-worktree-20261029` → `e2abfc3` (alterações locais da worktree antiga)

## 2. Erro "Sua sessão não tem permissão para estes dados"

**Causa encontrada no código.** A mensagem vinha de `clinicalLoadErrorMessage`
(`lib/core/utils/clinical_access.dart`), que trocava **qualquer** recusa pelo
mesmo texto genérico:

1. Em `flutter run` (debug) ou build com `SKIP_AUTH=true`, o app entra como a
   convidada "Carolina Souza" (perfil profissional, **sem login no Firebase**).
   Pacientes e Agenda recusam dados reais para essa sessão — comportamento
   correto —, mas a tela dizia "sua sessão não tem permissão", sem explicar
   que faltava entrar com uma conta.
2. No Paciente 360, o motivo "o responsável ainda não autorizou o acesso…"
   (de `encounter_repository.dart`) também era substituído pelo genérico.

**Correção (sem abrir acesso).** A recusa do modo demonstração recebe código
próprio e diz que falta login; recusas geradas pelo app mostram o próprio
motivo; só a recusa real das regras recebe a orientação (conta certa, registro
verificado, vínculo com a clínica ativo, sair e entrar de novo).

**Regras conferidas com as consultas exatas das telas** (novo
`test/rules/telas_pacientes_agenda.test.js`, 12/12 no emulador):

- profissional autenticado lista os próprios atendimentos e a própria agenda;
- profissional de outra clínica, recepção (prontuário) e sessão sem login são recusados;
- recepção e enfermagem com vínculo ativo carregam a agenda da clínica;
- financeiro (fora do papel) e gestão de outra clínica são recusados;
- vínculo só no perfil do usuário, sem o lado da clínica, é recusado;
- vínculo desativado pela clínica é recusado.

**Risco que permanece.** O app considera o vínculo ativo lendo só
`users/{uid}/clinic_memberships`; as regras exigem também
`clinics/{id}/memberships/{uid}` ativo. Se os dois lados divergirem (dado
antigo, gravação manual no Console), a recepção vê "o servidor recusou o
acesso". Os vínculos são gravados pelas Functions `addClinicMember` e
`setClinicMemberStatus`, que ainda não estão publicadas no Firebase.

**Homologação publicada.** O canal `homologacao-auditoria` (publicado em
29/10 17:28, expira em 05/11) usa o Firebase real `pediatria360-app`, e não
emuladores. As regras e Functions das Etapas 1–3 nunca foram publicadas
nesse projeto. Não consegui ler as regras publicadas (acesso por credencial
bloqueado nesta sessão); fica para conferir com você.

## 3. Publicação: o que foi corrigido no código

| Achado | Conferido | Correção |
| --- | --- | --- |
| Release Android assinado com chave de debug | Sim (`build.gradle.kts`) | Assina com `android/key.properties`; sem ele, `assembleRelease`/`bundleRelease` param com erro, exceto APK interno com `ALLOW_DEBUG_SIGNED_RELEASE=true` |
| `google-services.json` ausente (build Android falharia) | Sim | Copiado localmente da configuração oficial do app `app.pediatria360`; ignorado pelo Git |
| Bundle iOS `app.pediatria360.pediatria360` ≠ app iOS do Firebase `app.pediatria360` | Sim | Alinhado em `project.pbxproj` |
| `Info.plist` com 3 chaves duplicadas | Sim | Duplicatas removidas |
| Termos, Privacidade e suporte com domínio `pediatria360.app` não confirmado | Sim | Passam a vir do build; vazio = "documento ainda não publicado" |
| Controlador e DPO sem campo | Sim | `DATA_CONTROLLER_NAME`, `DATA_CONTROLLER_CNPJ`, `DPO_EMAIL` |
| Build de produção dependia de lembrar `--dart-define=ENV=prod` | Sim | `tools/release/build_prod.ps1`: sempre `ENV=prod` e `FORCE_REAL_AUTH=true`; recusa build de loja sem dados legais |
| `ENV=prod` com emuladores | Sim | A inicialização recusa a combinação |
| Comentário dizia que as curvas da OMS eram "aproximações" | Sim, desatualizado | O arquivo atual traz LMS oficiais da OMS (repositório `WorldHealthOrganization/anthro`, commit fixado); comentário corrigido. Conferência clínica continua pendente |
| DevMode em produção | Já corrigido antes | `DevMode.isEnabled` é `false` com `ENV=prod` (teste `dev_mode_test.dart`) |
| Vídeo, pagamento, ICP-Brasil, TISS e voz | Conferido | Continuam desligados por flag em `AppConfig`; nada foi marcado como concluído |
| App Check | Conferido | Cliente pronto e desligado; depende do registro no Console |

## 4. Testes executados (logs em `logs/`)

| Comando | Resultado |
| --- | --- |
| `flutter analyze` antes das correções | 143 itens: **1 erro** (`schedule_config.dart`), 0 avisos, 142 informativos |
| `flutter analyze` depois | **0 erros, 0 avisos**, 140 informativos |
| Functions `tsc --noEmit` | sem erros |
| Functions Jest (12 suítes) | **104/104** |
| Regras Firestore + Storage no emulador (5 suítes existentes) | **346/346** |
| Regras: consultas de Pacientes e Agenda (nova suíte) | **12/12** |
| `flutter test -j 2` (suíte completa, `05_flutter_test_completo.txt`) | **890 aprovados, 1 falha** — o teste exigia URL fixa de Termos (a inventada). Teste corrigido para a nova regra e reexecutado: 13/13 nos arquivos afetados (`05b_flutter_test_reexecucao.txt`). A suíte completa não foi repetida depois dessa correção |
| Build web `ENV=prod` (`build_prod.ps1 -Target web -Homologacao`) | **gerado**, `build/web` |
| Build APK `ENV=prod` (assinatura de debug, só interno) | **falhou** após 44 min: "Gradle build daemon disappeared unexpectedly". A máquina tem 7,9 GB de RAM (2,2 GB livres) e o projeto pede 4 GB de heap ao Gradle — mesmo bloqueio de 28/09. Nova tentativa com memória reduzida exigiria alterar `~/.gradle/gradle.properties` e não foi feita. Log: `09_build_apk_prod.txt` |
| Build AAB para a Play Store | **não executado**: falta a chave de upload |
| Build iOS / IPA | **não executado**: exige Mac com Xcode |

### Não executado nesta rodada (sem aprovação declarada)

- Fluxos ponta a ponta pela interface (família, profissional, recepção,
  gestão, multidisciplinar): não repetidos hoje. A última evidência é a
  auditoria tela por tela de 28/10 (`docs/homologacao/auditoria-telas`),
  feita nos emuladores, com as pendências registradas lá.
- Teste em aparelho Android ou iPhone: nenhum aparelho conectado.
- Envio real por WhatsApp, pagamento e IA: sem credenciais e sem autorização.
- Publicação de regras, índices e Functions: não autorizada.

## 5. Pedidos da etapa de auditoria completa que não foram feitos agora

Redesenho premium de todas as telas, painel com todos os indicadores pedidos,
importação/exportação de pacientes, agenda com feriados e lista de espera na
interface, integração real com WhatsApp, central de documentos com assinatura,
novas calculadoras, biblioteca com importação de PDF e Central de IA completa.
Algumas dessas partes já existem no código desde a Etapa 3 (testadas no
emulador, ver `fluxo-atendimento/PROGRESSO.md`); as demais estão ausentes.
Nada disso foi declarado pronto nesta rodada.

## 6. Classificação por módulo (evidência até 29/10/2026)

Legenda: FUNCIONAL E TESTADO = teste automatizado ou de interface registrado;
IMPLEMENTADO, MAS NÃO TESTADO = código existe sem evidência de teste nesta
linha; PARCIAL; APENAS VISUAL; AUSENTE; BLOQUEADO = depende de credencial,
conta ou decisão externa.

| Módulo | Classificação | Evidência / observação |
| --- | --- | --- |
| Login e sessão (Firebase Auth) | FUNCIONAL E TESTADO | Testes Flutter; auditoria de telas 28/10 (emulador) |
| Permissões por perfil e isolamento entre clínicas (regras) | FUNCIONAL E TESTADO | 346 + 12 testes de regras no emulador; ainda não publicadas no Firebase |
| Isolamento por unidade (`unitId`) | PARCIAL | Só na camada do app, não nas regras |
| Cadastro de crianças e responsáveis | FUNCIONAL E TESTADO | Fase 2 + Etapa 2; testes de regras e Flutter |
| Autorização do responsável ao profissional | FUNCIONAL E TESTADO | Etapas 1–2; ponta a ponta no emulador (76/76, 25/10) |
| Pacientes (lista do profissional) | FUNCIONAL E TESTADO | Consulta nas regras 12/12; tela na auditoria 28/10 |
| Agenda (dia/semana/mês, reserva, remarcação, lista de espera) | PARCIAL | Servidor testado no emulador (Etapa 3); agendar paciente já da clínica e agendamento pela família sem tela |
| Prontuário (rascunho, assinatura por hash) | PARCIAL | Regras testadas; sem ICP-Brasil; fluxo pela interface não exercitado em 28/10 |
| Documentos/receituário | PARCIAL | Geração existe; assinatura legal ausente |
| Vacinas | PARCIAL | Calendário sem data de versão; validação clínica pendente |
| Crescimento (OMS) | PARCIAL | LMS oficiais e fórmula testada; conferência clínica pendente |
| Calculadoras | IMPLEMENTADO, MAS NÃO TESTADO | Sem reteste nesta rodada; exigem conferência profissional |
| Cursos e biblioteca | PARCIAL | Conteúdo depende de Bunny (sem credenciais) |
| IA (chat, Central de IA) | BLOQUEADO | Indicadores determinísticos testados no emulador; chamadas reais sem `ANTHROPIC_API_KEY` |
| Financeiro | PARCIAL | Operações do servidor testadas no emulador; lançamentos antigos ainda no cliente |
| Mensagens / WhatsApp | BLOQUEADO | Integração preparada; sem credenciais Meta |
| Pagamento | BLOQUEADO | Desligado por flag; sem provedor |
| Vídeo-consulta | BLOQUEADO | Desligado por flag |
| Prontuário por voz | BLOQUEADO | Desligado por flag |
| TISS / ICP-Brasil | AUSENTE | Desligados por flag; sem integração |
| Termos, Privacidade, controlador, DPO | BLOQUEADO | Campos prontos; valores dependem da titular |
| App Check | BLOQUEADO | Cliente pronto; registro no Console pendente |
| Redesenho premium de todas as telas | AUSENTE | Não feito nesta rodada |
| Build web ENV=prod | FUNCIONAL E TESTADO | Gerado em 29/10 (`build/web`) |
| Build Android | BLOQUEADO | APK falhou por memória; AAB sem chave de upload |
| Build iOS | BLOQUEADO | Exige Mac com Xcode |

## 7. Recomendação

Não publicar nas lojas nem usar com pacientes reais. Próximos passos, em
ordem: revisar e mesclar o PR; publicar regras, índices e Functions num
projeto de homologação separado (com autorização); repetir os fluxos por
perfil pela interface nesse projeto; fornecer os itens de
`PUBLICACAO_PENDENCIAS_USUARIO.md`; gerar o AAB numa máquina com 16 GB de RAM
ou mais (ou com a memória do Gradle reduzida); validação clínica de OMS, PNI e
calculadoras.