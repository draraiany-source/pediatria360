# Pedi360 - Crescimento, vitaminas e laboratório (homologação web)

Demonstração pública (dados fictícios, sem Firebase):
https://draraiany-source.github.io/pediatria360-demo/

Telas novas, já no perfil do profissional:

| Tela | Endereço |
|---|---|
| Curva de crescimento | `#/pacientes/p1/crescimento?perfil=profissional` |
| Exames laboratoriais | `#/pacientes/p1/exames?perfil=profissional` |
| Suplementação do paciente | `#/pacientes/p1/suplementacao?perfil=profissional` |
| Visão do responsável | `#/pacientes/p1/crescimento?perfil=responsavel` |

- Branch `feat/area-profissional`, commits `af2f77f` e `4392d45`, no [PR #6](https://github.com/draraiany-source/pediatria360/pull/6).
- Build publicado: `4392d45` (arquivo `SOURCE_COMMIT.txt` do site).
- Nada foi publicado nas lojas nem ativado em produção. O login da versão real não mudou.

## O que foi entregue

### Curva de crescimento

- Registro por consulta: data, peso, comprimento ou altura (com a posição deitado/em pé), perímetro cefálico e idade gestacional ao nascer. Uma prévia do escore Z aparece enquanto se digita.
- Gráficos separados: peso, comprimento/altura, IMC e perímetro cefálico, com as janelas 0-2, 2-5 e 5-19 anos. Cada gráfico mostra os pontos anteriores.
- Cada ponto mostra o escore Z, o percentil e a referência usada.
- Referências oficiais da OMS por sexo e idade: Padrões 2006 (0 a 5 anos, tabelas diárias) e Referência 2007 (5 a 19 anos, tabelas mensais).
  - Comprimento deitado até 24 meses e altura depois, com ajuste de 0,7 cm quando a posição não corresponde à idade.
  - Peso e IMC usam o método restrito da OMS além de ±3.
  - Sem escore de peso acima de 10 anos (a tela orienta usar o IMC) e sem perímetro cefálico acima de 5 anos.
- Prematuros (menos de 37 semanas):
  - A tela mostra a idade cronológica e a idade corrigida, e a curva usa a corrigida até 24 meses de idade cronológica.
  - Antes do termo corrigido não há escore. A tela explica que a referência neonatal para prematuros não está incluída.
- Idades exibidas em calendário (meses e dias pelas datas). Os cálculos usam a contagem em dias da OMS.
- Correção de medida lançada errada:
  - Exige motivo e guarda antes/depois, autor e data no "Histórico de alterações".
  - O ponto corrigido fica marcado no gráfico.
  - Um lançamento errado pode ser anulado: sai da curva e continua no histórico.
- A alteração da idade gestacional também exige motivo e fica no histórico.
- Visão do responsável: faixa de referência e pontos, as últimas medidas, sem escore Z, sem edição e sem exportação. Ele só vê as crianças vinculadas a ele.
- Visão do profissional: linhas de escore Z -3, -2, 0, +2 e +3, tabela de pontos e os botões "Exportar PDF" e "Imprimir".
  - O PDF traz o paciente, as referências usadas, os quatro gráficos com tabela, o histórico de correções e a marca DEMONSTRACAO.
  - Exemplo: `curvas-luna-20260927.pdf`.

### Exames laboratoriais

- Linha do tempo por data de coleta, com busca.
- Lançamento manual:
  - Campos: exame, resultado, unidade, data da coleta, laboratório e intervalo de referência copiado do próprio laudo (texto e limites).
  - Anexo do arquivo original (PDF ou imagem, até 10 MB), com "Abrir arquivo original".
- Cada resultado guarda o intervalo do seu laudo. Não existe intervalo padrão por idade nem por laboratório.
  - A tela só informa a posição em relação ao intervalo daquele laudo ("Dentro/Abaixo/Acima do intervalo do laudo").
  - Não gera diagnóstico nem prescrição.
- Laudo importado (PDF ou imagem):
  - Entra como "Pendente de conferência", com os campos vazios. Nada é lido automaticamente do arquivo (não há OCR).
  - Não aparece no prontuário, nas comparações nem na decisão de suplementação.
  - Para liberar, o profissional preenche os campos, marca "Conferi os valores com o arquivo original" e confirma. A conferência parcial pode ser salva e o resultado continua pendente.
- Comparação do mesmo exame no tempo: gráfico e lista com o laudo de origem de cada ponto. Se as unidades forem diferentes, os resultados são separados e a tela avisa.
- Relações:
  - Com a consulta (campo "Consulta").
  - Com os temas de suplementação (sugestões pelo nome do exame, editáveis).
  - Na etapa Avaliação da consulta: atalhos "Registrar medidas", "Curva de crescimento" e "Exames do paciente".
- Correção de valor exige motivo, e o valor anterior fica no histórico. Mudar só os vínculos (consulta, temas, anexo) não exige motivo.

### Vitaminas e suplementação

- Biblioteca: busca (inclusive pelo nome de exames relacionados) e filtros por grupo (Vitaminas, Minerais, Ácidos graxos, Exames) e por situação (rascunho/validada).
- Os 17 temas pedidos estão presentes.
- Cada ficha tem os blocos Avaliação, Exames relacionados, Fontes alimentares, Cuidados e Conteúdo clínico validado, com fonte e data da última revisão.
- Todas as fichas continuam em rascunho e identificadas como tal. Nenhum conteúdo do PDF "Suplementação na Pediatria" foi copiado: o arquivo não foi anexado e a licença não foi confirmada.
- No prontuário, a tela "Suplementação do paciente" lista os temas com a decisão atual e os exames conferidos relacionados.
- A decisão por tema tem quatro opções: sem indicação no momento, acompanhar e reavaliar, suplementação indicada ou suspensa.
  - Exige justificativa e registra a situação da ficha no momento (rascunho) e os exames considerados.
  - Cada alteração vira nova versão no histórico.
- Quando a decisão é "Suplementação indicada", o botão "Levar à calculadora e ao receituário" abre a calculadora com a origem da decisão.
  - O item calculado entra num receituário em rascunho, que ainda passa por revisão antes da emissão.
  - O receituário fica ligado à decisão.
  - O item de teste é o "Suplemento Exemplo D (fictício)", com referência de dose fictícia.

### Em todas as telas

- As telas têm voltar, salvar, editar e "Retornar ao paciente". Os fluxos abertos a partir da consulta voltam para a consulta.
- O visual revisado do Pedi360 foi conferido no computador e no celular.
- Os campos únicos de texto foram corrigidos para leitores de tela: a decisão de suplementação e as buscas deixaram de absorver o texto da página inteira.
- Permissões:
  - O profissional usa tudo.
  - O responsável vê só a curva simplificada dos próprios filhos.
  - Recepção, financeiro e administração não abrem curva, exames nem suplementação do paciente.

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa) | 525 aprovados, 0 falhas |
| Testes novos de unidade: `test/clinical/growth_test.dart`, `test/clinical/lab_results_test.dart` | Aprovados |
| Testes novos de tela: `test/demo_growth_lab_test.dart` (12) | Aprovados |
| Navegador no link público, Chrome em contexto novo por bloco (`tools/demo/e2e_clinico.js`) | 122/122 aprovadas |

