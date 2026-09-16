"""Verificador de balanceamento de delimitadores para Dart e TypeScript.

Substitui as versoes ad-hoc que vinham sendo coladas a cada sessao. Duas delas
regrediram por copia-e-cola:

  1. A versao TS-aware perdeu o tratamento de strings ''' do Dart, e passou a
     acusar erro em todo SQL multilinha.
  2. A versao Dart nao entendia literais de regex, e acusava erro em /\\//g.

Ambos os casos eram falso positivo. Um verificador que erra e pior que nenhum:
ele treina quem o usa a ignorar o resultado.

Uso:
    python3 tool/check_syntax.py            # lib/, test/ e functions/src/
    python3 tool/check_syntax.py caminho    # arquivo ou diretorio especifico
"""

import os
import sys

PAIRS = {"(": ")", "{": "}", "[": "]"}
CLOSING = {v: k for k, v in PAIRS.items()}

# Um '/' precedido por um destes tokens inicia literal de regex em JS/TS.
REGEX_PRECEDING = set("(,=:[!&|?{};+*%~^<>")


def check(path, typescript=False):
    """Devolve None se balanceado, ou a descricao do problema."""
    src = open(path, encoding="utf-8").read()
    i, n = 0, len(src)
    line = 1
    stack = []
    prev = ""

    while i < n:
        c = src[i]

        if c == "\n":
            line += 1
            i += 1
            continue

        if c in " \t\r":
            i += 1
            continue

        # ---------------------------------------------------------- comentarios
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue

        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                if src[i] == "\n":
                    line += 1
                i += 1
            i += 2
            continue

        # ------------------------------------------------------------- regex
        if typescript and c == "/" and prev in REGEX_PRECEDING:
            i += 1
            in_class = False
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "[":
                    in_class = True
                elif src[i] == "]":
                    in_class = False
                elif src[i] == "/" and not in_class:
                    break
                elif src[i] == "\n":
                    break
                i += 1
            i += 1
            while i < n and src[i].isalpha():  # flags
                i += 1
            prev = "r"
            continue

        # ------------------------------------------------------------ strings
        if c in "'\"`":
            # Dart: literal de tres aspas, usado para SQL e texto longo.
            if not typescript and src[i : i + 3] in ("'''", '"""'):
                delimiter = src[i : i + 3]
                i += 3
                while i < n and src[i : i + 3] != delimiter:
                    if src[i] == "\n":
                        line += 1
                    if src[i] == "\\":
                        i += 1
                    i += 1
                i += 3
                prev = "s"
                continue

            quote = c
            raw = prev == "r" and not typescript  # Dart raw string: r'...'
            i += 1

            while i < n and src[i] != quote:
                if src[i] == "\\" and not raw:
                    i += 2
                    continue

                if src[i] == "\n":
                    line += 1
                    # Template literal atravessa linhas; string comum, nao.
                    if quote == "`":
                        i += 1
                        continue
                    break

                # Interpolacao: o conteudo dentro de ${...} e codigo.
                if src[i] == "$" and i + 1 < n and src[i + 1] == "{":
                    depth = 1
                    i += 2
                    while i < n and depth > 0:
                        if src[i] == "{":
                            depth += 1
                        elif src[i] == "}":
                            depth -= 1
                        elif src[i] == "\n":
                            line += 1
                        i += 1
                    continue

                i += 1

            i += 1
            prev = "s"
            continue

        # ---------------------------------------------------------- delimitadores
        if c in PAIRS:
            stack.append((c, line))
        elif c in CLOSING:
            if not stack or stack[-1][0] != CLOSING[c]:
                return f"{path}:{line}  '{c}' sem abertura correspondente"
            stack.pop()

        prev = c
        i += 1

    if stack:
        char, opened = stack[-1]
        return f"{path}:{opened}  '{char}' nunca fechado"

    return None


def walk(target):
    if os.path.isfile(target):
        yield target
        return
    for root, _, files in os.walk(target):
        for f in files:
            if f.endswith((".dart", ".ts")):
                yield os.path.join(root, f)


def main():
    targets = sys.argv[1:] or ["lib", "test", "functions/src"]

    checked = 0
    problems = []

    for target in targets:
        if not os.path.exists(target):
            continue
        for path in walk(target):
            checked += 1
            result = check(path, typescript=path.endswith(".ts"))
            if result:
                problems.append(result)

    if problems:
        print(f"{len(problems)} problema(s) em {checked} arquivos:\n")
        for p in problems:
            print(f"  {p}")
        sys.exit(1)

    print(f"Balanceamento OK — {checked} arquivos")


if __name__ == "__main__":
    main()
