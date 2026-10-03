# Compartilhamento seletivo de informações por criança

Módulo multidisciplinar do Pediatria360 (versão de demonstração com dados
fictícios). Branch de trabalho `feat/area-profissional`. Nada foi publicado
em produção.

> **Situação:** proposta para revisão clínica e jurídica. A matriz da seção 2
> e os pontos de decisão da seção 3 foram implementados como estão descritos,
> mas podem mudar depois da revisão. Nenhuma regra foi publicada no Firebase
> de produção.

## 1. Auditoria das regras atuais (antes desta mudança, commit 285930c)

O que o módulo fazia, conferido no código (`lib/shared/care/`), nas regras
(`firestore.rules`, `storage.rules`), nas telas (`care_team_screens.dart`) e
nos testes.

| # | Achado | Onde | Efeito |
|---|---|---|---|
| A1 | Três níveis de visibilidade: `reservado`, `equipe`, `familia`. O padrão ao criar registro era `equipe`. | `care_store.addRecord`, `validVisibility` | Avaliações, evoluções e medidas de pediatria e fisioterapia ficavam legíveis por toda a equipe ativa da mesma clínica, sem escolha do autor. |
| A2 | Só a psicologia podia marcar registro como reservado. | `CarePolicy.canReserve`, regra `validVisibility` | Pediatra e fisioterapeuta não tinham como manter o registro completo restrito. |
| A3 | Resumo para a equipe era um texto livre gravado como registro `resumoEquipe`, visível na hora para toda a equipe. | `addRecord(teamSummary:)`, `shareSummary` | Sem escolha de destinatários, sem prévia, sem confirmação e sem encerrar o acesso. |
| A4 | A visão da equipe juntava automaticamente evoluções, medidas, objetivos e planos de todos os registros não reservados. | `CareStore.sharedView` | Inclusão automática de conteúdo clínico. |
| A5 | A IA montava o rascunho a partir da visão da equipe (A4) e podia salvá-lo como registro da equipe. | `CareAi.teamSummary`, `saveReviewed` | A IA lia o conteúdo completo de registros não reservados. |
| A6 | Documentos emitidos ficavam legíveis por toda a equipe da clínica. | `documentsFor`, regra `documents` | Relatórios psicológicos emitidos circulavam sem decisão do autor. |
| A7 | Plano combinado era um texto único que qualquer membro sobrescrevia, com objetivos só de texto. | `updatePlan`, regra `plan` | Sem responsável, ações, prazo nem reavaliação. |
| A8 | Anexos seguiam a visibilidade do registro (equipe lia anexos de registros `equipe`). | `attachmentsFor`, `storage.rules` | Anexos de evoluções da equipe ficavam abertos à equipe. |
| A9 | A regra de Storage da equipe consultava até 3 ou 4 documentos do Firestore (registro, vínculo, perfil, equipe). A documentação do Firebase limita a **2** chamadas `firestore.get/exists` por requisição de Storage. | `storage.rules` | Em produção a leitura da equipe falharia (falha fechada). O teste do emulador não cobria esse caminho. |
| A10 | Retirar da família devolvia o registro para `equipe`. | `CareStore.withdraw` | Retirar um conteúdo da família o expunha à equipe. |
| A11 | Não havia registro de "com quem foi compartilhado" nem de "quem acessou" um conteúdo específico, só a trilha geral. | `CareStore._log`, `access_log` | Não dava para responder quem leu um resumo. |
| A12 | Não havia separação entre conteúdo clínico, anotação privada, transcrição e conversa: o registro tinha só um campo de texto. | `CareRecord.body` | Qualquer compartilhamento do registro levava tudo junto. |
| A13 | Área da família: só orientações e atividades liberadas e documentos liberados. Vínculo com a criança não abria registros reservados. | `familyView`, regra `records` | Já atendia ao pedido; mantido. |
| A14 | Comunicação da equipe (encaminhamento, parecer, mensagem) é escrita para a equipe. | `messages` | Mantida: é conteúdo que o autor já redige para compartilhar. |
| A15 | Nenhuma Cloud Function lê dados do cuidado multidisciplinar; a IA do módulo é simulada no aplicativo. | `functions/` (0 ocorrências) | A regra da IA fica no cliente e nas regras de leitura. |

## 2. Matriz de acesso proposta

Legenda: **L** lê, **E** cria ou altera, **—** sem acesso. "Equipe" é sempre
a equipe com vínculo ativo, autorizado pela família, na mesma clínica do
registro.

