# Auditoria - modulo CONSULTORIO 360

## Implementado
- Dominio: workflow, triagem, voz, marcos, KPIs
- ClinicRepository (hoje, check-in, triagem, stats parciais)
- VoiceConsultationRepository + merge draft local
- Providers Riverpod
- Telas: dashboard, recepcao, triagem, paciente 360, fluxo IA
- Banner permanente de disclaimer IA
- Rotas + autorizacao profissional + shell Consultorio
- Home: atalhos Consultorio 360 + Consulta com IA
- firestore_paths / rules / functions voice.ts
- grantChildSummaryAccess com vinculo de agendamento
- Testes unitarios workflow + draft

## Parcial
- KPIs financeiros/mensagens: zeros com TODO
- Transcricao ao vivo depende de STT
- Paciente 360: atalhos para rotas existentes

## Pendente
- Microfone / Storage de audio
- Indices Firestore compostos
- Financeiro, CRM, chat, telemedicina video
- UI desenvolvimento / neuropediatria

## Riscos
- Deploy obrigatorio de rules + functions apos remocao do self-write
- Queries de agenda podem exigir indice
