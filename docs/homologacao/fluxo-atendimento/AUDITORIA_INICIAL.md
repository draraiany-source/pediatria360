# Fluxo de atendimento: auditoria antes das alterações

Data: 03/10/2026. Branch de trabalho `feat/fluxo-atendimento`, criada de `feat/area-profissional` em `b9cbacd`. Este documento é o commit de referência: nenhum código foi alterado antes dele.

Escopo pedido em 03/10: fluxo de atendimento de ponta a ponta (família, recepção, pediatra, psicólogo, fisioterapeuta), IA na consulta (gravação, transcrição e rascunho da evolução) e IA para organizar a agenda e marcar consultas.

Método: leitura do código seguindo cada botão até o repositório e a regra do Firestore. Tela pronta não foi considerada prova de funcionamento.

Legenda: **Funcional** = grava e aparece para o outro perfil; **Parcial** = funciona com lacunas; **Visual** = tela sem efeito real ou com dados fixos; **Não existe**.

## 1. Arquitetura

O projeto tem duas partes independentes:

- **App real** (`lib/main.dart`, `lib/features/*`, Firebase Auth, Firestore, Storage e Functions em `southamerica-east1`). Tem login, papéis (`UserRole` parent/professional/admin; `ClinicRole` clinicAdmin/physician/healthProfessional/receptionist/finance/nursing/technician/patient), suporte a emuladores (`USE_FIREBASE_EMULATOR`) e cerca de 50 Functions. Nunca foi testado de ponta a ponta com login real.
- **Demonstração web** (`lib/main_demo.dart`, `lib/demo/*`): dados fictícios em memória, sem login nem servidor. Perfis: profissional (contas de pediatra, segundo pediatra, duas psicólogas, fisioterapeuta), recepção, financeiro, administrador e responsável.
- **Regras compartilhadas** (`lib/shared/*`, Dart puro): agenda, pré-consulta, documentos, rotina, cuidado multidisciplinar. Só a demonstração as usa; o app real importa apenas `scheduling/agenda_conflicts.dart` e `widgets/sync_banner.dart`.

## 2. Estado por fluxo

| Fluxo | App real | Demonstração |
|---|---|---|
| Login e papéis | Funcional (sem recepção cadastrável: só existe `createClinic`) | Funcional por perfil, sem login |
| Psicólogo e fisioterapeuta como papéis | Não existe | Funcional como contas |
| Cadastro e vínculo da criança | Parcial: cadastro grava; segundo responsável exige digitar o UID e nunca vê a criança | Parcial: criança criada não recebe vínculo de cuidado, o pediatra não a abre e a consulta iniciada pela agenda falha |
| Família agenda consulta | Visual: botão "Agendar" com `onPressed: null`; `book()` e `availability()` sem chamador; lista de profissionais bloqueada pela regra de `users` | Funcional pelo assistente (regras fixas, sem IA generativa); psicologia e fisioterapia sem horários |
| Recepção: confirmar, cancelar, remarcar | Parcial: agenda do profissional e recepção gravam; nenhuma tela cria consulta | Funcional |
| Retorno | Não existe (só texto no resumo) | Parcial: prazo vira tarefa; sem "agendar retorno" |
| Configurar horários, bloqueios, férias | Parcial: horários semanais e bloqueios da clínica | Visual: horários fixos no código, só para os pediatras |
| Reserva temporária e marcação duplicada | Parcial: `bookAppointment` confere conflito em transação; sem reserva temporária | Parcial: confere conflito ao gravar; sem reserva temporária |
| Pré-consulta (queixas, dúvidas, fotos, exames) | Parcial: só texto; sem anexos; Storage bloquearia o profissional | Funcional para a família; o cartão dentro da consulta mostra a última pré-consulta do paciente, não a da consulta |
| Evolução por profissão | Parcial: só pediatria; correção (`amendEncounter`) sem tela; histórico do paciente negado pela regra e sem índice | Pediatria funcional (rascunho, finalizar, complemento); psicologia e fisioterapia com formulário genérico, sem rascunho nem finalização |
| Revisar e finalizar; alteração após finalizar | Parcial: assinatura por Function; sem etapa de revisão | Pediatria: complemento com autor; puericultura: correção com motivo; demais profissões: revisões sem finalização |
| Documentos (receituário, atestado, encaminhamento, orientações) | Parcial: emissão por Function com código de verificação; modelos fixos; sem orientações; sem liberação à família | Funcional para pediatria (modelos por profissional e clínica, prévia, PDF, versões, liberação); psicologia e fisioterapia sem PDF |
| Acompanhamento pela família | Parcial: consultas e resumos liberados; tela de documentos não existe | Funcional (pediatria); sessões de outras profissões só na área de cuidado |
| Resumo compartilhável entre profissões | Visual: regras prontas, nenhuma tela do app usa | Funcional por registro (não por atendimento); consentimento do responsável é por vínculo, não por resumo; sem finalidade nem prazo |
| Trilha de auditoria | Parcial: `security_audit_logs` (só profissionais gravam), `audit_log` das Functions | Funcional em várias telas |
| IA na consulta (gravação e transcrição) | Visual: cronômetro sem captura de áudio nem transcrição; estruturação por IA preparada nas Functions sem chave; consentimento registrado como do próprio profissional | Parcial: "Inserir rascunho simulado" e organizador por regras |
| IA de agenda para recepção e campanhas | Não existe | Parcial: painel de acompanhamento e lembretes simulados; sem aprovação de envio em lote |

## 3. Regras de acesso e banco

- `firestore.rules` (1.740 linhas) protege `appointments`, `pre_visit_questionnaires`, `encounters`, `clinical_documents`, `visit_summaries`, `voice_sessions`, `clinics/**` e `care_teams/**`.
- Pontos que contrariam o pedido atual:
  - o responsável lê o prontuário completo (`encounters`) de qualquer profissão, porque a regra usa `ownsChild`;
  - a recepção precisa ser "profissional verificado" para alterar consultas;
  - nada separa profissões dentro de `encounters`;
  - não há coleção de resumo por atendimento nem de consentimento para gravação.
- `storage.rules`: arquivos do usuário só para o dono; caminhos do cuidado multidisciplinar prontos; nenhum caminho para anexos de pré-consulta nem para áudio de consulta.

## 4. Testes existentes (última execução, 03/10)

| Suíte | Resultado |
|---|---|
| `flutter test` | 858/859 (a falha é antiga e depende do relógio: agenda dia/semana/mês) |
| Regras no emulador (`test/rules`) | 196/196 |
| Functions (Jest) | 25/25 (agendamento, WhatsApp, voz) |
| Navegador na demonstração (`tools/demo/e2e_clinico.js`) | blocos do cuidado 34/34; suíte completa da etapa anterior aprovada |

Não há testes de ponta a ponta do app real com contas de teste.

## 5. Botões e navegação

- Sem `onPressed: () {}` vazios na demonstração. Indisponíveis por decisão: vídeo da teleconsulta, cobrança online, exportação, termos e "registrar vacina" (só aviso).
- Navegação: quase tudo usa `context.go`. Voltar segue a árvore de rotas, não a origem. Exemplos: consulta aberta pela agenda volta ao prontuário; a área de cuidado e o resumo não têm botão de voltar.
