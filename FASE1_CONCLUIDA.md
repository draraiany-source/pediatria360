# FASE1_CONCLUIDA.md — Resumo 360° + Linha do Tempo Pediátrica

Relatório único, consolidando o que foi entregue em várias rodadas. Nenhuma
afirmação aqui é nova — é o estado real, verificado contra o código nesta
mesma revisão final, não recitado de memória.

## 1. O que existe, e de onde vem cada campo

`PatientTimelineScreen` (existente, evoluída — nunca recriada) é hoje a
porta de entrada única do prontuário longitudinal: `Pacientes → Paciente →
Resumo 360° → Crescimento/Vacinas/Timeline`.

| Seção | Campo | Fonte real |
|---|---|---|
| Cabeçalho | Nome, idade, sexo | `Child` (via concessão `authorized_professionals`) |
| | Responsável | `Child.guardianName`, denormalizado no cadastro |
| | Alergias, condições | `Child.allergies`/`.conditions` |
| Crescimento | Peso, altura, data | `GrowthRecord` mais recente |
| | IMC | Calculado com `PediatricCalculators.bmi`, já existente |
| | Perímetro cefálico | `GrowthRecord.headCircumferenceCm` |
| Vacinação | Situação, contagem | `VaccineSummary` (aplicadas/total/atrasadas) |
| Consultas | Última, contagem | `List<Encounter>` |
| Exames | Último, contagem | `List<LabResult>` |
| Documentos | Último, contagem (só ativos) | `List<ClinicalDocument>`, cancelado não conta |
| Linha do tempo | 5 tipos de evento | `Encounter`+`ClinicalDocument`+`LabResult`+`GrowthRecord`+`VaccineDose`, intercalados cronologicamente, com filtro |

## 2. O que a Fase 1 pediu e genuinamente não tem fonte — não inventado

- **Desenvolvimento**: nenhum acompanhamento estruturado existe no projeto.
  Não aparece no resumo nem na timeline — omitido, não fingido.
- **Medicamentos em uso** (como lista persistente): só existe dentro da
  anamnese de cada consulta, não como estado contínuo no cadastro.
- **Próxima consulta**: viria de `Appointment`, que este resumo não recebe.
  Testado explicitamente que a formatação nunca menciona "próxima".
- **Situação vacinal do PNI**: aviso de dado aproximado continua visível na
  tela de vacinas — não tratado como calendário oficial validado.

## 3. Navegação

`Pacientes → Paciente (Resumo 360°) → Crescimento/Vacinas` tocando os
indicadores — navega de verdade (`Routes.growth`/`Routes.vaccines`), não é
decoração. Timeline com filtro por tipo, sem trocar o padrão intercalado
por abas (motivo já documentado no código: reconstruir mentalmente a ordem
cronológica entre tipos diferentes é o problema que abas causariam).

## 4. Segurança — quatro bugs reais encontrados e corrigidos nesta série

Não hipotéticos: achados verificando o código real, cada um com teste que
o exercita.

1. **`encounters`/`clinical_documents`/`lab_results`**: a regra comparava
   `patientId == request.auth.uid`, mas `patientId` é id de criança, não
   de usuário — nunca batia. Corrigido com `ownsChild()`.
2. **`lab_results`**: bug de precedência de operador (`&&` liga mais forte
   que `||`) permitia qualquer profissional verificado ler exame de
   qualquer criança. Corrigido, com `professionalId` adicionado à escrita.
3. **`children/{childId}`**: profissional não tinha nenhum caminho de
   leitura, mesmo com vínculo real — o alerta de alergia nunca chegava a
   quem mais precisava. Resolvido com Cloud Function
   (`grantChildSummaryAccess`) + subcoleção `authorized_professionals`,
   não com atalho client-side.
4. **`patient_timeline_screen.dart`**: zero tratamento de erro — um stream
   que falhasse virava silenciosamente "prontuário vazio". Corrigido com
   `ErrorState`, reaproveitando `ErrorMapper` já existente.

## 5. Testes adicionados nesta série

| Tipo | Onde | O que cobre |
|---|---|---|
| Regra (Firestore) | `test/rules/rules.test.js` | Isolamento família/profissional nas 3 coleções corrigidas (12), concessão de acesso (7) |
| Roteador (Dart, puro) | `test/route_authorization_test.dart` | Autorização por perfil — responsável/profissional/admin |
| Formatação (Dart, puro) | `test/patient_summary_formatting_test.dart` | Crescimento, consultas, exames, documentos — com dado e sem dado |
| Widget (Dart, Riverpod mockado) | `test/patient_timeline_screen_test.dart` | Paciente com/sem dado, isolamento entre pacientes, carregamento, erro, filtro |

Nesta série: 19 casos de regra novos (63→82) e 24 casos Dart novos — 17 em
`patient_summary_formatting_test.dart`, 7 em `patient_timeline_screen_test.dart`.

## 6. Lista exata de arquivos modificados nesta série da Fase 1

**Criados:**
- `lib/features/emr/presentation/screens/patient_summary_formatting.dart`
- `test/patient_timeline_screen_test.dart`
- `test/patient_summary_formatting_test.dart`

**Modificados:**
- `lib/features/emr/presentation/screens/patient_timeline_screen.dart` — resumo, timeline expandida, filtro, erro
- `lib/shared/domain/entities/child.dart` — campo `guardianName`
- `lib/shared/data/models/child_model.dart` — mapeamento do novo campo
- `lib/features/children/data/repositories/children_repository_impl.dart` — preenchimento automático do responsável
- `lib/features/children/presentation/providers/children_providers.dart` — callback de nome
- `lib/features/children/presentation/screens/child_detail_screen.dart` — `InfoBanner` extraído
- `lib/core/widgets/app_widgets.dart` — `InfoBanner` adicionado (extraído de `child_detail_screen.dart`)
- `firestore.rules` — 4 correções de segurança (seção 4)
- `functions/src/emr.ts` — `grantChildSummaryAccess`
- `functions/src/index.ts` — export registrado
- `test/rules/rules.test.js` — 19 casos novos

## 7. O que fica para a Fase 2 (Pré-consulta + Pós-consulta)

Não começado, conforme pedido. Nenhum dos dois tem fonte de dado nem tela
hoje — construção nova de verdade, diferente de tudo nesta série, que foi
evolução do que já existia.
