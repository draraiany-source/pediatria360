"""Detector de lista renderizada sem tratar o caso vazio.

## O que isto verifica

Dentro de um `AsyncValue.when(...)`, o caso `data:` que recebe uma
`List`/`Iterable` e a renderiza direto — sem checar `.isEmpty` em lugar
nenhum do corpo — deixa a tela em branco, sem explicação, quando a lista
vem vazia. "Nenhuma tela deve ficar vazia sem dizer o que aconteceu" só é
verdade se alguém checar.

## Por que a checagem é frouxa de propósito

A primeira versão procurava `{nome_do_parametro}.isEmpty` — e deu falso
positivo real: é comum filtrar a lista original numa variável derivada
(`final visible = _filtered(all); if (visible.isEmpty) ...`) antes de
checar. Procurar só pelo nome original perde esse caso inteiro. Esta
versão procura `.isEmpty` em qualquer variável, dentro da janela — isso
troca falso positivo por falso negativo ocasional, que é a troca certa:
melhor deixar de sinalizar um caso raro do que gritar lobo toda hora em
código correto.

Nem toda ausência de `.isEmpty` é bug — algumas seções são
deliberadamente "some quando vazio" (uma seção secundária dentro de uma
tela maior, por exemplo), não a tela inteira. Confira antes de corrigir.

Uso: python3 tool/check_empty_states.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib", "features")

WINDOW = 500


def main():
    findings = []
    files_scanned = 0

    for root, _, files in os.walk(LIB):
        if "presentation" not in root:
            continue
        for f in files:
            if not f.endswith(".dart"):
                continue
            path = os.path.join(root, f)
            src = open(path, encoding="utf-8").read()
            files_scanned += 1

            for m in re.finditer(
                r"data:\s*\((?:List|Iterable)<\w+>\s*(\w+)\)\s*(?:=>|\{)", src
            ):
                window = src[m.end() : m.end() + WINDOW]
                if ".isEmpty" in window or ".shrink()" in window:
                    continue  # trata o caso vazio de algum jeito

                line = src[: m.start()].count("\n") + 1
                rel = os.path.relpath(path, ROOT)
                findings.append(
                    f"{rel}:{line}  data: (List<...> {m.group(1)}) renderiza "
                    "sem checar lista vazia nem retornar algo condicional"
                )

    if not findings:
        print(f"Nenhum caso encontrado ({files_scanned} arquivos de tela).")
        return 0

    print(f"{len(findings)} candidato(s), em {files_scanned} arquivos:\n")
    for f in findings:
        print(f"  {f}")
    print(
        "\nHeurística: confira cada um. Seção secundária que soma quando "
        "vazia pode ser design correto, não bug — o alvo real é tela "
        "principal que fica em branco sem nenhuma explicação."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
