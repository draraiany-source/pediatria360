# Fase 1 — Diagnóstico (auditoria completa)

**Data:** 15/11/2026  
**Branch:** `audit/modulos-integracao-20261115`  
**HEAD:** `35f6045`  
**Versão:** `1.0.0+1`  
**Ponto de restauração:** tag `restauracao/pre-auditoria-completa-20261115`  
**Restrição confirmada pela titular:** não usar o projeto `pediatria360-homolog`; seguir com emulador local e canais já existentes no app, sem abrir regras.

## Escopo desta fase

Auditar o estado atual, reproduzir a causa do erro de permissão nas telas de
pacientes/agenda e listar o que já foi corrigido em rodadas anteriores versus
o que ainda bloqueia a auditoria completa.

## Erro urgente — "Sua sessão não tem permissão para estes dados"

### Causa real (reproduzida no código)

Há **duas** situações distintas que geravam a mesma mensagem genérica:

1. **Modo demonstração / `SKIP_AUTH` (convidado sem Firebase Auth)**  
   O app entra como "Carolina Souza" local, sem sessão Firebase. Pacientes e
   Agenda corretamente recusam dados clínicos reais. Antes, a UI dizia só
   "sem permissão"; desde `4814a3d` a falha usa `guestSessionFailure` e
   explica que falta login profissional.

2. **Profissional autenticado consultando sem filtro de autor / sem grant**  
   Corrigido na auditoria tela por tela (`1159b1c`): consultas de encounters,
   documentos e labs do 360 passam a filtrar pelo próprio `professionalId`
   quando o perfil é profissional. Regras **não** foram afrouxadas.

### O que NÃO será feito

- Liberar acesso geral, convidado com dados clínicos, ou regras permissivas.
- Publicar em `pediatria360-homolog` ou em produção sem autorização.

### Evidência de regras (já existente)

`test/rules/telas_pacientes_agenda.test.js` — profissional autenticado lista
próprios atendimentos/agenda; outra clínica, recepção no prontuário e sessão
sem login são recusados.

## Achado P0 ainda aberto — vacinas/crescimento pela clínica

| Camada | Situação |
| --- | --- |
| `Encounter.patientId` | Id da **criança** (confirmado em `firestore.rules`) |
| Lista de pacientes | Usa esse id como `childId` (correto como identificador) |
| `childProvider` / `growthProvider` / `vaccineDosesProvider` | Só olham `users/{uid_logado}/children/...` |
| Profissional logado | Não é dono → criança nunca aparece → tela carrega vazio/infinito |
| Regras de `growth_records` / `vaccine_doses` | Só dono ou responsável vinculado — **grant do profissional não lê** |
| `child_registry` | Só o dono lê no cliente — profissional não resolve `ownerUid` |

Mitigação atual (Etapa 1 do shell): menu clínico **não** abre vacinas/crescimento
da área da família. Isso evita o loop, mas **não** entrega a funcionalidade.

## Homologação

| Ambiente | Situação |
| --- | --- |
| Emulador `demo-pediatria360` + seed | Caminho autorizado pela titular |
| Canal `homologacao-modulos-20261115` em `pediatria360-app` | Já existia (login obrigatório); não revalidado nesta fase |
| Projeto `pediatria360-homolog` | **Fora de escopo** por decisão da titular |
| Demo estática GitHub Pages | Dados fictícios sem Firebase; não substitui teste de permissões reais |

## Trabalho já documentado (não reinventar)

- Auditoria tela por tela 28/10: `docs/homologacao/auditoria-telas/`
- Publicação 29/10 + PDF: `docs/homologacao/publicacao-20261029/`, `AUDITORIA_FINAL_PEDIATRIA360.pdf`
- Integração modular 15/11: `docs/auditoria-mestre/` (Etapas 1–6, Kids/Tia Cris com flags off)

## Ordem das próximas fases (esta auditoria)

1. ~~Diagnóstico~~ (este documento)  
2. Segurança — fechar P0 childId/owner + conferir permissões no emulador  
3. Funcionalidades — pacientes, agenda, mensagens, prontuário, documentos  
4. IA — sem ações clínicas sem backend  
5. Design premium + dashboard com dados reais  
6. Testes  
7. Homologação (emulador / canal autorizado; sem `pediatria360-homolog`)  
8. Relatório final atualizado  

**Veredito parcial:** o app **não** está pronto para publicação com pacientes
reais. O erro de mensagem do convidado já tem correção no código; o P0 de
vacinas/crescimento clínico permanece e é o próximo alvo da Fase 2.
