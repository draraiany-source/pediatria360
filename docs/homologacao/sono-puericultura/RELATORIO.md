# Pedi360 - Sono e puericultura (homologação web)

Demonstração pública (dados fictícios, sem Firebase):
https://draraiany-source.github.io/pediatria360-demo/

| Tela | Endereço |
|---|---|
| Diário do sono (família) | `#/rotina/p1?vista=sono&perfil=responsavel` |
| Orientações da clínica (família) | `#/rotina/p1/orientacoes?perfil=responsavel` |
| Prontuário com puericultura e diário do sono | `#/pacientes/p1/prontuario?perfil=profissional` |
| Consulta de puericultura finalizada (exemplo) | `#/pacientes/p1/consulta/c3?perfil=profissional` |
| Diário do sono visto pelo profissional | `#/rotina/p1?vista=sono&perfil=profissional` |

- Branch `feat/area-profissional`, no [PR #6](https://github.com/draraiany-source/pediatria360/pull/6):
  - `e04fcbf`: sono e puericultura;
  - `bc91fdd`: correção do despertar e teste no navegador;
  - `e3bd7a9`: abas da rotina no celular e correção do teste da logomarca.
- Build publicado: `e3bd7a9` (arquivo `SOURCE_COMMIT.txt` do site).
- Nada foi publicado nas lojas e nada foi ativado em produção. O app real não foi alterado e o login da versão real continua como estava.

## O que já existia no projeto

Verificado antes de implementar e reaproveitado, sem duplicar:
- **Rotina da criança** (calendário e diário):
  - o sono era um registro simples, com "Dormindo desde ..." e "Acordou";
  - o calendário já reunia consultas, vacinas e doses de receitas;
  - a família já controlava o compartilhamento com a clínica.
- **Curvas de crescimento** (OMS):
  - idade corrigida para nascidos antes de 37 semanas, até 24 meses;
  - histórico de medidas, com correção e motivo.
- **Prontuário**: consultas, evoluções e carteira de vacinação.
- **Documentos**: "Orientações ao responsável" com revisão e emissão, PDF e impressão.
- **Logomarca por conta**, já usada no cabeçalho dos documentos e nos PDFs.
- **Não existiam**: diário próprio de sono, puericultura estruturada, modelos por faixa etária, ruído branco e temporizador.

## O que foi implementado

### Área do sono
- **Aba "Sono"** na rotina, ao lado de Calendário e Diário.
- **Registro pela família:**
  - "Dormiu agora (noite)" abre o sono em andamento; o sono aparece no topo com "Despertar" e "Acordou";
  - "Despertar" registra o horário e o tempo acordado (5 a 60 min, opcional);
  - "Noite com horários" e "Cochilo" permitem lançar depois, com início, fim e despertares;
  - "Observação" registra uma nota.
- **Correção:** guarda a versão anterior, o motivo e o autor, igual aos demais registros do diário.
- **Linha do tempo:** 7 dias, com faixa de 0h a 24h e cores para sono noturno, cochilo e despertar. Tocar no dia mostra os registros daquele dia.
- **Resumo do dia:**
  - noite, número de despertares, cochilos e total;
  - maior trecho contínuo à noite.
- **Resumo da semana:**
  - dias com registro;
  - média da noite e horário de início;
  - despertares, cochilos e sono total;
  - as médias usam só os dias com registro.
- **Profissional:**
  - abre o diário pelo prontuário ("Diário do sono (família)") ou durante a consulta, só para leitura;
  - "Registrar avaliação do sono no prontuário" traz os dados da família para revisão (editáveis) e o campo "Sua avaliação";
  - só grava depois de "Revisei os dados informados pela família";
  - a evolução entra como "Avaliação do sono".
- **Modelos de orientação:**
  - editáveis, por faixa etária: 0 a 3 meses, 4 a 11 meses, 1 a 2 anos, 3 a 5 anos, 6 anos ou mais;
  - por tema: Sono seguro, Rotina e sono, Puericultura, Geral;
  - o editor sugere a faixa pela idade (corrigida, quando se aplica) e filtra por tema e faixa;
  - o texto é revisado antes de emitir; a emissão fica bloqueada enquanto houver trechos "[a definir: ...]";
  - "Salvar como modelo" guarda tema e faixa, só na conta de quem salvou.
- **Ruído branco e temporizador:** não existiam no projeto e não foram criados (ver decisões abaixo). Os modelos de sono seguro trazem o aviso "Ruído branco, aplicativos ou aparelhos para ninar não substituem as orientações de sono seguro."

### Área de puericultura
- **Início:** "Nova consulta de puericultura" no prontuário.
- **Consulta em 5 etapas**, com Voltar, Cancelar, Salvar rascunho e Próximo:
  1. Consulta: história, alimentação, sono, eliminações e vacinação;
  2. Exame: exame físico e crescimento;
  3. Marcos: desenvolvimento;
  4. Conduta: avaliação, plano de acompanhamento, dúvidas dos responsáveis, orientações dadas, próxima consulta e itens de acompanhamento;
  5. Resumo, histórico e PDF.
- **Idade:** o cabeçalho mostra a idade cronológica e a corrigida, com a regra usada. Marcos, faixa das orientações e curvas usam a corrigida quando se aplica.
- **Crescimento:**
  - "Registrar peso, comprimento e PC" abre o registro de medidas ligado à consulta; "Voltar à consulta" retorna à etapa do exame;
  - a lista mostra as medidas anteriores com data, idade e idade corrigida;
  - a medida feita na consulta aparece marcada "nesta consulta";
  - "Curvas de crescimento" abre as curvas já existentes.
- **Marcos:**
  - lista de exemplo pela faixa da criança, com os estados Adquirido, Em aquisição, Não observado e Requer seguimento;
  - "Outro marco" com área (motor grosso, motor fino, linguagem, social e afetivo, cognitivo).
- **Dúvidas e orientações:**
  - cada dúvida dos responsáveis guarda a orientação dada;
  - há um campo para as orientações da consulta;
  - "Preparar orientação" abre o documento escrito para a família.
- **Diário da família na evolução:** "Incorporar diário do sono" mostra o texto editável e só incorpora depois da revisão. O resumo e o PDF registram "Dados da família incorporados (revisados)", com período, quem revisou e a data.
- **Modelos de evolução:**
  - exemplos por faixa etária;
  - "Salvar como modelo": o nome da criança e do responsável viram marcadores, e o texto vindo da família não entra no modelo;
  - cada modelo tem versão e fica só na conta de quem o salvou;
  - aplicar um modelo mantém os campos já escritos, e tudo continua editável.
- **Finalização e correção:**
  - finalizar grava a evolução "Consulta de puericultura (demonstração)" no prontuário, e a consulta fica somente leitura;
  - "Corrigir" exige motivo e guarda a versão anterior no histórico ("Versão anterior").
- **Calendário da família:** a próxima consulta ("data sugerida", com orientação para confirmar o horário com a recepção) e os itens de acompanhamento aparecem no calendário da criança.
- **PDF do resumo:**
  - usa a logomarca da conta, gravada ao finalizar;
  - consultas finalizadas antes de cadastrar a logomarca continuam com o cabeçalho da época;
  - o rascunho sai marcado RASCUNHO;
  - há também "Imprimir".

### Fluxo e permissões
- **Família:**
  - vê só as próprias crianças, o próprio diário e o calendário;
  - em "Orientações da clínica", só as orientações já emitidas;
  - rascunhos e documentos internos não abrem ("Orientação não encontrada").
- **Profissional:**
  - consulta o diário só com o compartilhamento ligado; sem ele, vê "Rotina não compartilhada";
  - não registra sono em nome da família;
  - dados da família só entram na evolução depois da revisão.
- **Recepção, financeiro e administrador:** "Acesso restrito" na puericultura, no diário do sono e nas orientações.
- **Responsável:** não abre a consulta de puericultura.

## Decisões que merecem sua validação
1. **Ruído branco e temporizador não foram criados.** O pedido condicionava ("se houver") e o projeto não tinha essas ferramentas. Se quiser, entram numa próxima etapa, com controle simples de volume e duração e com o aviso de sono seguro.
2. **Tipo do sono sem escolha da família:** quando não é indicado, o app sugere "noite" para sono iniciado entre 18h e 5h com 3 horas ou mais. A noite conta no dia em que começou; se começou de madrugada, conta na noite anterior.
3. **Faixas etárias:** os limites (0 a 3 meses, 4 a 11 meses, 1 a 2 anos, 3 a 5 anos, 6 anos ou mais) foram escolhidos para a demonstração.
4. **Idade corrigida:** segue a regra já usada nas curvas (nascidos antes de 37 semanas, até 24 meses de idade cronológica).
5. **Próxima consulta:** entra no calendário como "data sugerida". O agendamento continua com a recepção.

## O que ainda depende de conteúdo ou validação clínica
- **Lista de marcos do desenvolvimento:** é um exemplo sem idades de referência, e a tela avisa isso. Precisa ser substituída pela referência adotada pelo serviço.
- **Textos dos modelos de orientação e de evolução:**
  - foram escritos para a demonstração, sem copiar material de terceiros;
  - trazem trechos "[a definir: ...]" que bloqueiam a emissão até serem completados;
  - precisam de revisão clínica antes de qualquer uso real.
- **Regras para validar:** limites das faixas etárias e regra de sugestão do tipo de sono (itens 2 e 3 acima).
- **App real:** levar sono e puericultura exige gravação no Firestore, regras de segurança por criança e por conta, e a logomarca no armazenamento. Nada disso foi ativado.

## Problemas encontrados nos testes e corrigidos
- **Despertar no mesmo minuto:** se a família tocava "Despertar" no mesmo minuto em que tocou "Dormiu agora (noite)", o app recusava o despertar como "fora do período de sono", porque o início guardava os segundos. Agora o início é gravado em minutos inteiros. Há um teste de tela para isso.
- **Abas da rotina no celular:** a aba "Calendário" quebrava no meio da palavra depois que entrou a aba "Sono". Em telas estreitas, as abas ficam sem ícone.
- **Cabeçalho dos documentos:** passava 1 pixel da largura em 390 px. Corrigido.
- **Caixa "Outro marco":** a lista de áreas estourava a largura. Corrigido.
- **Teste da logomarca:** o teste no navegador abria o documento emitido por um endereço errado (`##/...`). O erro era do teste, não do app, e foi corrigido.

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa, commits `bc91fdd` e `e3bd7a9`) | 616 aprovados, 0 falhas nas duas rodadas |
| Testes de tela novos: `test/demo_sleep_wellchild_test.dart` | 9 aprovados |
| Testes de unidade novos: `test/routine/sleep_log_test.dart` (10) e `test/wellchild/well_child_test.dart` (14) | Aprovados |
| Depois da correção das abas: `test/demo_routine_test.dart` e `test/demo_sleep_wellchild_test.dart` | 21 aprovados |
| `flutter analyze` | Sem erros nem avisos; os 132 apontamentos informativos são antigos, em arquivos não tocados |
| Navegador, link público, suíte completa (`tools/demo/e2e_clinico.js`, build `bc91fdd`) | 277/279 na primeira rodada. As 2 falhas estão explicadas abaixo e passaram ao repetir. |
| Das verificações acima, as de sono e puericultura | 50/50 aprovadas |
| Navegador, link público, build `e3bd7a9`, todos os blocos de celular (rotina, sono, orientações) | 68/68 aprovadas |

