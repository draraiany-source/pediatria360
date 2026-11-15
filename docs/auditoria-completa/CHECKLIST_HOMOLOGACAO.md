# CHECKLIST DE HOMOLOGAÇÃO

**Data:** 15/11/2026 (America/Sao_Paulo)  
**Projeto:** `pediatria360-app`  
**Canal sugerido (já existente):** `homologacao-modulos-20261115`  
**Proibido nesta rodada:** produção, lojas, `pediatria360-homolog` sem autorização

## Antes de liberar canal
- [ ] Checkpoint git/stash documentado (`branch backup/auditoria-completa-20261115 + stash audit-checkpoint-20261115-192733`)
- [ ] Flags M2/M3 explícitas só no canal de homolog
- [ ] Contas fictícias (pro, recepção, família) sem PII real
- [ ] `flutter test` suites críticas OK (registrar log)
- [ ] `tsc` functions OK
- [ ] Rules emulator (suite pacientes/agenda) OK — **pendente reexecutar**
- [ ] Smoke: login → menu → paciente 360 → receita rascunho sem assinar acidental
- [ ] Família: home → kids (se flag) → guardian; sem prontuário
- [ ] Tia Cris: recusa clínica + handoff
- [ ] Convidado: sem dados clínicos
- [ ] Sem WhatsApp real / sem cobrança real
- [ ] Sem declarar “pronto para pacientes reais” com P0 aberto

## Critério de saída “homolog interno”
- Zero P0 conhecidos não mitigados
- P1 documentados com owner
- Evidências sem PII anexadas em `docs/homologacao/`

## Critério de saída “publicação”
- **Não atendido** enquanto P0-1..P0-3 e revalidação rules/APK permanecerem abertos
