# Fluxo de atendimento — registro de progresso

Versão de homologação. Nada aqui foi publicado em produção, nenhuma migração
foi aplicada e o aplicativo **não** está pronto para pacientes reais.
Todos os testes usam emuladores e dados fictícios.

## Etapa 1 — vínculo profissional–criança (commit `ea7c841`, local)

- Concessão com escopo (`summary`, `chartWrite`), validade e revogação.
- Registros clínicos exigem `chartWrite` ativo; ids da consulta protegidos.
- Equipe só marca consulta para criança já autorizada pelo titular.

## Etapa 2 — autorizações explícitas e fluxo da clínica (25/10/2026)

### O que mudou

1. **Sem concessão automática.** A Function `grantChildSummaryAccess`, que
   gravava acesso a partir de uma consulta pedida pela família, foi
   removida. Concessão antiga com origem `familyAppointment` deixou de valer
   nas regras e no servidor. No lugar há `checkChildAccess`, que só consulta.
   Pedir ou ter consulta não abre nada.
2. **Tela de autorizações do responsável** (Criança → "Profissionais
   autorizados"): escolher o profissional (das consultas da família ou pelo
   e-mail de um profissional verificado), limitar à clínica, escolher o nível
   ("Somente resumo" ou "Resumo e prontuário"), a validade (30, 90, 180 ou
   365 dias), confirmar, ver ativas, vencidas, revogadas e antigas sem efeito,
   e revogar. Cada nível mostra o que permite e o que não permite.
3. **Paciente novo pela recepção (solicitação provisória).** A recepção, a
   gestão ou o próprio profissional registram nome da criança, data de
   nascimento, responsável, e-mail e horário. Isso cria só um registro
   provisório (`clinic_intakes`), sem id de criança, sem prontuário e sem
   consulta. O horário fica reservado. Um código de convite de uso único
   (válido por 7 dias ou até o horário) é mostrado uma vez para envio ao
   responsável (o envio por WhatsApp continua simulado).
4. **Confirmação pela família** (Início → "Convite da clínica"): a conta
   precisa ter e-mail confirmado e igual ao informado à clínica. O responsável
   escolhe uma criança **já cadastrada na própria conta** (o convite não cria
   nem transfere criança) e decide se autoriza nada, só resumo, ou resumo e
   prontuário, com validade. A consulta é criada pelo servidor
   (`origin: clinicIntake`). Código errado conta tentativa: 10 erros por hora
   bloqueiam.
5. **Ids `pending_` eliminados.** "Novo paciente" na lista do profissional
   abre a solicitação provisória, e a nota de suplementação não grava mais em
   `pending_patient`.
6. **Perfis da clínica em conta comum.** Recepção, financeiro e gestão não
   precisam da marca de profissional verificado; vale o papel ativo no
   vínculo com a clínica, conferido nas regras e no servidor.
   - Recepção: agenda, recepção, solicitações e pendências.
   - Financeiro: financeiro, faturamento e baixa de pagamento.
   - Gestão: equipe (adicionar por e-mail, ativar e desativar), agenda,
     recepção e financeiro, sem acesso clínico.
   - Papel clínico só em conta de profissional.
7. **Origem da consulta.** `origin` e `intakeId` não podem ser forjados nem
   trocados. A equipe só grava `clinicStaff`, a família só grava
   `familyRequest`, e o servidor grava `familyBooking` ou `clinicIntake`.
8. **Diagnóstico somente leitura** de dados antigos e plano de
   reautorização: veja `MIGRACAO_REAUTORIZACAO.md`.
9. **Política de revogação** atual e decisões pendentes: veja
   `POLITICA_REVOGACAO.md`.

### Testes executados (25/10/2026)