As 2 falhas da primeira rodada no navegador:
- **Logomarca:** o erro de endereço do teste descrito acima. Corrigido o teste, o bloco passou com 26/26.
- **"Dose máxima" da calculadora:** o navegador automatizado não registrou a digitação no campo. Repetido sem nenhuma mudança, passou com 2/2. É instabilidade do teste, não do app.

**Verificado no navegador (link público):**
- **Família no celular, com toque:**
  - cochilo com despertar;
  - noite com horários e despertar;
  - resumo do dia ("noite 9h40 com 1 despertar - 1 cochilo (1h10) - total 10h50") e da semana;
  - sono em andamento com "Despertar" e "Acordou";
  - registro aberto a partir do sono, corrigido com motivo, e volta ao sono com o total atualizado (11h10).
- **Profissional:**
  - diário aberto pelo prontuário, sem botões de registro;
  - avaliação exige texto e revisão;
  - voltar leva ao prontuário, com a "Avaliação do sono".
- **Puericultura no computador:**
  - modelo "Puericultura 1 a 2 anos (exemplo) (v1)" pela idade corrigida;
  - incorporação do diário bloqueada até a revisão;
  - ida e volta ao diário;
  - medida registrada na consulta, com volta ao exame e selo "nesta consulta";
  - marcos e outro marco;
  - dúvida com orientação e item de acompanhamento;
  - próxima consulta no resumo;
  - PDF do rascunho;
  - finalização e PDF final com a logomarca (imagem 600 px dentro do PDF);
  - impressão com a logomarca;
  - evolução no prontuário;
  - correção com motivo, histórico e versão anterior;
  - voltar percorre as etapas até o prontuário.