**Testes de unidade.** Conferem valores publicados pela OMS: mediana e desvios ao nascer e aos 12 meses, medianas da Referência 2007 e o método restrito. Também cobrem a idade corrigida, o histórico de correções, o intervalo por laudo, o laudo pendente e a leitura de números com vírgula.

**Testes de tela** cobrem:
- A curva do profissional, com o PDF e a impressão.
- A correção com motivo e a nova medida.
- A Referência 2007 para a criança acima de 5 anos.
- A visão simples do responsável e o bloqueio para outros perfis.
- O laudo importado pendente até a conferência e a recusa de arquivo que não é PDF nem imagem.
- O intervalo de cada laudo, a correção de resultado com motivo e a decisão indicada levada à calculadora e ao receituário.

**No navegador**, as 122 verificações somam 81 das etapas anteriores e 41 novas:
- Curva: idade corrigida, referência, escore Z e percentil, os três gráficos, o PDF baixado e a impressão.
- Histórico de alterações e correção com motivo obrigatório.
- Laudo importado pelo seletor de arquivos: pendente fora do prontuário, conferência obrigatória, arquivo original em nova aba, entrada no prontuário depois de conferido e comparação de três laudos.
- Decisão de suplementação até o receituário em rascunho.
- 8 verificações de permissão e 5 no celular.

