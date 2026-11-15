# Pediatria360 — Auditoria tela por tela e correção dos fluxos

Data: 28/10/2026 · Branch `feat/fluxo-atendimento` · base `99715ae` (Etapa 3)

> Este relatório **não** declara o aplicativo pronto para publicação nem para
> uso com pacientes reais. Tudo foi feito em ambiente isolado, com dados
> fictícios, sem mensagens, cobranças, migrações ou deploy.

## 1. Como a auditoria foi feita

- **Ambiente isolado:** emuladores Firebase (Auth, Firestore, Functions,
  Storage) com projeto `demo-pediatria360`; build web do próprio app apontando
  para os emuladores, com login real (`FORCE_REAL_AUTH=true`).
- **Dados fictícios** (`tools/homologacao/seed_auditoria.js`): 2 famílias
  (Ana — Luna e Theo; Bruno — Mia), Dra. Carla (médica da clínica), Dr. Diego
  (verificado, fora da clínica), Eva (recepção), Fábio (financeiro), Gina e
  Hugo (gestão), clínica `clinica-auditoria`, 2 consultas e autorizações por
  escopo.
- **Interface:** navegador Chrome automatizado (Puppeteer) clicando, digitando
  e lendo a árvore de acessibilidade do Flutter; capturas em
  `evidencias/`. Cada perfil foi logado com conta própria.
- **Legenda de verificação**
  - **[UI]** Verificado pela interface (navegador, conta real no emulador).
  - **[TESTE]** Verificado apenas por teste automatizado.
  - **[CÓDIGO]** Revisado apenas no código.
  - **[BLOQUEADO]** Não verificado ou bloqueado (motivo indicado).

## 2. Matriz de telas

A matriz completa (126 telas, com rota, perfil, origem, ações, dados lidos e
gravados, destinos, saída e estado) está em
[`INVENTARIO.md`](INVENTARIO.md). Situação depois desta etapa, nas telas
exercitadas pela interface:

| Tela | Rota | Perfil | Antes | Depois | Verificação |
| --- | --- | --- | --- | --- | --- |
| Login | `/login` | todos | funcional | funcional | [UI] |
| Início da família | `/inicio` | família | funcional | funcional | [UI] |
| Lista de crianças | `/criancas` | família | **com erro** (vazia na web) | funcional | [UI] |
| Detalhe da criança | `/criancas/:id` | família | **com erro** | funcional (também após recarregar) | [UI] |
| Nova criança | `/criancas/nova` | família | parcial (saía sem avisar) | funcional pelo botão do app | [UI] |
| Profissionais autorizados | detalhe › Profissionais autorizados | família | funcional | funcional (conceder e revogar) | [UI] |
| Pré-consulta | `/pre-consulta/:id` | família | **com erro** (estado de outra consulta) | funcional | [UI] |
| Consultas da família | `/telemedicina` | família | parcial | parcial (agendar indisponível, informado) | [UI] |
| Agenda | `/agenda` | profissional | parcial | funcional | [UI] |
| Agenda | `/agenda` | recepção/gestão | **com erro** (sempre vazia) | funcional (agenda da clínica) | [UI] |
| Paciente 360 | `/consultorio/paciente/:id/360` | profissional | **com erro** (sempre "sem permissão") | funcional | [UI] |
| Triagem | `/consultorio/triagem/:consulta` | profissional | **com erro** (ID digitado; gravação recusada) | funcional | [UI] |
| Recepção | `/consultorio/recepcao` | recepção | funcional | funcional | [UI] |
| Solicitações de paciente novo | `/consultorio/solicitacoes` | recepção | funcional | funcional | [UI] |
| Contas a receber | `/financeiro/receber` | financeiro | **com erro** (permissão negada) | funcional | [UI] carregamento · [CÓDIGO] ações |
| Contas a pagar | `/financeiro/pagar` | financeiro | **com erro** | funcional | [UI] |
| Inadimplência | `/financeiro/inadimplencia` | financeiro | **com erro** | funcional | [UI] |
| Editor de documento clínico | consulta › documento | profissional | parcial | parcial (aviso de saída; nome da clínica) | [CÓDIGO] |

