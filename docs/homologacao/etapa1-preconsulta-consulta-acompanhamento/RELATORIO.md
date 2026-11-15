# Pedi360 - Etapa 1: pré-consulta, consulta e acompanhamento (homologação web)

Primeira etapa da plataforma integrada para profissionais e famílias. Tudo foi feito na demonstração, com dados fictícios em memória (nada é salvo ao fechar a aba). As regras novas ficam em `lib/shared` para o app real reaproveitar.

| Tela | Endereço (na demonstração) |
|---|---|
| Saúde e desenvolvimento (família) | `#/rotina/p1/saude?perfil=responsavel` |
| Documentos da consulta (família) | `#/rotina/p1/documentos?perfil=responsavel` |
| Pré-consulta enviada pela família, com orientações | `#/pre-consulta/a6?perfil=responsavel` |
| Revisão da pré-consulta com resumo organizado (profissional) | `#/pacientes/p1/pre-consulta?perfil=profissional` |
| Liberar ou retirar documento da área da família | `#/pacientes/p1/documentos/d1?perfil=profissional` |
| Orientações antes da consulta (configuração) | `#/orientacoes-previas?perfil=profissional` |
| Consulta com hipóteses diagnósticas | `#/pacientes/p5/consulta/c2?etapa=avaliacao&perfil=profissional` |

- Branch `feat/area-profissional`, commits locais `ed57698` (etapa 1) e o seguinte, com a ordem das seções do documento e este relatório. **Ainda não foram enviados ao GitHub nem publicados no link público**: os dois passos aguardam sua autorização.
- Nada foi publicado nas lojas e nada foi ativado em produção. O app real não foi alterado e o login da versão real continua como estava.
- WhatsApp e IA real continuam só preparados ou simulados.

## O que já existia e foi aproveitado

Levantado antes de implementar, sem duplicar:
- **Pré-consulta da família:** queixa, sintomas, medicamentos, dúvidas, fotos e exames, com envio, correção e anexos originais. O profissional já revisava as respostas.
- **Agenda:** horários do profissional, solicitação, confirmação e remarcação pela família, assistente de horários (simulado) com confirmação final, lembretes com consentimento.
- **Diário da criança:** mamadas, alimentação, fraldas, banho, sono, temperatura, peso e observações, com data, horário e calendário.
- **Clínica:** prontuário, consulta com anamnese, exame físico, avaliação, conduta e retorno; puericultura; curvas de crescimento (OMS); vacinação; marcos; vitaminas e exames laboratoriais; calculadora de doses com revisão obrigatória.
- **Documentos:** receita, atestado, encaminhamento, exames e orientações, com modelos, revisão, emissão, PDF, impressão e logomarca.
- **Orientações da clínica para a família:** já mostravam as orientações emitidas.

## O que foi corrigido
- **Documentos para a família:** antes, qualquer orientação emitida aparecia automaticamente para a família. Agora só aparece o que o profissional liberou.
- **Resumo da pré-consulta:** o profissional via apenas as respostas soltas. Agora vê um resumo organizado, mantendo as respostas e os arquivos originais.
- **Rótulos de assistente:** os textos simulados eram marcados só como "Simulado". Agora todo texto automático mostra a origem e "Revisão humana obrigatória".

## O que foi criado

### Família (responsável, só as próprias crianças)
- **Saúde e desenvolvimento**, a partir da ficha da criança:
  - próximas consultas, com as orientações daquela consulta e o botão "Abrir pré-consulta";
  - consultas anteriores: data, tipo, profissional, clínica, retorno e documentos liberados, sem anotações clínicas internas;
  - último crescimento com acesso às curvas; vacinação; marcos adquiridos na última puericultura; orientações por faixa etária.
- **Documentos da consulta:**
  - só documentos emitidos e liberados, agrupados por consulta e filtrados por tipo (Receitas, Orientações, Exames solicitados, Encaminhamentos, Atestados e declarações);
  - abrir, baixar PDF e voltar; estado vazio "Nenhum documento liberado".
- **Orientações antes da consulta:** aparecem na pré-consulta, na lista de próximas consultas e na confirmação do agendamento, com o aviso fixo "Se a criança piorar antes da consulta, não espere o horário marcado: procure atendimento de urgência."

### Profissional
- **Liberação para a família:**
  - área "Área da família" no documento: liberar (com confirmação) ou retirar (com motivo obrigatório);
  - só quem emitiu libera ou retira, e só depois de emitir;
  - histórico com quem, quando e motivo, também no registro de auditoria;
  - ao emitir, a opção "Liberar para a família ao emitir" vem marcada só para orientações; receita, atestado, encaminhamento e exames precisam de escolha explícita.
- **Resumo organizado da pré-consulta:**
  - seções: motivo, sintomas e evolução, medicamentos em uso, outras informações, anexos por tipo;
  - "Para conferir": medicamentos (omitido quando a família responde "Nenhum"), anexos com mais de 6 meses, datas ausentes e abrir os arquivos originais;
  - feito por regras, sem IA, com o rótulo "Organizado por regras, sem IA - Revisão humana obrigatória" e a observação de que não é diagnóstico.
