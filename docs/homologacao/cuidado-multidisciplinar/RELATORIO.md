# Cuidado multidisciplinar: relatório de homologação

Branch `feat/area-profissional`, 02/10/2026. Todos os nomes, registros profissionais e conteúdos clínicos usados nos testes e nas capturas são fictícios.

**Situação:** o módulo está pronto na camada de domínio (`lib/shared/care/`), nas regras do Firestore e do Storage e na demonstração. No aplicativo real, as telas ainda não foram construídas: o acesso aos dados já é controlado pelas regras do banco e dos anexos, mas falta a interface. Nada foi publicado em produção nem no GitHub Pages.

## 1. O que já existia, o que era só visual e o que foi criado

Levantamento feito no commit `c75e667`, antes desta entrega.

### Já existia (aplicativo real)

- O papel `ClinicRole.healthProfessional` ("Outro profissional de saúde"): genérico, sem permissões por especialidade.
- Um campo `specialty` de texto livre no vínculo com a clínica (`ClinicMembership`), que não controlava nenhuma permissão.
- `PermissionMatrix` por módulo da clínica. "Multidisciplinar" aparecia só como apelido de rótulo para `healthProfessional`.
- No Firestore, `authorized_professionals` por criança, responsáveis vinculados com `canViewData` e vínculos de clínica.
- Nutricionista aparecia apenas em um comentário de `app_user`.

### Já existia (demonstração)

- Duas contas de pediatra (prof-a e prof-b) com registro e especialidade, pacientes, agenda, documentos e modelos.
- Área da família com documentos liberados.

### Era só visual

- O protótipo de telemedicina.
- O rótulo "multidisciplinar", sem nenhuma regra por trás.
- A IA, que já era simulada.

### Foi criado nesta entrega

| Parte | Onde |
|---|---|
| Especialidades (pediatria, psicologia, fisioterapia ativas; fonoaudiologia, terapia ocupacional e nutrição preparadas), conselho do registro | `lib/shared/care/care_model.dart` |
| Vínculo do profissional com a criança: pendente → autorizado pela família → encerrado | `care_model.dart`, `care_store.dart` |
| Registros com visibilidade (reservado, equipe, família), revisões e origem (autor, especialidade, data) | `care_store.dart` |
| Visão compartilhada da equipe e plano combinado com histórico de versões | `care_store.dart` |
| Áreas de psicologia e fisioterapia, área da família, comunicação da equipe (encaminhamento interno, parecer, mensagem) | `care_store.dart`, `lib/demo/screens/care_team_screens.dart` |
| Documentos e modelos por especialidade (rascunho → revisado → emitido → liberado) | `care_store.dart`, `care_policy.dart` |
| Rascunho de resumo pela IA, identificado e salvo só após revisão | `lib/shared/care/care_ai.dart` |
| Trilha de acessos e alterações por criança, inclusive tentativas recusadas | `care_store.dart` |
| Matriz de permissões (fonte única das regras do domínio) | `lib/shared/care/care_policy.dart` |
| Regras do banco: `care_teams/{criança}` com `members`, `records` (+ `revisions`), `plan`, `messages`, `documents` e `access_log`, além de `care_templates` | `firestore.rules` |
| Regras dos anexos: `care/{criança}/{registro}/{arquivo}` | `storage.rules` |
| Demonstração: contas de psicóloga, segundo psicólogo e fisioterapeuta, ficha multidisciplinar da Luna, perfil profissional, pacientes vinculados | `lib/demo/demo_care.dart`, `care_team_screens.dart`, `demo_session.dart`, `demo_router.dart` |

## 2. Como o acesso funciona