| Conjunto | Resultado |
| --- | --- |
| Regras Firestore e Storage (emulador), 4 arquivos | 315 de 315 aprovados |
| Functions: `tsc`, Jest (5 suítes) | sem erros; 50 de 50 aprovados |
| Functions: ESLint | 0 erros, 1 aviso preexistente (`emr.ts`, `any`) |
| Fluxo completo nos emuladores (Auth, Firestore, Functions) | 76 de 76 conferências |
| Diagnóstico: autoteste no emulador | 17 de 17 contagens; nenhum documento alterado |
| Flutter: testes afetados (4 arquivos) | 70 de 70 aprovados |
| Flutter: suíte completa (sequencial, `-j 2`) | 877 de 877 aprovados (em 7 min) |
| `flutter analyze` nos arquivos alterados | 0 erros, 0 avisos; 9 informativos (8 `groupValue` descontinuado, padrão do projeto, e 1 aspas preexistente) |

O fluxo completo está em `tools/homologacao/etapa2_e2e.js`, com o resultado em
`tools/homologacao/etapa2_e2e_resultado.json`.

`demo_workspace_test` falhava aos sábados e domingos: o teste fixava o
relógio no dia de hoje, e a profissional da demonstração só atende de
segunda a sexta. Agora o teste abre a agenda no próximo dia útil. Ele passou
num domingo (25/10).

### Pendências e bloqueios

- Aplicar em homologação no Firebase (regras e Functions) só com sua
  autorização. Nada foi publicado.
- Rodar o diagnóstico no projeto real, em modo leitura, antes de decidir a
  reautorização. Veja o plano.
- Decisões da política de revogação (leitura pelo autor depois da revogação,
  questionário pré-consulta, retenção legal). Veja `POLITICA_REVOGACAO.md`.
- Envio real do convite (WhatsApp ou e-mail) continua simulado.
- A confirmação de e-mail depende do fluxo de verificação do Firebase Auth
  já existente no app.
- Os commits das etapas 1 e 2 são locais; não houve push.

## Etapa 3: gestão integrada, agenda inteligente, anamnese e Central de IA (26 e 27/10/2026)

Situação: **pronto para homologação com dados fictícios**, não para uso com
pacientes reais. Nada foi publicado. Nenhuma mensagem, cobrança ou campanha
real foi executada, e nenhuma migração foi aplicada.

### O que mudou, por módulo

| Módulo | Já existia | Corrigido | Implementado | Situação |
| --- | --- | --- | --- | --- |
| Agenda | Telas da agenda, status, telemedicina, `bookAppointment` | O cliente não grava mais horário, sala ou status terminal direto no banco; reabrir consulta cancelada ou falta foi bloqueado nas regras; o cancelamento exige motivo | `scheduling.ts`: grade, pausas, férias e bloqueios; travas por recurso em transação; recorrência; lista de espera com reserva temporária; histórico de mudanças; lembretes por versão | Testado no emulador |
| Lembretes | Lembrete agendado antigo (`notifications.ts`) | A remarcação cancelava também o aviso de mudança e o formulário da versão nova (encontrado no teste de ponta a ponta) | Fila `message_queue` com chave idempotente, nova checagem no envio, novas tentativas e cancelamento ao remarcar ou cancelar | Testado no emulador |
| CRM | `clinicCrm` (tela) | O CRM quebrava com pedido da família sem horário | Contatos derivados das consultas, estágios, duplicados, fusão com revisão (nada é apagado), sem conteúdo clínico | Regras testadas; fusão não testada de ponta a ponta |
| Anamnese | Questionário pré-consulta antigo | O questionário antigo só aparece em consulta sem clínica | Modelos por especialidade e idade, campos condicionais, rascunho, envio imutável, novas versões sem sobrescrever, reaproveitamento com origem, data e confirmação, resumo preliminar com campos faltantes | Testado no emulador |
| Financeiro | Lançamentos no cliente (`finance_receivables`) | O pagamento de cobrança da clínica passa pelo servidor | `finance.ts`: operações idempotentes, recibo único, estorno só pelo financeiro, webhook assinado; "pago" nunca vem do retorno da página | Testado no emulador (sem provedor real) |
| Comunicação e WhatsApp | Não havia | n/a | Provedor oficial (Graph API), assinatura do webhook, opt-out, caixa de entrada com atendimento humano; o telefone não autentica ninguém | **Bloqueado por credenciais** (ver abaixo) |
| Automações | Não havia | n/a | Regras por tipo, pausa geral, horários permitidos, limite diário, execução manual pela gestão | Testado no emulador (só aviso no app) |
| Marketing | Não havia | n/a | Rascunho, prévia sem nomes, aprovação por outra pessoa, limite de frequência, supressão, descadastro; segmentação clínica recusada | Testado no emulador |
| Central de IA | Não havia | n/a | Indicadores determinísticos com período, filtros e fonte; perguntas só da lista; financeiro restrito a indicadores financeiros; cota por usuário | Testado no emulador |
| Gravação e transcrição | `voice.ts` e telas de voz | n/a | Atalho "Transcrever consulta" no painel de gestão (só papel clínico, com a função ligada) | Verificada a existência; não retestada nesta etapa |
| Interface | Painéis por perfil | n/a | `/gestao` com 10 módulos por perfil, estados de carregando, erro e tentar de novo, painel de custos | Analisador sem problemas; testes de visibilidade |

