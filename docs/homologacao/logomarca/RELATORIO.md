# Pedi360 - Logomarca personalizada por conta (homologação web)

Demonstração pública (dados fictícios, sem Firebase):
https://draraiany-source.github.io/pediatria360-demo/

| Tela | Endereço |
|---|---|
| Logomarca da conta | `#/perfil/logomarca?perfil=profissional` |
| Painel do profissional | `#/inicio?perfil=profissional` |
| Documento emitido (exemplo) | `#/pacientes/p1/documentos/d2?perfil=profissional` |

- Branch `feat/area-profissional`, commit `4d244b9`. A correção do teste no navegador está em `e3bd7a9`. Tudo no [PR #6](https://github.com/draraiany-source/pediatria360/pull/6).
- Build publicado: `e3bd7a9` (arquivo `SOURCE_COMMIT.txt` do site).
- Nada foi publicado nas lojas e nada foi ativado em produção. O app real não foi alterado.

## O que foi entregue
- **Onde fica:** Perfil, em "Logomarca da clínica ou profissional".
- **Operações:** enviar, visualizar ampliada, trocar e remover. Trocar e remover pedem confirmação.
- **Arquivo aceito:**
  - PNG ou JPG, até 2 MB, entre 64 e 4096 pixels;
  - o formato é conferido pelo conteúdo do arquivo, não pelo nome;
  - um SVG disfarçado de PNG é recusado.
- **Antes de salvar:** prévia de como fica no cabeçalho.
- **Onde aparece:**
  - no painel do profissional;
  - no cabeçalho de receitas, atestados, declarações, encaminhamentos, orientações, solicitações de exames, relatório de curvas e resumo da puericultura;
  - na tela, no PDF e na impressão.
- **Sem logomarca:** painel e documentos usam a identidade padrão do Pediatria360. As telas gerais do app mantêm sempre a identidade do Pedi360.
- **Documento emitido:** guarda a logomarca em uso na emissão. Trocar ou remover depois muda só os documentos novos.
- **Separação por conta:**
  - a logomarca fica vinculada só à conta que a cadastrou;
  - outra conta profissional fictícia não a vê e não abre os documentos da primeira;
  - recepção, financeiro e responsável não cadastram logomarca ("Acesso restrito").

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa, commits `bc91fdd` e `e3bd7a9`) | 616 aprovados, 0 falhas nas duas rodadas |
| Testes da logomarca: `test/brand_logo_test.dart` (9) e `test/demo_brand_test.dart` (3) | Aprovados |
| Navegador, link público, computador e celular | 38/38 aprovadas |

Sobre os 38 aprovados no navegador:
- Na primeira rodada, o bloco principal parou depois da troca de logomarca. O teste abria o documento emitido por um endereço errado (`##/...`); o erro era do teste, não do app.
- Corrigido o teste, o bloco foi repetido no link público e passou com 26/26. Os outros 12 (separação entre contas e celular) passaram na primeira rodada.

**Verificado no navegador (link público):**
- **Computador:**
  - painel sem logomarca;
  - arquivo disfarçado recusado;
  - prévia e envio (PNG 600 x 200);
  - visualizar;
  - PDF de exemplo com a imagem;
  - painel com a logomarca.
- **Seis tipos de documento:** cabeçalho na tela, no PDF e na impressão com a imagem (600 px dentro do PDF). Também o relatório de curvas.
- **Troca por JPG (500 x 250):**
  - o documento já emitido continua com a logomarca da emissão, na tela e no PDF;
  - o documento novo usa a nova.
- **Remoção:**
  - painel e documentos novos voltam à identidade padrão, e o PDF novo sai sem imagem;
  - o documento emitido continua com a logomarca da emissão.
- **Separação por conta:** segunda conta sem a logomarca, com configuração vazia; não abre o documento da primeira conta; os documentos dela saem sem imagem.
- **Celular, com toque:** envio, painel, cabeçalho do documento e PDF com a logomarca.
- **Resumo da puericultura:** PDF e impressão com a logomarca; a consulta finalizada antes do cadastro sai sem imagem.

## Capturas

| Arquivo | Tela |
|---|---|
| `lg01_painel_padrao.png`, `lg02_sem_logomarca.png` | Painel e configuração sem logomarca |
| `lg03_arquivo_recusado.png` | Arquivo que não é imagem recusado |
| `lg04_confirmar_envio.png`, `lg05_logomarca_salva.png` | Prévia antes de salvar e logomarca salva |
| `lg06_visualizar.png`, `lg07_pdf_exemplo.png` | Visualizar ampliada e PDF de exemplo |
| `lg08_painel_com_logomarca.png` | Painel com a logomarca |
| `lg09_receita_emitida_com_logomarca.png`, `lg10_pdf_receita_com_logomarca.png` | Receita emitida e o PDF dela |
| `lg11_logomarca_trocada.png`, `lg12_emitido_mantem_logomarca.png` | Troca e documento emitido intacto |
| `lg13_remover_confirmacao.png`, `lg14_documento_identidade_padrao.png` | Remoção e documento novo com a identidade padrão |
| `lg15_outra_conta_painel.png`, `lg16_outra_conta_documento.png` | Segunda conta sem acesso à logomarca e aos documentos da primeira |
| `lg17_celular_confirmar.png` a `lg20_celular_documento.png` | Celular: envio, painel e documento |

## Pendente de autorização sua
- Levar a logomarca ao app real exige guardar a imagem no armazenamento da nuvem, com regras de acesso por conta. Não foi feito: depende da sua autorização para mudar as regras de armazenamento.
