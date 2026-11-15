# Pedi360 - Documentos da consulta e modelos reutilizáveis (homologação web)

Demonstração com dados fictícios, sem Firebase. Os testes no navegador foram feitos no build local desta branch. O link público ainda não foi atualizado: isso depende da sua autorização.

| Tela | Endereço (na demonstração) |
|---|---|
| Biblioteca de modelos | `#/modelos?perfil=profissional` |
| Modelos da clínica (gestão) | `#/modelos?perfil=administrador` |
| Novo documento a partir de modelo | `#/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1` |
| Documentos da criança | `#/pacientes/p1/documentos?perfil=profissional` |
| Logomarca e dados profissionais | `#/perfil/logomarca?perfil=profissional` |

- Branch `feat/area-profissional`, [PR #6](https://github.com/draraiany-source/pediatria360/pull/6). Nada foi publicado nas lojas, nada foi ativado em produção e nada foi enviado à branch principal.
- O app real (`lib/features/emr`) não foi alterado.

## O que já existia e foi aproveitado
- Editor de documentos (atestado, declaração, encaminhamento, exames, orientações e receituário), com revisão, emissão, PDF, impressão, versões e liberação para a família.
- Receituário com calculadora pediátrica, conferência item a item e modelos de receita.
- Modelos de orientação por faixa etária e logomarca por conta.

## O que foi entregue

### Biblioteca de modelos (`Modelos de documentos`)
- Abas **Meus modelos**, **Da clínica**, **Exemplos** e **Arquivados**, com filtro por tipo, busca e **pastas**.
- Cada profissional **cria, nomeia, edita, duplica, organiza em pastas e arquiva** os próprios modelos de atestado, declaração, encaminhamento, exames, orientações e receitas.
- **Editar** um modelo cria uma nova versão. As anteriores ficam listadas, e documentos já gerados não mudam.
- **Modelos da clínica:** a gestão da clínica (perfil Administração) cria e mantém os modelos compartilhados. Os profissionais da clínica usam ou duplicam esses modelos, mas não os alteram. A cópia vira um modelo pessoal independente, e editar o modelo da clínica não muda as cópias pessoais.
- **Acesso:** outro profissional não vê os seus modelos pessoais. Recepção, financeiro e família não abrem a biblioteca.

### Aplicar modelo: só dados confirmados
- Entram automaticamente apenas dados confirmados:
  - cadastro da criança e do responsável;
  - dados do profissional;
  - consulta vinculada (data e avaliação).
- O que falta aparece como **`[conferir: ...]`** (por exemplo, `[conferir: peso]`, `[conferir: data da consulta]`). O que o modelo deixou em aberto aparece como **`[preencher: ...]`**.
- Na tela, cada campo traz uma das indicações:
  - "Automático (dado confirmado): ...", em verde;
  - "Campo variável" ou "Conferir", em laranja.
- A prévia destaca os trechos entre colchetes, e a revisão fica bloqueada até que sejam resolvidos.
- **Salvar como modelo:** nome, datas, peso e dados da criança viram marcadores. Ficam fora do modelo:
  - resumo clínico, exames e tratamentos;
  - CID;
  - horários.

### Receituário
Mantém o que já existia:
- vários itens por receita, com medicamento, apresentação/concentração, dose, via, frequência, duração e orientações;
- a calculadora mostra o peso usado e a conta para revisão;
- cada item exige conferência, e nada é prescrito ou emitido automaticamente;
- receitas frequentes podem ser salvas como modelo sem a dose da criança: ao abrir em outra criança, a dose é refeita com o peso dela, ou fica bloqueada sem peso.

Nesta entrega, os modelos de receita entraram na mesma biblioteca:
- pastas, arquivamento e duplicação;
- modelo de receita da clínica, que o profissional usa ou duplica, mas não edita.

### Atestado
- Campos: finalidade, dias, data de início e data final calculada no texto, além da identificação do profissional no cabeçalho e na assinatura.
- **Texto editável**: "Editar o texto livremente", com opção de voltar ao texto gerado pelos campos.
- **Diagnóstico e CID nunca entram automaticamente**: modelos não guardam CID, e aplicar um modelo mantém "Incluir CID: Não". O CID só sai se o profissional escolher incluir, com autorização do responsável.

### Fluxo de todos os documentos
- Prévia, rascunho, revisão obrigatória, **emissão (finaliza o documento)**, PDF, impressão e histórico na ficha da criança.
- **Correção depois de emitido**: exige motivo e gera nova versão, registrando quem fez, quando e o motivo ("Correção: ..."). A versão emitida continua preservada e visível.
- **Histórico de versões** em cada documento: quem criou, revisou e emitiu, e quando.
- **Família:** só vê o documento depois que o profissional libera. Rascunhos e versões não emitidas nunca aparecem para ela.
- **Logomarca e dados profissionais configuráveis**: nome, registro, especialidade, clínica, endereço, cidade e telefone. Na emissão, o documento grava esses dados. Mudar a logomarca ou os dados depois não altera documentos emitidos, nem na tela nem no PDF.

## Testes executados

| Teste | Resultado |
|---|---|
| `flutter test` (suíte completa, 02/10/2026, já com o módulo multidisciplinar da mesma branch) | 837 aprovados, 0 falhas |
| `test/doc_templates_test.dart` (regras: escopo, permissões, versões, aplicação em duas crianças, CID, emissão com dados gravados, nova versão com motivo) | 22/22 aprovados |
| `test/demo_doc_templates_flow_test.dart` (telas: biblioteca, criar, editar, organizar, aplicar em Luna e Maya, permissões, emissão, PDF, histórico, liberação, dados profissionais) | 13/13 aprovados |
| `flutter analyze` nos arquivos alterados | Nenhum aviso |
| Navegador (Chrome, build local desta branch): blocos novos de modelos e versões | 20/20 + 5/5 aprovadas |
| Navegador (Chrome, build local): suíte completa | 447/450 aprovadas (ver "Suíte completa no navegador") |

### Suíte completa no navegador

Execução de 02/10/2026, das 21h20 às 22h23, no build local desta branch: **447 de 450 verificações aprovadas**. As 3 falhas:

- **"agenda: semana com contagem de livres"** e **"celular: agenda da semana"**: a contagem de horários livres considera só horários a partir de agora, com a antecedência mínima. Na sexta-feira à noite a semana já não tinha horário livre (sábado e domingo sem expediente), então o texto não aparece. As duas passaram na execução de 01/10 (quinta-feira à tarde). Não houve mudança no código da agenda.
- **"celular: sem peso, nenhuma dose copiada e cálculo bloqueado"**: a tela estava correta (Maya sem peso, dose não calculada), mas o teste parava de rolar antes de chegar à lista de conferência. O script passou a rolar até encontrar cada texto. Na nova execução (02/10, 23h) a verificação foi aprovada, junto com as outras 4 do mesmo bloco.

**Verificado no navegador:**
- **Biblioteca:**
  - meus modelos em pastas, e o modelo de outro profissional não aparece;
  - modelos da clínica só com "Usar" e "Duplicar para meus modelos".
- **Criar modelo:** atestado com marcadores; a prévia marca `[conferir: peso]`; o modelo aparece na lista.
- **Editar modelo:** cria a versão 2 e mantém a 1 no histórico.
- **Luna (com consulta):**
  - data da consulta e nome entram como dados confirmados;
  - `[preencher: orientação para o retorno]` fica marcado;
  - nenhum CID.
- **Maya (sem consulta):**
  - `[conferir: data da consulta]` marcado;
  - nada da Luna é reaproveitado;
  - a revisão fica bloqueada.
- **Emissão:**
  - emitido com histórico de versões;
  - PDF baixado (`atestado-luna-v1.pdf`, 5,9 KB);
  - a família não vê antes de liberar e passa a ver depois.
- **Correção:** pede motivo; a v2 fica em rascunho com o motivo registrado; a v1 emitida é preservada.
- **Acesso:**
  - recepção, financeiro e família recebem "Acesso restrito";
  - a gestão edita os modelos da clínica e não vê os pessoais.
- **Dados profissionais:** editáveis na tela de logomarca.

## Capturas

| Arquivo | Tela |
|---|---|
| `dm01_biblioteca.png` | Meus modelos, em pastas |
| `dm02_modelos_clinica.png` | Modelos da clínica: usar ou duplicar |
| `dm03_novo_modelo.png` | Novo modelo com marcadores e prévia com campos a conferir |
| `dm04_versoes_modelo.png` | Edição do modelo (nova versão) |
| `dm05_aplicado_luna.png`, `dm05b_previa_luna.png` | Modelo aplicado à Luna: campos automáticos e campo variável marcado |
| `dm06_emitido_historico.png` | Documento emitido, área da família e histórico de versões |
| `dm07_familia_documento.png` | Família vê o atestado depois da liberação |
| `dm08_nova_versao.png` | Correção como versão 2, com motivo |
| `dm09_aplicado_maya.png`, `dm09b_previa_maya.png` | Mesmo modelo aplicado à Maya: campos a conferir |
| `dm10_gestao_clinica.png` | Gestão da clínica mantendo os modelos compartilhados |
| `dm11_dados_profissionais.png` | Logomarca e dados profissionais |
| `dm12_pdf_atestado.png`, `atestado-luna-v1-ficticio.pdf` | PDF emitido (dados fictícios) |

## Situação

**Funcional na demonstração**
- Biblioteca com modelos pessoais, da clínica, exemplos e arquivados: criar, nomear, editar com versões, duplicar, pastas, arquivar e restaurar.
- Aplicação com dados confirmados e campos variáveis marcados, testada em duas crianças.
- Atestado sem CID automático e com texto editável.
- Receituário com calculadora e conferência; modelos sem dose de outra criança.
- Prévia, rascunho, revisão, emissão, PDF, histórico, nova versão com motivo e liberação para a família.
- Logomarca e dados profissionais configuráveis, gravados na emissão.

**Parcial**
- Modelos de orientação: editar atualiza o texto, mas sem lista de versões como nos outros tipos. Documentos já gerados não mudam.
- A data do atestado é a da consulta vinculada, ou a de hoje quando não há consulta. Não existe campo separado de "data de emissão"; o texto livre permite ajustar.
- A gestão da clínica é representada pelo perfil Administração de uma clínica fictícia. Convite de profissionais e várias clínicas por conta não fazem parte da demonstração.
- As capturas novas são do computador. No celular, o fluxo foi testado só nos testes automatizados de tela (largura de 430 px).
- Tudo fica em memória na demonstração: recarregar a página volta aos dados fictícios.

**Pendente (depende de autorização)**
- Levar biblioteca, rascunho, versões com motivo, dados gravados na emissão e liberação para o app real (`lib/features/emr`, Firestore e regras por conta e por clínica). O app real hoje só emite e cancela documentos.
- Atualizar o link público da demonstração (GitHub Pages).
- Assinatura digital ICP-Brasil (já indicada como não configurada).
- Os textos dos modelos de exemplo são fictícios e precisam de revisão clínica e jurídica antes de qualquer uso real.
