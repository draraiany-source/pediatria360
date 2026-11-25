# Testes do Espaço Kids

Arquivo: `test/kids_logic_test.dart`.

Coberto: catálogo (10 jogos, 8 histórias), conclusão de cada regra de jogo, memória sem cronômetro, quebra-cabeça no lugar certo, ordem de lavar as mãos, emoções, formas, sessão de recepção que não persiste e controle que desliga um jogo.

Não coberto nesta rodada: teste de widget de cada tela, microfone, offline de áudio (não há áudio), build Android/iOS e isolamento Firestore (não há coleção nova).

`flutter test test/kids_logic_test.dart` e o smoke da home passaram nesta máquina.
