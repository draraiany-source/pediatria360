> **HISTÓRICO — não é o documento atual.**
>
> Auditoria de classificação FUNCIONAL REAL/PARCIAL/MOCK por módulo, das versões 33-35.
>
> Para o estado atual do projeto, use:
> - `README.md` — visão geral
> - `ANTES_DE_COMPILAR.md` — o que verificar/rodar antes da primeira compilação real
> - `BLOQUEADORES_PRODUCAO.md` — o que falta para produção, categorizado
> - `CHECKLIST_PUBLICACAO_FINAL.md` — checklist de publicação
> - `CHANGELOG_V40.md` (ou o mais recente) — o que mudou, versão a versão
>
> Este arquivo fica como registro do que foi decidido e por quê — não é
> atualizado desde que virou histórico, então números e status aqui podem
> estar desatualizados.

---

# AUDITORIA_FINAL.md — Pediatria 360

Verificado contra o código nesta sessão — não é cópia de relatório anterior.
Cada linha da tabela tem o comando que a confirma, para você poder repetir a
checagem.

**O que esta auditoria NÃO é:** validação por compilador. `flutter analyze`,
`flutter test`, `npx tsc --noEmit`, os testes do emulador Firebase e os
builds Android/iOS nunca rodaram — este ambiente não tem Flutter, Dart, nem
acesso à rede. Os 223 testes Dart e 63 de regra foram escritos e as
asserções verificadas manualmente (com Python, fora do runner do Flutter),
o que é diferente de "passar no `flutter test`". Essa é a maior lacuna desta
auditoria, e fica registrada aqui, não escondida.

---

## Taxonomia usada

| Rótulo | Significado |
|---|---|
| **FUNCIONAL REAL** | Código + regra + teste, ponta a ponta, verificado |
| **FUNCIONAL PARCIAL** | Funciona, mas com lacuna concreta identificada abaixo |
| **MOCK/PLACEHOLDER** | Existe só como exemplo, dado de desenvolvimento |
| **SEM BACKEND** | Tela ou lógica sem Function/regra correspondente |
| **DESATIVADO** | Existe, funciona, mas está atrás de flag de propósito |
| **PENDENTE** | Não existe ainda |
| **BLOQUEADOR DE PRODUÇÃO** | Não pode ir ao ar como está |

---

## Autenticação

| Item | Classificação | Evidência |
|---|---|---|
| Login e-mail/senha | FUNCIONAL REAL | `signInWithEmailAndPassword` chamado de verdade |
| Login Google | FUNCIONAL REAL | `GoogleAuthProvider`/`_googleSignIn.signIn()` real, não placeholder |
| Recuperação de senha | FUNCIONAL REAL | `sendPasswordResetEmail` do Firebase Auth |
| Consentimento LGPD no cadastro | FUNCIONAL REAL | `showConsentSheet` bloqueia `completeOnboarding`; `recordConsent` valida termos+privacidade+finalidades no servidor |
| Biometria / Face ID / 2FA | PENDENTE | `local_auth` foi removido do projeto por estar sem uso — não é lacuna, é decisão registrada |

## Perfil

| Item | Classificação | Evidência |
|---|---|---|
| Edição de nome/telefone/especialidade | FUNCIONAL REAL | 4 camadas (`UpdateProfileParams` → `AuthRepository` → data source → Firestore) ligadas, `updateProfileProvider` tem consumidor real |
| Alterar CRM/papel/verificação pelo próprio usuário | **Corretamente PENDENTE** | Ausência é a proteção — CRM é dado verificado pela equipe, não deveria ser autoeditável |
| Foto de perfil | PENDENTE, documentado | `image_picker` removido por não ter upload funcional — decisão, não esquecimento |

## Prontuário / atendimento

| Item | Classificação | Evidência |
|---|---|---|
| Lista de pacientes, busca, filtro | FUNCIONAL REAL | `professional_patients_screen.dart` |
| Linha do tempo do paciente | FUNCIONAL REAL | `patient_timeline_screen.dart`, funde atendimento/documento/exame |
| Anamnese, exame físico, sinais vitais | FUNCIONAL REAL | `encounter_editor_screen.dart`, salvamento automático |
| Diagnóstico com CID | FUNCIONAL PARCIAL | Aceita código digitado; **não há busca oficial por descrição** — item 61 do seu pedido anterior, ainda pendente |
| Assinatura/fechamento | FUNCIONAL PARCIAL, com aviso correto | Sela e tranca com hash; a UI e o PDF **já avisam explicitamente** que isso não é ICP-Brasil — não apresenta como assinatura jurídica válida |
| Retificação sem apagar | FUNCIONAL REAL | `amendsEncounterId`, texto original preservado |
| PDF de documentos (receita, atestado, etc.) | FUNCIONAL REAL | 6 tipos, cancelamento sem apagar histórico |

## Crescimento

