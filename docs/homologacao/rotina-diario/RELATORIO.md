# Pedi360 - Rotina da criança: calendário e diário (homologação web)

Demonstração pública (dados fictícios, sem Firebase):
https://draraiany-source.github.io/pediatria360-demo/

| Tela | Endereço |
|---|---|
| Rotina (família) | `#/rotina?perfil=responsavel` |
| Diário do dia | `#/rotina/p1?vista=diario&perfil=responsavel` |
| Resumo para o pediatra | `#/rotina/p1/resumo?perfil=responsavel` |
| Resumos recebidos (profissional) | `#/rotina/p1/resumos?perfil=profissional` |
| Rotina vista pelo profissional | `#/rotina/p1?perfil=profissional` |

- Branch `feat/area-profissional`, commits `bc19c75` (rotina), `a0be2fa` (varredura do build) e `3fb5b8f` (teste no navegador), no [PR #6](https://github.com/draraiany-source/pediatria360/pull/6).
- Build publicado: `a0be2fa` (arquivo `SOURCE_COMMIT.txt` do site).
- Nada foi publicado nas lojas e nada foi ativado em produção. O app real não foi alterado e o login da versão real continua como estava.

## O que foi entregue

### Uma tela, duas visões
- Novo item "Rotina" no menu do responsável e atalho "Rotina e diário" no início e na ficha da criança.
- Botões fixos no topo: Calendário / Diário e a troca de criança (Luna / Alice). Continuam visíveis ao rolar, para trocar de visão com um toque no celular.
- Tocar em um dia do calendário mostra os compromissos e a linha do tempo do diário daquele dia; "Abrir no diário" abre o mesmo dia no diário.

### Calendário
- Visões por dia, semana e mês, com "Hoje" e setas de período.
- Reúne, sem copiar nem recadastrar:
  - consultas e retornos agendados pela clínica;
  - consultas realizadas;
  - vacinas aplicadas, lidas da carteira;
  - receitas emitidas e as doses dos medicamentos prescritos;
  - atividades, lembretes, consultas e vacinas cadastrados pela família.
- Vacina pendente na carteira: "Agendar" cria um compromisso ligado a ela. A carteira não muda; o registro da aplicação continua sendo da clínica.
- Medicamento da receita: "Programar" lê intervalo e duração da posologia (por exemplo, 8/8h por 5 dias gera 15 doses) e cria os horários. Cada dose é confirmada por um registro no diário.
- Diferença visual:
  - planejado: círculo vazado;
  - realizado: círculo cheio com marca;
  - cancelado: cinza e riscado;
  - "Atrasado" aparece quando um planejado passou do horário.
- Compromissos da família: adicionar, editar, concluir, reabrir e cancelar com motivo. Cada mudança fica no histórico do compromisso.
- Lembretes: no horário, 10 min, 30 min, 1 hora ou 1 dia antes, em compromissos da família, doses e consultas da clínica. O remarcar e o cancelar de consultas da clínica continuam com a clínica.
- Filtros por tipo e legenda.

### Diário
- "Registrar agora" com 9 botões: mamada, alimentação, fralda, sono, banho, temperatura, peso, medicamento e observação.
- Fralda em 3 toques: botão, tipo e Salvar.
- Cada registro guarda horário, autor e papel (família), além do que for necessário:
  - duração: mamada, sono e banho;
  - quantidade e unidade: mamadeira em mL, alimentação, medicamento, temperatura em °C e peso em kg.
- Sono aberto: "Dormindo desde ..." com o botão "Acordou".
- Correção: guarda a versão anterior, o motivo, quem corrigiu e quando. Excluir exige motivo e o lançamento continua no histórico.
- Anexo de foto ou PDF (até 10 MB) em alimentação, fralda, temperatura, peso, medicamento e observação.
- Filtros por tipo com contagem e linha do tempo do dia.
- Dias futuros não aceitam registro.

### Resumo para o pediatra
- Período: hoje, últimos 7 dias, desde a última consulta ou outro período. Filtro por tipo de registro e opção de incluir os próximos compromissos.
- Totais (mamadas, mamadeira em mL, fraldas com xixi/cocô, horas de sono, temperatura máxima etc.) e a lista dos registros.
- Correções e anexos aparecem marcados no resumo.
- Tudo sai marcado como "Informado pela família".
- Enviar ao pediatra (com mensagem opcional), baixar PDF ou copiar o texto.

### Profissional e proteção dos dados
- O profissional vê a rotina, o diário e os resumos só para leitura, com o selo "Informado pela família" e o autor em cada registro. Não cria, não edita e não conclui.
- Acesso só com a chave "Compartilhar a rotina com a clínica" ligada pela família. Desligada, o profissional vê "Rotina não compartilhada" e o envio de resumo fica bloqueado.
- Recepção, financeiro e administrador: "Acesso restrito".
- Responsável não abre criança de outra família: "Criança não encontrada".
- As regras de acesso também valem nas funções de gravação, não só nas telas.

### Decisões que merecem sua validação
1. O peso informado pela família aparece no diário e no resumo, mas não entra na curva de crescimento. A curva continua recebendo só medidas da clínica.
2. Na demonstração os lembretes aparecem dentro do app, numa faixa no topo com "Ver" e "Dispensar", enquanto ele está aberto. Notificação no celular com o app fechado depende do app real e não foi ativada.
3. O resumo não entra no prontuário sozinho. O profissional lê e decide o que registrar.

## Problemas encontrados nos testes e corrigidos
- No celular, a troca Calendário/Diário saía da tela ao rolar. Agora fica fixa no topo.
- Erros de validação ficavam no fim do formulário, fora da tela, depois de tocar em Salvar. Agora aparecem logo acima dos botões.
- A caixa de motivo (cancelar compromisso, excluir lançamento) gerava um erro interno ao fechar. Corrigido.
- O cabeçalho dos dias na visão semanal podia estourar a largura com fonte grande. Agora encurta com reticências.
- A tela de resumo quebrava se o acesso mudasse com ela aberta. Agora mostra "Rotina não compartilhada".
- A varredura de segurança do build bloqueava a palavra "agora", comum nos botões. Agora procura o serviço de vídeo Agora pelos identificadores técnicos dele (`agora.io`, `agora_rtc`, `AgoraRTC`); as demais proibições continuam iguais.

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa) | 555 aprovados, 0 falhas |
| Testes novos de unidade: `test/routine/child_routine_test.dart` (18) | Aprovados |
| Testes novos de tela no tamanho de celular: `test/demo_routine_test.dart` (12) | Aprovados |
| `flutter analyze` | Sem erros nem avisos; nenhum apontamento nos arquivos novos |
| Navegador no link público, Chrome em contexto novo por bloco (`tools/demo/e2e_clinico.js`) | 170/170 aprovadas, das quais 48 da rotina no celular |

