# Auditoria modular — Pediatria 360
**Data:** 15/11/2026  
**Branch de trabalho:** `audit/modulos-integracao-20261115` (HEAD `b131013`)  
**Checkpoint recuperável:** `backup/checkpoint-b131013-20261115`  
**WIP pré-existente preservado:** `backup/wip-antes-auditoria-modulos-20261115` + `backup/wip-antes-etapa1-20261114` + stash local  
**Escopo:** Etapa 1 (auditar e documentar). Nenhuma alteração estrutural de código, migração ou deploy de produção.

---

## 1. Stack e infraestrutura (verificado)

| Camada | Tecnologia |
|---|---|
| App | Flutter >=3.32 / Dart >=3.8, Riverpod, go_router |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions (Node 20) |
| Projeto | `pediatria360-app` |
| Região Functions | `southamerica-east1` |
| Auth no código | E-mail/senha + Google |
| Flags off | pagamento, vídeo, voz, TISS, ICP-Brasil, App Check (default) |
| Persistência local | Hive, sqflite, shared_preferences |

**Não verificado neste passo:** valores live de Remote Config no Console; URL canônica de Hosting de produção; providers habilitados no Console.

---

## 2. Organização atual vs. três módulos desejados

### Módulo 1 — Gestão clínica (plataforma existente)
Já existe como núcleo do app (`lib/features/` clinic, emr, children, telemedicine, finance, billing, management, vaccines, growth, supplementation, security, etc.).

**Funcionando com evidência (FV / testes / UI homologada):**
- Login, cadastro, recuperar senha; perfis família / médico / recepção / financeiro / gestão
- Isolamento por clínica (regras + membership espelhado); profissional verificado no servidor
- Agenda e agendamento (recepção + família) — commit `cb30a09`, testes e e2e
- Cadastro de crianças/responsáveis; BI básico; financeiro contas a receber/pagar (matriz)
- Shell Etapa 1: identidade roxa, menu 15 itens por perfil, paciente em foco (`b131013`)

**Incompleto / parcial:**
- As 10 telas de referência (Dashboard, Agenda inteligente, Pacientes, Prontuário, Prescrições, Vacinação, Crescimento, Puericultura, Multidisciplinar, Financeiro) — **PAR**
- Prontuário/assinatura, documentos clínicos, anexos de anamnese — **PAR**
- Reagendamento pela família (UI), lista de espera (UI), histórico de mudanças — **PAR/AUS**
- Admin de plataforma sem gestão de unidades — **PAR**

**Correções conhecidas:**
- Vacinação/Crescimento pelo lado clínica: risco de loop / `childId` incorreto (responsável) — não marcar como pronto
- Suíte Flutter: 3 testes de `demo_sleep_wellchild_test.dart` instáveis na suíte completa
- Status “em atendimento/concluído” ainda no cliente (PROGRESSO)

### Módulo 2 — Recepcionista virtual Tia Cris
**Estado:** placeholder de tela + rota + RBAC. **Sem backend de atendimento.**

| Item | Estado |
|---|---|
| Rota `/recepcionista-ia` | Existe; só admin / clinicAdmin / receptionist |
| Tela informativa (escopo/limites) | PAR (`receptionist_ai_screen.dart`) |
| Chat, STT, agendamento automático, FAQ, preços | AUS |
| Functions dedicadas Tia Cris | AUS |
| Ilustração da personagem | AUS (arquivo externo) |
| WhatsApp / fila / transferência humana | Backend parcial de automações; Meta BLQ; UI da persona AUS |

**Isolamento clínico:** rotas de chart bloqueiam recepção; regras Firestore de encounters exigem profissional/grant — alinhado à regra “não acessar dados clínicos sem autorização”.

### Módulo 3 — Espaço Kids 360
**Estado:** **não existe** como feature (`lib/features/kids|games|waiting_room` ausentes).

| Item | Estado |
|---|---|
| Jogos (memória, quebra-cabeça, cores, atenção, associação) | AUS (matriz) |
| Áudio / sala de espera restrita | AUS |
| Gamificação atual (`/conquistas`, `/ranking`) | FV para **adultos** — não reutilizar como Kids |
| Preparação app independente | Não iniciada |

---

## 3. Bloqueadores externos (não declarar pronto)

| Bloqueio | Impacto |
|---|---|
| Plano Blaze | Functions não publicadas no projeto → homologação real sem callables |
| Storage não ativado | Anexos/fotos; regras Storage não publicadas |
| WhatsApp Meta | Sem credenciais; nenhum envio real |
| Gateway pagamento / TISS / ICP / vídeo / voz | Flags `false` |
| Validação clínica (PNI, OMS, doses) | Pendente — não substituir por aproximação |
| Arquivos da personagem Tia Cris | Externos ao repo |

---

## 4. Git e preservação / rollback

| Ref | Uso |
|---|---|
| `b131013` / `backup/checkpoint-b131013-20261115` | Restaurar ponto limpo da Etapa 1 identidade |
| `audit/modulos-integracao-20261115` | Branch isolada desta auditoria/integração |
| `backup/wip-antes-auditoria-modulos-20261115` | Proteção do estado local pré-auditoria |
| `backup/wip-antes-etapa1-20261114` | WIP anterior à Etapa 1 |
| Worktree Desktop `pediatria360` | Outro worktree em `handoff/final-20260926` — **não** misturar |

