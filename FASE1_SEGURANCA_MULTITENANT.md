# FASE 1 ? Seguranca + Multitenant + RBAC clinico

## Objetivo
Introduzir isolamento por clinica sem quebrar o modo legado (profissional/parent/admin).

## Modelo
- `clinics/{clinicId}` ? organizacao
- `clinics/{clinicId}/units/{unitId}` ? multiunidade
- `clinics/{clinicId}/memberships/{id}` ? papel do usuario na clinica
- `users/{uid}/clinic_memberships/{clinicId}` ? indice invertido

## Roles clinicos (`ClinicRole`)
clinicAdmin | physician | healthProfessional | receptionist | finance | nursing | technician | patient

Distintos de `UserRole` da plataforma (parent/professional/admin).

## Estrategia de migracao
1. Codigo novo convive com dados sem `clinicId` (legado).
2. Onboarding cria clinica + membership admin.
3. Rules novas so para colecoes `clinics/**`.
4. Fase futura: anexar `clinicId` em appointments/encounters.

## Status desta entrega
- Domain + paths + repository + providers + testes unitarios RBAC
- Rules Firestore para `clinics` (ver firestore.rules)
- voice.ts convertido UTF-8 (exports validos)
- Sem servicos pagos ativados
