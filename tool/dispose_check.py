"""Detector de controllers, streams e listeners não encerrados.

## Por que isso é sério e por que é fácil passar despercebido

Um `TextEditingController` não descartado não trava nada na hora — a tela
abre, funciona, fecha normalmente. O vazamento é silencioso: o controller
continua vivo na memória, preso a um `State` que o Flutter já descartou, e
isso se acumula a cada vez que a tela é aberta e fechada. Em uma sessão
curta de teste manual, ninguém percebe. Depois de um dia de uso real —
entrar e sair do prontuário, abrir e fechar formulários — é isso que causa
o app ficando mais lento e derrubando por falta de memória.

## O que o script verifica

Para cada classe `State`/`ConsumerState`:
  1. Lista os campos declarados com tipo descartável (TextEditingController,
     AnimationController, ScrollController, FocusNode, StreamSubscription,
     StreamController, PageController, TabController, Timer).
  2. Confere se o método `dispose()` da classe chama `.dispose()` (ou
     `.cancel()`, para Timer/StreamSubscription) em cada um.

Objetos passados por parâmetro ou obtidos de um provider não entram nesta
lista — o dono é quem criou, não quem só usa. Só o que a própria classe
instancia com `= XController(...)` é responsabilidade dela descartar.

Uso: python3 tool/dispose_check.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# Tipo -> metodo de descarte esperado.
DISPOSABLE_TYPES = {
    "TextEditingController": "dispose",
    "AnimationController": "dispose",
    "ScrollController": "dispose",
    "PageController": "dispose",
    "TabController": "dispose",
    "FocusNode": "dispose",
    "OverlayEntry": "remove",
    "StreamController": "close",
    "StreamSubscription": "cancel",
    "Timer": "cancel",
    "AudioPlayer": "dispose",
    "VideoPlayerController": "dispose",
}


def strip_comments_and_strings(src):
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
        if src[i] in "'\"":
            q = src[i]
            i += 1
            while i < n and src[i] != q:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "\n":
                    break
                i += 1
            i += 1
            out.append(" ")
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def extract_classes(src):
    """(nome, corpo) de cada classe, por posicao de chave balanceada."""
    classes = []
    for m in re.finditer(r"class\s+(\w+)[^{]*\{", src):
        start = m.end()
        depth = 1
        i = start
        while i < len(src) and depth > 0:
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
            i += 1
        classes.append((m.group(1), src[start : i - 1]))
    return classes


findings = []
files_scanned = 0

for root, _, files in os.walk(LIB):
    if "presentation" not in root:
        continue
    for f in files:
        if not f.endswith(".dart"):
            continue
        path = os.path.join(root, f)
        raw = open(path, encoding="utf-8").read()

        if not re.search(r"extends\s+(?:State|ConsumerState)<", raw):
            continue

        files_scanned += 1
        src = strip_comments_and_strings(raw)
        rel = os.path.relpath(path, ROOT)

        for class_name, body in extract_classes(src):
            # Campos own-instantiated: `Tipo nome = Tipo(...)` ou
            # `late final Tipo nome;` seguido de atribuicao com o mesmo tipo.
            #
            # Só campos de classe de verdade entram aqui — declarados direto
            # no corpo da classe, indentação rasa. Uma variável local dentro
            # de um método (indentação mais funda) tem responsabilidade de
            # descarte no próprio método que a criou, não no dispose() da
            # classe; cobrar isso ali seria checar o lugar errado para
            # sempre, mesmo quando o método já descarta corretamente.
            owned = {}
            for dtype, method in DISPOSABLE_TYPES.items():
                for m in re.finditer(
                    r"(?:^|\n)([ \t]*)(?:final\s+)?" + dtype
                    + r"(?:<[^>]*>)?\s+(_?\w+)\s*=\s*" + dtype + r"\(",
                    body,
                ):
                    indent, name = m.groups()
                    if len(indent.expandtabs()) > 2:
                        continue  # variável local de método, não campo
                    owned[name] = (dtype, method)
                for m in re.finditer(
                    r"(?:^|\n)([ \t]*)late\s+(?:final\s+)?" + dtype
                    + r"(?:<[^>]*>)?\s+(_?\w+)\s*;",
                    body,
                ):
                    indent, name = m.groups()
                    if len(indent.expandtabs()) > 2:
                        continue
                    if re.search(re.escape(name) + r"\s*=\s*" + dtype + r"\(", body):
                        owned[name] = (dtype, method)

            if not owned:
                continue

            dispose_match = re.search(
                r"\bdispose\s*\(\s*\)\s*(?:async\s*)?\{", body
            )
            dispose_body = ""
            if dispose_match:
                d_start = dispose_match.end()
                depth = 1
                i = d_start
                while i < len(body) and depth > 0:
                    if body[i] == "{":
                        depth += 1
                    elif body[i] == "}":
                        depth -= 1
                    i += 1
                dispose_body = body[d_start : i - 1]

            # Descarte em lote: `for (final X c in _algumaLista) { c.dispose();
            # }` — quer a lista venha de um getter nomeado, quer venha
            # escrita direto no `in` do loop (`in <Tipo>[a, b, c]`).
            batch_disposed_names = set()
            for loop_m in re.finditer(
                r"for\s*\(\s*(?:final\s+)?\w+(?:<[^>]*>)?\s+(\w+)\s+in\s+"
                r"(?:(\w+)|(?:<[^>]*>)?\[([^\]]*)\])\s*\)\s*\{([^}]*)\}",
                dispose_body,
            ):
                loop_var, iterable_name, inline_items, loop_body = loop_m.groups()

                calls_directly = re.search(
                    re.escape(loop_var) + r"[?!]?\.\w+\(", loop_body
                )
                calls_via_cascade = bool(
                    re.search(r"\b" + re.escape(loop_var) + r"\b", loop_body)
                    and re.search(r"\.\.\w+\(", loop_body)
                )
                if not (calls_directly or calls_via_cascade):
                    continue

                if inline_items is not None:
                    # Lista escrita direto no `in`: os nomes já estão aqui.
                    batch_disposed_names.update(
                        re.findall(r"\b(_?\w+)\b", inline_items)
                    )
                elif iterable_name:
                    decl = re.search(
                        re.escape(iterable_name)
                        + r"\s*(?:=>|=)\s*(?:<[^>]*>)?\[([^;]*)\]",
                        body,
                    )
                    if decl:
                        batch_disposed_names.update(
                            re.findall(r"\b(_?\w+)\b", decl.group(1))
                        )

            for name, (dtype, method) in owned.items():
                # Chamada direta (`x.dispose()`) OU cascade num campo que não
                # está dentro de loop nenhum (`x\n  ..dispose();`). A janela
                # depois do nome do campo é onde o cascade normalmente mora.
                direct = re.search(
                    re.escape(name) + r"[?!]?\." + method, dispose_body
                )
                field_pos = dispose_body.find(name)
                cascade = False
                if field_pos != -1:
                    window = dispose_body[field_pos : field_pos + 150]
                    cascade = bool(re.search(r"\.\." + method + r"\(", window))

                if direct or cascade or name in batch_disposed_names:
                    continue

                findings.append(
                    f"{rel}  classe {class_name}: `{name}` ({dtype}) nunca "
                    f"chama `.{method}()` em dispose()"
                )

if not findings:
    print(f"Nenhum controller/stream sem descarte encontrado ({files_scanned} arquivos com estado).")
    sys.exit(0)

print(f"{len(findings)} candidato(s) em {files_scanned} arquivos com estado:\n")
for f in findings:
    print(f"  {f}")

print(
    "\nHeurística sobre texto: objeto recebido por parâmetro ou de um "
    "provider não é responsabilidade desta classe descartar — confira antes "
    "de agir."
)