## 3. Mapa de fluxos por perfil

**Família** — login → início → crianças → detalhe → (crescimento, vacinas,
responsáveis, profissionais autorizados, consultas) → pré-consulta da
consulta → acompanhamento.
Verificado [UI]: lista, detalhe, autorização por escopo e validade,
revogação, pré-consulta, isolamento (Ana não vê a Mia, de outra família).
Interrompido: **agendar pela família não existe na versão real** (o botão
informa "indisponível nesta versão").

**Recepção** — login → agenda da clínica (7 dias) → novo paciente
(solicitação com convite) → recepção (quadro, fila, check-in).
Verificado [UI]: agenda da clínica, ausência de ações clínicas, acesso a
solicitações; recepção bloqueada no 360 e na triagem.
Interrompido: **agendar paciente que já é da clínica não tem tela** (ver
pendências).

**Profissional** — login → agenda → triagem da consulta → Paciente 360 →
atendimento → documentos.
Verificado [UI]: agenda, triagem com criança vinda da consulta, gravação só
com "Resumo e prontuário" válido na clínica, bloqueio após revogação, 360.
Não exercitado pela interface: atendimento, documentos, assinatura,
transcrição (voz desligada por configuração).

**Financeiro** — login → contas a receber / a pagar / inadimplência.
Verificado [UI]: carregamento com dados da clínica, cadastro de despesa com
validação e vencimento, confirmação antes de marcar como paga, persistência
após recarregar.

**Gestão** — varredura de rotas [UI]: acesso às áreas de gestão; módulos
clínicos ainda aparecem no hub (pendente, item P4 abaixo).

## 4. Problemas corrigidos

Prioridade: 1 = acesso indevido, perda ou mistura de dados · 2 = erro
clínico ou financeiro, duplicidade · 3 = fluxo quebrado · 4 = navegação e
usabilidade · 5 = visual.

### C1 — Dados da criança não salvavam na web (perda de dados) · P1
- **Tela/perfil:** Nova criança, crescimento, vacinas · família.
- **Passos:** entrar como Ana na web → cadastrar criança ou medida.
- **Esperado:** gravar no servidor ou mostrar erro. **Observado:** a tela
  confirmava, mas nada era gravado; listas sempre vazias.
- **Causa:** sem banco local na web, a fila de sincronização descartava a
  escrita; as listas liam só o banco local.
- **Correção:** `sync_service.dart` grava direto no servidor quando não há
  banco local e propaga a falha; `children_repository_impl.dart` lê do
  servidor na web.
- **Reteste:** [UI] lista com Luna e Theo, detalhe, recarregar rota interna.

### C2 — Pré-consulta mostrava respostas de outra consulta (mistura) · P1
- **Tela/perfil:** Pré-consulta, 360, triagem e outras telas por id · família/profissional.
- **Passos:** abrir a pré-consulta da Luna → navegar para a da Mia.
- **Observado:** o formulário da Luna aparecia na URL da Mia.
- **Causa:** o roteador reaproveitava o estado da tela entre ids.
- **Correção:** chave por rota em 11 telas (`app_router.dart`).
- **Reteste:** [UI] troca de consulta na triagem e na pré-consulta.

### C3 — Recepção com conta de profissional abria prontuário · P1
- **Causa:** a checagem de rota considerava a conta, não o papel na clínica.
- **Correção:** `route_authorization.dart` exige papel clínico para 360 e
  triagem; removido bloco duplicado de `/gestao`.
- **Reteste:** [TESTE] 2 testes novos em `route_authorization_test.dart`;
  [UI] varredura de rotas por perfil.