1. **Vínculo real com a criança.** O acesso existe só se o profissional tiver vínculo ativo com aquela criança. O vínculo começa como *pendente*, pedido pela gestão da clínica ou pelo próprio profissional ao aceitar um encaminhamento, e só vale depois que a família o autoriza. Pertencer à mesma clínica não dá acesso a nada.
2. **Especialidade do vínculo.** A especialidade que define o que o profissional pode registrar e emitir é a conferida no cadastro (`users/{uid}.careSpecialty`), e não a que ele declara. O pedido de vínculo é recusado se as duas não coincidirem, e todo registro e documento precisa ter a especialidade do vínculo.
3. **Clínica do registro.** A equipe vê os registros da própria clínica. Se a família trocar de clínica, todos os vínculos são encerrados e a nova equipe começa sem acesso ao que foi registrado antes.
4. **O autor lê o que escreveu**, mesmo depois de encerrado o vínculo, por causa da guarda do prontuário. Ele não lê mais os registros dos outros.
5. **Reservado.** Só a psicologia pode criar registros reservados, e só o autor os lê. O que vai para a equipe é um *resumo para a equipe* separado, escrito pela psicóloga. O texto reservado nunca é copiado para esse resumo, para a família nem para a IA.
6. **Família.** A família recebe só orientações, atividades para casa e documentos emitidos que o profissional liberou explicitamente. Ela também vê quem está na equipe atual, os próximos atendimentos, os pedidos de vínculo aguardando autorização e a trilha de acessos. A comunicação da equipe e o plano combinado não aparecem para a família.
7. **Gestão da clínica.** A gestão organiza a equipe (designa e encerra vínculos) e lê a trilha da clínica, mas não lê registros nem documentos.
8. **Origem.** Todo registro, versão do plano, mensagem e documento guarda o autor, a especialidade e a data. Rascunhos preparados pela IA são marcados e indicam os registros que serviram de fonte.

## 3. Matriz de permissões

### 3.1 Ações por especialidade

"Sim" significa permitido. Fonoaudiologia, terapia ocupacional e nutrição já têm o perfil e as permissões definidos, mas a área própria na ficha ainda não foi ativada.

| Ação | Pediatria | Psicologia | Fisioterapia | Fono / TO | Nutrição |
|---|---|---|---|---|---|
| Prescrever medicamentos e calcular doses | Sim | — | — | — | — |
| Solicitar exames laboratoriais | Sim | — | — | — | — |
| Emitir atestado médico | Sim | — | — | — | — |
| Avaliação e evolução psicológica | — | Sim | — | — | — |
| Registro reservado | — | Sim | — | — | — |
| Avaliação funcional e medidas | — | — | Sim | Sim | — |
| Exercícios e atividades para casa | — | — | Sim | Sim | — |
| Orientações aos responsáveis | Sim | Sim | Sim | Sim | Sim |
| Liberar conteúdo para a família | Sim | Sim | Sim | Sim | Sim |
| Editar o plano compartilhado | Sim | Sim | Sim | Sim | Sim |
| Encaminhamento interno | Sim | Sim | Sim | Sim | Sim |
| Solicitar parecer | Sim | Sim | Sim | Sim | Sim |
| Mensagens da equipe | Sim | Sim | Sim | Sim | Sim |
| Rascunho de resumo pela IA (com revisão) | Sim | Sim | Sim | — | — |

As ferramentas médicas da demonstração (calculadora de doses, prontuário médico, suplementação) só aparecem para a pediatria.

### 3.2 Registros por especialidade

| Registro | Pediatria | Psicologia | Fisioterapia | Fono / TO | Nutrição | Pode ir à família |
|---|---|---|---|---|---|---|
| Resumo para a equipe | Sim | Sim | Sim | Sim | Sim | — |
| Avaliação | Sim | Sim | — | Sim | Sim | — |
| Evolução da sessão | — | Sim | — | — | — | — |
| Plano terapêutico | — | Sim | — | — | — | — |
| Avaliação funcional | — | — | Sim | — | — | — |
| Objetivos | Sim | Sim | Sim | Sim | Sim | — |
| Plano de sessões | — | — | Sim | — | — | — |
| Intervenções realizadas | — | — | Sim | — | — | — |
| Evolução | Sim | — | Sim | Sim | Sim | — |
| Medida de acompanhamento | — | — | Sim | — | — | — |
| Orientação aos responsáveis | Sim | Sim | Sim | Sim | Sim | Sim |
| Atividade ou exercício para casa | — | — | Sim | Sim | — | Sim |

Visibilidade: *reservado* só para psicologia; *liberado para a família* só para orientação e atividade para casa, e só depois de o autor liberar. Qualquer outro registro fica visível à equipe da mesma clínica.

### 3.3 Documentos por especialidade

| Documento | Pediatria | Psicologia | Fisioterapia | Fono / TO / Nutrição |
|---|---|---|---|---|
| Atestado médico | Sim | — | — | — |
| Receituário | Sim | — | — | — |
| Solicitação de exames | Sim | — | — | — |
| Declaração de comparecimento | Sim | Sim | Sim | Sim |
| Encaminhamento | Sim | Sim | Sim | Sim |
| Orientações aos responsáveis | Sim | Sim | Sim | Sim |
| Relatório psicológico | — | Sim | — | — |
| Relatório fisioterapêutico | — | — | Sim | — |
| Plano de exercícios para casa | — | — | Sim | — |

