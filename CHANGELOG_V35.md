> **HISTÓRICO — não é o documento atual.**
>
> Changelog da versão 35 — consentimento LGPD, decisões de produto (VideoQuality, rotas admin).
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

# CHANGELOG_V35.md — Pediatria 360

## Contexto desta versão

A v34 entregou dois documentos (`PENDENCIAS_PRODUCAO.md`,
`CHECKLIST_PUBLICACAO_FINAL.md`) mas o `AUDITORIA_FINAL.md` continuou
dizendo que eles "ainda não existiam" — frase que sobreviveu de uma versão
anterior do texto. A v35 corrige essa contradição e fecha a agenda
profissional, que na v34 tinha ficado incompleta.

## Arquivos modificados

| Arquivo | O que mudou |
|---|---|
| `lib/features/telemedicine/data/telemedicine_repository.dart` | `AppointmentType` (presencial/teleconsulta); `myWeeklyAvailability`/`setWeeklyAvailability`; `confirm()`/`markCompleted()` |
| `lib/features/telemedicine/presentation/telemedicine_screen.dart` | Providers `myAgendaProvider`, `myAvailabilityProvider` |
| `lib/core/router/routes.dart` | `agendaPath`/`agendaName` |
| `lib/core/router/app_router.dart` | Rota da agenda registrada |
| `lib/features/shell/presentation/screens/home_screen.dart` | Atalho "Agenda" na home, restrito a profissional |
| `AUDITORIA_FINAL.md` | Seção "o que falta" removida (estava desatualizada); classificação da agenda atualizada; contagem de teste corrigida; seção "Versão 35" adicionada |
| `PENDENCIAS_PRODUCAO.md` | Seção "corrigido na v35" adicionada |
| `RELATORIO_CONSOLIDADO.md` | Números atualizados; seção 8b reescrita |
| `README.md`, `SETUP.md`, `CHECKLIST_PUBLICACAO.md` | Contagem de teste de regra corrigida (48→50) |

## Arquivos criados

| Arquivo | Propósito |
|---|---|
| `lib/features/telemedicine/presentation/professional_agenda_screen.dart` | Tela de agenda: hoje/7 dias, confirmar, cancelar, iniciar atendimento, editar disponibilidade |
| `CHANGELOG_V35.md` | Este arquivo |

## Arquivos removidos

| Arquivo | Por quê |
|---|---|
| `lib/features/telemedicine/domain/professional_schedule.dart` | Duplicava sistema já funcional (`getAvailability`) — confirmado zero uso real antes de apagar |
| `test/professional_schedule_test.dart` | Testava o arquivo acima |

## Funcionalidades realmente implementadas nesta versão

- Agenda profissional: visualizar consultas (hoje / 7 dias), confirmar,
  cancelar, editar disponibilidade semanal — tudo escrevendo em Firestore
  de verdade, sem mock
- "Iniciar atendimento" ligando agenda → prontuário para consulta
  presencial (cria ou retoma `Encounter`, abre o editor)
- Distinção presencial/teleconsulta no modelo de agendamento

## Testes adicionados

- 2 casos de regra: profissional grava a própria disponibilidade;
  profissional NÃO grava disponibilidade de outro (total 50, era 48)
- Nota: os 13 testes de `professional_schedule_test.dart` foram
  **removidos junto com o arquivo que testavam** — não substituídos, porque
  a lógica que eles verificavam não faz mais parte do sistema (223 testes
  Dart agora, era 236)

## Funcionalidades ainda parciais

- Agenda: sem visão de calendário mensal, sem bloqueio de horário pontual
  (férias) — só disponibilidade semanal recorrente
- "Iniciar atendimento" para teleconsulta continua bloqueado (ver
  integrações desativadas)

## Mocks / placeholders

Nenhum criado nesta versão. Nenhum dado de exemplo inventado.

## Integrações desativadas (sem mudança)

- Videochamada — `AppConfig.videoConsultationEnabled = false`
- Pagamento — `AppConfig.paymentGatewayEnabled = false`

## Bloqueadores de produção (sem mudança nesta versão)

Ver `PENDENCIAS_PRODUCAO.md`, seção BLOQUEADOR — nenhum item novo
adicionado ou removido desta lista na v35. O mais relevante continua sendo:
nenhuma linha foi compilada com Flutter real.

## O que depende de você

Sem mudança — ver `PENDENCIAS_PRODUCAO.md`, seção "Depende do
proprietário".

## O que depende de serviço externo

Sem mudança — ver `PENDENCIAS_PRODUCAO.md`, seção "Depende de serviço
externo".

## Relatórios atualizados e consistentes

`AUDITORIA_FINAL.md`, `PENDENCIAS_PRODUCAO.md`, `RELATORIO_CONSOLIDADO.md`,
`README.md`, `SETUP.md`, `CHECKLIST_PUBLICACAO.md` — todos com a mesma
contagem de teste (223 Dart, 50 regra), verificada contra os arquivos reais
nesta sessão, não copiada de versão anterior.

`CHECKLIST_PUBLICACAO_FINAL.md` não precisou de mudança nesta versão — os
itens que ele cobre (build, assinatura, lojas) continuam no mesmo estado.

## Não afirmado nesta versão

- Não digo "compilou" — nenhuma linha rodou em Flutter real
- Não digo "100% pronto" — ver `PENDENCIAS_PRODUCAO.md`
- Não digo "todos os testes passaram" — os 223 + 50 foram escritos e as
  asserções verificadas manualmente, o que é diferente de `flutter test`
  ter rodado