### 2.1 Registro do atendimento

| Recurso | Autor | Destinatário do resumo | Acesso concedido (justificado) | Equipe sem compartilhamento | Mesma clínica sem vínculo | Gestão da clínica | Família | IA |
|---|---|---|---|---|---|---|---|---|
| Registro completo (conteúdo clínico) | L E | — | L | — | — | — | — | — |
| Anotação privada, transcrição, conversa | L E | — | — | — | — | — | — | — |
| Anexos do registro | L E | — | L | — | — | — | — | — |
| Histórico de alterações do registro | L | — | — | — | — | — | — | — |
| Concessões de acesso do registro | L E | — | L (a própria) | — | — | — | — | — |
| Orientação ou atividade liberada para a família | L E | — | L | — | — | — | L | — |

### 2.2 Resumo para a equipe

| Recurso | Autor | Destinatário do resumo | Acesso concedido | Equipe sem compartilhamento | Mesma clínica sem vínculo | Gestão | Família | IA |
|---|---|---|---|---|---|---|---|---|
| Versão atual do resumo (publicado) | L E | L | — | — | — | — | — | L (só para o próprio destinatário) |
| Resumo encerrado | L | — | — | — | — | — | — | — |
| Versões anteriores | L | — | — | — | — | — | — | — |
| Anexos escolhidos para o resumo | L E | L | — | — | — | — | — | — |
| Quem acessou o resumo | L | — | — | — | — | L (trilha) | L (trilha) | — |

### 2.3 Plano terapêutico conjunto

| Recurso | Profissional da equipe | Responsável pelo objetivo | Mesma clínica sem vínculo | Gestão | Família | IA |
|---|---|---|---|---|---|---|
| Objetivos, responsável, prazo, reavaliação | L E (novo objetivo) | L E (reavaliar) | — | — | — | L (para a equipe) |
| Ações e informações compartilhadas | L E (a própria contribuição) | L E | — | — | — | L (para a equipe) |
| Histórico do plano | L | L | — | — | — | — |

### 2.4 Demais áreas

| Recurso | Autor ou dono | Equipe | Gestão | Família |
|---|---|---|---|---|
| Agenda do profissional | L E | próximos horários da equipe (data, hora e área) | conforme agenda da clínica | próximas sessões |
| Documentos (rascunho, revisado, emitido) | L E | — | — | — |
| Documento liberado para a família | L E | — | — | L |
| Modelos de documento | L E | — | — | — |
| Comunicação da equipe | L E | L E | — | — |
| Trilha de acessos da criança | — | — | L (da clínica) | L |

### 2.5 Ações do resumo

1. Ao concluir um atendimento, o autor abre "Criar resumo para a equipe".
2. **Informações:** todas começam desmarcadas. Só aparecem para seleção o
   texto do registro, as seções clínicas e a medida. Anotação privada,
   transcrição e conversa aparecem com cadeado, sem caixa de seleção. Anexos
   também começam desmarcados.
3. **Destinatários:** nenhum vem marcado. O autor escolhe profissionais da
   equipe ou "equipe de cuidado autorizada".
4. **Prévia:** mostra exatamente o que será enviado, para quem e a versão.
5. **Confirmação:** só depois de confirmar o resumo é publicado.
6. Atualizar gera nova versão; encerrar retira o acesso dos destinatários na
   hora. As versões ficam com o autor; ninguém apaga.

## 3. Pontos para decisão clínica e jurídica