- **Orientações antes da consulta:** tela própria com texto geral e textos por tipo de consulta (rotina e puericultura, queixa, retorno, teleconsulta). Os textos padrão aparecem como "Texto sugerido pelo aplicativo. A clínica ainda não revisou." até alguém salvar com "Revisar e salvar". Tem Cancelar, Salvar e aviso ao sair sem salvar.
- **Hipóteses diagnósticas** na consulta, escritas pelo profissional, com o aviso "Escritas por você. O assistente não sugere hipóteses." Entram no resumo, no histórico e no prontuário.

## Separação de acesso e proteção dos dados

| Perfil | Pode | Não pode |
|---|---|---|
| Responsável | Ver saúde, documentos liberados e orientações das próprias crianças | Ver outra criança, documento não liberado ou rascunho (mesmo pelo endereço), anotações clínicas, hipóteses |
| Profissional | Liberar e retirar os documentos que emitiu; configurar orientações; revisar pré-consulta | Entrar na área da família como se fosse o responsável; liberar documento de outro profissional |
| Recepção, financeiro, administrador | Sem mudança nas áreas já permitidas | Área da família, documentos e configuração das orientações ("Acesso restrito") |

- A criança não tem login próprio: cada criança tem sua área dentro do acesso do responsável.
- O modelo de consulta mostrado à família (`FamilyVisit`) não carrega campos clínicos, para evitar vazamento por engano.
- No app real, essa separação precisa ser repetida nas regras de segurança do Firestore, por criança e por conta. Isso ainda não foi feito.

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test`, suíte completa, commit `ed57698` e de novo com a correção da ordem das seções | 769 aprovados, 0 falhas nas duas rodadas |
| Novos testes de regra: `test/clinical/family_release_test.dart` e `test/previsit/pre_visit_guidance_summary_test.dart` | Aprovados |
| Novos testes de tela: `test/demo_family_area_test.dart` (família no celular e no computador, liberar e retirar, liberação explícita ao emitir, orientações, recepção bloqueada, hipóteses) | Aprovados |
| `flutter analyze` | 132 apontamentos informativos antigos, em arquivos não tocados; nenhum nos arquivos da etapa |
| Build da demonstração (`tools/demo/build_demo.ps1`) | Concluído, sem termos proibidos |
| Navegador, servidor local, suíte completa (`tools/demo/e2e_clinico.js`, build do commit `ed57698`) | 425/427. As 2 falhas estão explicadas abaixo. |
| Navegador, servidor local, depois da correção: todos os blocos que passam por documentos, receitas, modelos, logomarca, orientações e etapa 1 | 127/127 aprovadas |
| Navegador, bloco "dose máxima" da calculadora, repetido isoladamente | Falha intermitente (2 de 8 na última série). Ver pendência abaixo. |

Ainda não testado no link público, porque a publicação depende da sua autorização.

### Problemas encontrados nos testes
- **Ordem das seções do documento (corrigido):** a nova "Área da família" ficava entre a assinatura e o conteúdo, empurrando o texto da receita para baixo. O teste "modelo editado depois não muda a receita emitida" falhou porque não via mais o conteúdo na tela; a receita estava intacta. A área da família agora fica no fim, depois do conteúdo e da revisão, e o bloco passou.
- **Resumo com "Nenhum" em medicamentos (corrigido):** o resumo pedia para conferir medicamentos mesmo quando a família respondia "Nenhum". Agora o item não aparece nesses casos, com teste próprio.
- **"Dose máxima" da calculadora (pendente, não é da etapa 1):**
  - no navegador automatizado, o teste apaga o campo "Dose prescrita" e digita 16; às vezes o campo fica com "6" ou vazio;
  - acontece só quando o campo fica vazio antes da digitação: substituindo o texto selecionado sem apagar, passou 10 de 10;
  - o teste liga o modo de acessibilidade do Flutter no navegador, o mesmo usado por leitores de tela. Nesse modo, a troca da tela para "Cálculo bloqueado" enquanto se digita pode tirar a tecla do campo;
  - a calculadora não foi alterada nesta etapa e a falha já tinha aparecido em 28/09. Os testes de tela da calculadora passam. Testei tirar a mensagem de erro do campo vazio e não resolveu, então a mudança foi desfeita;
  - precisa de verificação manual com leitor de tela e de uma correção própria numa próxima etapa.

## Roteiro de teste manual

Abra a demonstração e escolha o perfil pela tela inicial ou acrescente `?perfil=...` ao endereço. Os dados são fictícios e voltam ao estado inicial ao recarregar.

### Responsável (use o celular)
1. Entre como **Responsável** e abra a criança da sua família.
2. Toque em **Saúde e desenvolvimento**. Confira: próximas consultas com "Antes da consulta" e o aviso de urgência; consultas anteriores sem anotações do médico; crescimento, vacinas, marcos e orientações por faixa etária. **Voltar** deve levar à ficha da criança.
3. Em uma próxima consulta, toque **Abrir pré-consulta**. As orientações da clínica aparecem no fim. Voltar deve retornar à tela de saúde.
4. Volte e toque **Documentos da consulta**. Devem aparecer a receita e a orientação liberadas, e não o atestado. Use os filtros por tipo.
5. Abra a receita, toque **Baixar PDF** e confira o arquivo. Toque **Voltar**.
6. Tente abrir um documento não liberado pelo endereço `#/rotina/p1/documentos/d1`: deve aparecer "Documento não encontrado".
7. Tente abrir a criança de outra família (`#/rotina/p2/documentos`): não deve mostrar documentos.
8. Preencha uma pré-consulta com "Nenhum" em medicamentos e envie.

