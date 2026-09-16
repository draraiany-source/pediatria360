"""Detector de botões só-com-ícone sem rótulo acessível.

## Por que isso importa de verdade

Um `IconButton` sem `tooltip` funciona perfeitamente para quem vê a tela — o
ícone de lixeira já diz "excluir". Para quem usa VoiceOver ou TalkBack, o
leitor de tela anuncia só "botão", sem dizer qual. Numa tela de prontuário
com seis ícones na barra superior, isso transforma a navegação em adivinhação
às cegas: qual dos seis é "assinar" e qual é "cancelar"?

`tooltip` no Flutter não é só a dica visual do toque-e-segure — o framework
usa o mesmo texto como rótulo semântico para leitor de tela automaticamente.
Um `tooltip` ausente é uma lacuna de acessibilidade real, não só estética.

## O que o script verifica

Para cada `IconButton(` no código de telas: tem `tooltip:` na mesma
construção, ou está embrulhado em `Semantics(label: ...)`? Se nenhum dos
dois, é candidato.

`IconButton.filled`/`.outlined`/`.filledTonal` contam igual — são a mesma
classe por baixo.

Uso: python3 tool/accessibility_labels.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")


def strip_comments_and_strings_keep_structure(src):
    """Remove comentario e conteudo de string, preservando aspas como
    marcador (para nao perder a posicao de `tooltip: '...'` na busca de
    presenca da chave, mesmo que o texto em si nao importe aqui)."""
    out = []
    i, n = 0, len(src)
    while i < n:
        if src[i : i + 2] == "//":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if src[i : i + 2] == "/*":
            i += 2
            while i + 1 < n and src[i : i + 2] != "*/":
                out.append("\n" if src[i] == "\n" else " ")
                i += 1
            i += 2
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def find_balanced(src, start):
    """A partir de um '(' em start, devolve o indice do ')' que fecha."""
    depth = 0
    i = start
    while i < len(src):
        if src[i] == "(":
            depth += 1
        elif src[i] == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


findings = []
files_scanned = 0

ICON_BUTTON_RE = re.compile(
    r"\bIconButton(?:\.\w+)?\s*\("
)

for root, _, files in os.walk(LIB):
    if "presentation" not in root and "shared" + os.sep + "widgets" not in root:
        continue
    for f in files:
        if not f.endswith(".dart"):
            continue
        path = os.path.join(root, f)
        raw = open(path, encoding="utf-8").read()
        src = strip_comments_and_strings_keep_structure(raw)
        rel = os.path.relpath(path, ROOT)
        files_scanned += 1

        for m in ICON_BUTTON_RE.finditer(src):
            open_paren = m.end() - 1
            close_paren = find_balanced(src, open_paren)
            if close_paren == -1:
                continue
            call_body = src[open_paren : close_paren + 1]

            if "tooltip:" in call_body or "tooltip :" in call_body:
                continue

            # Semantics(label: ...) pode envolver o IconButton por fora —
            # olha uma janela curta antes da construção.
            before = src[max(0, m.start() - 200) : m.start()]
            if re.search(r"Semantics\s*\([^)]*label\s*:", before):
                continue

            line = src[: m.start()].count("\n") + 1
            findings.append(f"{rel}:{line}  IconButton sem tooltip nem Semantics(label:)")

if not findings:
    print(f"Todo IconButton tem rótulo acessível ({files_scanned} arquivos verificados).")
    sys.exit(0)

print(f"{len(findings)} IconButton sem rótulo acessível, em {files_scanned} arquivos:\n")
for f in findings:
    print(f"  {f}")
