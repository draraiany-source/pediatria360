# Dados antigos: diagnóstico, reautorização e plano de migração

Este documento é um plano. Nenhuma migração foi aplicada.

## Princípios

- Nenhuma concessão antiga vira consentimento novo automaticamente.
- `requestedBy` gravado antes da etapa 1 **não** prova que a família pediu
  nada, porque o app permitia gravá-lo. Não serve para conceder acesso.
- Quem decide o acesso é o responsável titular, pela tela de autorizações ou
  pelo convite da clínica.
- Sem apagar dados clínicos. Retenção e exclusão dependem de decisão
  jurídica (veja `POLITICA_REVOGACAO.md`).

## 1. Diagnóstico (somente leitura)

Script: `tools/diagnostics/child_access_diagnostic.js`. Ele só lê, e fora do
emulador exige `--project <id> --confirm-read-only`. A saída traz só
contagens e caminhos de documentos: nenhum nome, e-mail ou dado clínico.

```
node tools/diagnostics/child_access_diagnostic.js --project <id> --confirm-read-only --out diagnostico.json
```

| Indicador | O que significa | Efeito hoje |
| --- | --- | --- |
| `concessaoAutomaticaPorConsulta` | Origem `familyAppointment`, gravada pela Function removida | Não vale |
| `concessaoSemOrigemValida`, `concessaoSemEscopoValido`, `concessaoSemValidade` | Formato antigo | Não vale |
| `concessaoVencida`, `concessaoRevogada` | Fim natural ou decisão do titular | Não vale |
| `concessaoAutorNaoTitular` | Autor diferente do titular | Só vale se a origem for válida; revisar |
| `concessaoEmCriancaSemRegistro`, `concessaoEmCriancaDeOutroTitular` | Criança sem `child_registry` ou de outro dono | Não vale nas regras (dono pelo registro) |
| `consultaSemOrigemRegistrada`, `consultaComRequestedBySemProva` | Consulta anterior à etapa 2 | Não concede nada; só agenda |
| `consultaTitularDivergente`, `consultaSemCrianca`, `consultaComIdProvisorio`, `consultaCriancaSemRegistro` | Vínculo inconsistente | Revisar com a clínica e a família |
| `registroClinicoComIdProvisorio`, `registroClinicoCriancaSemRegistro` | Registro feito em id `pending_` ou de criança sem registro | Fica só com o autor; não se associa sozinho |
| `criancaSemRegistro`, `criancaComDonoDivergente` | Cadastro sem `child_registry` | Profissionais não acessam |
| `vinculoSemDocumentoNaClinica`, `vinculoComIdsDivergentes`, `vinculoAtivoDivergente`, `vinculoPapelDivergente` | As duas pontas do vínculo não batem | Vale o documento da clínica; corrigir pela gestão |
| `papelClinicoEmContaNaoProfissional`, `papelClinicoSemVerificacao` | Papel clínico sem conta de profissional verificado | Sem acesso clínico; corrigir pela gestão |

Autoteste no emulador (dados fictícios; também confere que nenhum documento
muda):

```
firebase emulators:exec --only firestore --project demo-pediatria360 "node tools/diagnostics/child_access_diagnostic.selftest.js"
```

## 2. Reautorização

1. A partir do diagnóstico, listar por titular as crianças com consultas
   ativas cujo profissional não tem concessão válida.
2. O app avisa o responsável (notificação no app; e-mail ou WhatsApp quando
   o envio real for aprovado): "A clínica X pede acesso para o profissional
   Y. Revise em Profissionais autorizados."
3. O responsável concede pela tela de autorizações (origem `guardian`), ou a
   clínica gera um convite novo e o responsável aceita (`guardianInvite`).
4. Enquanto isso, o profissional vê a consulta na agenda, mas não abre o
   cadastro nem o prontuário. O app mostra a mensagem para pedir a
   autorização.

Nenhum passo grava concessão em nome do responsável.

## 3. Migração (quando autorizada)

A migração **só marca** documentos antigos para auditoria. Não concede, não
apaga e não move registros clínicos.

| Passo | Como |
| --- | --- |
| Simulação | Rodar o diagnóstico, gerar a lista do que seria marcado (por exemplo `legacyReviewedAt`, `legacyStatus: 'semEfeito'` em concessões antigas) e revisar com você. Sem escrita. |
| Backup | `gcloud firestore export gs://<bucket-de-backup>/<data>` do banco inteiro, antes de qualquer escrita. Guardar o caminho e a hora. |
| Execução | Script com Admin SDK, em lotes, gravando só os campos de marcação e registrando cada alteração em `audit_log`. Exige `--confirm` e o caminho do backup. |
| Verificação | Rodar de novo o diagnóstico e as conferências de leitura (os testes de regras e o fluxo completo contra o ambiente de homologação). |
| Rollback | Os campos de marcação são novos e não alteram regras. Basta removê-los pela lista gravada no `audit_log`. Em caso grave, `gcloud firestore import` do backup, sabendo que isso desfaz também o que foi gravado depois. |

Concessões `familyAppointment` já não valem pelas regras desde a etapa 2.
Marcá-las é só organização; não é necessário para a segurança.

## 4. Ids `pending_` antigos

Registros com `pending_` (prontuário criado antes do cadastro da família) não
se ligam a nenhuma criança automaticamente. Proposta para decidir:

1. O profissional autor gera, pela clínica, uma solicitação provisória para
   a família.
2. Depois que o responsável aceita e autoriza o prontuário, uma operação de
   servidor, auditada, associa o registro antigo à criança escolhida, e só
   com confirmação explícita do titular.

Essa operação ainda não foi implementada.
