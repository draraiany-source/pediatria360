"""Detector de codigo morto.

Encontra o que foi escrito e nunca chegou a ser usado. Em projeto construido
em sessoes longas, isso acumula: uma tela substituida, um provider criado para
uma abordagem abandonada, um widget que ficou orfao apos uma mudanca de rota.

Codigo morto nao e so desperdicio de espaco. Ele engana quem le — alguem
assume que aquele caminho existe — e engana ferramentas de cobertura.

O que detecta:
  1. Arquivos .dart nunca importados por ninguem
  2. Classes declaradas e nunca referenciadas fora do proprio arquivo
  3. Providers declarados e nunca observados
  4. Enums declarados e nunca usados

Falsos positivos possiveis: pontos de entrada (main.dart), classes usadas
apenas por reflexao, e o que so aparece em testes. O script marca esses casos
em vez de ignora-los em silencio.

Uso: python3 tool/dead_code.py
"""

import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")
TEST = os.path.join(ROOT, "test")

# Arquivos que ninguem importa por definicao.
ENTRY_POINTS = {"main.dart", "firebase_options.dart"}


def strip_comments(src):
    """Remove comentarios para nao contar mencao em documentacao como uso."""
    out = []
    i, n = 0, len(src)
    while i < n:
        if src[i] == "/" and i + 1 < n and src[i + 1] == "/":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if src[i] == "/" and i + 1 < n and src[i + 1] == "*":
            i += 2
            while i + 1 < n and not (src[i] == "*" and src[i + 1] == "/"):
                i += 1
            i += 2
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def dart_files(base):
    for root, _, files in os.walk(base):
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(root, f)


sources = {}
stripped = {}

for path in dart_files(LIB):
    raw = open(path, encoding="utf-8").read()
    sources[path] = raw
    stripped[path] = strip_comments(raw)

test_sources = {}
if os.path.isdir(TEST):
    for path in dart_files(TEST):
        test_sources[path] = strip_comments(open(path, encoding="utf-8").read())

all_lib = "\n".join(stripped.values())
all_test = "\n".join(test_sources.values())

findings = defaultdict(list)


# ---------------------------------------------------------------------------
# 1. Arquivos nunca importados
# ---------------------------------------------------------------------------

imported = set()

for path, src in {**stripped, **test_sources}.items():
    for m in re.finditer(r"import\s+'([^']+)'", src):
        target = m.group(1)

        if target.startswith("package:pediatria360/"):
            resolved = os.path.join(LIB, target.replace("package:pediatria360/", ""))
        elif target.startswith(("package:", "dart:")):
            continue
        else:
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))

        imported.add(os.path.normpath(resolved))

for path in sources:
    name = os.path.basename(path)
    if name in ENTRY_POINTS:
        continue
    if os.path.normpath(path) not in imported:
        findings["arquivo"].append(os.path.relpath(path, ROOT))


# ---------------------------------------------------------------------------
# 2. Classes nunca referenciadas fora do proprio arquivo
# ---------------------------------------------------------------------------

CLASS_RE = re.compile(
    r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|mixin\s+)*class\s+(\w+)", re.M
)

for path, src in stripped.items():
    rel = os.path.relpath(path, ROOT)

    classes_in_file = CLASS_RE.findall(src)

    for m in CLASS_RE.finditer(src):
        name = m.group(1)

        # Privadas por convencao sao locais ao arquivo.
        if name.startswith("_"):
            continue

        # Notifier e usado no proprio arquivo via NotifierProvider(X.new).
        # Cobrar uso externo produziria falso positivo em toda a camada de
        # estado do Riverpod.
        if re.search(r"\b" + re.escape(name) + r"\.new\b", src):
            continue

        # Variante de sealed class: existe para o pattern matching, e usada
        # implicitamente por quem faz switch sobre o tipo pai.
        if re.search(r"class\s+" + re.escape(name) + r"[^{]*\bextends\s+\w+|"
                     r"class\s+" + re.escape(name) + r"[^{]*\bimplements\s+\w+", src):
            parent = re.search(
                r"class\s+" + re.escape(name) + r"[^{]*\b(?:extends|implements)\s+(\w+)",
                src,
            )
            if parent and re.search(r"\bsealed class\s+" + parent.group(1), all_lib):
                continue

        others = "\n".join(s for p, s in stripped.items() if p != path)
        used_in_lib = re.search(r"\b" + re.escape(name) + r"\b", others)
        used_in_test = re.search(r"\b" + re.escape(name) + r"\b", all_test)

        if used_in_lib:
            continue

        # Varios arquivos de tela guardam mais de uma classe publica: a
        # "porta de entrada" e importada de fora, e as demais (sub-telas,
        # sheets, cartoes) so sao citadas dentro do proprio arquivo. Cobrar
        # uso externo de TODAS produz falso positivo sistematico — foi assim
        # que ContentEditorScreen, GrowthFormSheet e outras 20+ classes
        # legitimas apareceram como "mortas" numa auditoria real.
        #
        # Se qualquer outra classe do mesmo arquivo E referenciada de fora,
        # tratamos o arquivo como alcancavel e suprimimos as irmas.
        siblings_reachable = any(
            other_name != name
            and re.search(r"\b" + re.escape(other_name) + r"\b", others)
            for other_name in classes_in_file
        )
        if siblings_reachable:
            continue

        label = f"{name}  ({rel})"
        if used_in_test:
            label += "  — usada apenas em testes"
        findings["classe"].append(label)


