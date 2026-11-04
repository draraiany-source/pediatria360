# Área do profissional — relatório de homologação

- Link (dados fictícios, sem login): https://draraiany-source.github.io/pediatria360-demo/
- Código-fonte publicado: commit `57ec015` (branch `feat/area-profissional`)
- Data da execução: 27/09/2026

## O que já existia
- Demonstração web com cinco perfis, pacientes, prontuário (evoluções), agenda, vacinação, biblioteca e telemedicina (protótipo).
- No app real: editor de documentos com conferência de dose feita a partir do mg/kg e dos tetos digitados pelo prescritor; emissão de documentos por Cloud Function (regras do Firestore bloqueiam escrita direta).

## O que foi adicionado
- Consulta em quatro etapas (Consulta → Avaliação → Conduta → Documentos), com peso do dia, rascunho e finalização registrada no prontuário.
- Seis modelos de documento: atestado, declaração de comparecimento, encaminhamento (motivo, resumo clínico, exames relevantes, tratamentos, especialidade), orientações ao responsável (modelos salvos e personalizáveis por criança), solicitação de exames e receituário.
  - Dados do paciente e do profissional pré-preenchidos; revisão obrigatória antes de emitir; histórico com autor, data e versão; editar documento emitido cria nova versão.
  - PDF e impressão; rascunho sai com marca "RASCUNHO - SEM VALIDADE".
  - Assinatura: requisito exibido por tipo; nenhum documento aparece como assinado.
- Calculadora de doses integrada ao receituário: peso e data da pesagem, idade, referência com fonte e revisão, mg/kg/dose ou mg/kg/dia, intervalo, dose máxima, concentração, mL por dose, dose diária separada da dose por administração e a conta exibida passo a passo.
  - Bloqueia sem peso, sem referência validada, com alergia, restrição de idade, apresentação incompatível ou dose acima do máximo; alerta peso desatualizado e valores fora da faixa, exigindo ciência.
  - Inserir exige conferir resultado e apresentação e sempre gera rascunho para revisão.
- Biblioteca de suplementação com 17 temas, todos em rascunho e sem conteúdo clínico.
- Contraste: textos secundários, bordas, menus e indicadores mais escuros (app real e demo); menu lateral em azul-marinho; consultas e pacientes em destaque no início.
- Botões Voltar, Cancelar, Salvar rascunho e Voltar ao prontuário em todos os fluxos.
- Acessibilidade: menu lateral, faixa de demonstração, listas suspensas e textos vizinhos de imagens voltaram a ser lidos corretamente por leitores de tela.

## Depende de validação, licença ou configuração
- Referências de dose: as três da demonstração são fictícias. Uso real exige base validada, com fonte e revisor.
- Suplementação: o conteúdo do PDF "Suplementação na Pediatria" não foi copiado; as fichas só podem ser preenchidas e validadas após confirmação da licença e revisão clínica.
- Assinatura digital ICP-Brasil: não configurada.
- App real: novos tipos de documento, versões e assinatura exigem Cloud Function, regras e deploy, que não foram feitos (sem autorização). O receituário real mantém a conferência de dose atual.

## Testes executados

### Unitários e de widget (`flutter test`)
483 aprovados, 0 falhas. Incluem 15 do motor de dose, 15 de documentos e 16 do fluxo clínico da demonstração (calculadora, seis documentos com PDF e impressão, versões, orientações, consulta, suplementação e permissões de quatro perfis).

### Navegador no link publicado (`tools/demo/e2e_clinico.js`)
80 de 80 verificações aprovadas, cada bloco em contexto novo (equivalente a janela anônima), computador (1366×860) e celular (390×844, toque).

| Área | Verificações |
|---|---|
| Início profissional | 1 |
| Calculadora (mg/kg/dose, mg/kg/dia, mg→mL, conferências, inserção) | 9 |
| Dose máxima e limitação | 2 |
| Bloqueios e alertas (sem peso, referência não validada, alergia, idade, peso desatualizado, apresentação) | 6 |
| Seis documentos (editor, revisão, emissão não assinada, autor, PDF, impressão, histórico) | 43 |
| Versões | 3 |
| Consulta completa | 3 |
| Suplementação | 2 |
| Permissões (recepção, responsável, financeiro, administrador) | 7 |
| Celular (calculadora, PDF, impressão em nova aba, barra de ações) | 4 |

Casos com pacientes fictícios:
- mg/kg/dose: 15 mg/kg × 10,2 kg = 153 mg; 153 mg ÷ 20 mg/mL = 7,65 mL → 7,7 mL por dose; 612 mg/dia.
- mg/kg/dia: 40 mg/kg/dia × 12,8 kg = 512 mg/dia ÷ 2 = 256 mg → 5,1 mL por dose.
- Dose máxima: 16 mg/kg × 32 kg = 512 mg bloqueado (máx. 500 mg); limitado → 25 mL, com três alertas que exigem ciência.

### Limites do teste automatizado
- Impressão no computador: o teste confirma que o PDF é carregado no quadro de impressão e que `print()` é chamado. A chamada final foi substituída no teste porque o navegador automatizado não abre o diálogo de impressão do sistema.
- Celular: a acessibilidade do Flutter foi ativada com identificação de navegador de computador; para a impressão, o teste muda a identificação para Android, e o PDF abre em nova aba.
- Console: o único erro é o bloqueio, pela política de segurança da página, do script externo do login Google registrado pelo Flutter. A demonstração não carrega nada externo; o bloqueio é intencional.

## Capturas
Arquivos `d*.png` (computador) e `m*.png` (celular) nesta pasta.
