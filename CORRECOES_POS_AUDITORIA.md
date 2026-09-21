# CORRECOES POS-AUDITORIA (onda 1)
Data: 2026-09-21
Commit base auditoria: abbf607

## Feito nesta onda (codigo)
1. Telemedicina: controles de video ocultos quando flag OFF; copy honesta.
2. Consultorio KPIs: retornos (motivo), rascunhos EMR, novos/mes, billing pago do dia, msgs via unread.
3. Encounter.create aceita clinicId opcional; call sites passam activeClinicId.
4. Perfil Ajuda: mailto AppConfig.supportEmail (nao mais "em breve").
5. Relatorios de auditoria: AUDITORIA_FINAL_PEDIATRIA360.md/.pdf

## Ainda depende do proprietario / dados externos (nao inventado)
- Textos legais reais (Termos/Privacidade hospedados)
- Tabelas OMS LMS oficiais
- Validacao PNI gov.br
- Provedor de video + gateway pagamento
- Keystore release, App Check, DPO/CNPJ
- Regras Firestore indexes para queries novas (drafts/createdAt) se falharem em prod

## Proxima onda sugerida
- Indexes firestore para professionalId+status e professionalId+createdAt
- Rules clinicId deny cross-tenant
- Financeiro minimo + tela relatorios