| # | Decisão adotada nesta versão | Alternativa a avaliar |
|---|---|---|
| D1 | "Equipe de cuidado autorizada" é a equipe ativa **no momento da publicação**. Quem entra depois não recebe resumos antigos; o autor atualiza o resumo se quiser incluí-lo. | Estender automaticamente a novos membros. |
| D2 | Anotação privada, transcrição e conversa **nunca** entram no resumo, nem por escolha. Se algo delas for necessário, o autor reescreve na observação do resumo. | Permitir seleção explícita com aviso. |
| D3 | Acesso ao registro completo só por concessão do autor, a profissional da equipe, com justificativa (mínimo 15 caracteres), revogável e registrado. A concessão mostra o conteúdo clínico e os anexos, nunca as anotações privadas. | Exigir também ciência ou consentimento do responsável; permitir concessão pelo responsável técnico na ausência do autor. |
| D4 | O autor continua lendo os próprios registros depois de encerrado o vínculo (guarda do prontuário). | Prazos de guarda por conselho (CFM, CFP, COFFITO) a confirmar pela assessoria jurídica. |
| D5 | Encerrar o acesso ao resumo não apaga o que já foi lido; fica registrado quem leu e quando. | Texto de aviso ao destinatário sobre uso e sigilo. |
| D6 | Quem acessou o resumo: visível para o autor; a trilha geral fica com a família e a gestão da clínica. | Restringir a trilha da gestão a metadados. |
| D7 | O plano conjunto é da equipe da clínica; a família não vê o plano. | Versão do plano liberada à família pelo responsável. |
| D8 | A IA só usa o que já foi compartilhado com quem pede (resumos endereçados a ele e o plano) ou, ao redigir um resumo, só os itens que o autor marcou. O texto é identificado como rascunho e não é salvo sozinho. | Contrato de tratamento de dados com o provedor de IA real (pendente). |
| D9 | Documentos deixam de ser visíveis para a equipe; vão só para a família quando o autor libera. | Permitir anexar documento emitido a um resumo. |
| D10 | Sem acesso de emergência ("quebra de vidro"). | Acesso de emergência com justificativa e alerta ao autor. |
| D11 | Os próximos horários da equipe aparecem na visão da equipe (data, hora e área, sem motivo). | Esconder horários de outros profissionais. |
| D12 | O registro de quem acessou é gravado pelo aplicativo. Um cliente modificado poderia ler sem gravar. | Ativar os registros de auditoria de acesso a dados do Firestore no Google Cloud ou servir a leitura por uma Function. |

Referências para a revisão (a confirmar pela assessoria jurídica): LGPD,
art. 11 (dado sensível de saúde) e art. 14 (dados de crianças, no melhor
interesse); normas de prontuário e sigilo de cada conselho profissional.

## 4. Onde as permissões são aplicadas

A mesma matriz vale em quatro camadas. As telas nunca são a única barreira:
cada leitura passa pela regra do domínio, e as regras do Firestore e do
Storage repetem a decisão no servidor.

| Camada | Arquivo | O que garante |
|---|---|---|
| Domínio (decisão única usada pelas telas e pela IA) | `lib/shared/care/care_policy.dart`, `care_store.dart` | Registro completo só para o autor ou acesso concedido; partes privadas só para o autor; resumo só para destinatários com vínculo ativo na mesma clínica; itens bloqueados recusados na prévia; publicação só com confirmação; cada leitura de resumo grava quem acessou; cada negação fica na trilha. |
| Banco de dados | `firestore.rules`, bloco `care_teams` | `records` com padrão `privado`; `records/{id}/sections` (anotação privada, transcrição e conversa só para o autor); `records/{id}/grants/{uid}` (concessão com justificativa de 15 caracteres ou mais, retirada sem apagar, nova concessão guarda a anterior); `summaries/{id}` com destinatários, versão obrigatória em `versions/{n}` no mesmo lote, sem campos extras e sem o próprio autor como destinatário; `summaries/{id}/access` gravado por quem lê; `plan/{clínica}/goals` com responsável da equipe, prazo, reavaliação só pelo responsável e contribuições em nome próprio; documentos só do autor e, depois de liberados, da família. |
| Arquivos | `storage.rules`, bloco `care/` | `care/{criança}/registros/{autor}/{registro}/` só o autor (sem consulta) ou quem tem acesso concedido e vínculo ativo; `familia/` só o autor e a responsável; `resumos/{registro}/{versão}/` só o destinatário, enquanto publicado, na versão em vigor e só o arquivo escolhido. Arquivo gravado não é substituído nem apagado. Cada regra faz no máximo 2 consultas ao Firestore (limite do Storage). |
| IA (simulada) | `lib/shared/care/care_ai.dart` | "Visão com IA" lê só `summariesFor` e `planFor` de quem pede; "Sugerir com IA" no resumo lê só `selectedItems` (os itens marcados) e recusa itens bloqueados. O texto é rascunho identificado e nunca é salvo sozinho. |
| Telas | `lib/demo/screens/care_team_screens.dart` | Assistente do resumo em 4 passos (informações, destinatários, prévia, confirmação), concessões com justificativa, plano conjunto, área da família separada. |

O módulo de cuidado ainda roda só na demonstração (dados em memória). As
regras do Firestore e do Storage estão prontas e testadas no emulador para
quando o aplicativo real gravar esses dados; nada foi publicado no Firebase.

## 5. Cenário pedido e resultados