**Como restaurar o app ao estado atual:**
```text
git checkout audit/modulos-integracao-20261115   # ou b131013
# ou: git reset --hard backup/checkpoint-b131013-20261115
```
(Comandos destrutivos só com autorização explícita.)

**Backup de banco (Etapa 2 — ainda não executado):**
- Não há migração nestas etapas iniciais.
- Antes de qualquer migração/alteração de schema: export agendado Firestore (Console ou `gcloud firestore export` para bucket dedicado), snapshot das regras (`firestore.rules` / `storage.rules` no Git) e registro do commit.
- **Impedimento atual:** export de produção exige projeto Blaze + permissões GCP + autorização explícita. Emulador `demo-pediatria360` pode ser espelhado via seed, sem dados reais.
- **Proibido:** dados reais de pacientes em demo/teste.

---

## 5. Arquitetura modular proposta (Etapa 3 — só proposta, sem código)

Manter **um** app Pediatria 360 (proibido segundo projeto sem necessidade técnica).

```text
Pediatria 360 (shell + auth + clinic_org)
├── M1 Gestão clínica     → features atuais (emr, clinic, agenda, finance…)
├── M2 Tia Cris           → feature receptionist_ai + callables dedicados
│                            contratos: scheduling + communication (sem chart)
└── M3 Espaço Kids 360    → feature kids_space (nova), rotas /kids/*
                             zero acesso a encounters/documentos/prescrições
                             feature flag + modo kiosk sala de espera
                             pacote interno extraível depois (app independente)
```

**Contratos:**
- Auth/membership reutilizados; Kids pode usar token de sessão de espera **sem** grants clínicos.
- Feature flags: Remote Config + `AppConfig` (ex.: `kids_space_enabled`, `tia_cris_enabled`).
- Permissões: ampliar `route_authorization` / rules; **não** só ocultar botões.
- Não alterar tabelas/coleções clínicas sem análise de impacto; Kids em coleções próprias (`kids_sessions`, `kids_progress`) sem PII clínica.

---

## 6. Arquivos que seriam modificados (após aprovação)

### Etapa 2 (proteção) — docs + scripts de backup/rollback
- `docs/auditoria-mestre/*` (runbooks)
- possivelmente `tools/homologacao/` (export emulador) — sem tocar produção

### Etapa 4 — Espaço Kids (isolado)
- **Novos:** `lib/features/kids_space/**`, rotas, testes, assets de jogos/áudio
- **Touches mínimos:** `app_router.dart`, `routes.dart`, `route_authorization.dart`, Remote Config keys, `firestore.rules` (coleções novas only)
- **Não tocar:** emr, prescriptions, visual das telas clínicas

### Etapa 5 — Tia Cris
- **Estender:** `lib/features/receptionist_ai/**`
- **Novos callables** (scheduling/FAQ/handoff) reutilizando `scheduling` / `automations`
- **Não duplicar** booking já existente; **não** abrir chart à persona

### Explicitamente fora sem aprovação
- Dependências novas incompatíveis, visual das telas atuais, produção, Blaze upgrade, WhatsApp real, pagamento real

---

## 7. Testes obrigatórios antes de considerar integração concluída

1. Auth (login/logout/onboarding)  
2. Permissões / RBAC (recepção ≠ chart; Kids ≠ clínico)  
3. Prontuário (leitura/escrita com grant)  
4. Agendamento (recepção + família) — regressão `booking_flow_test` / e2e  
5. APIs/callables (emulador Functions)  
6. Responsividade (desktop + mobile shell)  
7. Isolamento M1/M2/M3 (regras + rotas)  
8. Jogos + sincronização de áudio (quando existirem)  
9. Regressão suíte Flutter + rules tests + jest Functions  

**Critério:** falha crítica ⇒ integração **não** concluída. Não inventar resultado de teste.

---

## 8. Plano de etapas (status)

| Etapa | Conteúdo | Status |
|---|---|---|
| 1 | Auditar e documentar | **Concluída neste relatório** |
| 2 | Riscos, backup, rollback | Aguarda aprovação |
| 3 | Arquitetura modular (docs/contratos) | Aguarda aprovação |
| 4 | Espaço Kids isolado | Bloqueado até 2–3 |
| 5 | Integrar Tia Cris | Bloqueado até 2–3 |
| 6 | Testes individuais e conjuntos | Depois de 4–5 |
| 7 | Homologar e liberar gradualmente | Sem produção sem autorização |

---

## 9. Riscos principais

1. Misturar WIP de Functions/management com o branch modular e regressar agenda/financeiro.  
2. Liberar Tia Cris com acesso amplo a Firestore (violação LGPD / dados de saúde).  
3. Kids com login de responsável “por conveniência” expondo clínica.  
4. Declarar Modules 2/3 prontos só com UI.  
5. Deploy Functions sem Blaze / sem backup.  
6. Segundo app Flutter desnecessário (proibido pelo prompt).  

---

## 10. Decisão solicitada

Aguardo aprovação explícita para:
1. **Etapa 2** — runbook de backup/rollback (sem migração de produção), e  
2. **Etapa 3** — documentar contratos/feature flags no repo **sem** mudar comportamento do app.

**Não** iniciarei Etapas 4–7, migrações, instalação de deps novas, mudança visual das telas atuais nem deploy em produção sem nova autorização.
