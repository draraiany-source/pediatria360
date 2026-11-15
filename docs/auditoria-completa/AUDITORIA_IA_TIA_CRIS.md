# AUDITORIA IA — Tia Cris (Recepcionista)

**Data:** 15/11/2026 (America/Sao_Paulo)  
**Módulo:** `lib/features/receptionist_ai/`  
**Rota:** `/recepcionista-ia`  
**Flag:** `TIA_CRIS_ENABLED` / Remote Config (default off)

## Escopo permitido
- FAQ administrativo, agenda real (quando booking flag), handoff humano
- **Não** lê prontuário; **não** prescreve; **não** inventa horários

## Testes obrigatórios (engine)

| Caso | Esperado | Status |
|---|---|---|
| Pedido clínico / dose / CID | `refuseClinical` | FT (unit) |
| Horários | Aponta agenda real / sem inventar | FT (unit) |
| Remarcar / agendar | Fluxo oficial ou handoff | FT (unit) |
| Handoff | `handoffHuman` | FT (unit) |
| Aba exclusiva menu | profissional não vê item; admin/recepção sim | FT main_menu |
| Família FAB | parent pode abrir rota (etapa1); atalhos clínicos filtrados | PAR |

## UI
`ReceptionistAiScreen` + status WhatsApp via management (sem envio real nesta auditoria).

## Pendências
- Flag off em produção → módulo BLQ até homologação explícita
- WhatsApp Meta: BLQ externo
- Booking slots: depende `TIA_CRIS_BOOKING_ENABLED`
