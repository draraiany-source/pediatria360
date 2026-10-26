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
