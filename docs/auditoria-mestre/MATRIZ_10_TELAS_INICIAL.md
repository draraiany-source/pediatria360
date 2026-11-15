# Matriz inicial — 10 telas de referência (14/11/2026)

- **Base:** commit `cb30a09`, branch `audit/mestre-20261114`.
- **Complementa:** `MATRIZ_FUNCIONALIDADES_PEDIATRIA360.md`, que traz as evidências por módulo.
- **Estados:** os mesmos da matriz geral (FV, PAR, VIS, AUS, BLQ, NV).
- **Regra desta matriz:** "existe tela" não significa funcional. Quando só o código foi lido, o estado fica PAR ou NV até haver teste ou verificação pela interface.

## Stack e infraestrutura

| Item | Situação | Onde |
|---|---|---|
| Aplicativo | Flutter 3.44 (web, Android, iOS, Windows), Riverpod 2, GoRouter | `pubspec.yaml`, `lib/core/router` |
| Backend | Cloud Functions TypeScript, região `southamerica-east1` | `functions/src` |
| Banco | Firestore, com regras por clínica, unidade e família | `firestore.rules` (346 testes) |
| Autenticação | Firebase Auth; papéis `UserRole`, `ClinicRole`, `WorkspaceProfile` | `route_authorization.dart` |
| Arquivos | Storage com regras próprias | **BLQ:** não ativado no `pediatria360-app` |
| IA | Anthropic via Functions | **BLQ:** Functions exigem o plano Blaze |
| WhatsApp, gateway, TISS, ICP-Brasil, vídeo | Código parcial, desligado por configuração | `app_config.dart` |

## Identidade visual

| Item pedido | Situação atual | Estado |
|---|---|---|
| Menu lateral roxo com gradiente; item ativo rosa | Menu branco, item ativo azul (`_PremiumSidebar` em `app_shell.dart`) | AUS |
| Fundo lavanda; cards em tons suaves; botões roxos | Fundo cinza-azulado; botões azuis | AUS |
| Logomarca Pediatria360 | `assets/images/logo.png`, `assets/icons/logo.svg` | FV (arquivo existe) |
| Personagem Tia Cris | **Nenhum arquivo.** Só existe a capivara Capi (`assets/illustrations/capi`) | AUS: precisa dos arquivos originais |
| Cabeçalho com usuário e função real | Nome e "Conta" no topo; o rodapé do menu mostra "Área da família" para a recepcionista | PAR (rótulo errado) |

## Estrutura global

| Item | Situação | Estado |
|---|---|---|
| Menu com os 15 módulos pedidos | Menu atual por perfil: Início, Agenda, Recepção, Perfil etc. Prontuário, Prescrições, Exames, Vacinação, Crescimento, Puericultura e Multidisciplinar não aparecem como itens próprios | PAR |
| Menu filtrado por perfil | Sim, por `WorkspaceProfile`; as regras do servidor também protegem os dados | FV |
| Busca global | Nenhum código (`globalSearch`/`buscaGlobal`: 0 ocorrências) | AUS |
| Notificações reais | `/avisos`, `features/notifications` | PAR (sem verificação nesta rodada) |
| Paciente selecionado entre módulos | Os módulos clínicos abrem por `childId` na rota; não há paciente "ativo" global nem confirmação de troca | AUS |
| Aviso de alterações não salvas | Só no editor de atendimento (autosave) | PAR |

## As 10 telas

| # | Tela | O que já existe (arquivos) | O que falta | Estado |
|---|---|---|---|---|
| 1 | Dashboard | `profile_homes.dart` (início por perfil), `features/bi` (indicadores admin, clínico, recepção, operacional) | Visão única do profissional (consultas do dia, retornos pendentes, pendências vacinais, tarefas), cards que abrem listas filtradas, documentação do cálculo de cada indicador | PAR |
| 2 | Agenda inteligente | `professional_agenda_screen.dart` (Hoje / 7 dias), agendamento novo (`booking_screens.dart`), conflitos em transação (`scheduling.ts`, testado), lista de espera e recorrência no backend, `change_log` | Visão de mês, filtros por unidade e sala, bloqueios e férias na tela, lista de espera na tela, histórico visível, padronizar os rótulos de status ("Solicitada" e "Aguardando confirmação" coexistem) | PAR |
| 3 | Pacientes | `/pacientes`, `clinicPatient360Path`, `ChildForm`, responsáveis, `ChildAccessScreen` | Lista com painel lateral, nome social, convênio, duplicidades, importação com prévia, arquivamento, abas unificadas | PAR |
| 4 | Prontuário e evolução | `features/emr` (`EncounterEditorScreen`, autosave, `signEncounter`, `amendEncounter`), consulta por voz (`/consultorio/ia`, consentimento, sessão, revisão) | Layout de 3 colunas, modelos por especialidade, tela de retificação, verificação da voz pela interface (depende das Functions) | PAR / BLQ (voz) |
| 5 | Prescrições e documentos | `DocumentEditor`/`Viewer`, `issueClinicalDocument`, prescrição de suplementação | 7 tipos com modelos versionados, favoritos, prévia, PDF real (o da suplementação é VIS); assinatura ICP-Brasil desligada | PAR |
| 6 | Vacinação | `VaccinesScreen`, `pni_calendar.dart` (testado) | Origem e conferência do registro, lote e comprovante, relatório de cobertura, PDF; fonte e versão do calendário; **validação clínica pendente** | PAR |
| 7 | Crescimento e desenvolvimento | `features/growth`, LMS oficial da OMS (`who_growth_lms.json`), marcos (14 arquivos) | Autor e origem por medida, idade corrigida, comparação de períodos, exportação; **validação clínica pendente** | PAR |
| 8 | Puericultura | Registros de sono e alimentação espalhados (29 e 10 arquivos), biblioteca (`/biblioteca`) | Módulo próprio com as 7 abas, separação relato da família × registro profissional, plano em PDF | PAR (fragmentado) |
| 9 | Multidisciplinar | `careSpecialty`, autorização por escopo, encaminhamentos (28 arquivos), menções a plano terapêutico (5 arquivos) | Tela da equipe do paciente, plano terapêutico com metas e prazos, resumos compartilhados com registro de finalidade e vigência | PAR |
| 10 | Financeiro | `/financeiro` (receber, pagar, fluxo, DRE, inadimplência, produção, relatórios), faturamento | Painel único da referência, filtros combinados, conciliação e repasses conferidos, caixa × competência explícitos | PAR |
| — | Tia Cris (aba própria) | Chat de IA (`/ia`), painel de IA da gestão (`/gestao/ia`), WhatsApp no backend | Aba que centraliza conversas, fila, solicitações, lembretes e transferência humana; personagem; permissões separadas do assistente clínico | AUS (aba) / BLQ (IA e WhatsApp) |

## Dependências externas que limitam a verificação

1. **Plano Blaze no `pediatria360-app`:** sem ele, nenhuma Function roda no projeto publicado. Isso afeta agendamento, IA, documentos e financeiro no link de homologação.
2. **Storage:** sem ele não há anexos, fotos nem comprovantes.
3. **Arquivos da Tia Cris:** personagem e variações.
4. **Credenciais de WhatsApp, gateway de pagamento e ICP-Brasil:** essas integrações seguem desligadas.
5. **Validação clínica** do calendário PNI, das curvas OMS e das calculadoras por profissional habilitado.
