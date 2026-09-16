"""Detector de consultas Firestore sem limite explícito.

## O que isto NÃO é

Não é "toda `.get()`/`.snapshots()` precisa de `.limit()`". Uma consulta já
restrita à subcoleção de um único registro — filhos de uma família, doses do
calendário vacinal de uma criança, aulas de um curso — tem limite natural
imposto pelo próprio domínio. Forçar um `.limit()` arbitrário nesses casos
não protege nada e arrisca cortar dado real (um histórico de crescimento
truncado nas medições mais antigas, por exemplo).

## O que é

Leitura de coleção (não de documento único por id) sem nenhum `.limit()` ou
`.limitToLast()` na cadeia. É candidato a rever, não veredito automático —
o script lista; humano decide se o domínio já limita sozinho.

Uso: python3 tool/query_limits.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")


def strip_comments(src):
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
                i += 1
            i += 2
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


findings = []

for root, _, files in os.walk(LIB):
    # Consultas de verdade rodam na camada de dados — repositório ou fonte
    # remota. Domínio e apresentação não tocam o Firestore diretamente.
    if "data" not in root:
        continue

    for f in files:
        if not f.endswith(".dart"):
            continue
        path = os.path.join(root, f)
        src = strip_comments(open(path, encoding="utf-8").read())
        rel = os.path.relpath(path, ROOT)

        for m in re.finditer(r"\.(get|snapshots)\(\)", src):
            start = max(src.rfind(";", 0, m.start()), src.rfind("{", 0, m.start()))
            window = src[start : m.end()]

            if ".limit(" in window or ".limitToLast(" in window:
                continue

            # Leitura de documento único por id: o conceito de "limite" não
            # se aplica. Detecta pela ausência de operador de consulta
            # (`.collection(`, `.where(`, `.orderBy(`) depois do último
            # `.doc(` — checar por posição em vez de casar parênteses
            # evita quebrar em `.doc(_todayKey())`, que tem parênteses
            # aninhados que uma regex ingênua não fecha corretamente.
            last_doc = window.rfind(".doc(")
            if last_doc != -1:
                after_doc = window[last_doc:]
                if not any(
                    op in after_doc
                    for op in (".collection(", ".collectionGroup(", ".where(", ".orderBy(")
                ):
                    continue

            if ".collection(" not in window and ".collectionGroup(" not in window:
                continue

            line = src[: m.start()].count("\n") + 1
            findings.append(f"{rel}:{line}  .{m.group(1)}() sem limite na cadeia")


if not findings:
    print("Nenhuma consulta de coleção sem limite encontrada.")
    sys.exit(0)

print(f"{len(findings)} consulta(s) de coleção sem `.limit()`/`.limitToLast()`:\n")
for f in findings:
    print(f"  {f}")

print(
    "\nCada uma merece julgamento, não correção automática: uma coleção já "
    "restrita ao escopo de um único usuário/registro pode ser segura sem "
    "limite explícito. Revisar antes de adicionar `.limit()` às cegas."
)