O documento nasce como rascunho e passa por revisado e emitido; depois de emitido, pode ser liberado à família. A equipe da mesma clínica só lê documentos emitidos. Os modelos pessoais (`care_templates`) também só aceitam tipos da especialidade do profissional.

### 3.4 Acesso por papel

| Quem | Ficha multidisciplinar | Reservado | Registros da equipe | Plano combinado | Comunicação | Conteúdo para a família | Vínculos | Trilha de acessos |
|---|---|---|---|---|---|---|---|---|
| Profissional com vínculo ativo | Abre | Só os próprios | Lê os da mesma clínica; cria os tipos da sua especialidade; edita só os próprios (com revisão gravada) | Lê e edita (versões guardadas) | Lê e envia | Cria e libera os próprios | Encerra o próprio | — |
| Profissional com vínculo pendente | Não abre | — | — | — | — | — | Aguarda a família | — |
| Profissional da mesma clínica, sem vínculo | Não abre | — | — | — | Só o encaminhamento aberto para ele ou para a sua especialidade, para aceitar ou recusar | — | Aceitar encaminhamento gera pedido pendente | — |
| Profissional com vínculo encerrado | Não abre | Só os próprios (guarda) | Só os próprios | — | — | — | Pode receber novo pedido | — |
| Profissional de outra clínica | Não abre | — | — | — | — | — | — | — |
| Família / responsável | Área da família | — | — | — | — | Lê orientações, atividades e documentos liberados; vê a equipe atual e os próximos atendimentos | Autoriza, encerra, troca de clínica | Lê toda a trilha da criança |
| Gestão da clínica | Vê a equipe da clínica | — | — | — | — | — | Designa (pedido pendente) e encerra | Lê a trilha da clínica |
| Recepção | Não abre (continua com a agenda, como antes) | — | — | — | — | — | — | — |
| Financeiro | Não abre | — | — | — | — | — | — | — |
| Administração da plataforma | Não abre | — | — | — | — | — | — | — |

Profissionais sem verificação do registro profissional não criam vínculo nem leem registros.

## 4. Onde as permissões são aplicadas

| Camada | O que faz |
|---|---|
| Domínio (`care_policy.dart`, `care_store.dart`) | Toda leitura e escrita passa pela política. Recusas lançam `CareAccessDenied` e entram na trilha. |
| Firestore (`firestore.rules`, bloco "Cuidado multidisciplinar") | Mesma matriz: vínculo ativo e verificado, especialidade conferida, mesma clínica, reservado só para o autor, família só com o que foi liberado, tipos por especialidade, transições de vínculo explícitas, revisões obrigatórias, IA só com `reviewedBy` de quem grava, trilha sem alteração nem exclusão. |
| Storage (`storage.rules`, `care/{criança}/{registro}/{arquivo}`) | O anexo herda a visibilidade do registro: autor; equipe ativa da mesma clínica, quando o registro não é reservado; responsável, quando liberado à família. Aceita imagem ou PDF até 10 MB e não permite substituir nem apagar. |
| Interface da demonstração | Esconde o que o perfil não pode fazer: abas, botões, ferramentas médicas e tipos de documento. A interface não é a proteção principal; quem protege é o domínio e, no aplicativo real, as regras. |
| Trilha | Registra abertura, criação, edição, liberação, retirada, vínculos, troca de clínica e tentativas recusadas, com autor, data e alvo. Aberturas repetidas em sequência são agrupadas. |

**Comportamento do emulador documentado:** durante os testes, uma expressão do tipo `false && (careGuardian() || x)` foi aceita pelo emulador de regras. Por isso, a atualização de vínculo foi reescrita como uma máquina de estados explícita em ternário, e `careGuardian()` fica sempre por último nas disjunções do bloco. Há testes cobrindo exatamente essas tentativas: profissional pendente se ativando sozinho e alteração de motivo ou status por quem não pode.

## 5. Cenário testado

A criança fictícia **Luna Exemplo Souza** é atendida no Consultório Exemplo por:

- **Pediatra:** conta principal da demonstração;
- **Psicóloga Exemplo Ramos:** CRP fictício;
- **Fisioterapeuta Exemplo Moura:** CREFITO fictício.