### Telas por perfil (`/gestao`)

- **Gestão (clinicAdmin):** os 10 módulos: agenda, CRM, anamnese,
  atendimento, financeiro, comunicação, automações, marketing, Central de IA
  e configurações (custos e limites).
- **Recepção:** agenda, CRM (sem conteúdo clínico), comunicação e
  automações. Nas automações, a recepção acompanha e cancela envios; mudar
  regras, pausar ou executar a fila é só da gestão (conferido no servidor).
- **Financeiro:** financeiro e Central de IA restrita a indicadores
  financeiros.
- **Profissional:** agenda, anamnese das próprias consultas, atendimento e
  "Transcrever consulta".
- **Família:** fora de `/gestao`. No cartão da consulta: confirmar presença,
  cancelar (pelo servidor, dentro do prazo da clínica) e "Pré-consulta
  (anamnese)".

### Testes executados

| Conjunto | Resultado |
| --- | --- |
| Regras Firestore e Storage (emulador), 5 arquivos | 346 de 346 aprovados |
| Functions: `tsc` e Jest (12 suítes) | sem erros; 102 de 102 aprovados |
| Functions: ESLint | 0 erros, 1 aviso preexistente (`emr.ts`) |
| Ponta a ponta nos emuladores (Auth, Firestore, Functions) | 88 de 88 conferências |
| `flutter analyze` em `lib/features/management` e no teste | sem problemas |
| Flutter: suíte completa (`-j 2`) | 885 de 885 aprovados (em 5 min) |

O roteiro de ponta a ponta está em `tools/homologacao/etapa3_e2e.js`, com o
resultado em `tools/homologacao/etapa3_e2e_resultado.json`. Ele confere:

- duas reservas simultâneas no mesmo horário: só uma passa;
- a remarcação cancela os lembretes antigos, mantém os novos e libera o
  horário antigo;
- lista de espera sem duplicar, com convite e reserva temporária;
- o assistente só reserva depois da confirmação e revalida o horário;
- pagamento repetido gera um único recibo, e o webhook sem assinatura é
  recusado;
- executar a fila de novo não duplica avisos, e nenhum WhatsApp aparece como
  enviado;
- campanha com consentimento, aprovação por outra pessoa e descadastro;
- perfis da Central de IA, cota e perda de acesso ao inativar o vínculo;
- valores da IA iguais aos do banco;
- anamnese imutável depois do envio, invisível para a recepção e lida como
  relato.

### Não executado nesta etapa

- Envio real por WhatsApp, pagamento real e chamadas à IA (Anthropic): faltam
  credenciais, e o uso real não foi autorizado.
- Fusão de duplicados do CRM e caixa de entrada do WhatsApp de ponta a ponta:
  só a lógica pura e as regras foram testadas.
- Eventos do provedor de pagamento fora de ordem ou repetidos pelo webhook:
  só os testes unitários de `financeCore`, porque o webhook exige o segredo.
- Gravação e transcrição: sem reteste nesta etapa.
- Testes visuais (celular e computador) das telas novas.

### Integrações e credenciais pendentes

