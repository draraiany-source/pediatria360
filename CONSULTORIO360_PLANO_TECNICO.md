# CONSULTORIO 360 + Prontuario IA - Plano tecnico

## Objetivo
Fundacao do Consultorio 360 e Prontuario IA sem quebrar EMR/agenda. IA gera apenas rascunho; assinatura permanece em signEncounter.

## Arquitetura
- lib/features/clinic/{domain,data,presentation}
- functions/src/voice.ts
- firestore.rules: voice_sessions, triage, parent-only authorized_professionals

## Rotas
- /consultorio (shell dashboard)
- /consultorio/recepcao|triagem|paciente|ia...

## Seguranca
- Sem API keys no Flutter
- applyVoiceDraftToEncounter nunca assina
- grantChildSummaryAccess exige agendamento ativo

## Proximos passos
1. Audio + STT
2. KPIs financeiros
3. Deep-link ao editor de encounter
4. Deploy rules/functions