- **Calendário da família:** próxima consulta de puericultura e item de acompanhamento nos dias certos.
- **Logomarca antiga:** a consulta finalizada antes da logomarca gera PDF sem imagem.
- **Orientações da família:** só as emitidas, PDF baixado, voltar à lista; documento interno e outra família bloqueados.
- **Permissões:** recepção, financeiro e administrador bloqueados nas três áreas; responsável sem a consulta; profissional fora da área da família e sem ver rotina não compartilhada.

Único erro de console: o bloqueio antigo e intencional do script de login do Google pela política de segurança da demonstração. Não houve erro de página.

## Capturas

| Arquivo | Tela |
|---|---|
| `sp01_sono_familia.png` | Aba Sono da família: registrar, resumo da semana e linha do tempo |
| `sp02_cochilo_com_despertar.png` | Cochilo com despertar incluído |
| `sp03_linha_do_tempo_resumo.png` | Resumo da semana e linha do tempo depois dos registros |
| `sp04_sono_em_andamento.png` | Sono em andamento com despertar |
| `sp05_correcao_historico.png` | Registro corrigido com motivo no histórico |
| `sp06_sono_profissional.png` | Profissional: diário só leitura |
| `sp07_avaliacao_sono.png` | Avaliação do sono com revisão dos dados da família. A mensagem vermelha é da tentativa anterior sem a confirmação e some ao salvar. |
| `sp08_prontuario_avaliacao_sono.png` | Prontuário com a avaliação do sono |
| `sp09_puericultura_modelo.png` | Consulta com modelo por faixa etária e idade corrigida |
| `sp10_exame_medidas.png` | Exame com medidas anteriores e a medida "nesta consulta" |
| `sp11_marcos.png` | Marcos do desenvolvimento |
| `sp12_conduta.png` | Conduta: dúvidas, orientações, próxima consulta e itens |
| `sp13_resumo_finalizado.png` | Resumo finalizado com histórico |
| `sp14_versao_anterior.png` | Versão anterior depois da correção |
| `sp15_calendario_proxima_consulta.png` | Calendário da família com a próxima consulta |
| `sp16_orientacoes_familia.png`, `sp17_orientacao_aberta.png` | Orientações emitidas vistas pela família |
| `sp18_recepcao_acesso_restrito.png` | Recepção sem acesso |

## Funcional x pendente

**Funcional na demonstração**, com dados fictícios em memória (nada é salvo ao fechar a aba): tudo o que está descrito em "O que foi implementado".

**Pendente de decisão ou autorização sua:**
1. Validar as decisões acima e o conteúdo clínico (marcos, textos dos modelos, faixas).
2. Decidir se ruído branco e temporizador devem entrar.
3. Levar sono e puericultura para o app real (Firestore, regras de segurança e armazenamento da logomarca). Nada disso foi ativado.
