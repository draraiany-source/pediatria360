"""Detector de BuildContext usado depois de `await` sem checar `mounted`.

## Por que isso é sério

Entre o `await` e a linha seguinte, o usuário pode ter saído da tela — voltado
uma página, trocado de aba, fechado o modal. Se o código usar `context`
depois disso sem checar `mounted`/`context.mounted`, duas coisas podem
acontecer: uma exceção ("Looking up a deactivated widget's ancestor is
unsafe") em builds de debug, ou em release, silenciosamente nada acontece, ou
pior, referencia estado de uma tela que não existe mais.

Funciona perfeitamente nos testes manuais de quem programou — ninguém sai da
tela no meio de um clique de propósito. Aparece em produção, aleatoriamente,
para o usuário que tocou duas vezes ou girou o aparelho no momento errado.

## Como o script decide

Para cada método `async` de uma classe State/ConsumerState:
  1. Acha cada `await`.
  2. Olha o texto entre esse `await` e o próximo (ou o fim do método).
  3. Se esse trecho usa `context` de um jeito que toca a árvore de widgets
     (Navigator.of, ScaffoldMessenger.of, Theme.of, context.push/go,
     Provider.of...) e não tem `mounted` nem `context.mounted` em lugar
     nenhum antes desse uso, é candidato.

Isso é heurística sobre texto, não análise de fluxo de controle real — um
`if (!mounted) return;` uma linha acima do `await` já protege o resto do
método e o script deveria (e tenta) reconhecer isso.

Uso: python3 tool/context_after_await.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# Usos de `context` que tocam a arvore de widgets e sao perigosos depois de
# um gap assincrono. Ler `context.mounted` em si nao conta como uso perigoso.
DANGEROUS_CONTEXT_USES = re.compile(
    r"(?<!\.)\bcontext\.(?!mounted\b)\w+|"      # context.push, context.go...
    r"\.of\(\s*context\s*\)"                     # Navigator.of(context), Theme.of(context)...
)

MOUNTED_CHECK = re.compile(r"\bmounted\b|\bcontext\.mounted\b")

# Um parâmetro `(BuildContext context)` dentro do trecho REDECLARA o nome —
# sombreia o de fora com um novo, escopado ao builder (showDialog, showModal
# BottomSheet...). Esse context novo é válido enquanto o próprio diálogo
# existir, independente do mounted da tela que o abriu. É o padrão correto e
# onipresente do Flutter para diálogo — não um bug.
SHADOWS_CONTEXT = re.compile(r"\(\s*BuildContext\s+context\s*\)")


def strip_comments_and_strings(src):
    """Preserva contagem de linha: todo `\\n` do original sobrevive aqui,
    mesmo dentro de comentário ou string removidos."""
    out = []
    i, n = 0, len(src)
    while i < n:
        if src[i : i + 2] == "//":
            while i < n and src[i] != "\n":
                i += 1
            continue  # o \n em si cai no ramo generico abaixo, na proxima volta
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


def extract_methods(src):
    """Extrai o corpo de cada método/função async, por posição inicial."""
    methods = []
    for m in re.finditer(
        r"(?:Future(?:<[^>]*>)?\s+)?(\w+)\s*\([^)]*\)\s*async\s*\{", src
    ):
        start = m.end()
        depth = 1
        i = start
        while i < len(src) and depth > 0:
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
            i += 1
        methods.append((m.group(1), start, src[start : i - 1]))
    return methods


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

        # Só interessa em classes com estado (StatefulWidget/ConsumerState);
        # widgets sem estado não guardam BuildContext entre chamadas.
        if not re.search(r"extends\s+(?:State|ConsumerState)<", raw):
            continue

        files_scanned += 1
        src = strip_comments_and_strings(raw)
        rel = os.path.relpath(path, ROOT)

        for method_name, offset, body in extract_methods(src):
            awaits = list(re.finditer(r"\bawait\b", body))
            for idx, aw in enumerate(awaits):
                seg_start = aw.end()
                seg_end = (
                    awaits[idx + 1].start() if idx + 1 < len(awaits) else len(body)
                )
                segment = body[seg_start:seg_end]

                match = DANGEROUS_CONTEXT_USES.search(segment)
                if not match:
                    continue

                # Se o `context` foi sombreado por um `(BuildContext
                # context)` de builder ANTES deste uso, o context aqui é o
                # novo, escopado ao diálogo — não o de fora, que poderia
                # estar obsoleto.
                shadow = SHADOWS_CONTEXT.search(segment[: match.start()])
                if shadow:
                    continue

                # Mounted pode estar ANTES do await inteiro, ou dentro do
                # próprio trecho, na mesma linha do uso perigoso — o padrão
                # comum `if (mounted) context.x();` tem os dois na mesma
                # instrução. Checar só "antes do await" perdia esse caso.
                before_use = body[:seg_start] + segment[: match.start()]
                if MOUNTED_CHECK.search(before_use):
                    continue

                line = src[: offset + seg_start + match.start()].count("\n") + 1
                findings.append(f"{rel}:{line}  em `{method_name}` — context após await sem checar mounted antes")


if not findings:
    print(f"Nenhum uso arriscado de BuildContext após await encontrado ({files_scanned} arquivos com estado).")
    sys.exit(0)

print(f"{len(findings)} candidato(s) em {files_scanned} arquivos com estado:\n")
for f in findings:
    print(f"  {f}")

print(
    "\nHeurística sobre texto, não fluxo de controle real: confira cada uma —"
    " um guard mais cedo no método, fora do padrão que o script reconhece,"
    " pode já proteger o trecho."
)