Na troca de profissional, o **Psicólogo Exemplo Teixeira** assume a psicologia. Também há o **Dr. Exemplo Colega**, pediatra da mesma clínica sem vínculo com a Luna.

| Item pedido | Como foi verificado | Resultado |
|---|---|---|
| Agendas separadas | Cada profissional vê só a própria agenda; a ficha mostra os próximos atendimentos de cada um | Aprovado (widget e navegador) |
| Plano compartilhado | Plano editado pela equipe, com autor, especialidade e versão; a IA prepara rascunho marcado | Aprovado (domínio, regras, navegador) |
| Evolução individual | Registros por especialidade com autor e data; a edição grava a revisão anterior | Aprovado (domínio, regras) |
| Reservado bloqueado para os demais | Pediatra, fisioterapeuta, novo psicólogo, família e gestão não leem o reservado; a psicóloga lê | Aprovado (domínio, regras, Storage, navegador) |
| Orientação liberada para a família | O exercício da fisioterapeuta aparece para a família só depois de liberado; anotações reservadas não aparecem | Aprovado (domínio, regras, navegador no celular) |
| Troca de profissional | Gestão encerra a psicóloga e designa o novo psicólogo; ele aguarda a família; depois de autorizado, vê o plano e o resumo, mas não o reservado da anterior; a anterior lê só o que escreveu | Aprovado (domínio, regras, navegador) |
| Troca de clínica | A família troca de clínica; todos os vínculos são encerrados; a nova equipe não vê os registros anteriores; a família mantém o que foi liberado; a fisioterapeuta antiga perde a visão da equipe | Aprovado (domínio, regras, navegador) |
| Mesma clínica sem vínculo | O Dr. Exemplo Colega não abre a ficha multidisciplinar da Luna | Aprovado (domínio, regras, navegador) |
| Documentos por especialidade | A psicóloga não prepara atestado médico nem receituário; a fisioterapeuta prepara o plano de exercícios | Aprovado (domínio, regras, navegador) |

## 6. Resultados dos testes

Todos executados em 02/10/2026 nesta máquina.

| Suíte | Resultado |
|---|---|
| `test/care_team_test.dart` (domínio: política, vínculos, reservado, família, comunicação, documentos, IA, trilha) | 27/27 aprovados |
| `test/demo_care_flow_test.dart` (telas da demonstração) | 6/6 aprovados |
| Regras no emulador (`test/rules`, Firestore + Storage) | 182/182 aprovados, dos quais 37 novos em `care_rules.test.js` |
| `flutter test` (suíte completa) | 837/837 aprovados |
| `flutter analyze` | 0 erros, 0 avisos (restam 132 sugestões de estilo em testes antigos) |
| Navegador (Chrome, build local): fluxo multidisciplinar | 23/23 verificações aprovadas |
| Navegador: suíte completa | ver a seção 6.1 |

Os 37 testes de regras cobrem: reservado; equipe e família; tipos por especialidade, inclusive especialidade falsificada e IA sem revisão; revisão obrigatória na edição; vínculo autorizado pela família, inclusive tentativa de autoativação; profissional não verificado ou de especialidade diferente; outra clínica; troca de profissional; troca de clínica; comunicação; documentos por especialidade; trilha sem alteração; modelos e `careSpecialty` gravado só pelo servidor; anexos no Storage.

### 6.1 Suíte completa no navegador

A suíte completa (todos os fluxos da demonstração, inclusive os 23 do cuidado multidisciplinar) foi iniciada às 23h22 de 02/10/2026 sobre a build desta entrega. O resultado será registrado aqui quando a execução terminar.

Na execução anterior (02/10, 21h20, antes do módulo multidisciplinar) foram 447 de 450 verificações aprovadas. Duas falhas dependem do relógio: a contagem de horários livres da semana considera só horários futuros, e na sexta à noite não sobra nenhum. A terceira era do próprio script e já foi corrigida (detalhes em `docs/homologacao/documentos-consulta/RELATORIO.md`).

## 7. Capturas

Geradas pelo teste de navegador, na build local da demonstração.

