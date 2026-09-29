# Agenda e acompanhamento clínico do profissional: relatório de homologação

Código: commits `467d10e` e `bd281dc` na branch `feat/area-profissional`.
Todos os pacientes, consultas e anotações usados são fictícios. O app real, o Firebase e as lojas não foram alterados.

## O que existia

- **App real** (não alterado):
  - agenda do profissional com as visões "hoje" e "semana" (`professional_agenda_screen.dart`);
  - editor de atendimento, linha do tempo do paciente e editor de resumo de visita (`lib/features/emr`).
- **Demonstração:**
  - agenda só do dia, sem horários livres e sem visões de semana e mês;
  - o agendamento não tinha ligação com a consulta registrada;
  - qualquer profissional abria qualquer horário pelo endereço `/agenda/:id`, sem conferir se era dele;
  - não havia diário de atendimentos, tarefas, observações por paciente, linha do tempo, resumo da consulta nem registro geral de alterações;
  - consultas finalizadas não aceitavam adendo.

A demonstração não pode importar o código do app real (`lib/features`). Por isso as regras novas ficam em `lib/shared` (código puro, sem Flutter nem Firebase), para o app real poder usar as mesmas:

| Arquivo | Conteúdo |
|---|---|
| `lib/shared/scheduling/agenda_range.dart` | dias da semana e do mês, horários livres por dia |
| `lib/shared/clinical/visit_diary.dart` | situação de cada atendimento e filtros por período |
| `lib/shared/clinical/clinical_tasks.dart` | tarefas e lembretes de acompanhamento, prazos |
| `lib/shared/clinical/consultation_organizer.dart` | organização do registro em rascunho |
| `lib/shared/clinical/patient_notes.dart` | observações internas ou visíveis ao responsável, versões |
| `lib/shared/clinical/patient_timeline.dart` | linha do tempo e comparação de crescimento |
| `lib/shared/clinical/audit_trail.dart` | registro de alterações |

## O que foi implementado (perfil Profissional)

### Agenda (`/agenda`)

- **Dia, Semana e Mês**, com botões de anterior, próximo e "Voltar para hoje". A visão e a data ficam no endereço (`?vista=semana&dia=...`): voltar de uma consulta retorna à mesma visão.
- **Cada horário** mostra a situação: Agendada, Confirmada, Retorno, Cancelada, "Pede reagendamento", Falta ou Concluído.
- **Horários livres:** calculados a partir do expediente do profissional e dos bloqueios. Aparecem como "Horário livre" no dia; na semana e no mês, como contagem de "horário(s) livre(s)".
- **Ao abrir um horário** aparece "Dados essenciais":
  - idade, responsável, alergias, último peso e última consulta;
  - a pré-consulta ("Ver pré-consulta");
  - atalhos para a ficha, o histórico e as observações;
  - botão **Iniciar consulta** (ou "Continuar consulta" e "Resumo da consulta" quando já existe).
- **Ligação com a consulta:** a consulta iniciada pelo horário fica ligada a ele. Ao finalizar, o horário passa a "Concluído" e leva ao resumo.
- **Acesso:** o profissional só abre os próprios horários; a recepção vê todos.

### Diário de atendimentos (`/diario`)

- **Lista cronológica** agrupada por dia, com a situação de cada atendimento: Realizada, Pendente (consulta iniciada e não finalizada), Falta, Agendada ou Cancelada.
- **Contagem no topo:** "Realizadas: N - Pendentes: N - Faltas: N".
- **Filtros:**
  - período: Hoje, 7 dias, 30 dias ou Tudo;
  - situação;
  - paciente.
- **Ações por atendimento:** Resumo, Continuar registro, Registrar atendimento, Registrar falta.
- **Tarefas e lembretes de acompanhamento:**
  - campos: descrição, tipo (Tarefa ou Lembrete de acompanhamento), prazo (Hoje, Amanhã, 7 dias, 30 dias ou Sem data) e paciente;
  - aparecem como Atrasada, Para hoje, Próxima ou Sem data; marcar como feita move para "Concluídas".
- **Outros acessos:** o Início do profissional tem o cartão "Diário de atendimentos" com pendências e tarefas. A ficha do paciente tem "Tarefas do paciente", e o resumo da consulta tem "Lembrete de acompanhamento".

### Resumo da consulta (`/pacientes/:id/consulta/:cid/resumo`)

