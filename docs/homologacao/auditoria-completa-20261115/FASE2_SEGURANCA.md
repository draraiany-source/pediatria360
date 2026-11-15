# Fase 2 — Segurança (em andamento)

**Data:** 15/11/2026  
**HEAD base:** `35f6045`  
**Restrição:** sem afrouxar regras; sem `pediatria360-homolog`; sem produção.

## Correções aplicadas nesta fase

### 1. `checkChildAccess` devolve `ownerUid` só com concessão

Arquivo: `functions/src/emr.ts`

- Sem registro / sem grant: `ownerUid: null`
- Com `summary` ou `chartWrite` ativo: devolve o dono
- Evita enumeração: conhecer o `childId` não revela o responsável

### 2. Cliente resolve cadastro clínico pelo dono

- `ChildAccessRepository.checkAccess`
- `ChildrenRepository.watchChildOfOwner`
- Providers `childOwnerForAccessProvider` / `clinicalChildProvider`
- Linha do tempo usa `clinicalChildProvider` (alergias / nome com grant)

### 3. Fim do loop vacinas/crescimento no prontuário clínico

**Decisão de produto alinhada às regras existentes:** growth/vaccines na
subcoleção da família **continuam** só para dono/responsável vinculado.
Testes de regras já exigem isso (`concessão continua sem dar acesso a
growth_records/vaccine_doses`).

Em vez de abrir as regras:

- Profissional **não** consulta mais `growthProvider` / `vaccineDosesProvider`
  com o id da criança (caminho errado → permissão negada / loading eterno)
- Cards do prontuário e do Paciente 360 explicam o limite e apontam triagem /
  sinais vitais / evolução
- Comentários de `Encounter.patientId` e `PatientSummary` alinhados ao
  significado real (id da criança)

## O que NÃO mudou (de propósito)

- Regras de `growth_records` / `vaccine_doses`
- Isolamento por clínica / grants
- Mensagem de sessão convidada (`guestSessionFailure`) — já correta desde
  `4814a3d`

## Testes desta fase

| Comando | Resultado |
| --- | --- |
| `npx tsc -p functions --noEmit` | OK (exit 0) |
| `flutter analyze` nos arquivos da correção child/prontuário | 0 erros (só infos pré-existentes) |
| `flutter analyze` dashboard (week/canceladas) | **No issues found** |
| `flutter test test/features/children/child_access_check_test.dart` | **1/1** |
| Regras emulator (suite completa) | Não reexecutada nesta rodada |
| Emulador UI Dra. Carla 360 | Pendente (Fase 6) |

## Dashboard (avanço Fase 5 acoplado)

`ClinicDashboardStats` passa a expor `weekAppointments` (próximos 7 dias)
e `cancelledToday`, calculados das consultas reais do profissional — sem
inventar KPIs de vacinas/exames/aniversários (continuam 0 explícitos).
