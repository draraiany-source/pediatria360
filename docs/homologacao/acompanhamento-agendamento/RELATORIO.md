# Acompanhamento de pacientes, lembretes e agendamento assistido: relatório de homologação

Código: commits `eeb5239`, `0b422bc`, `c907986` e `cbeed24` na branch `feat/area-profissional`.
Todos os nomes, telefones e consultas usados são fictícios. O app real, o Firebase e as lojas não foram alterados. Nenhuma mensagem de WhatsApp foi enviada.

## O que existia

- **App real:**
  - regras de conflito de agenda em `lib/features/clinic/domain/agenda_scheduling.dart`;
  - a função `bookAppointment` (`functions/src/commerce.ts`), que grava o agendamento dentro de uma transação;
  - o lembrete de consulta por **notificação no aparelho** (`checkAppointmentReminders` em `functions/src/notifications.ts`, na véspera e 1 hora antes);
  - o campo `whatsapp` no cadastro da clínica, mas nenhum envio por WhatsApp.
- **Demonstração:** agenda do dia e pré-consulta. Não havia:
  - painel de acompanhamento;
  - critérios configuráveis;
  - lembretes ao responsável e respostas da família;
  - agendamento feito pela família;
  - pendências de contato manual para a recepção.

## O que foi implementado

As regras ficam em `lib/shared/scheduling/` (código puro, sem Flutter nem Firebase), para servirem à demonstração e ao app real:

| Arquivo | Conteúdo |
|---|---|
| `follow_up.dart` | indicadores Frequentes, Inativos e Retorno próximo, com critérios da clínica |
| `reminders.dart` | intervalos de envio, consentimento, preferência de canal, texto discreto, status |
| `slots.dart` | horários livres a partir do expediente, antecedência mínima e prazos de remarcação/cancelamento |
| `agenda_conflicts.dart` | as regras de conflito que estavam em `features` (o arquivo antigo reexporta este) |
| `assistant_text.dart` e `booking_assistant.dart` | a conversa de agendamento assistido |

### Painel de acompanhamento (`/acompanhamento`)

- **Indicadores:** Frequentes, Inativos e Retorno próximo, com a lista de cada um.
- **Filtros:** por profissional e por período (3, 6, 12 ou 24 meses).
- **Inativos:** quem já tem consulta marcada não conta como inativo; a tela avisa quantos ficaram de fora por isso.
- **Contato:** a recepção registra tentativas de contato (com resultado) e agenda pelo mesmo assistente da família.
- **Critérios** (`/acompanhamento/criterios`), com valores sugeridos:

  | Critério | Valor sugerido |
  |---|---|
  | Inativo | sem consulta há 6 meses |
  | Retorno próximo | nos próximos 15 dias |
  | Frequente | 3 consultas em 12 meses |

  Só a administração altera; a recepção só consulta.
- **Profissional:** vê só os próprios pacientes, sem registrar contato.

### Lembretes de consulta (`/lembretes`)

- **Intervalos:** a administração escolhe quando enviar; o padrão é 2 dias, 1 dia e 2 horas antes.
- **Sistema parado:** se mais de um horário venceu, sai só o lembrete mais próximo da consulta, nunca vários seguidos.
- **Bloqueios:** sem consentimento, com preferência por outro canal ou com número inválido, **não envia**. O caso vira uma pendência de "Contato manual" para a recepção. Falha de entrega também vira pendência, uma só por consulta.
- **Texto discreto:** só o primeiro nome da criança, a data, a hora e a modalidade. Nunca motivo, queixa, exame ou especialidade.
- **Registro de envios:** destinatário mascarado (por exemplo "•••• 0001") e status enviado, entregue, lido ou falhou.
- **Respostas da família** pelos botões do lembrete:
  - **Confirmar** marca "Confirmado pela família (WhatsApp)" na agenda da recepção e do profissional;
  - **Reagendar** cria uma pendência para a recepção e sinaliza "A família pediu outro horário" no agendamento;
  - **Cancelar** dentro do prazo libera o horário; fora do prazo vira pedido para a recepção.
- **Envio na demonstração:** o envio é **simulado** ("Enviar lembretes pendentes agora") e a família vê a mensagem em "Mensagens da clínica" (`/mensagens`), onde também escolhe se quer receber lembretes e por qual canal.

### Agendamento assistido (`/agendar`)