- **O que reúne:**
  - queixa;
  - a pré-consulta enviada pela família;
  - anamnese, exame físico, avaliação e conduta;
  - **plano de retorno**, novo na etapa Conduta: "Retorno em 7, 15, 30, 60 ou 90 dias" ou "Sem retorno marcado", mais o que reavaliar;
  - medidas, marcos do desenvolvimento, documentos emitidos na consulta, observações ligadas e o registro de alterações.
- **Situação:** a etiqueta mostra "Rascunho" ou "Finalizada". Ao finalizar a consulta, o app abre o resumo.
- **Assistente para organizar a consulta** (só com a consulta em rascunho):
  - o profissional cola ou digita a transcrição e toca **Organizar rascunho**;
  - as sugestões aparecem **separadas do registro**, marcadas "Aguardando revisão", seção por seção;
  - só as seções vazias recebem sugestão; o que já estava escrito é mantido;
  - **a avaliação nunca é sugerida**: o aviso pede a conclusão clínica do profissional;
  - "Aplicar ao registro" fica desativado até marcar "Revisei o conteúdo sugerido e confirmo que está correto";
  - ao aplicar, o registro mostra "revisado e aplicado por" com o nome e a hora;
  - "Descartar rascunho" apaga as sugestões sem mexer no registro;
  - aplicar e descartar ficam no registro de alterações.
- **Sem IA ativa:** na demonstração, a organização é feita por **regras fixas**, identificada como "Organização simulada por regras (sem IA ativa)". Nenhum texto sai para serviço externo. Com um modelo de IA no app real, o mesmo fluxo de rascunho, revisão e confirmação continua valendo.
- **Consulta finalizada:** não é editada. Correções entram como **adendo** datado, com autor.

### Observações por paciente (`/pacientes/:id/observacoes`)

- **Cada observação** mostra data, autor e uma etiqueta clara:
  - **"Observação interna"** (cadeado): só a equipe clínica vê;
  - **"Visível ao responsável"** (olho): aparece para a família.
- **Nova observação:** texto, escolha da visibilidade e um aviso explicando quem vai ver.
- **Edição:**
  - cria uma nova versão; "Versões (N)" mostra as anteriores;
  - mudar a visibilidade exige um motivo, que fica registrado;
  - "Arquivar" tira a observação da lista sem apagar ("Arquivadas (N)").
- **Família:** vê só as visíveis, na tela "Recados da equipe" da ficha da criança, sem botão de criar ou editar.
- **Outras clínicas:** observações de outra clínica não aparecem.

### Histórico de consultas (`/pacientes/:id/historico`)

- **Linha do tempo** do mais recente para o mais antigo:
  - consultas e evoluções;
  - prescrições, atestados, encaminhamentos, exames anexados e orientações;
  - medidas de crescimento e pré-consultas;
  - faltas e cancelamentos.

  Filtro por tipo; cada item abre a consulta, o resumo ou o documento.
- **Comparar consultas** (`/historico/comparar`):
  - escolha da Consulta A e da Consulta B;
  - as seções do registro lado a lado (no celular, em cartões);
  - "Crescimento entre as consultas": diferença de peso, comprimento e perímetro cefálico, com ganho em g/dia e cm/mês;
  - medidas ao longo do tempo;
  - marcos do desenvolvimento ao longo do tempo.
- **Registro de alterações** (`/historico/alteracoes`): quem fez, quando e o quê, para consultas, observações, tarefas, agendamentos e rascunhos do assistente.

### Como as telas se ligam

A **agenda** leva ao horário. O horário mostra os dados essenciais e leva à **ficha do paciente** e à **pré-consulta**. **Iniciar consulta** abre o **atendimento**, com a pré-consulta do horário no primeiro passo. **Finalizar** abre o **resumo**, e o resumo leva ao **histórico**, que abre consultas anteriores e a comparação. O diário, as observações e as tarefas têm atalhos em cada uma dessas telas.

Todo registro é gravado no paciente do endereço e da consulta. Uma consulta de outro paciente não abre em `/pacientes/:id/consulta/:cid`.

### Proteção de acesso (na demonstração)

