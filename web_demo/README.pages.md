# Pediatria 360 – DEMONSTRAÇÃO

Build estático da **demonstração** do Pediatria 360 para homologação de navegação e design.

- Abre sem login. Todos os nomes, datas e valores são **fictícios**.
- Não há Firebase, prontuários, dados de pacientes, pagamentos nem IA. O que for digitado fica só na aba do navegador e some ao recarregar.
- Funções que dependem de servidor aparecem como **indisponíveis** ou como exemplo fictício. Elas só podem ser validadas na versão autenticada.
- O aplicativo real continua exigindo login e conta própria por perfil.

Este repositório contém apenas os arquivos gerados (`flutter build web -t lib/main_demo.dart`). O código-fonte fica no repositório privado do projeto, no commit indicado em `SOURCE_COMMIT.txt`.