### C4 — Paciente 360 sempre "sem permissão" para o profissional · P3
- **Passos:** Dra. Carla (autorizada) abre o 360 da Luna.
- **Observado:** "Sua sessão não tem permissão para estes dados".
- **Causa:** as consultas buscavam todos os atendimentos, documentos, exames
  e agendamentos da criança; as regras só liberam ao profissional o que ele
  mesmo registrou, então a consulta inteira era recusada.
- **Correção:** para profissional, as consultas filtram pelo próprio autor
  (`encounter_repository.dart`, `patient_timeline_screen.dart`,
  `telemedicine_repository.dart`, `patient_360_screen.dart`); índices
  compostos adicionados em `firestore.indexes.json`. **Regras não foram
  alteradas.**
- **Reteste:** [UI] 360 da Luna carrega com a próxima consulta.

### C5 — Triagem: criança digitada à mão e gravação recusada · P2
- **Observado:** era preciso digitar o ID da criança (risco de registrar no
  paciente errado); com autorização válida, a gravação era recusada; se só a
  atualização da fila falhasse, a tela mostrava erro e uma nova tentativa
  criava outra triagem.
- **Causa:** a tela não lia a consulta; o registro saía sem a clínica, e a
  autorização "somente na clínica" não valia; ID novo a cada gravação.
- **Correção:** criança e clínica vêm da consulta (campo travado); uma
  triagem por consulta (gravar de novo atualiza); fila atualizada à parte,
  com aviso próprio; mensagem clara quando falta autorização.
- **Reteste:** [UI] grava com "Resumo e prontuário"; segunda gravação
  atualiza o mesmo registro (1 documento); Mia (só resumo) bloqueada com
  explicação; após revogação, bloqueada.

### C6 — Financeiro com "permissão negada" e erro técnico na tela · P3
- **Causa:** a equipe financeira consultava pelo dono do lançamento em vez da
  clínica; o erro era exibido como texto bruto.
- **Correção:** consultas por clínica para a equipe (`finance_repository.dart`,
  `finance_providers.dart`); estados de erro com "Tentar novamente".
- **Reteste:** [UI] receber, pagar e inadimplência carregam para o Fábio.

### C7 — Contas a pagar marcava como paga com um toque · P2
- **Observado:** tocar na linha pagava sem confirmar e sem conferir o
  resultado; categoria escolhida não aparecia; vencimento fixo em +30 dias;
  valor inválido descartado sem aviso; texto corrompido.
- **Correção:** confirmação "Registrar pagamento?", aviso de sucesso ou
  falha, categoria visível, escolha de vencimento, validação, texto corrigido.
- **Reteste:** [UI] validação, criação, confirmação, "Voltar" mantém
  pendente, persiste após recarregar.

### C8 — Contas a receber: pagamento, edição e cancelamento inseguros · P2
- **Observado no código:** método sempre PIX; resultado ignorado; "Editar
  valor" para qualquer perfil e aceitando total menor que o já pago;
  cancelamento sem confirmação, inclusive com pagamento registrado; recibo
  de pré-visualização com nome "Consultorio"; texto corrompido.
- **Correção:** escolha do método e valor (parcial permitido, sem passar do
  aberto); edição só para quem gerencia o caixa e com mínimo = já pago;
  cancelamento com confirmação e bloqueado se houver pagamento (orienta
  estorno); pré-visualização identificada como tal, só com valor pago, e com o
  nome da clínica.
- **Reteste:** [CÓDIGO] + análise estática. **Não exercitado na interface:**
  não há conta a receber no seed (ela nasce do atendimento finalizado).

### C9 — Agenda vazia para recepção e gestão · P3
- **Causa:** a agenda buscava só consultas em que o usuário é o profissional.
- **Correção:** recepção, gestão, enfermagem e técnicos veem a agenda da
  clínica; profissional continua vendo a própria. "Iniciar atendimento"
  oculto para a equipe.
- **Reteste:** [UI] Eva vê as consultas da clínica sem ações clínicas.

