# Anexos na pré-consulta: relatório de homologação

Versão publicada na demonstração: fonte `29aa169`, Pages `0c9188c`.
Todos os dados, fotos e PDFs usados são fictícios. O app real, o Firebase e as lojas não foram alterados.

## O que existia

- **App real:** o questionário de pré-consulta (`pre_visit_questionnaire_form_screen.dart`) tem um campo `attachmentUrls` na entidade, mas nenhuma tela o usa. O `storage.rules` só tem as pastas `/users/{uid}` (imagens até 8 MB) e `/public`, e nega todo o resto. Não existe lugar no Storage para anexos de pré-consulta.
- **Demonstração:** não havia pré-consulta.

Como ativar anexos no app real exigiria uma pasta nova no Storage e novas regras em produção, a funcionalidade foi feita **só na demonstração**. As regras necessárias estão propostas no fim deste relatório, sem publicação.

## O que foi implementado

### Família (perfil Responsável)

- **Onde entra:**
  - no Início, a seção "Próximas consultas" mostra cada consulta com a situação da pré-consulta (Não preenchida / Rascunho / Alterações não enviadas / Enviada em …);
  - na ficha da criança, um atalho "Pré-consulta de dd/mm às hh:mm" para cada consulta futura.
- **Tela da pré-consulta:**
  - campos: motivo da consulta, sintomas e quando começaram, medicamentos em uso, outras observações;
  - dois botões: **Adicionar foto da queixa** (lesões de pele, alterações visíveis) e **Adicionar exame, laudo ou relatório** (foto ou PDF).
- **Conferir antes de incluir:** para cada arquivo abre a janela "Conferir anexo antes de incluir", com:
  - **prévia**: imagem ampliável; para PDF, o número de páginas e o botão "Abrir PDF para conferir", que abre o arquivo original em outra aba;
  - **tipo do documento**: Foto da queixa, Exame, Laudo ou Relatório médico. Para documentos a escolha é obrigatória. "Foto da queixa" fica desativada quando o arquivo é PDF;
  - **data**: "Data do exame" (obrigatória para exame e laudo), "Data do relatório" (obrigatória) e "Data da foto" (opcional). Pode ser digitada ou escolhida no calendário. Não aceita data futura nem anterior ao nascimento;
  - **descrição** opcional (até 80 caracteres).
- **Lista de anexos:** separada em "Fotos da queixa" e "Exames, laudos e relatórios". Cada anexo mostra miniatura, tipo, data, nome, formato, tamanho e a situação ("Ainda não enviado" ou "Enviado em …").
  - **Ver** abre o arquivo ampliado.
  - **Remover** pede confirmação. Se o anexo já tinha sido enviado, o histórico registra a remoção e a clínica deixa de ver o arquivo.
- **Envio:**
  - só depois de marcar "Autorizo o envio destas informações e anexos à equipe da clínica que atende [criança]"; sem a marcação, aparece um aviso logo abaixo da caixa;
  - até o envio, respostas e anexos são rascunho e a clínica não vê nada;
  - depois do envio, a família pode editar e usar "Enviar alterações". A clínica sempre vê a última versão enviada;
  - com a consulta concluída, a pré-consulta fica só para leitura.
- **Aviso fixo:** "Os anexos ajudam a preparar a consulta. Não são diagnóstico nem resultado validado: o profissional avalia cada um." Nenhum conteúdo de arquivo é lido, interpretado ou resumido automaticamente.

### Profissional autorizado

- **Na consulta da criança**, a etapa 1 tem o cartão "Pré-consulta enviada pela família", com a data da consulta, quando foi enviada e quantas fotos e documentos há, além do botão **Ver pré-consulta**. O botão Voltar da pré-consulta retorna à consulta. O cartão mostra a pré-consulta enviada mais recente da criança, identificada pela data do agendamento.
- **Página da pré-consulta** (`/pacientes/:id/pre-consulta`):
  - uma seção por consulta, da mais recente para a mais antiga;
  - respostas enviadas;
  - anexos agrupados em "Fotos da queixa" e "Exames, laudos e relatórios", do mais recente para o mais antigo pela data informada;
  - histórico de envios e remoções;
  - aviso para conferir cada anexo e registrar a avaliação no prontuário.
- **Também aparece** na ficha do paciente (atalho "Pré-consulta enviada pela família") e no agendamento (situação e botão Ver pré-consulta).
- **Sem edição:** o profissional só visualiza; não há Remover nem Adicionar.

### Limites e formatos

| Regra | Valor |
|---|---|
| Formatos aceitos | JPG, PNG, WEBP e PDF |
| Tamanho por arquivo | até 10 MB |
| Quantidade | até 10 anexos por pré-consulta |
| Total | até 40 MB por pré-consulta |

O formato é conferido pelo **conteúdo** do arquivo, não pelo nome. Mensagens quando o arquivo não pode ser enviado (janela "Arquivo não anexado"):

- arquivo vazio;
- acima de 10 MB, informando o tamanho e sugerindo foto menor ou PDF em partes;
- soma acima de 40 MB;
- 11º anexo;
- foto HEIC do iPhone, com o caminho para enviar como JPG;
- formato não aceito, avisando quando o nome termina como um formato aceito mas o conteúdo não é;
- PDF protegido por senha;
- arquivo repetido.

