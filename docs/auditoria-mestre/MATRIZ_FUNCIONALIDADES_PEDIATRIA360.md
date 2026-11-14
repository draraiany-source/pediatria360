# Matriz de funcionalidades — Pediatria360 (inicial)

- **Data:** 14/11/2026
- **Branch:** `audit/mestre-20261114`, criada a partir de `14127cd`, que é a ponta da `feat/fluxo-atendimento` e do [PR #7](https://github.com/draraiany-source/pediatria360/pull/7).
- **Base:** inventário de 126 telas de 28/10 (`docs/homologacao/auditoria-telas/INVENTARIO.md`) e as correções registradas em `docs/homologacao/auditoria-telas/RELATORIO.md` e `docs/homologacao/publicacao-20261029/RELATORIO.md`. Esta matriz consolida esse material e acrescenta o que ele não cobria: Recepcionista IA Tia Cris, Espaço Kids, perfis multidisciplinares, segredos e dependências.

**Estados:**
- **FV** = funcional e verificado. A evidência indica como: [UI] pela interface, [TESTE] por teste automatizado, [REST] contra o projeto publicado.
- **PAR** = parcial.
- **VIS** = apenas visual.
- **AUS** = ausente.
- **BLQ** = bloqueado por dependência externa.
- **NV** = não verificado nesta rodada.

**Prioridades:**
- **P0:** risco crítico de segurança, exposição ou perda de dados.
- **P1:** impede um fluxo essencial.
- **P2:** funcionalidade incompleta ou problema relevante de uso.
- **P3:** melhoria visual ou de conveniência.

Nenhum P0 foi confirmado até aqui (ver seção "Segurança").

## 1. Entrada, perfis e isolamento

| Módulo | Tela/rota | Arquivo ou serviço | Estado real | Problema | Prior. | Correção | Evidência |
|---|---|---|---|---|---|---|---|
| Conta | Login, cadastro, recuperar senha (`/login`, `/cadastro`, `/esqueci-senha`) | `features/auth` | FV | — | — | — | [UI] 28/10; [REST] login das 3 contas fictícias em 04/11 |
| Conta | Confirmação de e-mail | `sendEmailVerification` sem tela | AUS | Convite orienta "Perfil > Confirmar e-mail", opção que não existe | P2 | Criar ação no perfil | Inventário, achado 20 |
| Conta | Troca de senha / biometria | `profile_tab.dart` | AUS | O rótulo promete senha e biometria, mas abre só a tela de privacidade | P2 | Ação "Alterar senha" via reautenticação | Inventário, achado 19 |
| Conta | Logout | `/perfil`, menu lateral | FV | Só existe dentro do Shell | P3 | — | Inventário, achado 34 |
| Conta | Expiração de sessão | Firebase Auth | NV | Comportamento com token revogado não testado pela interface | P2 | Testar | — |
| Perfis | Família, médico, recepção, financeiro, gestão | `route_authorization.dart`, `firestore.rules` | FV | — | — | — | [UI] 28/10; [TESTE] regras 346/346 e 12/12; [REST] 7/7 em 04/11 |
| Perfis | Psicólogo, fisioterapeuta, outros | `ClinicRole.healthProfessional` + `careSpecialty` | NV | Sem conta fictícia nem roteiro de interface para esses perfis | P2 | Incluir no seed e no roteiro | `cuidado-multidisciplinar/RELATORIO.md` (regras) |
| Perfis | Administrador da plataforma ("superadmin") | `UserRole.admin` | PAR | Existe como `admin`; não existe gestão de unidades | P2 | Documentar mapeamento | Levantamento da Tia Cris |
| Perfis | Profissional verificado | `isVerifiedProfessional` (regras) | FV | O usuário não consegue se marcar como verificado; só o servidor grava esse campo | — | — | `firestore.rules` linhas 173, 216, 233 e 266 |
| Isolamento | Clínica, unidade, família | regras + `clinical_access.dart` | FV | Membership do lado do usuário é conferida só no cliente (o servidor confere os dois lados) | P3 | — | [TESTE] regras 346/346 e 12/12; [REST] 3 recusas esperadas |
| Isolamento | Gestão vê módulos clínicos no hub | `management_modules.dart` | PAR | Os dados são protegidos pelas regras; só o menu está errado | P2 | Ocultar no hub | Relatório 28/10, pendência P4 |
| Compartilhamento | Autorização por escopo, validade e revogação | `ChildAccessScreen`, `childAccess.ts` | FV | — | — | — | [UI] 28/10; [TESTE] `childAccess.test.ts` |

## 2. Painel e agenda

| Módulo | Tela/rota | Arquivo ou serviço | Estado real | Problema | Prior. | Correção | Evidência |
|---|---|---|---|---|---|---|---|
| Agenda | Agenda do profissional e da clínica (`/agenda`) | `professional_agenda_screen.dart` | FV | — | — | — | [UI] 28/10 |
| Agenda | **Agendar paciente já cadastrado (recepção)** | `ClinicBookingScreen` (`/agenda/agendar`) → `scheduleAppointment` | **FV** | Corrigido no commit `cb30a09` | — | — | [TESTE] `booking_flow_test.dart` 9/9; ponta a ponta nos emuladores 10/10 (`tools/homologacao/agendamento_e2e.js`); [UI] `evidencias/p1-agendamento/p1-02` a `p1-04` |
| Agenda | **Agendamento pela família** | `FamilyBookingScreen` (`/agendar-consulta`) → `scheduleAppointment` | **FV** | Corrigido no commit `cb30a09`. Só com profissional e clínica de consultas anteriores. O envio pela interface foi coberto pelo teste ponta a ponta, não por captura de tela | — | — | [TESTE] `booking_flow_test.dart`; ponta a ponta nos emuladores; [UI] `evidencias/p1-agendamento/p1-07` (formulário) |
| Agenda | Reagendamento pela família | `rescheduleAppointment` + `familyMayReschedule` | AUS (interface) | Só a equipe remarca | P2 | Ação no card da consulta | Levantamento da Tia Cris |
| Agenda | Confirmar/cancelar pela família | `_AppointmentCard` → `setAppointmentStatus` | FV | — | — | — | [UI] 28/10 |
| Agenda | Conflitos e reservas simultâneas | `scheduling.ts` (travas em transação) | FV | — | — | — | [TESTE] `schedulingCore.test.ts` |
| Agenda | Lista de espera, recorrência | `joinWaitlist`, `seriesId` | PAR | Backend existe; a interface não foi verificada | P2 | — | NV pela interface |
| Agenda | Status e histórico de alterações | `change_log` | PAR | Histórico gravado; sem tela de consulta | P3 | — | Código |
| Painel | Indicadores (BI) | `features/bi` | FV | — | — | — | Inventário 28/10 |

## 3. Cadastro, pré-consulta, prontuário e documentos

| Módulo | Tela/rota | Arquivo ou serviço | Estado real | Problema | Prior. | Correção | Evidência |
|---|---|---|---|---|---|---|---|
| Cadastro | Criança e responsáveis | `ChildForm`, `ChildGuardians` | FV | — | — | — | [UI] 28/10 (correção C1 na web) |
| Pré-consulta | Anamnese da família | `FamilyAnamnesisScreen` | PAR | O campo de anexos é só informativo | P2 | Upload privado (depende do Storage) | Inventário; Storage não ativado (BLQ) |
| Prontuário | Atendimento, autosave, assinatura | `EncounterEditorScreen`, `signEncounter` | PAR | Fluxo não exercitado pela interface; retificação sem tela | P2 | Tela de adendo (`amendEncounter`) | Relatório 28/10, P3 e P11 |
| Documentos | Receita, atestado, encaminhamento | `DocumentEditor`/`Viewer`, `issueClinicalDocument` | PAR | Emissão sem prévia; ICP-Brasil desligada (não declarar validade jurídica) | P2 | — | Inventário |
| Suplementação | PDF e compartilhar | `supplement_more_screens.dart`, `calculator_prescription_screens.dart` | VIS | Botões só mostram um aviso | P2 | Gerar PDF real | Relatório 28/10, P9 |

## 4. Módulos pediátricos

| Módulo | Tela/rota | Arquivo ou serviço | Estado real | Problema | Prior. | Correção | Evidência |
|---|---|---|---|---|---|---|---|
| Crescimento | Curvas OMS | `who_reference.dart`, `who_growth_lms.json` | PAR | Dados LMS oficiais da OMS; **conferência clínica pendente** | P2 | Validação especializada | Relatório 29/10 |
| Vacinas | Calendário PNI e doses | `pni_calendar.dart`, `VaccinesScreen` | PAR | Sem data/versão do calendário; **conferência clínica pendente** | P2 | Validação especializada | [TESTE] `pni_calendar_test.dart` |
| Calculadoras de dose | Suplementação | `SupplementCalculatorScreen` | NV | Validações de entrada, fórmula e referência não reauditadas nesta rodada | P2 | Auditar | — |

## 5. Recepcionista IA — Tia Cris (10 telas de referência)

| # | Tela | Estado real | O que existe | O que falta | Prior. |
|---|---|---|---|---|---|
| 1 | Boas-vindas adulta | AUS | Home da família (`profile_homes.dart`) | Tela, avatar, voz | P2 |
| 2 | Boas-vindas infantil | AUS | Mascote Capi (capivara) | Tela infantil, ilustrações da Tia Cris | P2 |
| 3 | Agendamento inteligente | PAR | `getScheduleSlots`, `scheduleAppointment` (backend, com testes) | Tela real (é o mesmo P1 da agenda); escolha por especialidade | P1 |
| 4 | Confirmação e reagendamento | PAR | Confirmar/cancelar pela família; WhatsApp no backend | Reagendar pela família | P2 |
| 5 | Setores e localização | AUS | Cadastro de unidades e salas | Mapa e setores | P3 |
| 6 | Exames e vacinas | PAR | Calendário PNI real | Orientação de preparo de exames (exige conteúdo aprovado por profissional) | P2 |
| 7 | Atendimento por voz | PAR | Chat de texto com Claude (`aiChat`) | Fala e síntese de voz (nenhum pacote instalado); voz adulta/infantil; limites de urgência | P2 |
| 8 | Kids — jogos | AUS | — | Jogo da memória, quebra-cabeça, Pequeno Doutor | P2 |
| 9 | Kids — histórias e vídeos | AUS | Player de vídeo (Bunny) dos cursos | Biblioteca infantil, áudio | P3 |
| 10 | Painel admin da IA | PAR | Uso e custo **estimado** (`usage.ts`), insights, CMS versionado, WhatsApp | Métricas de atendimento da IA, avatar/voz, kiosk, biblioteca kids | P2 |

**Problemas relacionados:**
- **P2 — custo de IA subestimado.** Só `askManagementAssistant` passa por `consumeOrThrow`. O `aiChat`, o `structureVoiceDraft` e as mensagens não entram nos contadores do painel.
- **P3 — placeholder do urso.** O `teddy_tip.png` é uma silhueta genérica.

## 6. Espaço Kids e jogos

| Item | Estado real | Evidência |
|---|---|---|
| Jogo da memória | AUS | Nenhum código; as imagens recebidas são só referência visual |
| Quebra-cabeça | AUS | Idem |
| Pequeno Doutor | AUS | Idem |
| Gamificação existente | FV (adultos) | `features/gamification`: XP, medalhas e ranking. **Não se aplica a crianças**, porque o ranking é público. |

## 7. Financeiro, faturamento e integrações

| Módulo | Estado real | Problema | Prior. | Evidência |
|---|---|---|---|---|
| Contas a receber/pagar, inadimplência | FV | — | — | [UI] 28/10 (C6–C8) |
| Ciclo atendimento → cobrança → pagamento → recibo | NV | Não há cobrança no seed | P2 | Relatório 28/10, seção 8 |
| Glosas, repasses, conciliação | PAR | Resultado das ações não conferido | P2 | Relatório 28/10, P8 |
| Gateway de pagamento | BLQ | `paymentGatewayEnabled=false`, sem credenciais | — | `app_config.dart` |
| TISS / ICP-Brasil / vídeo | BLQ (desligados) | Não implementados; não declarar | — | `app_config.dart` |
| WhatsApp (Meta Cloud API) | BLQ | Sem credenciais; nenhuma mensagem enviada | — | `whatsapp.ts`, `automations.ts` |
| IA (Anthropic) | BLQ em homologação | Functions não publicadas (exige plano Blaze) | P1 (homologação) | Log `07_demo_projeto.txt` |
| Storage | BLQ | Não ativado no `pediatria360-app`; anexos indisponíveis | P1 (homologação) | Idem |

## 8. Segurança, dependências e qualidade

| Item | Estado real | Problema | Prior. | Correção | Evidência |
|---|---|---|---|---|---|
| Segredos versionados | FV | Nenhum encontrado (chaves de API, chaves privadas, `.env`, `key.properties`, `google-services.json`) | — | — | `git grep` + `git ls-files` em 14/11 |
| Dependências das Functions | FV após a correção | 2 altas (`body-parser`, `node-forge`) | P2 | `npm audit fix`, sem troca de versão maior; restam 8 moderadas | Commit `4088b12`; tsc OK; jest 104/104 |
| Dependências do Flutter | NV | — | P3 | — | — |
| Regras Firestore publicadas | FV | Idênticas a `39132d3` | — | — | Deploy de 04/11 |
| Regras Storage publicadas | BLQ | Storage não ativado | P1 (homologação) | Ativar no Console | Idem |
| App Check | PAR | Cliente pronto, desligado | P2 | Ativar no Console | Relatório 29/10 |
| Backup e restauração | NV | Sem acesso autorizado a teste de restauração | P2 | — | — |
| Builds | PAR | Web OK; APK falhou por memória; AAB sem chave de upload; IPA exige Mac | P1 (publicação) | — | Relatório 29/10 |

## Ordem de correção proposta

1. **P1 de fluxo essencial (código):**
   - agendamento pela recepção para paciente existente;
   - agendamento pela família.
   Os dois reutilizam o backend existente e testado.
2. **P1 externos:** ativar o Storage e o plano Blaze (titular). Sem isso, a homologação não exercita anexos, IA nem agendamento pelo servidor.
3. **P2 (por grupos):**
   - reagendar pela família;
   - contabilizar o custo de IA;
   - hub de gestão sem módulos clínicos;
   - alterar senha e confirmar e-mail;
   - PDF da suplementação;
   - roteiro para os perfis multidisciplinares.
4. **Novas funcionalidades:** Espaço Kids (Etapa 12) e Tia Cris (Etapa 10), em fases, depois dos P1.