### C10 — "+ Novo atendimento" abria a disponibilidade · P4
- **Correção:** profissional vê "Disponibilidade"; equipe vê "Novo paciente",
  que abre as solicitações de paciente novo.
- **Reteste:** [UI] nos dois perfis.

### C11 — Sair com alterações não salvas sem aviso · P4
- **Correção:** componente `UnsavedChangesGuard` com "Continuar editando",
  "Descartar" e "Salvar"; aplicado em Nova/editar criança, pré-consulta da
  família e editor de documento (neste, sem "Salvar", porque emitir é
  irreversível).
- **Reteste:** [UI] Nova criança: as três opções funcionam. [CÓDIGO]
  pré-consulta e editor de documento.
- **Limite conhecido:** o botão **voltar do navegador** no Flutter Web troca a
  rota sem passar pelo aviso (limitação da plataforma); o aviso vale para os
  botões do app e para o voltar do Android.

### C12 — Avisos automáticos com rotas inválidas · P3
- **Observado no código:** avisos apontavam para `/pre-consulta` sem id,
  `/notificacoes` (inexistente) e `/financeiro` (área da equipe) para a família.
- **Correção:** `notificationRoute()` em `automationCore.ts`: pré-consulta
  com o id da consulta, demais para `/telemedicina` ou `/avisos`.
- **Reteste:** [TESTE] 2 testes novos em `automationCore.test.ts`.

### C13 — Documentos e recibos com nome fixo da clínica · P5
- **Correção:** `documentClinicNameProvider` usa o nome da clínica ativa
  (sem clínica, "Pediatria 360") no editor, visualizador e relatórios.
- **Reteste:** [CÓDIGO].

## 5. Pendências (não corrigidas nesta etapa)

| # | Prioridade | Pendência | Situação |
| --- | --- | --- | --- |
| P1 | 3 | **Agendar paciente que já é da clínica** não tem tela (`createClinicAppointment` sem uso) | [CÓDIGO] — requer tela nova (paciente, profissional, horário, conflito) |
| P2 | 3 | **Agendamento pela família** não existe na versão real (`book` sem uso) | [UI] informado como indisponível |
| P3 | 3 | Atendimento, documentos, assinatura, adendos e transcrição não exercitados pela interface | [BLOQUEADO] voz desligada; atendimento depende de consulta "em andamento" |
| P4 | 1 | Gestão (clinicAdmin) ainda vê módulos clínicos no hub (`management_modules.dart`) | [CÓDIGO] dados protegidos pelas regras |
| P5 | 1 | Profissional verificado sem clínica abre telas de finanças/BI/triagem (vê só dados próprios ou vazio) | [UI] dados protegidos; comportamento de autônomo a definir |
| P6 | 4 | Telas abertas com `Navigator.push` não mudam a URL (autorizações, pendências) | [UI] |
| P7 | 4 | Rotas declaradas sem tela (`/ajustes`, `/assinatura`, calculadoras, primeiros socorros) | [CÓDIGO] nenhum link aponta para elas |
| P8 | 2 | Glosas, repasses e conciliação: resultado de ações não conferido | [CÓDIGO] |
| P9 | 3 | Suplementação: PDF/compartilhar da orientação e da prescrição são apenas aviso | [CÓDIGO] |
| P10 | 4 | Card de consulta presencial diz "A sala abre 10 minutos antes" | [UI] |
| P11 | 3 | Callables sem tela: adendos, cancelar mensagem, estorno, negociação, reenvio de verificação de e-mail | [CÓDIGO] |
| P12 | 3 | WhatsApp, pagamentos e IA (Anthropic) | [BLOQUEADO] sem credenciais; telas marcam como bloqueado |
| P13 | 4 | Mensagem de senha errada some antes de 5 s (SnackBar) | [UI] parcial |
| P14 | 5 | Erros de console no ambiente isolado: Firebase Installations 403 (projeto fictício) e teclado sintético do navegador automatizado | artefato do ambiente, não do app |