- WhatsApp Cloud API:
  - `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_APP_SECRET` e
    `WHATSAPP_VERIFY_TOKEN`;
  - número aprovado e modelos aprovados por tipo de mensagem;
  - habilitar na clínica.
  
  Sem isso, a tela mostra exatamente o que falta e nenhum envio é simulado.
- Provedor de pagamento: `PAYMENT_WEBHOOK_SECRET` e a integração do
  provedor. Sem o segredo, o webhook responde 503.
- IA: `ANTHROPIC_API_KEY`, já usada por `voice.ts`, `clinical.ts` e
  `aiChat`. A transcrição é feita no aparelho; o servidor só estrutura o
  rascunho.
- Condições de uso de dados dos provedores (Anthropic, Meta/WhatsApp,
  provedor de pagamento): **não verificadas nesta etapa**. Antes de usar
  dados reais, confirme e registre por escrito que os dados enviados não são
  usados para treinar modelos, além da retenção e da região de
  processamento.

### Custos estimados (premissas ajustáveis em Configurações)

Estas são premissas, não fatura: IA R$ 0,05 por requisição, transcrição
R$ 0,04 por minuto, armazenamento R$ 0,0015 por MB por mês, WhatsApp
R$ 0,08 por mensagem de utilidade. O aviso no app não tem custo.

Limites padrão por clínica e por mês: 2.000 requisições de IA, 1.200 minutos
de áudio, 5.000 MB e 3.000 mensagens; além disso, 100 requisições de IA por
usuário por dia. Nesses limites, o teto mensal estimado fica em cerca de
R$ 100 de IA, R$ 48 de áudio, R$ 7,50 de armazenamento e R$ 240 de WhatsApp.

### Pendências por impacto

1. **Alto:** a recepção ainda grava direto os status de fluxo "em
   atendimento" e "concluído" (comportamento anterior). Mover para o
   servidor.
2. **Alto:** lançamentos financeiros antigos (`finance_receivables` sem
   clínica) ainda são gravados pelo cliente. Migrar para as operações do
   servidor.
3. **Alto:** credenciais e condições dos provedores (acima).
4. **Médio:** fusão do CRM e caixa de entrada sem teste de ponta a ponta.
5. **Médio:** índices novos em `firestore.indexes.json` precisam ser
   publicados com as regras quando você autorizar.
6. **Baixo:** anexos da anamnese: as regras do Storage estão prontas, mas a
   tela da família ainda não envia arquivos.

### Passos de homologação

1. Publicar regras, índices e Functions num projeto de homologação
   (não produção), com sua autorização.
2. Criar uma clínica fictícia com gestão, recepção, financeiro e
   profissional, e configurar a grade em `professional_schedules`.
3. Repetir os cenários do roteiro de ponta a ponta pelas telas, no celular e
   no computador.
4. Configurar WhatsApp e pagamento em modo de teste dos provedores e validar
   os webhooks.
5. Revisar a matriz e as pendências antes de qualquer uso real.

Commit local; não houve push nem publicação.

## Auditoria tela por tela (28/10/2026)

Relatório completo: `docs/homologacao/auditoria-telas/RELATORIO.md`
(matriz em `INVENTARIO.md`, capturas em `evidencias/`).

- Corrigidos e retestados pela interface: perda de dados da criança na web,
  mistura de estado entre consultas, Paciente 360 recusado para o médico
  autorizado, triagem com criança digitada e sem clínica, financeiro com
  permissão negada, contas a pagar sem confirmação, agenda vazia para a
  recepção, botão "Novo atendimento" enganoso, aviso de alterações não salvas.
- Corrigidos com teste automatizado ou só no código: recepção com conta de
  profissional no prontuário, rotas dos avisos automáticos, contas a receber,
  nome da clínica nos documentos.
- Principais pendências: agendar paciente já da clínica e agendamento pela
  família não têm tela; atendimento, documentos e transcrição não exercitados
  pela interface.
- Testes: Flutter 887 aprovados; Functions 104/104; regras não alteradas.

Commit local; não houve push nem publicação.