# Auditoria gestao clinica (inspiracao de fluxos — nao copia)

## Modulo | Ja existe | Status | O que falta | Duplicacao? | Acao
| Modulo | Ja existe | Status | O que falta | Duplicacao? | Acao |
|--------|-----------|--------|-------------|-------------|------|
| Pacientes | Sim | PARCIAL | filtros premium | Nao | Ampliar depois |
| Agenda | Sim | PARCIAL | dia/semana/mes | Nao | Ampliar FASE agenda |
| Prontuario | Sim | PARCIAL | abas premium | Nao | Ampliar |
| IA Clinica | Sim | PARCIAL | audio fluxo | Nao | Ampliar |
| Vacinas | Sim | PARCIAL | caderneta | Nao | Ampliar |
| Telemedicina | Sim | PARCIAL | video | Nao | Ampliar |
| Mensagens | Sim | PARCIAL | chat | Nao | Ampliar |
| Financeiro | Nao/placeholder | NAO | FASE 4 | Nao | Criar |
| Relatorios | Nao | NAO | FASE 7 | Nao | Criar |
| Biblioteca | Sim | PARCIAL | — | Nao | Manter |
| Recepcao | Sim | AMPLIADO FASE1 | — | Nao | Ampliar (feito) |
| Fila | Parcial | AMPLIADO FASE1 | salas | Nao | Ampliar (feito) |
| Check-in | Parcial | AMPLIADO FASE1 | QR portal auth | Nao | Ampliar (feito) |
| Triagem | Sim | FUNCIONANDO | — | Nao | Manter |
| Paciente 360 | Sim esqueleto | PARCIAL | dados reais | Nao | FASE 2 |
| CRM | Nao | NAO | segmentos | Nao | FASE 3 |
| Pendencias | Nao | NAO | — | Nao | FASE 3 |
| Convenios | Nao | NAO | — | Nao | FASE 5 |
| Estoque | Nao | NAO | — | Nao | FASE 6 |
| Auditoria | Path rules | PARCIAL | UI | Nao | FASE 8 |
| Multiunidade | clinic_org | PARCIAL | — | Nao | FASE 9 |

## FASE 1 (esta entrega)
- Corrigido bug: quadro ignorava workflowStatus apos check-in
- Abas: Quadro | Fila | Check-in
- Acoes: check-in, triagem, chamar, iniciar, falta, cancelar, 360
- Tempo de espera / atraso
- Status called (Chamado)
- Check-in digital: deep link identificador (sem envio fake)
- Sem novas collections; sem relaxar rules
