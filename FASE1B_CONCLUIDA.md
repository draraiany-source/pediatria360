# FASE 1b — Criar / selecionar clinica (UI)

**Status:** concluida
**Data:** 2026-09-18
**Pre-requisito:** FASE 1 (modelos + paths + rules deny-by-default)

## Objetivo

Tornar o tenant utilizavel: profissional cria clinica, ve memberships e escolhe a clinica ativa sem migrar dados legados.

## Entregue

| Item | Detalhe |
|------|---------|
| Hub /clinica | Lista memberships, card da clinica ativa, CTA criar |
| Criar /clinica/nova | Formulario basico + owner = clinicAdmin |
| Preferencia local | p360_active_clinic_id via SharedPreferences |
| Providers | activeClinicIdProvider, activeClinicProvider, myClinicMembershipsProvider |
| Atalhos | Sidebar Minha clinica + tile no Perfil (so profissional) |
| Authz | Rotas /clinica* restritas a UserRole.professional |
| clinicName | Campo denormalizado no membership para UI |

## Nao feito (intencional)

- Migrar patients/agenda/Rx com clinicId -> FASE 2
- Convite de equipe / multiunidade UI
- Deploy Firestore rules em producao (pendente aprovacao)
- Servicos pagos (WhatsApp, PIX, ICP)

## Como validar

1. Login profissional -> Perfil ou sidebar -> Minha clinica
2. Nova clinica -> preencher nome -> criar
3. Confirmar snackbar ativa e card no hub
4. Criar segunda clinica e trocar tocando na lista
5. Usuario familia: rota /clinica redireciona para home

## Proximo

**FASE 2** — anexar clinicId gradualmente a patients, agenda e documentos clinicos, sem quebrar modo legado.
