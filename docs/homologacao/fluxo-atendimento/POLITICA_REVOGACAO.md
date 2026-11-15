# Revogação de acesso: política atual e decisões pendentes

Este documento descreve o que as regras fazem **hoje** (25/10/2026). A
justificativa de "retenção legal" para manter leitura depois da revogação
**não foi validada juridicamente** e está registrada aqui como decisão
pendente. Nada nesta etapa ampliou acesso.

## O que deixa de valer na hora da revogação

Testado nas regras (`test/rules/etapa2_fluxo.test.js`,
`vinculo_crianca.test.js`) e no fluxo com Functions
(`tools/homologacao/etapa2_e2e.js`):

| Superfície | Depois da revogação |
| --- | --- |
| Cadastro e alergias (`users/{titular}/children/{criança}`) | Negado |
| Crescimento e vacinas | Negado (nenhuma concessão abre) |
| Novo atendimento, exame, triagem, resumo, desenvolvimento, suplementação | Negado |
| Edição de rascunho de atendimento | Negada |
| Listagem de registros pela criança (`where patientId == criança`) | Negada |
| Assinatura de atendimento (`signEncounter`), retificação, emissão de documento (`issueClinicalDocument`) | Negadas no servidor |
| IA clínica (`clinicalAssist`), consulta por voz (`startVoiceConsultation`, aplicar rascunho) | Negadas no servidor |
| Marcar consulta nova pela equipe | Negado (exige concessão ativa) |
| Desfazer a revogação pelo profissional | Negado |

## O que o autor ainda lê, e por qual regra

| Coleção | Regra de leitura (`firestore.rules`) |
| --- | --- |
| `encounters` | `resource.data.professionalId == request.auth.uid` |
| `clinical_documents` | `resource.data.professionalId == request.auth.uid` |
| `visit_summaries` | `resource.data.professionalId == request.auth.uid` |
| `lab_results` | `resource.data.professionalId == request.auth.uid` |
| `triage_records`, `development_records` | profissional verificado e `professionalId == uid` |
| `supplement_*` | autor (`professionalId`, `recordedBy` ou `createdBy`) |
| `voice_sessions` | `professionalId == uid` (escrita só pelo servidor) |
| `pre_visit_questionnaires` | `professionalId == uid` da consulta |
| `appointments` | `professionalId == uid` ou equipe de agenda da clínica |
| Storage `care/{criança}/registros/{autor}/...` | o autor (pelo caminho); outros leitores dependem do modelo `care_teams` (acesso justificado, vínculo ativo) |

O autor só lê **por id ou filtrando pelo próprio `professionalId`**. Ele não
lista por criança, não lê o que outros registraram, não lê o cadastro atual e
não grava mais nada.

## Decisões pendentes (suas ou jurídicas)

1. **Leitura pelo autor depois da revogação.** Manter (registro do próprio
   ato profissional), limitar a um período, ou passar a exigir pedido
   justificado e auditado. Hoje: mantém.
2. **Questionário pré-consulta.** O profissional da consulta lê o
   questionário que a família enviou para aquela consulta, mesmo sem
   concessão. É informação que a família escolheu enviar, mas cabe decidir se
   deve exigir pelo menos `summary`. Hoje: lê.
3. **Retenção legal.** Prazos e base legal da guarda do prontuário (por
   exemplo, normas do CFM e LGPD) precisam de validação jurídica antes de
   serem usados como justificativa.
4. **Exclusão a pedido do titular.** Hoje prontuário não se apaga
   (`allow delete: if false`). O fluxo de pedido de exclusão
   (`deletion_requests`) precisa de regra própria para dados clínicos.
5. **Aviso ao profissional.** Hoje ele descobre a revogação quando o acesso é
   negado (o app mostra a mensagem). Cabe decidir se deve haver notificação.

Até essas decisões, a regra fica como está; nenhuma leitura foi ampliada.