- **Conversa guiada:**
  - pergunta a criança, o motivo, o tipo de consulta, a modalidade, o profissional e a preferência de dia e período;
  - entende frases como "próxima semana" (a partir da segunda seguinte), "de manhã" e dias da semana;
  - mostra **só horários livres**.
- **Confirmação:**
  - nada é gravado antes do "Resumo do agendamento" e do botão **Confirmar agendamento**;
  - se o horário acabou de ser ocupado, pede para escolher outro.
- **Depois de agendar:**
  - oferece **Preencher pré-consulta**, já com o motivo informado;
  - a agenda da recepção mostra "Agendado pela família (assistente)".
- **Remarcar e cancelar:** pelo assistente, respeitando os prazos, que são sugestões:
  - antecedência mínima de 2 horas;
  - até 60 dias à frente;
  - remarcar até 24 h antes;
  - cancelar até 12 h antes.

  Fora do prazo, o pedido vai para a recepção. Cada remarcação e cancelamento fica no histórico do agendamento com quem fez.
- **Possível urgência:** frases como "falta de ar" ou "lábios roxos" interrompem o agendamento. O assistente orienta procurar o pronto-socorro ou ligar 192, sem diagnóstico e sem oferecer horários.
- **Encaminhamento:** "Falar com a recepção" cria a pendência "Encaminhado pelo assistente".
- **Sem IA generativa:** o assistente funciona com regras fixas e nenhum texto sai para um serviço externo.

### Proteção de acesso (na demonstração)

| Perfil | Acompanhamento | Lembretes | Agendar | Mensagens |
|---|---|---|---|---|
| Responsável | "Acesso restrito" | "Acesso restrito" | só as próprias crianças | só as próprias |
| Recepção | vê, filtra, registra contato | envia (simulado) e trata pendências | agenda por qualquer família | "Acesso restrito" |
| Administração | altera critérios | altera intervalos | | |
| Profissional | só os próprios pacientes, sem contato | | "Acesso restrito" | "Acesso restrito" |
| Financeiro | "Acesso restrito" | "Acesso restrito" | "Acesso restrito" | "Acesso restrito" |

## WhatsApp: preparado, não ativado

O envio real usa a **API oficial da Meta (WhatsApp Business Platform, Cloud API)**. O código está em `functions/src/whatsapp.ts`:

- modelo de mensagem `lembrete_consulta_v1` com os botões Confirmar, Reagendar e Cancelar;
- envio pela Graph API;
- validação do webhook (desafio de verificação e assinatura `X-Hub-Signature-256`);
- leitura dos status e das respostas.

O arquivo **não é exportado** em `functions/src/index.ts`: nenhuma função foi implantada e nenhuma mensagem sai. Na demonstração, o envio é um simulador.

### O que falta para ativar (depende de você)

1. Verificação da empresa no Meta Business Manager.
2. Conta WhatsApp Business (WABA) com o número oficial da clínica e o respectivo **Phone Number ID**.
3. Aprovação do modelo `lembrete_consulta_v1` pela Meta (categoria utilidade, pt_BR, 5 variáveis e 3 botões de resposta rápida).
4. Token permanente de usuário do sistema, App Secret e um token de verificação do webhook.
5. Cadastro desses quatro valores como segredos do Firebase:
   - `WHATSAPP_TOKEN`
   - `WHATSAPP_PHONE_NUMBER_ID`
   - `WHATSAPP_APP_SECRET`
   - `WHATSAPP_VERIFY_TOKEN`
6. Criação dos gatilhos (envio agendado e webhook), exportação em `index.ts` e **sua autorização para implantar**.
7. Texto de consentimento (LGPD) para o responsável aceitar receber lembretes pelo WhatsApp, com a forma de revogar.

## Lacuna encontrada no app real

A função `bookAppointment` só recusa um agendamento com **exatamente o mesmo horário de início** (`startsAt ==`) para o profissional. Ela não considera a duração: uma consulta de 40 minutos às 9h00 não impede outra às 9h20. As regras de sobreposição por duração já existem em `lib/shared/scheduling/agenda_conflicts.dart` e são usadas pela demonstração, mas não pela função. A correção não foi feita porque exige implantar a função em produção.

## Testes executados

