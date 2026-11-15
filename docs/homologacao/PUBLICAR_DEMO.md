# Como atualizar a demonstração de homologação

Link público: https://draraiany-source.github.io/pediatria360-demo/

- O site sai do repositório separado `draraiany-source/pediatria360-demo`, branch `main`, pasta raiz (GitHub Pages). Esse repositório só guarda o build da demonstração.
- O código fica em `draraiany-source/pediatria360`, branch `feat/area-profissional`. A publicação não altera a branch principal do aplicativo, o Firebase, o app real nem as lojas.
- A demonstração não tem login nem servidor: os dados são fictícios e ficam só na aba aberta. A política de segurança da página só permite carregar arquivos do próprio site.

## Passos

Cada envio (branch do código e site) precisa de autorização.

1. **Código:** faça o commit das correções na branch `feat/area-profissional` e rode `flutter test` e `flutter analyze`.
2. **Build:** `powershell -ExecutionPolicy Bypass -File tools\demo\build_demo.ps1`. O script gera `build\web`, grava o commit de origem em `SOURCE_COMMIT.txt` e recusa o build se encontrar termos proibidos.
3. **Conferência de dados sensíveis** em `build\web`: procurar chaves (`AIza...`, `BEGIN PRIVATE KEY`, tokens), senhas, CPFs, e-mails e telefones reais. Na demonstração só devem aparecer dados fictícios (`@exemplo.invalid`, `90000-000x`, `CRM 00000-UF`).
4. **Publicação**, numa cópia local do repositório do site:
   - `git fetch` e `git reset --hard origin/main`;
   - copiar o conteúdo de `build\web` para a raiz, manter `.nojekyll` e apagar `.last_build_id`;
   - `git commit -m "Demo: <resumo> (fonte <commit>)"` e `git push origin HEAD:main`.
5. **Confirmação:** aguardar `https://draraiany-source.github.io/pediatria360-demo/SOURCE_COMMIT.txt` mostrar o commit novo (1 a 2 minutos).
6. **Testes no link publicado:**
   - suíte completa no Chrome, em computador (1366 px) e celular (390 px com toque): `set BASE=https://draraiany-source.github.io/pediatria360-demo/` e `node tools/demo/e2e_clinico.js` (cerca de 70 minutos; `ONLY=<trecho do nome>` roda só alguns blocos);
   - teste curto no WebKit com perfil de iPhone: `node tools/demo/smoke_ios.js` (instruções no início do arquivo).
7. Registrar os resultados no relatório da etapa em `docs/homologacao/`.
