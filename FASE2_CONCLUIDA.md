# FASE 2 — Cadastro, permissoes e agenda (concluida)

**Base de recuperacao:** `bdf3ef7` — ver `FASE2_RECOVERY.md`
**Escopo:** autenticacao/RBAC clinico, cadastro unico da crianca + responsaveis, agenda do consultorio (mesma collection `appointments`).
**Fora de escopo:** pre-consulta, prontuario/evolucao, transcricão, IA clinica (nao marcados como concluidos).

## Status por item

| Area | Status | Notas |
|------|--------|-------|
| Isolamento multi-clinica agenda | Funcional (parcial) | `clinicId` + rules staff; `unitId` ainda app-layer |
| Admin salas/bloqueios | Funcional | rooms + schedule_blocks + tela Minha clinica |
| Recepcao agenda sem evolucao | Funcional | PermissionMatrix + redirect `/pacientes` |
| Profissional agenda | Funcional | confirm/cancel/reagendar + change_log |
| Responsavel autorizado | Funcional (parcial) | guardians + linked_children + rules |
| Cadastro unico crianca | Funcional | Reuso `users/{uid}/children` |
| Multiplos responsaveis | Funcional | Subcollection guardians + flags + pendencia |
| Historico alteracoes | Funcional | change_log child e appointment |
| CRUD agenda | Funcional (parcial) | Ver/confirmar/cancelar/reagendar na UI; criar via API `createClinicAppointment` |
| Conflitos e bloqueios | Funcional | Dominio puro + repositorio |
| Integracao crianca-agenda | Funcional | childId/clinicId na mesma collection |
| Pre-consulta / prontuario / IA | Nao implementado nesta fase | Vinculos preparados |

## Arquivos principais

- firestore.rules, firestore.indexes.json
- route_authorization.dart, app_router.dart, permission_matrix.dart
- child_guardian*, guardians_*, agenda_scheduling, clinic_schedule_*
- telemedicine_repository.dart, professional_agenda_screen.dart
- test/fase2_agenda_guardians_test.dart (+ casos em permission_matrix e route_authorization)
- FASE2_RECOVERY.md

## Migracoes

Sem migracao destrutiva. Subcollections additive. Deploy do indice `clinicId`+`startsAt` antes de `watchClinicAgenda` em producao.

## Rotas e permissoes

- clinicAdmin / physician: agenda + chart
- receptionist: agenda + cadastro admin; **sem** `/pacientes` e evolucao
- guardian vinculado: leitura se `canViewData` ativo

## Testes\r\n\r\n- **46 passed** (`fase2_agenda_guardians` + `permission_matrix` + `route_authorization`)\r\n- Unit conflitos/bloqueios/2 responsaveis
- Unit receptionist chart deny
- Unit route redirect recepcao bloqueia pacientes
- UI E2E manual: ver passos abaixo (emulator rules especificos FASE2 ainda pendentes)

## Como verificar

1. Membership receptionist: `/agenda` OK; `/pacientes` redireciona inicio
2. Crianca → Responsaveis: 2 UIDs com flags diferentes
3. Minha clinica → Salas e bloqueios
4. Agenda: confirmar/cancelar/reagendar; conflito deve falhar na API
5. Guardian sem canViewData: rules negam leitura
6. clinicas distintas: isClinicMember isola

## Pendencias

- UI completa criar agendamento na recepcao
- Deduplicacao CPF/telefone automatica
- Isolamento unitId app-only
- Deploy indices + testes rules emulator guardians

## Custos

Indice composto Firestore. Sem novos provedores de comunicacao/video.

## Pare aqui

FASE 2 encerrada. Aguardar proximo prompt.