## 6. Testes e resultados

| Verificação | Resultado |
| --- | --- |
| `flutter analyze` nos arquivos alterados | sem erros nem avisos novos (permanecem infos antigas) |
| `flutter test --no-pub -j 2` (suíte completa) | **887 aprovados**, 0 falhas |
| `functions`: `tsc --noEmit` | aprovado |
| `functions`: `jest` (suíte completa) | **104/104 aprovados** (12 suítes; 2 testes novos) |
| `functions`: `eslint` | 0 erros (1 aviso antigo em `emr.ts`) |
| Regras Firestore/Storage | **não alteradas** nesta etapa; suíte não reexecutada |
| Reteste pela interface | roteiros `t01`–`t12` no navegador automatizado, resultados na seção 4 |

## 7. Evidências visuais

Pasta `evidencias/` (capturas do navegador automatizado, dados fictícios):

- `07_ana_criancas.png` — lista de crianças carregando na web.
- `07_carla_360_luna.png` — Paciente 360 carregando para a médica autorizada.
- `07_carla_triagem_prefill.png` — triagem com a criança vinda da consulta.
- `07_fabio_despesa_criada.png`, `07_fabio_confirmar_pagamento.png` — contas a pagar.
- `08_ana_sair_sem_salvar.png` — aviso de alterações não salvas.
- `10_ana_autorizados.png`, `10_ana_autorizacao_final.png` — autorização por escopo.
- `12_carla_triagem_salva.png`, `12_carla_triagem_mia_bloqueada.png` — gravação e bloqueio por escopo.
- `12_eva_agenda_clinica.png`, `12_eva_novo_paciente.png` — agenda da recepção.
- `12_ana_consultas.png` — consultas da família (isolamento entre famílias).

## 8. O que não foi verificado

- Mobile (390×844) e tablet: não houve captura sistemática nesta rodada.
- Acessibilidade além da árvore semântica (contraste, leitor de tela real).
- Fluxo financeiro completo (atendimento → cobrança → pagamento de teste →
  recibo → conciliação): não há cobrança no seed e o provedor de pagamento
  está sem credencial.
- IA, WhatsApp, automações e campanhas com provedor real: sem credenciais;
  nenhuma mensagem foi enviada.
- Sessão expirada e troca de clínica com duas clínicas ativas.

## 9. Roteiro simples para você testar

Use o ambiente de homologação com contas fictícias (nunca dados reais).

1. **Família:** entre como responsável → *Crianças* → confira a lista →
   abra uma criança → *Profissionais autorizados* → *Autorizar* → escolha a
   médica, "Resumo e prontuário", 30 dias → confirme. Depois *Revogar*.
2. **Família:** *Crianças* → *Adicionar* → digite um nome → toque em
   *Cancelar* → deve aparecer "Sair sem salvar?" com três opções.
3. **Profissional:** *Agenda* → *7 dias* → abra a triagem de uma consulta →
   a criança já vem preenchida → salve. Sem autorização de prontuário deve
   aparecer a explicação; com autorização, "Triagem salva".
4. **Profissional:** abra o *Paciente 360* de uma criança autorizada → deve
   carregar o resumo (sem "sem permissão").
5. **Recepção:** *Agenda* → *7 dias* → deve listar as consultas da clínica,
   sem "Iniciar atendimento" → *Novo paciente* abre as solicitações.
6. **Financeiro:** *Contas a pagar* → *+* → tente salvar sem valor (deve
   avisar) → preencha → toque na despesa → deve pedir confirmação.

## 10. Versão, commit, push e deploy

- Versão: branch `feat/fluxo-atendimento`, sobre `99715ae`.
- Commit: local, com caminhos explícitos (ver histórico do git).
- Push: **não realizado** (aguarda sua autorização).
- Deploy: **não realizado**; nada publicado em produção nem nas lojas.
- Índices novos em `firestore.indexes.json` só valem em produção após deploy
  autorizado.