Três profissionais da mesma clínica vinculados à Luna (fictícia): psicóloga,
pediatra e fisioterapeuta, mais a responsável. Resultados registrados em
03/10/2026 nesta máquina, com a build local da demonstração.

| Passo | Domínio (`flutter test`) | Regras (emulador) | Navegador (build local) |
|---|---|---|---|
| Psicóloga registra sessão privada com conteúdo clínico, anotação privada, transcrição e anexo | aprovado | aprovado: só ela lê registro, partes e anexo; pediatra, fisioterapeuta, psicólogo sem vínculo, gestão, outra clínica e família recebem negação | aprovado |
| Psicóloga compartilha só um resumo com o pediatra | aprovado | aprovado | aprovado (assistente: nada marcado, destinatário escolhido, prévia, confirmação) |
| Pediatra lê o resumo, mas não a evolução completa nem os anexos privados | aprovado | aprovado: resumo lido; registro, partes e anexo negados | aprovado |
| Fisioterapeuta vê só o que foi compartilhado com ela | aprovado | aprovado: não lê o resumo do pediatra; lê depois de incluída | aprovado |
| Família vê só as orientações liberadas | aprovado | aprovado: lê orientação e arquivo liberados; não lê resumo, plano, documento emitido nem registro | aprovado (celular) |
| Retirada do acesso ao resumo | aprovado: some para o destinatário, versão 2 com motivo, quem acessou continua registrado | aprovado: leitura negada depois de encerrado; versões imutáveis e só da autora; anexo do resumo deixa de abrir | aprovado |
| Retirada do acesso concedido ao registro completo | aprovado | aprovado: registro e anexo negados depois da retirada; só a autora retira | aprovado |
| Vínculo encerrado | aprovado | aprovado: perde resumo e acesso concedido; a autora mantém os próprios registros | aprovado |

Totais desta execução:

| Suíte | Resultado |
|---|---|
| `test/care_team_test.dart` (domínio) | 44 de 44 aprovados |
| `test/demo_care_flow_test.dart` (telas) | 10 de 10 aprovados |
| `test/rules/care_rules.test.js` (Firestore e Storage no emulador) | 51 de 51 aprovados; com `rules.test.js`, 196 de 196 |
| `tools/demo/e2e_clinico.js` com `ONLY=cuidado` (Chrome, computador e celular) | 34 de 34 verificações aprovadas |
| `flutter test` completo | 858 de 859 aprovados. A falha é `demo_workspace_test.dart` "agenda: dia, semana e mês", que depende do relógio (procura horário livre no dia) e falha igual no commit 285930c sem estas mudanças. |
| `flutter analyze` | sem erros nem avisos; 132 observações de estilo já existentes, nenhuma nos arquivos alterados |

A suíte completa do navegador (todos os módulos) não foi executada nesta
rodada; só os passos do cuidado multidisciplinar.

### Encontrado e corrigido durante os testes

- **Storage permitia substituir um anexo já gravado.** O emulador tratou a
  regravação como criação. Agora toda criação exige `resource == null`.
- **Assistente do resumo estourava a largura no celular** ("Cancelar" ao lado
  de "Escolher destinatários"). Os botões passam para a linha de baixo.
- **Acessibilidade:** o cabeçalho expansível ("Acessos concedidos",
  "Reavaliações", "Versões", "Quem acessou") se fundia ao cartão inteiro para
  leitores de tela; cada um agora é um elemento próprio, e cada cartão de
  registro, resumo e objetivo é um grupo identificado. O texto da IA passou a
  ser lido por leitores de tela.

## 6. Capturas

Build local da demonstração, dados fictícios.