| Item | Classificação | Evidência |
|---|---|---|
| Cálculo de escore Z / percentil | FUNCIONAL REAL (matemática) | LMS testado numericamente |
| Dado de referência (LMS) | **BLOQUEADOR DE PRODUÇÃO** | `who_reference.json` é aproximado, não a tabela oficial da OMS |
| Aviso visível na tela | **Corrigido nesta sessão** | Antes: aviso só existia em metadado de JSON que nenhum código lia. Agora `WhoReference.warning` é parseado do arquivo e `DataWarningBanner` aparece acima do gráfico, no primeiro lugar que os olhos passam |

## Vacinação

| Item | Classificação | Evidência |
|---|---|---|
| Calendário PNI | FUNCIONAL PARCIAL | Estrutura funciona; conteúdo precisa ser conferido contra gov.br antes de publicar |
| Aviso visível na tela | **Corrigido nesta sessão** | Mesmo problema do crescimento: aviso só em comentário de código, nunca na tela. Agora `PniCalendar.warning` aparece via o mesmo `DataWarningBanner` |
| Fonte/versão registrada como dado estruturado | PENDENTE | Existe como comentário e agora como `String` constante — não como campo versionado (data de revisão, número de versão) que sobreviva a uma atualização de conteúdo |

## Gamificação

| Item | Classificação | Evidência |
|---|---|---|
| XP por abertura diária | FUNCIONAL REAL | `registerDailyActivity` chamada no listener de sessão de `main.dart`, idempotente por dia |
| XP por conclusão de aula/conteúdo | PENDENTE | `awardXp` nunca chamada pelo cliente — confirmado de novo nesta auditoria (só aparece em comentário) |

## IA

| Item | Classificação | Evidência |
|---|---|---|
| Chave de API no cliente | Confirmado ausente | Zero ocorrência de `ANTHROPIC_API_KEY`/`sk-ant-` em `lib/` |
| Cota/rate limit em `aiChat` | FUNCIONAL REAL | Cota diária por plano |
| Cota/rate limit em `clinicalAssist`/`parseLabText` | FUNCIONAL REAL | Corrigido em rodada anterior desta conversa — as duas únicas funções que chamavam LLM sem proteção agora compartilham cota de 300/dia |
| `parseLabText` — interface | DESATIVADO, documentado | Function funciona; não há tela de importação de laudo na v1.0, por decisão registrada |

## Telemedicina

| Item | Classificação | Evidência |
|---|---|---|
| `bookAppointment` | FUNCIONAL REAL (backend) | Existe, valida, transaciona |
| `joinConsultation` | **DESATIVADO de propósito** | Valida autorização real (só paciente/profissional do agendamento específico), então lança `unimplemented` — não existe provedor de vídeo contratado |
| Botão de agendar na UI | DESATIVADO, sem botão falso | `AppConfig.videoConsultationEnabled = false`; aviso visível antes do toque, não erro depois |
| Agenda do profissional | FUNCIONAL REAL (com uma peça pendente) | `TelemedicineRepository` lê/grava disponibilidade no formato que `getAvailability` já espera; `professional_agenda_screen.dart` mostra consultas, confirma, cancela, edita disponibilidade. "Iniciar atendimento" liga de verdade ao prontuário para presencial. O que falta: `professional_schedule.dart` (v33) era duplicação de sistema já existente — removido; nunca compilado com Flutter real |

## Pagamento

| Item | Classificação | Evidência |
|---|---|---|
| `createOrder`/`quoteOrder` | FUNCIONAL REAL (backend) | Baixa de estoque em transação |
| Checkout na UI | DESATIVADO, sem checkout falso | `AppConfig.paymentGatewayEnabled = false`; botão desabilitado com aviso, não erro |
| Gateway real (PIX/cartão) | PENDENTE — depende de contrato | Nenhum provedor integrado |

## LGPD e segurança

| Item | Classificação | Evidência |
|---|---|---|
| Isolamento de prontuário por regra | FUNCIONAL REAL | `encounters/{id}`: só `patientId==uid` ou `professionalId==uid`; admin explicitamente fora |
| Exportação de dados | FUNCIONAL REAL | `exportUserData` |
| Exclusão de conta | FUNCIONAL REAL | `requestDataDeletion`, 15 dias de carência |
| Cancelamento da exclusão | FUNCIONAL REAL | Corrigido em rodada anterior — `AppUser.deletionScheduledFor` + UI condicional na tela de privacidade |
| Ações administrativas exigem claim real | FUNCIONAL REAL | `requireAdmin` confere `role === "admin"` no documento do próprio usuário, no servidor — não é botão escondido |

## Placeholders que bloqueiam publicação

| Item | Estado |
|---|---|
| `suporte@pediatria360.app`, `privacidade@pediatria360.app` | **AGUARDANDO DADO DO PROPRIETÁRIO** — endereço fictício, centralizado em `AppConfig`, marcado no código como bloqueador |
| URLs de Termos/Política | **AGUARDANDO DADO DO PROPRIETÁRIO** — apontam para página que não existe |
| CNPJ, endereço, encarregado de dados | **AGUARDANDO DADO DO PROPRIETÁRIO** — nunca inventados em nenhuma rodada desta conversa |
| Firebase de produção (`firebase_options.dart`) | **AGUARDANDO DADO DO PROPRIETÁRIO** — projeto real via `flutterfire configure` |
| Keystore Android de release | **AGUARDANDO DADO DO PROPRIETÁRIO** |

