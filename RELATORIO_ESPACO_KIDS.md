# Espaço Kids da Tia Cris

Marca de exibição: **Crisdepaula Pediatria**. Pacote, bundle e projeto Firebase continuam `pediatria360` / `pediatria360-app`. Checkpoint anterior: tag `checkpoint-pre-kids-201a`.

## O que funciona nesta entrega

- Tela do Espaço Kids em `/espaco-kids`, com os 10 jogos, histórias, colorir, conversa controlada, responsáveis, recepção e painel.
- Cada jogo tem regra jogável (não é só um botão “Jogar” vazio): doutor, escovação, prato, memória, quebra-cabeça, mãos, emoções, vacinas, formas e sono.
- Conquista local quando a regra termina. No modo recepção a conquista não entra na lista permanente e a sessão pode ser limpa.
- Oito histórias originais em texto, com página, play/pausa e avanço.
- Colorir com cor, borracha, desfazer, limpar e “salvar local” (memória da sessão).
- Controles dos responsáveis: estímulos, som, autorização da IA, microfone (o microfone não grava), tempo máximo e apagar histórico.
- Painel para ligar ou desligar cada jogo.

## Arte

Não há ilustração 3D final. O avatar usa ícone e o SVG `assets/illustrations/tia_cris.svg`, feito para ser trocado por PNGs com transparência (`tia_cris.png`, `ursinho.png`) sem mudar a lógica.

## Dados

Nenhuma coleção nova no Firestore. Progresso, autorização e sessão de recepção ficam só na memória do app. Isso evita regra nova sem revisão e impede que a IA infantil leia prontuário.

## Pendente

Áudio gravado, voz sintética self-hosted, microfone, salvamento na conta, tempo máximo que encerra sozinho, arte 3D, vídeos, e publicação do catálogo com revisão profissional.