| Teste | Resultado |
|---|---|
| Regras de acompanhamento (`test/scheduling/follow_up_test.dart`) | 15/15 aprovados |
| Regras de lembretes (`test/scheduling/reminders_test.dart`) | 11/11 aprovados |
| Horários livres e assistente (`test/scheduling/slots_assistant_test.dart`) | 19/19 aprovados |
| Fluxo da demonstração (`test/demo_scheduling_test.dart`) | 29/29 aprovados |
| WhatsApp e agendamento nas funções (`functions`: `whatsapp.test.ts` e `booking.test.ts`, `jest`) | 20/20 aprovados |
| Suíte completa `flutter test` (inclui o módulo seguinte) | 743/743 aprovados |
| `flutter analyze` | 132 avisos informativos, os mesmos de antes |
| Navegador automatizado, servidor local com a versão compilada `bd281dc` (etapas deste módulo) | 48/48 aprovados |
| Regressão completa no mesmo servidor local (todos os módulos) | 398/398 aprovados |
| Regressão completa no link público, fonte `bd281dc` | 395/398. As 3 falhas eram deste módulo e estão explicadas abaixo; corrigidas em `cbeed24` |
| Regressão completa no link público, fonte `cbeed24` | 398/398 aprovados (48/48 neste módulo) |
| Etapas de agenda no link público, fonte `c2b9c66` (ajuste visual do seletor da agenda) | 60/60 aprovados |

Versão publicada na demonstração: fonte `c2b9c66`, Pages `ca30ca6`.

### Falha encontrada no link público e corrigida

Na primeira rodada pública, o painel mostrou 3 inativos em vez de 2. O teste local tinha passado de manhã; no público, essa etapa rodou depois das 14h30. A regra só considerava "com consulta marcada" quem tinha consulta **depois do horário atual**. Assim, uma criança sem consultas havia mais de 6 meses, mas com consulta hoje às 14h30, passava a contar como inativa a partir desse horário, mesmo estando na clínica. Agora qualquer consulta de hoje ainda não concluída conta como marcada (`follow_up.dart` e `demo_scheduling.dart`). Foram incluídos dois testes que falham sem a correção: um das regras e outro do painel às 18h. Os testes da demonstração fixavam o relógio às 7h, por isso não pegaram o problema.

### O que o navegador automatizado verificou

- **Computador:**
  - administração configura os intervalos;
  - família agenda pelo assistente (só horários livres, resumo e confirmação explícita);
  - pré-consulta aberta com o motivo;
  - recepção vê o horário marcado pela família;
  - rodada de lembretes com destinatário mascarado;
  - falha e preferência viram contato manual;
  - família recebe a mensagem discreta e confirma;
  - recepção e profissional veem a confirmação;
  - família remarca;
  - família pede reagendamento e a recepção remarca pela agenda;
  - cancelamentos pela recepção, pela família dentro do prazo e fora do prazo.
- **Painel:**
  - indicadores iniciais;
  - lista de inativos sem quem já tem consulta;
  - filtro por profissional e por período;
  - contato registrado;
  - recepção agenda um inativo, que sai da lista;
  - administração altera os critérios e o indicador é recalculado;
  - recepção só consulta os critérios;
  - profissional vê só os próprios pacientes.
- **Celular:**
  - cartão de mensagens no Início da família;
  - preferência de contato;
  - orientação de urgência sem horários;
  - encaminhamento à recepção.
- **Permissões:** os bloqueios da tabela acima.

Capturas nesta pasta:
- `ag01` a `ag16`: agendar, lembrar, confirmar, reagendar e cancelar (fonte `c2b9c66`);
- `ag20` a `ag24`: painel e critérios (fonte `cbeed24`);
- `ag30` a `ag33`: celular (fonte `cbeed24`).

### O que não foi testado

- Envio real pelo WhatsApp: não há credenciais nem autorização.
- Aparelho físico: o celular foi simulado no Chrome.
- A correção da lacuna do `bookAppointment` no app real.

## Pendências e decisões para você

1. **Critérios e prazos:** confirme ou ajuste os valores sugeridos:
   - inativo após 6 meses, retorno próximo em 15 dias, frequente com 3 consultas em 12 meses;
   - lembretes 2 dias, 1 dia e 2 horas antes;
   - remarcar até 24 h e cancelar até 12 h antes.
2. **Texto do lembrete e lista de sinais de urgência:** precisam da sua revisão clínica.
3. **WhatsApp:** as credenciais e aprovações da lista acima, e a autorização para implantar.
4. **`bookAppointment`:** autorizar a correção da verificação por duração no app real.