| Arquivo | O que mostra |
|---|---|
| `cm01_visao_equipe.png` | Pediatra: profissionais, plano conjunto, próximos atendimentos e resumos compartilhados com ela |
| `cm02_ia_visao.png` | "Visão com IA": rascunho identificado, feito só com resumos recebidos e o plano |
| `cm03_psicologia_vista_pelo_pediatra.png` | Área da psicologia para o pediatra: só o resumo endereçado a ele |
| `cm04_psicologa_registro_completo.png` | Psicóloga: registro completo, partes privadas marcadas "só você vê" |
| `cm05_fisioterapeuta_equipe.png` | Fisioterapeuta: não recebe o resumo endereçado só ao pediatra |
| `cm06_fisioterapia.png` | Área própria da fisioterapia: agenda, medidas e registros |
| `cm07_documentos_psicologia.png` | Documentos só da própria área |
| `cm08_resumo_passo1_nada_marcado.png` | Passo 1: nada marcado; transcrição e conversa bloqueadas |
| `cm09_resumo_passo2_destinatarios.png` | Passo 2: profissionais escolhidos |
| `cm10_resumo_previa.png` | Passo 3: prévia com o item escolhido e a destinatária |
| `cm11_resumo_compartilhado.png` | Confirmação concluída |
| `cm12_fisioterapeuta_recebe_resumo.png` | Fisioterapeuta recebe só o resumo |
| `cm13_quem_acessou.png` | Autora vê quem acessou |
| `cm14_acesso_encerrado.png` | Acesso encerrado, versões preservadas |
| `cm15_trilha_resumo.png` | Trilha: compartilhou, acessou e encerrou |
| `cm16_conceder_acesso.png` | Concessão de acesso com justificativa |
| `cm17_registro_concedido.png` | Pediatra com acesso concedido: conteúdo clínico e anexo, sem a anotação privada |
| `cm18_acesso_retirado.png` | Acesso retirado com motivo |
| `cm19_novo_objetivo.png` | Novo objetivo: responsável, prazo, reavaliação e primeira ação |
| `cm20_plano_conjunto.png` | Plano terapêutico conjunto com ações e informações de cada área |
| `m_cm21_familia.png` | Celular: área da família com sessões e orientações liberadas |
| `m_cm22_familia_exercicio_liberado.png` | Exercício liberado pela fisioterapeuta aparece para a família |
| `cm23_gestao_equipe.png` | Gestão organiza a equipe sem ler registros |
| `cm24_novo_psicologo.png` | Novo psicólogo não herda registros da anterior |
| `cm25_psicologa_anterior.png` | Psicóloga com vínculo encerrado lê só os próprios registros |
| `cm26_nova_clinica.png` | Nova clínica sem resumos nem plano da anterior |

## 7. Como reproduzir

```powershell
flutter test test/care_team_test.dart test/demo_care_flow_test.dart
firebase emulators:exec --only "firestore,storage" --project pediatria360-rules-test "cd test\rules && node_modules\.bin\jest.cmd --runInBand care_rules"
powershell -ExecutionPolicy Bypass -File tools\demo\build_demo.ps1
# com a build servida em http://127.0.0.1:8765/pediatria360-demo/
$env:ONLY = 'cuidado'; node tools\demo\e2e_clinico.js
```

O emulador precisa de Java 21 ou mais recente no PATH.

## 8. Pendências e limites conhecidos

1. **Revisão clínica e jurídica** da matriz (seção 2) e das decisões D1 a D12.
2. **Registro de quem acessou (D12):** gravado pelo aplicativo; um cliente
   modificado poderia ler sem gravar. Recomendação: registros de auditoria de
   acesso a dados do Firestore no Google Cloud ou leitura por Function.
3. **Conteúdo do resumo:** as regras limitam campos, destinatários e versões,
   mas não conseguem conferir se o texto copiado veio de uma seção clínica. O
   bloqueio de anotação privada, transcrição e conversa está no domínio e na
   tela; o autor é dono do texto e pode reescrever o que quiser.
4. **Destinatários:** as regras não percorrem a lista na gravação; a validade
   de cada destinatário (vínculo ativo na mesma clínica) é conferida na
   leitura. Um nome inválido na lista não ganha acesso.
5. **Arquivos da família no Storage:** por causa do limite de 2 consultas, só
   a responsável titular abre o arquivo; o segundo responsável vinculado lê o
   registro no Firestore, mas não o arquivo. Resolver com cópia por Function ou
   URL assinada.
6. **IA real:** contrato de tratamento de dados com o provedor antes de ligar
   (D8). Hoje a IA é simulada.
7. **Publicação:** nenhuma regra foi publicada no Firebase e nada foi para
   produção. Publicar só com autorização.

## 9. Mudanças nos arquivos

- `lib/shared/care/`: modelo (seções, concessões, resumos versionados, plano
  com objetivos), política, store e IA.
- `lib/demo/demo_care.dart`, `lib/demo/demo_router.dart`,
  `lib/demo/screens/care_team_screens.dart`: dados fictícios, rota do
  assistente `/cuidado/:id/resumo/:registro` e telas.
- `firestore.rules`, `storage.rules`: bloco do cuidado multidisciplinar.
- `test/care_team_test.dart`, `test/demo_care_flow_test.dart`,
  `test/rules/care_rules.test.js`, `tools/demo/e2e_clinico.js`.