Na rodada completa, a etapa "corrigir medida" corrigiu a medida de nascimento. Depois ela passou a corrigir a medida mais recente (10,2 para 10,1 kg), para a captura ficar clinicamente plausível. Essa etapa foi repetida sozinha no link público: 3/3 aprovadas.

O único erro de console é antigo: a política de segurança bloqueia o script de login do Google na demonstração. Não houve erro de página.

## Capturas

| Arquivo | Tela |
|---|---|
| `c01_curva_peso_profissional.png` | Curva de peso, idade cronológica e corrigida, referência |
| `c02_curva_comprimento_corrigida.png` | Comprimento com ponto corrigido (anel laranja) |
| `c03_curva_perimetro_cefalico.png` | Perímetro cefálico |
| `c04_historico_alteracoes.png` | Pontos com Z/percentil, pontos antes do termo sem escore, histórico |
| `c05_corrigir_medida.png` | Correção exige motivo |
| `c06_exames_linha_do_tempo.png` | Exames: pendente separado, regras |
| `c07_conferencia_laudo.png` | Conferência de laudo importado |
| `c08_exame_conferido.png` | Resultado conferido com intervalo do próprio laudo e arquivo original |
| `c09_comparacao_ferritina.png` | Comparação no tempo (laudos A, B e C) |
| `c10_suplementacao_paciente.png` | Suplementação do paciente |
| `c11_decisao_suplementacao.png` | Decisão indicada, exames considerados |
| `c12_calculadora_origem_decisao.png` | Calculadora com a origem da decisão |
| `c13_receituario_da_decisao.png` | Receituário em rascunho com o item calculado |
| `c14_recepcao_sem_curva.png` | Recepção: acesso restrito |
| `c15_responsavel_visao_simples.png` | Responsável: visão simples |
| `m05` a `m09` | Celular: curva, exames, conferência, decisão, visão do responsável |
| `curvas-luna-20260927.pdf` | PDF das curvas exportado no link público |

## Funcional x pendente de validação clínica

**Funcional na demonstração**, com dados fictícios em memória, sem salvar nada:
- Os fluxos, cálculos, históricos, PDFs, anexos e permissões descritos acima.

**Pendente de validação clínica ou de decisão sua:**
1. Conferência clínica dos escores Z e percentis. As tabelas LMS são as oficiais da OMS: [anthro](https://github.com/WorldHealthOrganization/anthro), commit `02aa59c`, e [anthroplus](https://github.com/WorldHealthOrganization/anthroplus), commit `7cfcdb3`. Os repositórios estão sob GPL-3.0 e as mesmas tabelas são publicadas em who.int. Confirmar os termos de uso antes de produção.
2. Regras adotadas que precisam do seu aval:
   - Idade corrigida até 24 meses de idade cronológica, para menos de 37 semanas.
   - Sem escore antes do termo corrigido.
   - Ajuste de 0,7 cm pela posição.
   - Método restrito além de ±3 para peso e IMC.
   - Faixas de validação de digitação (valores impossíveis).
3. Referência neonatal para prematuros antes do termo (por exemplo Intergrowth-21st ou Fenton): não incluída.
4. Conteúdo das 17 fichas: tudo em rascunho. Depende do conteúdo validado e da autorização de uso do PDF, que não foi anexado.
5. Referência de dose do "Suplemento Exemplo D": fictícia, só para testar o caminho decisão → calculadora → receituário.
6. Leitura automática de laudos (OCR): não implementada de propósito. Todo laudo importado exige digitação e conferência humana.
7. App real (Firebase):
   - As telas novas existem só na demonstração.
   - O arquivo de referência mensal da OMS usado pelo app real (`assets/data/who_reference.json`) foi trocado pelos valores oficiais e continua exibindo o aviso de conferência pendente.
   - Levar curva, exames e decisões ao app real exige modelagem no Firestore, regras de acesso e armazenamento de anexos: etapa separada, só com sua autorização.