| Arquivo | O que mostra |
|---|---|
| `cm01_visao_equipe.png` | Visão compartilhada: profissionais, motivos dos encaminhamentos, objetivos, plano combinado, próximos atendimentos e evolução relevante |
| `cm02_ia_rascunho.png` | Rascunho da IA (simulado), identificado e aguardando revisão |
| `cm03_psicologia_vista_pela_pediatra.png` | Área de psicologia vista pela pediatra: só o resumo para a equipe, sem o reservado |
| `cm04_psicologia_reservado.png` | A psicóloga vê o próprio registro reservado |
| `cm05_fisioterapia.png` | Área de fisioterapia: avaliação funcional, medidas, plano de sessões e exercícios |
| `cm06_comunicacao.png` | Comunicação: encaminhamento interno, solicitação de parecer e mensagens com autor e data |
| `cm07_documentos_psicologia.png` | Documentos que a psicóloga pode preparar (sem atestado médico nem receituário) |
| `cm08_perfil_psicologa.png` | Perfil profissional: registro, pacientes vinculados, modelos e documentos |
| `cm09_pacientes_vinculados.png` | A psicóloga vê só a criança vinculada |
| `cm10_mesma_clinica_sem_vinculo.png` | Pediatra da mesma clínica sem vínculo: ficha bloqueada |
| `m_cm11_familia.png` | Área da família no celular: próximas sessões e orientações liberadas |
| `m_cm12_familia_exercicio_liberado.png` | Exercício liberado pela fisioterapeuta aparecendo para a família |
| `cm13_gestao_equipe.png` | Gestão organizando a equipe, sem acesso aos registros |
| `cm14_designado_aguardando.png` | Novo psicólogo designado, aguardando autorização da família |
| `cm15_familia_autoriza.png` | A família autoriza o vínculo |
| `cm16_novo_psicologo.png` | O novo psicólogo vê o plano e o resumo, mas não o reservado da anterior |
| `cm17_psicologa_anterior.png` | A psicóloga anterior lê só os próprios registros |
| `cm18_trilha_acessos.png` | Trilha de acessos e alterações vista pela família |
| `cm19_troca_de_clinica.png` | Troca de clínica: equipe encerrada, conteúdo liberado mantido |
| `cm20_nova_clinica.png` | A nova clínica não vê a equipe nem os registros anteriores |

## 8. Como rodar os testes

- Domínio e telas: `flutter test test/care_team_test.dart test/demo_care_flow_test.dart`
- Regras (requer Java e Firebase CLI), a partir da raiz do app:
  `firebase emulators:exec --only "firestore,storage" --project pediatria360-rules-test "cd test\rules && node_modules\.bin\jest.cmd --runInBand"`
- Navegador: gerar a build com `tools\demo\build_demo.ps1`, servir `build/web` localmente e rodar `node tools/demo/e2e_clinico.js` com `BASE` apontando para a build. A variável `ONLY=cuidado` restringe ao fluxo multidisciplinar.

## 9. Pendências

1. **Telas do aplicativo real.** O domínio e as regras estão prontos, mas as telas multidisciplinares existem só na demonstração.
2. **Especialidade conferida pelo servidor.** `users/{uid}.careSpecialty` só pode ser gravado pelo servidor; a regra impede o próprio usuário de gravá-lo. Falta a Cloud Function que grava o campo ao verificar o registro profissional (CRM, CRP, CREFITO etc.). Até lá, nenhum profissional consegue vínculo no aplicativo real.
3. **Leituras recusadas no servidor.** No banco, a trilha aceita só acréscimos (sem alteração nem exclusão), mas quem grava é o aplicativo. Registrar no servidor toda leitura, inclusive as recusadas, exige uma Function ou os logs de auditoria do Google Cloud.
4. **Responsáveis secundários nos anexos.** A regra do Storage libera anexos à família pelo titular da conta da criança. O responsável vinculado secundário já é atendido no Firestore, mas ainda não nos anexos, porque o Storage não consegue fazer essa consulta encadeada com uma única leitura.
5. **Fonoaudiologia, terapia ocupacional e nutrição.** Perfis, registros, documentos e regras estão prontos, mas as áreas próprias na ficha não foram ativadas.
6. **IA simulada.** O rascunho é montado a partir da visão compartilhada; não há modelo real conectado.
7. **Dados da demonstração em memória.** Recarregar a página volta ao estado inicial.
8. **GitHub Pages não atualizado.** A demonstração publicada ainda não tem este módulo; publicar depende da sua autorização.
9. **Revisão jurídica e ética.** Antes do uso real, a regra de guarda (o autor continua lendo o que escreveu após o fim do vínculo) e o conteúdo mínimo do resumo da psicologia devem ser conferidos com as normas do CFP, do COFFITO e do CFM e com a LGPD.