# ---------------------------------------------------------------------------
# 3. Providers nunca observados
# ---------------------------------------------------------------------------

# Ancorado ao inicio de linha (nivel de topo): sem isso, uma variavel local
# como `final GoogleAuthProvider provider = ...` dentro de um metodo era
# capturada como se fosse uma declaracao de provider do Riverpod.
PROVIDER_RE = re.compile(r"^final\s+[\w<>,\s?]+\s+(\w*[Pp]rovider)\s*=", re.M)

for path, src in stripped.items():
    rel = os.path.relpath(path, ROOT)

    for m in PROVIDER_RE.finditer(src):
        name = m.group(1)

        # Provider privado (prefixo _) e de uso interno por convencao —
        # cobrar observacao externa e o mesmo erro que a checagem de classes
        # ja cometia com Notifier.new.
        if name.startswith("_"):
            continue

        pattern = (
            r"(?:watch|read|listen|invalidate|refresh|overrideWith\w*)\s*\(\s*"
            + re.escape(name)
        )

        if re.search(pattern, all_lib) or re.search(pattern, all_test):
            continue

        # Provider pode ser composto dentro de outro sem chamada direta.
        others = "\n".join(s for p, s in stripped.items() if p != path)
        if re.search(r"\b" + re.escape(name) + r"\b", others):
            continue

        findings["provider"].append(f"{name}  ({rel})")


# ---------------------------------------------------------------------------
# 4. Enums nunca usados
# ---------------------------------------------------------------------------

for path, src in stripped.items():
    rel = os.path.relpath(path, ROOT)

    for m in re.finditer(r"^enum\s+(\w+)", src, re.M):
        name = m.group(1)

        # Privado por convencao: enum de estado interno de uma tela nao
        # precisa ser citado por fora para estar "vivo".
        if name.startswith("_"):
            continue

        others = "\n".join(s for p, s in stripped.items() if p != path)

        if re.search(r"\b" + re.escape(name) + r"\b", others):
            continue
        if re.search(r"\b" + re.escape(name) + r"\b", all_test):
            continue

        findings["enum"].append(f"{name}  ({rel})")


# ---------------------------------------------------------------------------
# Saida
# ---------------------------------------------------------------------------

LABELS = {
    "arquivo": "Arquivos nunca importados",
    "classe": "Classes nunca referenciadas fora do proprio arquivo",
    "provider": "Providers nunca observados",
    "enum": "Enums nunca usados",
}

total = sum(len(v) for v in findings.values())

if total == 0:
    print("Nenhum codigo morto encontrado.")
    print(f"  {len(sources)} arquivos analisados")
    sys.exit(0)

print(f"{total} candidato(s) a codigo morto:\n")

for kind in ("arquivo", "classe", "provider", "enum"):
    items = findings.get(kind)
    if not items:
        continue
    print(f"### {LABELS[kind]} ({len(items)})")
    for item in sorted(items):
        print(f"  {item}")
    print()

print("Nem todo achado e remocao obrigatoria: entidade de dominio pode ser")
print("legitimamente usada so em teste, e provider pode existir para uso")
print("futuro proximo. Confira antes de apagar.")
