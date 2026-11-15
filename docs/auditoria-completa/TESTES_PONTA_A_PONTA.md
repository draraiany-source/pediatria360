# TESTES PONTA A PONTA — Pediatria360

**Data:** 15/11/2026 (America/Sao_Paulo)  
**Branch:** `audit/modulos-integracao-20261115`

Legenda: **OK** | **PAR** | **FALHA** | **NT** | **BLQ**

| # | Fluxo | Resultado | Evidência | Notas |
|---|---|---|---|---|
| 1 | Login profissional → menu 15 módulos | PAR | main_menu_test + codigo | UI login NT nesta sessão |
| 2 | Selecionar paciente → Paciente 360 | PAR | codigo PatientModule+360 | grants WIP |
| 3 | Abrir atendimento → assinar → emitir receita | PAR | DocumentEditor checklist etapa2 | e2e Firestore NT |
| 4 | IA voz: consentimento → revisão → sem inventar | PAR/BLQ | rotas voice + flag | flag pode estar off |
| 5 | Família: home → agenda → pré-consulta convite | PAR | FamilyPortalHome | dados reais only |
| 6 | Família: crescimento WHO | FT/PAR | who_reference_test + GrowthScreen | UI NT |
| 7 | Família: vacinas | NT | codigo | |
| 8 | Tia Cris: FAQ admin → handoff; recusa clínica | FT | receptionist_ai tests | flag runtime |
| 9 | Kids: 6 jogos + guardian + sem clínico | FT | kids_space tests | flag runtime |
| 10 | Financeiro: lançar → recalcular dashboard | NT | | sem cobrança real |
| 11 | Multidisciplinar compartilhar/revogar | NT | grants child_access | |
| 12 | IDOR outra clínica/paciente | PAR | rules tests históricos | emulator NT agora |
| 13 | Convidado SKIP_AUTH sem dados clínicos | PAR | FASE1 guestSessionFailure | |
| 14 | Receituário: IA só rascunho + autorizar | PAR | DocumentEditor checks | |
| 15 | Kids a11y + pausa parental | PAR | kids home etapa5 | nível não muda engine |

## Automatizados reexecutados

```
flutter test test/features/children/child_access_check_test.dart \
  test/features/shell/main_menu_test.dart \
  test/features/kids_space \
  test/features/receptionist_ai \
  test/who_reference_test.dart
→ 37/37 OK

npx tsc -p functions --noEmit → OK
```
