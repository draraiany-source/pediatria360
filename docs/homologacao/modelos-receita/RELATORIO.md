# Pedi360 - Meus modelos de receita (homologação web)

Demonstração pública (dados fictícios, sem Firebase):
https://draraiany-source.github.io/pediatria360-demo/

| Tela | Endereço |
|---|---|
| Meus modelos de receita | `#/modelos-receita?perfil=profissional` |
| Consulta em andamento (escolher modelo) | `#/pacientes/p5/consulta/c2?perfil=profissional` |

- Branch `feat/area-profissional`, commits `58b7549` (modelos), `61c6c6a` (teste no navegador) e `db5625a` (texto da dose fixa), no [PR #6](https://github.com/draraiany-source/pediatria360/pull/6).
- Nada foi publicado nas lojas e nada foi ativado em produção. O app real não foi alterado.

## O que foi entregue
- **Área "Meus modelos de receita":**
  - salvar uma receita como modelo, com nome;
  - buscar (sem precisar de acento), editar, duplicar e escolher o modelo durante a consulta;
  - cada edição gera nova versão (v1, v2...). A cópia duplicada é independente do original.
- **Abrir um modelo** gera uma nova receita em rascunho com os dados do paciente atual.
- **Conferência obrigatória antes da emissão, item a item:** medicamento, apresentação, concentração, dose, volume, via, frequência, duração e quantidade. A emissão fica bloqueada enquanto algum item não for conferido.
- **Dose pelo peso:**
  - o modelo guarda só a regra (mg/kg), nunca a dose de outra criança;
  - ao abrir, a dose é recalculada com o peso atualizado do paciente, e a conta aparece na tela;
  - sem peso registrado, nenhuma dose é copiada e o cálculo fica bloqueado.
- **Mais de um item** por receita, orientações editáveis, visualizar o PDF e imprimir.
- **Receita emitida** fica no histórico da consulta, com a origem no modelo e a versão usada.
- **Modelo alterado depois** não modifica as receitas já emitidas.
- **Acesso:** os modelos ficam só na conta do profissional que os salvou. A recepção não acessa.

## Problemas encontrados e corrigidos
- O resumo de um item de dose fixa saía com parênteses aninhados. Agora sai, por exemplo, "2 jatos em cada narina (dose fixa)".

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa, commits `bc91fdd` e `e3bd7a9`) | 616 aprovados, 0 falhas nas duas rodadas |
| Testes dos modelos: `test/rx_templates_test.dart` (9) e `test/demo_rx_templates_test.dart` (6) | Aprovados |
| Navegador, link público, build `94fc948` (suíte completa) | 198/198 aprovadas |
| Navegador, link público, build `bc91fdd` (suíte completa) | As 18 verificações dos modelos aprovadas |

**Verificado no navegador (link público):**
- **Lista:** modelos de exemplo e busca sem acento pelo medicamento; busca sem resultado.
- **Duplicar e editar:**
  - duplicar abre a cópia para editar;
  - a edição salva como versão 2;
  - o original continua na v1, ao lado da cópia.
- **Item pelo peso:** usa a frequência da referência e guarda só mg/kg, recalculado por paciente. O novo modelo aparece na lista.
- **Consulta:**
  - escolha do modelo durante a consulta;
  - receita emitida com origem no modelo v1;
  - PDF baixado;
  - receita no histórico da consulta.
- **Modelo editado depois** não muda a receita emitida.
- **Celular:**
  - outra criança recebe a dose calculada com o peso dela (32 kg: 24 mL, 480 mg por dose);
  - criança sem peso tem o cálculo bloqueado e nenhuma dose copiada;
  - receita salva como modelo sem a dose da criança.
- **Acesso:** recepção não acessa os modelos.

## Capturas

| Arquivo | Tela |
|---|---|
| `mr01_lista.png`, `mr02_busca.png` | Lista e busca |
| `mr03_editor_copia.png` | Edição da cópia duplicada |
| `mr04_item_pelo_peso.png` | Item com dose pelo peso (regra em mg/kg) |
| `mr05_escolher_modelo.png` | Escolha do modelo durante a consulta |
| `mr06_rascunho_conferencia.png`, `mr07_bloqueado_sem_conferencia.png` | Rascunho com conferência e emissão bloqueada |
| `mr08_item_conferido.png`, `mr09_dois_itens_conferidos.png` | Itens conferidos |
| `mr10_receita_emitida.png`, `mr11_historico_consulta.png` | Receita emitida e histórico da consulta |
| `mr12_emitida_intacta.png` | Receita emitida sem mudança depois de editar o modelo |
| `mr13_celular_outra_crianca.png`, `mr14_celular_sem_peso.png`, `mr15_celular_modelo_da_receita.png` | Celular: outra criança, sem peso e modelo salvo da receita |

## Pendente de validação ou autorização sua
- As referências de dose dos medicamentos de exemplo são fictícias. Qualquer uso real depende da tabela validada pelo serviço.
- Levar os modelos ao app real (Firestore e regras por conta) não foi feito e depende da sua autorização.
