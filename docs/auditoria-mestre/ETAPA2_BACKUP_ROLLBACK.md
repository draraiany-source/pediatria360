# Etapa 2 — Proteção, backup e rollback
**Data:** 15/11/2026  
**Branch:** `audit/modulos-integracao-20261115`  
**Base:** commit `b131013` / `backup/checkpoint-b131013-20261115`  
**Status:** documentação pronta. **Nenhuma migração nem export de produção foi executado.**

---

## 1. Objetivo

Garantir restauração do Pediatria 360 antes de integrar Espaço Kids e Tia Cris, sem apagar funcionalidades existentes e sem expor dados reais.

---

## 2. Riscos priorizados

| ID | Risco | Severidade | Mitigação |
|---|---|---|---|
| R1 | Regressão em agenda/prontuário/financeiro ao integrar módulos | Alta | Branch isolada; PRs pequenos; testes de regressão obrigatórios |
| R2 | Tia Cris com leitura clínica indevida | Alta | RBAC em rota + rules + callables; sem grant de chart |
| R3 | Kids acessar encounters/prescrições | Alta | Coleções próprias; sem membership clínico no modo kiosk |
| R4 | Perda do WIP local / misturar branches | Média | Checkpoints e backup branches já criados |
| R5 | Export/migração em produção sem Blaze/autorização | Alta | Bloqueado até aprovação explícita + plano Blaze |
| R6 | Dados reais em demo/teste | Alta | Só `demo-*` / seeds fictícios; proibido paciente real |
| R7 | Deploy Functions sem rollback | Alta | Não publicar Functions sem autorização; manter Git das rules |

---

## 3. Pontos de restauração (código)

| Ref | Conteúdo |
|---|---|
| `b131013` | Etapa 1 identidade/menu |
| `backup/checkpoint-b131013-20261115` | Alias do mesmo ponto |
| `audit/modulos-integracao-20261115` | Branch desta auditoria |
| `backup/wip-antes-auditoria-modulos-20261115` | Estado local pré-auditoria |
| `backup/wip-antes-etapa1-20261114` | WIP anterior à identidade |
| stash local | Untracked (`tools/wip`, logs) se ainda presente |

### Rollback de código (somente com autorização)

```text
# Voltar o worktree ao checkpoint limpo da Etapa 1
git switch audit/modulos-integracao-20261115
git reset --hard backup/checkpoint-b131013-20261115
```

**Não** usar force push. **Não** apagar branches de backup.

### Preservar trabalho em andamento antes de mudanças grandes

```text
git switch audit/modulos-integracao-20261115
git stash push -u -m "wip antes de etapa-N YYYYMMDD"
git branch backup/wip-antes-etapa-N-YYYYMMDD
```

---

## 4. Backup de banco de dados

### 4.1 Produção / projeto `pediatria360-app`

**Não executado nesta etapa.**

Pré-requisitos (todos obrigatórios):
1. Autorização explícita por escrito da titular
2. Plano Blaze ativo
3. Conta GCP com permissão de export Firestore
4. Bucket dedicado (ex.: `gs://...-firestore-backups`) **sem** acesso público
5. Janela acordada (sem escrita crítica durante o export)

Procedimento seguro (referência; rodar só após os pré-requisitos):

```text
# 1) Anotar commit e revisão das rules no Git
git rev-parse HEAD
git show HEAD:firestore.rules > firestore.rules.HEAD.bak
git show HEAD:storage.rules > storage.rules.HEAD.bak
git show HEAD:firestore.indexes.json > firestore.indexes.HEAD.bak

# 2) Export Firestore (exemplo)
gcloud firestore export gs://BUCKET/pediatria360/YYYYMMDD-HHMM --project=pediatria360-app

# 3) Registrar: data, operador, URI do export, commit
```

Restauração (só com autorização; operação sensível):

```text
gcloud firestore import gs://BUCKET/pediatria360/YYYYMMDD-HHMM --project=pediatria360-app
```

**Impedimento atual:** Blaze / Storage / credenciais GCP de export **não** foram confirmados neste computador. Sem isso, **não** declarar backup de produção concluído.

### 4.2 Emulador / homologação fictícia

Usar apenas projeto `demo-*` (ex.: `demo-pediatria360`) e seeds em `tools/homologacao/` (contas `*.exemplo.invalid`).

Antes de testes que alteram o emulador:
1. Anotar o seed usado
2. Reiniciar emuladores e reaplicar o seed quando precisar de estado limpo
3. **Nunca** apontar seed/demo para o projeto real

---

## 5. Artefatos que já protegem a configuração

Versionados no Git (restauráveis sem Console):
- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`
- `firebase.json` / `.firebaserc`
- `functions/src/**`
- `lib/**`

Publicação de rules/indexes/Functions em produção: **somente com autorização explícita**.

---

## 6. Checklist pré-integração (Etapas 4–5)

- [ ] Branch limpa a partir de `audit/modulos-integracao-20261115` ou checkpoint
- [ ] WIP alheio não misturado no commit
- [ ] Feature flags novas com default **desligado**
- [ ] Nenhuma coleção clínica alterada sem análise de impacto
- [ ] Testes de auth, RBAC, agenda e rules planejados
- [ ] Sem dados reais em evidências/screenshots
- [ ] Backup de produção: executado **ou** bloqueio registrado com precisão

---

## 7. O que esta etapa NÃO fez

- Não exportou Firestore de produção
- Não alterou rules/indexes publicados
- Não instalou dependências novas
- Não mudou visual nem fluxos do app
- Não iniciou Espaço Kids nem backend da Tia Cris