### Proteção de acesso (na demonstração)

| Perfil | Pré-consulta |
|---|---|
| Responsável vinculado à criança | preenche, anexa, vê, remove e envia |
| Responsável de outra família | "Pré-consulta indisponível"; qualquer tentativa de alteração é recusada |
| Profissional da clínica que atende | vê só o que foi enviado (nunca rascunhos) |
| Profissional de outra clínica (conta "Dr. Exemplo Colega") | "Acesso restrito: esta conta é de outra clínica"; o cartão não aparece na consulta |
| Recepção | vê só a situação no agendamento ("enviada em … com N anexos"), sem abrir respostas ou arquivos |
| Financeiro e administração | "Acesso restrito" |

Na demonstração tudo fica na memória da aba e some ao recarregar a página.

## Testes executados

| Teste | Resultado |
|---|---|
| Unitários das regras (`test/previsit/pre_visit_test.dart`) | 16/16 aprovados |
| Widget da demo (`test/demo_pre_visit_test.dart`), celular e computador | 6/6 aprovados |
| Suíte completa `flutter test` | 638/638 aprovados |
| `flutter analyze` | 132 avisos informativos, os mesmos de antes; nenhum nos arquivos novos |
| Navegador automatizado no link público (`e2e_clinico.js`, filtro pré-consulta) | 33/33 aprovados |
| Regressão completa no link público | 259/261 na 1ª rodada. As 2 falhas eram erro do próprio script de teste: um nome repetido interrompeu as etapas "documentos" e "logomarca" antes de começarem. Após a correção, essas etapas e a pré-consulta foram repetidas: 59/59 aprovadas |

### O que o teste no link público verificou

- **Celular (390 × 844, toque):**
  - próximas consultas no Início;
  - abrir a pré-consulta;
  - aviso de que anexo não é diagnóstico;
  - prévia da foto;
  - foto incluída como rascunho;
  - PDF conferido e aberto em outra aba;
  - tipo e data obrigatórios;
  - data futura recusada;
  - laudo com a data do exame;
  - anexo por engano: confirmação e remoção;
  - mensagens para nome enganoso, arquivo de 11 MB e HEIC;
  - visualizar antes do envio;
  - envio exige autorização;
  - enviada com 2 anexos;
  - profissional vê motivo e anexos organizados e abre o PDF.
- **Computador (1366 × 860):**
  - cartão na consulta da criança;
  - abrir a partir da consulta;
  - grupos de fotos e documentos;
  - foto ampliada;
  - voltar à consulta;
  - situação no agendamento;
  - família envia relatório pelo computador;
  - criança de outra família não abre.
- **Permissões:**
  - recepção só vê a situação;
  - financeiro e administração bloqueados;
  - o profissional não usa a tela da família;
  - outra clínica não vê os anexos.

Capturas: `pc01` a `pc20` nesta pasta.

### O que não foi testado

- Aparelho físico: iPhone e Android reais. O celular foi simulado no Chrome.
- Foto HEIC real tirada no iPhone. O teste usou um arquivo com a assinatura HEIC.
- Abertura do PDF no Chrome do Android, que costuma entregar o PDF a outro aplicativo em vez de mostrar na aba.
- Leitor de tela usado manualmente.

## Pendências e decisões para você

1. **Limites:** 10 MB por arquivo, 10 anexos e 40 MB por pré-consulta são sugestões; confirme ou ajuste.
2. **Validação clínica:** os textos dos avisos e a lista de tipos (foto da queixa, exame, laudo, relatório médico) precisam da sua revisão.
3. **App real (não feito, exige sua autorização para produção):**
   - **Storage:** pasta `pre_visit/{appointmentId}/{arquivo}`. A regra proposta abaixo segue o mesmo modelo do `pre_visit_questionnaires`: família = `patientId` do agendamento, profissional = `professionalId`. **Não publicada.**

     ```
     match /pre_visit/{appointmentId}/{fileName} {
       function appt() {
         return firestore.get(/databases/(default)/documents/appointments/$(appointmentId)).data;
       }
       allow read: if request.auth != null
         && (appt().patientId == request.auth.uid
             || appt().professionalId == request.auth.uid);
       allow create: if request.auth != null
         && appt().patientId == request.auth.uid
         && appt().status in ['requested', 'confirmed']
         && request.resource.size <= 10 * 1024 * 1024
         && request.resource.contentType.matches('image/(jpeg|png|webp)|application/pdf');
       allow delete: if request.auth != null
         && appt().patientId == request.auth.uid
         && appt().status in ['requested', 'confirmed'];
       allow update: if false;
     }
     ```

   - **Limites de quantidade e total:** as regras do Storage não contam arquivos. Para impor 10 anexos e 40 MB é preciso um documento de controle no Firestore ou uma Cloud Function.
   - **Equipe autorizada:** a regra acima libera só o profissional do agendamento. Liberar outros membros da equipe clínica exige o modelo de vínculo da clínica.
   - **Privacidade das fotos:** fotos de celular podem trazer a localização (metadados EXIF). No app real, esses dados devem ser removidos antes do envio.
   - **Retenção e consentimento (LGPD):** falta definir por quanto tempo os anexos ficam guardados e como a família pede a exclusão.
4. **Verificação de vírus** dos PDFs no servidor: recomendável no app real.
