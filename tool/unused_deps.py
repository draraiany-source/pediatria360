"""Detector de dependencias declaradas e nao usadas.

Dependencia sobrando nao e so peso no bundle. Cada pacote e superficie de
ataque, ponto de quebra em atualizacao do Flutter e mais um licenciamento a
conferir antes de publicar.

O inverso tambem e verificado: pacote importado no codigo e ausente do
pubspec. Isso compila enquanto for dependencia transitiva de outro pacote — e
quebra sem aviso quando esse outro pacote troca de versao.

Uso: python3 tool/unused_deps.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Pacotes usados por configuracao, nao por import.
INDIRECT = {
    # Ferramentas de build e analise
    "flutter_lints",
    "flutter_test",
    "integration_test",
    "build_runner",
    "cupertino_icons",  # referenciado no pubspec do Flutter
    # Firebase: alguns sao inicializados por plugin nativo
    "firebase_core_platform_interface",
    # Usado por configuracao, nao por import: as macros PERMISSION_* do
    # Podfile controlam quais permissoes o app declara no iOS.
    "permission_handler",
    # hive_flutter reexporta hive, mas declarar explicito o que se usa evita
    # quebra quando o reexport mudar.
    "hive",
}

# package -> nome real da biblioteca importada, quando diferem.
IMPORT_ALIASES = {
    "google_fonts": "google_fonts",
    "flutter_riverpod": "flutter_riverpod",
    "cached_network_image": "cached_network_image",
    "flutter_local_notifications": "flutter_local_notifications",
    "shared_preferences": "shared_preferences",
    "url_launcher": "url_launcher",
    "package_info_plus": "package_info_plus",
    "permission_handler": "permission_handler",
    "image_picker": "image_picker",
    "video_player": "video_player",
    "flutter_animate": "flutter_animate",
    "connectivity_plus": "connectivity_plus",
    "hive_flutter": "hive_flutter",
    "sqflite": "sqflite",
    "path_provider": "path_provider",
    "fl_chart": "fl_chart",
    "go_router": "go_router",
    "equatable": "equatable",
    "printing": "printing",
    "crypto": "crypto",
    "chewie": "chewie",
    "uuid": "uuid",
    "dio": "dio",
    "pdf": "pdf",
}


def parse_pubspec():
    """Le as dependencias declaradas, separando diretas de dev."""
    path = os.path.join(ROOT, "pubspec.yaml")
    if not os.path.exists(path):
        return {}, {}

    deps, dev_deps = {}, {}
    section = None

    for line in open(path, encoding="utf-8"):
        stripped = line.rstrip()

        if stripped.startswith("dependencies:"):
            section = "deps"
            continue
        if stripped.startswith("dev_dependencies:"):
            section = "dev"
            continue
        if stripped and not stripped[0].isspace() and stripped.endswith(":"):
            section = None
            continue

        if section and re.match(r"^  \w", stripped):
            m = re.match(r"^  ([\w_]+):\s*(.*)$", stripped)
            if m:
                target = deps if section == "deps" else dev_deps
                target[m.group(1)] = m.group(2).strip()

    return deps, dev_deps


def collect_imports():
    """Todos os pacotes importados em lib/ e test/."""
    imported = set()

    for base in ("lib", "test"):
        full = os.path.join(ROOT, base)
        if not os.path.isdir(full):
            continue

        for root, _, files in os.walk(full):
            for f in files:
                if not f.endswith(".dart"):
                    continue
                src = open(os.path.join(root, f), encoding="utf-8").read()
                for m in re.finditer(r"import\s+'package:([\w_]+)/", src):
                    imported.add(m.group(1))
                for m in re.finditer(r"export\s+'package:([\w_]+)/", src):
                    imported.add(m.group(1))

    return imported


deps, dev_deps = parse_pubspec()
imported = collect_imports()

# O proprio pacote nao conta como dependencia externa.
imported.discard("pediatria360")
imported.discard("flutter")

problems = []

# ---------------------------------------------------------------------------
# 1. Declaradas e nunca importadas
# ---------------------------------------------------------------------------

for name in sorted(deps):
    if name in INDIRECT or name == "flutter":
        continue

    library = IMPORT_ALIASES.get(name, name)
    if library not in imported:
        problems.append(("nao usada", name, "declarada em dependencies"))

for name in sorted(dev_deps):
    if name in INDIRECT:
        continue
    library = IMPORT_ALIASES.get(name, name)
    if library not in imported:
        problems.append(("nao usada (dev)", name, "declarada em dev_dependencies"))

# ---------------------------------------------------------------------------
# 2. Importadas e nao declaradas
# ---------------------------------------------------------------------------

declared = set(deps) | set(dev_deps) | INDIRECT
alias_to_package = {v: k for k, v in IMPORT_ALIASES.items()}

for library in sorted(imported):
    package = alias_to_package.get(library, library)
    if package in declared or library in declared:
        continue
    problems.append(
        (
            "nao declarada",
            library,
            "importada no codigo mas ausente do pubspec — funciona so "
            "enquanto for dependencia transitiva",
        )
    )

# ---------------------------------------------------------------------------
# Saida
# ---------------------------------------------------------------------------

if not problems:
    print("Dependencias: nenhum problema.")
    print(f"  {len(deps)} diretas, {len(dev_deps)} de desenvolvimento")
    print(f"  {len(imported)} pacotes efetivamente importados")
    sys.exit(0)

print(f"{len(problems)} problema(s):\n")

for kind, name, detail in problems:
    print(f"[{kind}] {name}")
    print(f"          {detail}\n")

undeclared = sum(1 for k, _, _ in problems if k == "nao declarada")
sys.exit(1 if undeclared else 0)
