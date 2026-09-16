"""Verificador de caminho de import.

## Por que isto é diferente de check_references.py

`check_references.py` confere se um símbolo (classe, provider) existe em
ALGUM lugar do projeto — mas não confere se a linha `import '../../x.dart'`
de um arquivo específico aponta para o arquivo certo. Um import com um
`../` a menos ou a mais passa despercebido por aquele checador se o símbolo
usado existir em outro lugar do projeto (o que quase sempre existe, já que
é comum a mesma classe ser usada em vários arquivos).

Isso é exatamente o tipo de erro que `flutter analyze` acusa na hora
("Target of URI doesn't exist") e que nenhuma ferramenta de análise de
símbolo pega — porque o problema não é o símbolo, é o caminho do arquivo.

## Duas coisas que faltavam nesta ferramenta até esta versão

1. **`test/` nunca foi varrida** — só `lib/`. Os arquivos de teste usam
   `import 'package:pediatria360/...'` (import de pacote), nunca caminho
   relativo — por isso nunca acionavam a checagem antiga, não porque
   estivessem necessariamente corretos.
2. **Import de pacote do próprio projeto nunca era verificado** — a
   ferramenta pulava todo `package:...` de propósito, o que é certo para
   pacotes externos (`package:flutter/...`, sem como verificar sem o cache
   do pub), mas errado para `package:pediatria360/...`: esse é o nosso
   próprio código, sempre resolve para dentro de `lib/`, e dá para
   verificar do mesmo jeito que um caminho relativo.

Uso: python3 tool/check_imports.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
TEST = os.path.join(ROOT, "test")
PACKAGE_PREFIX = "package:pediatria360/"


def check_dir(base):
    problems = []
    checked = 0

    for root, _, files in os.walk(base):
        for f in files:
            if not f.endswith(".dart"):
                continue
            path = os.path.join(root, f)
            checked += 1
            src = open(path, encoding="utf-8").read()

            for m in re.finditer(r"^\s*(?:import|export)\s+'([^']+)'", src, re.M):
                target = m.group(1)
                rel = os.path.relpath(path, ROOT)

                if target.startswith(PACKAGE_PREFIX):
                    # E' o proprio pacote: sempre resolve dentro de lib/,
                    # verificavel independente de quem importa (lib/ ou
                    # test/) ou de onde o arquivo esta.
                    resolved = os.path.join(LIB, target[len(PACKAGE_PREFIX):])
                    if not os.path.exists(resolved):
                        problems.append(
                            f"{rel}: import '{target}' não resolve para arquivo real"
                        )
                    continue

                if target.startswith(("package:", "dart:")):
                    continue  # pacote externo — sem como verificar aqui

                resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.exists(resolved):
                    problems.append(f"{rel}: import '{target}' não resolve para arquivo real")

    return problems, checked


if __name__ == "__main__":
    all_problems = []
    total_checked = 0

    for base in (LIB, TEST):
        problems, checked = check_dir(base)
        all_problems.extend(problems)
        total_checked += checked

    if not all_problems:
        print(f"Todo import (relativo e de pacote próprio) resolve para um arquivo real ({total_checked} arquivos, lib/ + test/).")
        sys.exit(0)

    print(f"{len(all_problems)} import(s) quebrado(s), em {total_checked} arquivos:\n")
    for p in all_problems:
        print(f"  {p}")
    sys.exit(1)
