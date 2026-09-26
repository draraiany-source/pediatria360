# Auditoria — teste fechado v1 (2026-09-26)

| Campo | Valor |
|-------|-------|
| Branch | `closed-test/v1-20260926` |
| Base | publish prep + este trabalho |
| Backup | `backup/pre-closed-test-20260926` |
| FASE 2 | No GitHub desde `a580fd6` |

## Inventario por perfil

### Familia
| Area | Classificacao | Nota |
|------|---------------|------|
| Auth / cadastro / perfil | FUNCIONAL* | Firebase; DevMode off em ENV=prod |
| Criancas | FUNCIONAL* | CRUD sob users/{uid}/children |
| Vacinas | PARCIAL | UI + PNI local; validacao clinica pendente |
| Crescimento | PARCIAL | Matematica OMS OK; JSON aproximado |
| Biblioteca / cursos | PARCIAL | Depende de CMS/Bunny |
| IA conversacional | PARCIAL | Chat via Functions; nao e conduta |
| Notificacoes | PARCIAL | FCM |
| Loja / pagamento | AUSENTE (flag off) | paymentGatewayEnabled=false |

### Profissional
| Area | Classificacao | Nota |
|------|---------------|------|
| Pacientes / timeline | FUNCIONAL* | |
| Prontuario | FUNCIONAL* | Hash interno; sem ICP |
| Agenda | FUNCIONAL* | FASE 2 |
| Telemedicina | PARCIAL | Sem video |
| Consulta por voz / IA clinica | AUSENTE no teste | Flag off |
| Financeiro / BI / estoque | PARCIAL | RBAC |

### Recepcao / equipe
| Area | Classificacao | Nota |
|------|---------------|------|
| Recepcao / fila | FUNCIONAL* | |
| Responsaveis | FUNCIONAL* | FASE 2 |
| Pendencias / CRM | PARCIAL | |
| TISS operadora | AUSENTE | Stub XML |

\* FUNCIONAL = codigo + testes unitarios; E2E UI ainda incompleto nesta maquina.

## 1. Pronto para teste fechado
- Auth com ENV=prod (DevMode off)
- Android/iOS/web scaffolds
- RBAC + rules clinicId
- Video, pagamento, voz/IA clinica, TISS, ICP ocultos/sinalizados
- Avisos OMS/PNI na UI
- Homolog: https://pediatria360-app--homolog-orcamento-a9dstse4.web.app
- App Check preparado (ENABLE_APP_CHECK); rules sem exigir token

## 2. Pendente antes da publicacao
- Textos legais / CNPJ / DPO / URLs
- OMS LMS oficial + PNI gov.br
- App Check no Console antes de enforcement
- Keystore / Apple / contas lojas
- Dominio prod + deploy rules/indices
- Disco >10 GB para AAB/APK
- E2E manuais tres perfis (contas ficticias)

## 3. Melhoria futura
- Video, pagamento, STT real, ICP, TISS, unitId nas rules

## App Check (preparacao)
```
flutter run --dart-define=ENV=prod --dart-define=ENABLE_APP_CHECK=true
```