| Perfil | Agenda | Diário e tarefas | Resumo e histórico | Observações |
|---|---|---|---|---|
| Profissional da clínica | só os próprios horários | sim | sim | cria, edita e arquiva |
| Outro profissional (conta "Dr. Exemplo Colega", de outra clínica) | horários de outro profissional: "Acesso restrito" | só os atendimentos e tarefas dele | a pré-consulta de outra clínica fica bloqueada | não vê observações de outra clínica |
| Recepção | todos os horários, sem abrir o prontuário | "Acesso restrito" | "Acesso restrito" | "Acesso restrito" |
| Responsável | | "Acesso restrito" | "Acesso restrito" | só as visíveis ("Recados da equipe") |
| Financeiro e administração | | "Acesso restrito" | "Acesso restrito" | "Acesso restrito" |

Na demonstração tudo fica na memória da aba e some ao recarregar a página.

## Testes executados

| Teste | Resultado |
|---|---|
| Regras (`test/clinical/workspace_logic_test.dart`): agenda, diário, tarefas, observações, organizador, linha do tempo, crescimento e alterações | 16/16 aprovados |
| Demonstração (`test/demo_workspace_test.dart`): permissões, diário, agenda, resumo, observações, histórico e telas a 1280 × 900 | 15/15 aprovados |
| Fluxo clínico existente (`test/demo_clinical_flow_test.dart`), ajustado para abrir o resumo ao finalizar | aprovado |
| Suíte completa `flutter test` | 741/741 aprovados |
| `flutter analyze` | 132 avisos informativos, os mesmos de antes; nenhum nos arquivos novos |
| Navegador automatizado, servidor local com a versão compilada `bd281dc` (etapas deste módulo) | 30/30 aprovados. Na versão anterior (`467d10e`), 1 falha: o campo de transcrição não era encontrado pelo leitor de acessibilidade; corrigido em `bd281dc` |
| Regressão completa no mesmo servidor local (todos os módulos) | 398/398 aprovados |

O teste no link público e as capturas desta pasta dependem da publicação da nova versão na demonstração.

### O que o navegador automatizado verifica

- **Computador, fluxo completo do profissional:**
  - agenda do dia com horários livres, semana com a contagem de livres, mês com navegação;
  - o horário da criança com dados essenciais e pré-consulta;
  - Iniciar consulta e a pré-consulta dentro do atendimento;
  - resumo com o rascunho do assistente "Aguardando revisão", sem sugestão de avaliação e com "Aplicar" bloqueado até a revisão;
  - aplicação revisada; avaliação e "Retorno em 15 dias" preenchidos;
  - consulta finalizada abre o resumo "Finalizada";
  - histórico com a consulta, a pré-consulta, consultas anteriores e crescimento;
  - registro de alterações com a finalização, o retorno e a revisão do rascunho, com o nome da profissional;
  - comparação com crescimento e desenvolvimento;
  - o horário volta à agenda como "Concluído" e ligado ao resumo.
- **Diário:**
  - realizadas, pendentes e faltas;
  - filtro por situação;
  - nova tarefa com prazo, concluída;
  - registrar falta atualiza a contagem.
- **Observações:**
  - etiquetas interna e visível;
  - nenhuma nota de outra clínica;
  - nova observação visível com data e autor;
  - a família vê só as visíveis.
- **Celular (390 × 844):** agenda da semana e diário.
- **Permissões:**
  - recepção, financeiro e responsável bloqueados no diário, histórico, resumo, observações e comparação;
  - profissional bloqueado no horário de outro profissional.

### O que não foi testado

- Aparelho físico: o celular foi simulado no Chrome.
- Transcrição por voz e modelo de IA real: não há IA ativa; o organizador usa regras fixas.
- Leitor de tela usado manualmente.
- Nada disso foi ligado ao Firestore do app real.

## Pendências e decisões para você

1. **App real:** as telas foram feitas na demonstração, e as regras em `lib/shared` estão prontas para reuso. Levar ao app real exige:
   - coleções no Firestore para tarefas, observações, adendos e registro de alterações;
   - regras de segurança: observação interna nunca legível pela família, registro de alterações só de inclusão;
   - ligar agendamento e atendimento pelo identificador.

   Tudo isso depende da sua autorização para produção.
2. **IA para transcrever ou organizar:** escolher o serviço, o consentimento da família para gravar ou transcrever (LGPD) e onde o áudio fica guardado. O fluxo de rascunho, revisão e confirmação já está pronto para receber o resultado.
3. **Revisão clínica:**
   - opções de retorno (7, 15, 30, 60 e 90 dias);
   - tipos de tarefa e prazos;
   - os textos dos avisos sobre observações visíveis à família.