---

## O que foi corrigido nesta sessão especificamente

1. **Aviso de curva OMS aproximada estava invisível na tela.** Existia só em
   metadado de JSON (`_aviso`) que nenhum código Dart lia. `WhoReference`
   agora expõe `warning`/`version`, e a tela de crescimento mostra o aviso
   acima do gráfico.
2. **Mesmo problema no calendário de vacina**, mesma correção — aviso que
   existia só em comentário agora é `PniCalendar.warning`, visível na tela.
3. **`DataWarningBanner` criado como widget compartilhado** (não duplicado
   entre as duas telas) em `core/widgets/state_views.dart`.

Ambos são exemplos exatos do que você pediu para caçar: "não marcar como
concluído só porque existe uma tela" — as duas telas existiam, os avisos
existiam no código-fonte, mas **funcionalmente o médico usando o app nunca
via nenhum dos dois.**

---

## Correções desta sessão (versão 34)

- **Import quebrado, real, encontrado por leitura manual — não pela
  ferramenta.** `check_references.py` só confere se um símbolo existe em
  algum lugar do projeto, não se a linha `import` de um arquivo específico
  aponta para o arquivo certo. `clinical_pdf_service.dart` tinha um `../`
  a menos, apontando para um caminho que não existe — isso teria falhado
  a compilação real com "Target of URI doesn't exist". Corrigido, e
  formalizado como `tool/check_imports.py`, agora no CI.
- **`professional_schedule.dart` (construído numa rodada anterior) era
  duplicação de um sistema já funcionando.** Encontrei, ao investigar a
  Prioridade 2, que a Cloud Function `getAvailability` já lê disponibilidade
  do documento do profissional e já cruza com agendamentos — só faltava a
  escrita, que não exigia Function nenhuma (o campo já era gravável pelo
  dono). Implementado em `TelemedicineRepository.setWeeklyAvailability`/
  `.myWeeklyAvailability`, no formato que a Function real já espera.
  `professional_schedule.dart` foi marcado como superado, não apagado sem
  confirmação.
- **Erro meu, cometido e corrigido na mesma sessão**: uma chamada de edição
  malformada apagou parte de um teste de regra existente sem inserir a
  substituição corretamente, deixando código JavaScript órfão. Achei
  verificando com `node --check` (parser real, não heurística) antes de
  seguir, e corrigi.
- Avisos de dado aproximado (curva OMS, calendário PNI) agora aparecem na
  tela, não só em comentário/metadado invisível — ver `RELATORIO_CONSOLIDADO.md`.
- 2 testes de regra novos (disponibilidade do profissional), total 50.

## Correção de consistência (versão 35)

A seção anterior desta auditoria dizia que `PENDENCIAS_PRODUCAO.md` e
`CHECKLIST_PUBLICACAO_FINAL.md` "ainda não existem" — verdade quando essa
frase foi escrita, mas os dois foram criados na rodada seguinte, na mesma
entrega. A frase nunca foi removida depois. Mesmo tipo de erro que já
aconteceu antes nesta conversa com contagem de teste desatualizada: patch
incremental sem reler o documento inteiro. Removida agora; os dois arquivos
existem e estão listados na seção 8 (README) deste projeto.

## Versão 35

### Achado e corrigido pela minha própria ferramenta, contra o meu próprio código novo

`tool/check_imports.py` (criada na v34, depois de eu ter cometido um erro de
`../` faltando) pegou 13 imports quebrados no arquivo que eu tinha acabado
de escrever nesta mesma sessão — `professional_agenda_screen.dart` usava um
nível de `../` a mais em todo import, copiado por engano de um arquivo
vizinho que está uma pasta mais fundo. Corrigido, reverificado.

### `professional_schedule.dart` (v33) era duplicação — removido

Ao tentar ligar o domínio da v33 a um repositório real, descobri que a
Cloud Function `getAvailability` (`functions/src/commerce.ts`) já lia
disponibilidade do documento do profissional e já cruzava com agendamentos
— sistema completo que eu simplesmente não tinha visto ao construir
`professional_schedule.dart`. O arquivo modelava um sistema paralelo nunca
ligado a nada. Removido, com confirmação de zero uso real antes de apagar.
A peça que faltava de verdade — escrita de disponibilidade, não leitura —
foi implementada em `TelemedicineRepository`.

### Contagem de teste de regra corrigida em 6 lugares

`AUDITORIA_FINAL.md`, `RELATORIO_CONSOLIDADO.md`, `README.md`, `SETUP.md`
e `CHECKLIST_PUBLICACAO.md` (duas ocorrências) ainda diziam 48 depois da
correção para 50 na v34 — mesmo padrão de decadência por patch incremental
já visto antes nesta conversa. Corrigido em todos.

### Agenda profissional concluída

Ver seção "Telemedicina" da tabela acima e seção 8b de
`RELATORIO_CONSOLIDADO.md` para o detalhe completo.

### O que continua sem mudar

Nenhuma linha foi compilada com Flutter real nesta sessão — o mesmo aviso
do topo deste documento continua valendo integralmente.