### Profissional (use o computador)
1. Entre como **Profissional**. Na página inicial, toque **Orientações antes da consulta**. Confira o aviso de texto sugerido, altere um item de "Retorno" e toque **Revisar e salvar**. Deve aparecer "Revisado por ...". Teste também **Cancelar alterações** e sair sem salvar (deve pedir confirmação).
2. Abra a pré-consulta da criança p1. Confira o **Resumo organizado** com o rótulo "Organizado por regras, sem IA - Revisão humana obrigatória", a lista "Para conferir" e, abaixo, as **Respostas originais da família** e os anexos originais. Se a pré-consulta do passo 8 do responsável foi enviada na mesma aba, sem recarregar, o item de medicamentos não deve aparecer em "Para conferir".
3. Abra o atestado emitido (d1). A área da família deve dizer que a família ainda não vê o documento. Toque **Liberar para a família** e confirme. Confira o histórico.
4. Entre como responsável: o atestado agora aparece em Documentos da consulta.
5. Volte ao profissional, toque **Retirar da área da família** e tente sem motivo (deve recusar). Informe um motivo e confirme. O motivo aparece no histórico e o documento some para a família.
6. Crie e emita um pedido de exames. A opção "Liberar para a família ao emitir" deve vir desmarcada; marque-a, emita e confira na área da família.
7. Abra uma consulta em andamento, preencha **Hipóteses diagnósticas**, salve o rascunho e confira que o campo aparece no resumo da consulta.
8. Entre como **Recepção**, **Financeiro** e **Administrador** e tente `#/rotina/p1/saude`, `#/rotina/p1/documentos` e `#/orientacoes-previas`: todos devem mostrar "Acesso restrito".

## Capturas

| Arquivo | Tela |
|---|---|
| `e1_01_saude_familia.png` | Saúde e desenvolvimento: próximas consultas com orientações |
| `e1_02_saude_consultas.png` | Consultas anteriores vistas pela família |
| `e1_03_documentos_familia.png` | Documentos liberados, agrupados por consulta |
| `e1_04_receita_familia.png` | Receita liberada aberta pela família |
| `e1_05_documento_nao_liberado.png` | Profissional: atestado emitido ainda oculto para a família |
| `e1_06_documento_liberado.png` | Atestado liberado, com histórico |
| `e1_07_documento_retirado.png` | Liberação retirada, com motivo |
| `e1_08_resumo_pre_consulta.png` | Resumo organizado da pré-consulta e respostas originais |
| `e1_09_orientacoes_config.png` | Configuração das orientações, revisada |
| `e1_10_preconsulta_orientacoes.png` | Orientações na pré-consulta da família |
| `e1_11_hipoteses.png` | Hipóteses diagnósticas na consulta |

## Depende de você

**Decisões:**
1. Autorizar o envio da branch ao GitHub, o comentário no PR e a publicação no link público.
2. Quais estados de marcos a família vê. Hoje mostra só "Adquirido", para não expor "Requer seguimento" sem conversa com o profissional.
3. Se receita, atestado, encaminhamento e exames devem continuar exigindo liberação explícita (padrão atual) ou ser liberados ao emitir.

**Revisão clínica:**
- Textos padrão das orientações antes da consulta (sugeridos pelo aplicativo, sem copiar material de terceiros).
- Critério de "anexo antigo" no resumo (mais de 6 meses).

**Credenciais ou serviço externo (nada foi ativado):**
- App real: gravação da liberação, do resumo e das orientações no Firestore, e regras de segurança por criança e por conta.
- WhatsApp oficial e IA real, para mensagens e rascunhos.

## Próximas etapas
- Modelos próprios de evolução, atestado, encaminhamento e orientações (receita já existe).
- Visual novo: azul-marinho com turquesa e coral, fundos menos brancos, tema claro e escuro, ícones 3D do projeto em tamanho otimizado, celular e computador.
- Revisar os lembretes de retorno com consentimento e o painel de envio (enviado, falhou, pendente).
- Tabela final de funcionalidades com status real, tela, origem dos dados e pendência.