**Testes de tela** (dados fictícios, 390 x 844):
- troca entre calendário e diário e toque no dia;
- troca de criança;
- fralda em 3 toques, correção e exclusão;
- mamadeira, temperatura com foto e sono;
- dia futuro;
- criar, editar, concluir, reabrir e cancelar compromisso;
- vacina agendada sem alterar a carteira;
- doses da receita;
- lembrete com relógio simulado ("Ver" e "Dispensar");
- lembretes de consulta da clínica;
- resumo (filtro, envio, PDF, cópia, consentimento);
- proteção por perfil.

**No navegador (link público, celular 390 x 844, toque):**
- Calendário e diário:
  - calendário mensal, toque no dia 26/09 com a linha do tempo do dia;
  - troca para o diário no mesmo dia e filtro por fralda;
  - semana, dia e troca de criança mantendo a visão.
- Diário:
  - fralda registrada em 3 toques, com horário e autor;
  - correção com motivo e versão anterior no histórico;
  - mamadeira de 120 mL;
  - temperatura com foto anexada.
- Compromissos:
  - validação visível;
  - criação com lembrete de 1 hora, edição do horário e mais um lembrete de 1 dia;
  - concluir, reabrir e cancelar com motivo.
- Lembrete: compromisso daqui a 20 minutos com lembrete de 30 minutos. O aviso aparece no topo, "Ver" abre o dia e "Dispensar" remove.
- Resumo:
  - aberto pelo botão da rotina, com filtro por tipo;
  - enviado com mensagem;
  - PDF baixado (`resumo-rotina-luna-20260927.pdf`, 5.207 bytes, cabeçalho `%PDF-`);
  - texto copiado para a área de transferência;
  - envio bloqueado ao desligar o compartilhamento.
- Profissional: lista de resumos, resumo marcado como informado pela família com a mensagem, diário só leitura.
- Proteção: 7 acessos indevidos bloqueados (profissional sem compartilhamento, profissional tentando criar ou enviar resumo, recepção, financeiro, administrador, responsável de outra família).

Único erro de console: é o bloqueio antigo e intencional do script de login do Google pela política de segurança da demonstração. Não houve erro de página.

## Capturas

| Arquivo | Tela |
|---|---|
| `r01_calendario_mes.png` | Calendário do mês com legenda. Capturada logo ao abrir; a fonte ainda carregava e os rótulos dos filtros aparecem cortados. Nas capturas seguintes aparecem completos. |
| `r02_dia_com_diario.png`, `r02b_linha_do_tempo_do_dia.png` | Toque no dia: compromissos e linha do tempo do diário |
| `r03_diario_do_dia.png`, `r04_filtro_fralda.png` | Diário do dia e filtro por tipo |
| `r05_semana.png` | Semana com planejado, realizado e cancelado |
| `r06_diario_botoes_rapidos.png` | Botões de registro rápido |
| `r07_registro_fralda.png`, `r08_fralda_salva.png` | Registro de fralda e confirmação |
| `r09_correcao_historico.png` | Correção com motivo e versão anterior |
| `r10_temperatura_com_foto.png` | Temperatura com foto anexada |
| `r11_validacao.png`, `r12_novo_compromisso.png` | Validação e novo compromisso com lembrete |
| `r13_detalhe_compromisso.png` | Detalhe com lembretes e ações |
| `r14_concluido.png`, `r14b_cancelado.png` | Compromisso realizado e cancelado |
| `r15_lembrete_no_app.png` | Lembrete no topo com Ver e Dispensar |
| `r16_resumo_previa.png`, `r17_resumo_enviado.png` | Resumo: filtros, prévia e envio |
| `r18_profissional_resumo.png` | Profissional: resumo informado pela família |
| `r19_profissional_diario.png` | Profissional: diário só leitura |
| `r20_nao_compartilhada.png` | Profissional sem autorização da família |

## Funcional x pendente

**Funcional na demonstração**, com dados fictícios em memória (nada é salvo ao fechar a aba): tudo o que está descrito acima.

**Pendente de decisão ou autorização sua:**
1. Levar a rotina para o app real:
   - gravação no Firestore;
   - regras de segurança por criança e por responsável;
   - consentimento guardado no servidor;
   - notificações push dos lembretes.

   Nada disso foi ativado.
2. Validar as três decisões acima: peso fora da curva, lembretes dentro do app na demonstração e resumo fora do prontuário automático.
3. A prévia do resumo é texto selecionável. No navegador, o leitor de tela pode não lê-la; o conteúdo foi conferido pelo texto copiado e pelo PDF. Se quiser, ajusto a leitura por acessibilidade na próxima versão.
