"""Verificador de consistência do sistema de design.

## O que "profissional" significa aqui

Não posso renderizar a tela e julgar se está bonita — isso exige o Flutter
rodando. O que dá para garantir sem SDK é a parte mecânica de "parece feito
por uma equipe, não por três pessoas sem combinar": toda cor vem da paleta,
todo espaçamento vem da escala, todo raio de borda é um dos poucos valores
padronizados. Isso é o que este script audita.

Cada achado aqui é uma tela que, visualmente, vai destoar sutilmente do
resto — uma sombra levemente diferente, um azul que não é bem o `vital`,
um espaçamento de 15px onde todo o resto usa 16. Ninguém aponta o dedo pra
isso olhando rápido, mas o efeito cumulativo é o que faz um app parecer
"quase pronto" em vez de pronto.

Uso: python3 tool/design_consistency.py
"""

import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# Arquivos onde declarar cor/espaçamento cru é o trabalho do arquivo, não uma
# violação — a própria definição do token, e widgets muito genéricos de baixo
# nível que não têm outro jeito de existir.
EXEMPT_FILES = {
    "app_colors.dart",
    "app_tokens.dart",
    "app_theme.dart",
    "app_typography.dart",
}

# Contextos em que Colors.X é legítimo mesmo fora dos arquivos de tema:
# branco/preto puro de overlay que não tem token próprio (scrim de modal,
# ícone sobre foto).
ALLOWED_COLOR_TOKENS = {"Colors.transparent"}
ALLOWED_COLOR_PREFIXES = ("Colors.white", "Colors.black")

# Valores de espaçamento que a escala já cobre — qualquer EdgeInsets/SizedBox
# com um número fora desta lista é "espaçamento inventado".
SPACING_SCALE = {2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 96}

# Raios de borda padronizados.
RADIUS_SCALE = {4, 8, 12, 16, 20, 24, 999}  # 999 = pill/circular


def strip_comments_and_strings(src):
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        if c in "'\"":
            q = c
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
        out.append(c)
        i += 1
    return "".join(out)


def screen_files():
    """Só telas e widgets de apresentação — não vale cobrar token de camada
    de dados ou de Cloud Function, que não desenham nada."""
    for root, _, files in os.walk(LIB):
        is_presentation = "presentation" in root
        is_shared_widget = os.path.join("shared", "widgets") in root
        is_core_widget = os.path.join("core", "widgets") in root
        if not (is_presentation or is_shared_widget or is_core_widget):
            continue
        for f in files:
            if not f.endswith(".dart") or f in EXEMPT_FILES:
                continue

            full = os.path.join(root, f)

            # Arquivos que desenham com package:pdf (pw.EdgeInsets,
            # pw.BorderRadius) usam classes de MESMO NOME que as do Flutter,
            # mas de um pacote diferente — sem AppSpacing, sem AppColors, sem
            # relação nenhuma com o sistema de design da tela. Cobrar o
            # mesmo token ali e comparar duas linguagens visuais distintas
            # como se fossem uma só.
            head = open(full, encoding="utf-8").read(2000)
            if "package:pdf/widgets.dart" in head:
                continue

            yield full


findings = defaultdict(list)
files_scanned = 0

# ---------------------------------------------------------------------------
# 1. Cor hexadecimal crua ou Colors.X fora dos arquivos de tema
# ---------------------------------------------------------------------------

for path in screen_files():
    files_scanned += 1
    raw = open(path, encoding="utf-8").read()
    src = strip_comments_and_strings(raw)
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r"Color\(0x[0-9A-Fa-f]{6,8}\)", src):
        line = src[: m.start()].count("\n") + 1
        findings["cor"].append(f"{rel}:{line}  {m.group(0)}")

    for m in re.finditer(r"\bColors\.\w+", src):
        token = m.group(0)
        if token in ALLOWED_COLOR_TOKENS:
            continue
        if token.startswith(ALLOWED_COLOR_PREFIXES):
            continue
        line = src[: m.start()].count("\n") + 1
        findings["cor"].append(f"{rel}:{line}  {token}")


# ---------------------------------------------------------------------------
# 2. Espaçamento fora da escala (EdgeInsets, SizedBox)
# ---------------------------------------------------------------------------

for path in screen_files():
    raw = open(path, encoding="utf-8").read()
    src = strip_comments_and_strings(raw)
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r"EdgeInsets\.\w+\(([^)]*)\)", src):
        for num_m in re.finditer(r"(\d+(?:\.\d+)?)", m.group(1)):
            value = float(num_m.group(1))
            if value == 0 or value in SPACING_SCALE:
                continue
            line = src[: m.start()].count("\n") + 1
            findings["espaçamento"].append(
                f"{rel}:{line}  EdgeInsets com {value} (fora da escala)"
            )

    for m in re.finditer(r"SizedBox\((?:width|height):\s*(\d+(?:\.\d+)?)\)", src):
        value = float(m.group(1))
        if value in SPACING_SCALE:
            continue
        line = src[: m.start()].count("\n") + 1
        findings["espaçamento"].append(
            f"{rel}:{line}  SizedBox com {value} (fora da escala)"
        )


# ---------------------------------------------------------------------------
# 3. Raio de borda fora da escala
# ---------------------------------------------------------------------------

for path in screen_files():
    raw = open(path, encoding="utf-8").read()
    src = strip_comments_and_strings(raw)
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r"BorderRadius\.circular\((\d+(?:\.\d+)?)\)", src):
        value = float(m.group(1))
        if value in RADIUS_SCALE:
            continue
        line = src[: m.start()].count("\n") + 1
        findings["raio"].append(f"{rel}:{line}  BorderRadius.circular({value})")


# ---------------------------------------------------------------------------
# 4. Mistura de família de ícone (rounded vs sem sufixo)
# ---------------------------------------------------------------------------
#
# O app padronizou em `_rounded` (Icons.home_rounded) e, quando não existe
# variante rounded, `_outlined`. Um ícone sem sufixo (Icons.home) desenha
# levemente diferente dos vizinhos — quadrado onde o resto é arredondado.

SUFFIX_OK = ("_rounded", "_outlined", "_sharp")

for path in screen_files():
    raw = open(path, encoding="utf-8").read()
    src = strip_comments_and_strings(raw)
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r"\bIcons\.(\w+)", src):
        name = m.group(1)
        if any(name.endswith(s) for s in SUFFIX_OK):
            continue
        line = src[: m.start()].count("\n") + 1
        findings["ícone"].append(
            f"{rel}:{line}  Icons.{name} (sem sufixo padronizado)"
        )


# ---------------------------------------------------------------------------
# Saída
# ---------------------------------------------------------------------------

total = sum(len(v) for v in findings.values())

if total == 0:
    print(f"Consistência visual: nenhum desvio encontrado ({files_scanned} arquivos de tela).")
    sys.exit(0)

print(f"{total} desvio(s) do sistema de design em {files_scanned} arquivos de tela:\n")

LABELS = {
    "cor": "Cor fora da paleta (AppColors)",
    "espaçamento": "Espaçamento fora da escala (AppSpacing)",
    "raio": "Raio de borda fora da escala (AppRadius)",
    "ícone": "Ícone sem sufixo de família padronizado",
}

for kind in ("cor", "espaçamento", "raio", "ícone"):
    items = findings.get(kind)
    if not items:
        continue
    print(f"### {LABELS[kind]} ({len(items)})")
    for item in items:
        print(f"  {item}")
    print()
