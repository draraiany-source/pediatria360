"""Gera o arquivo de referencia antropometrica usado pelas curvas.

IMPORTANTE — LEIA ANTES DE USO CLINICO
======================================
Os valores de M (mediana) abaixo sao ANCORAS APROXIMADAS dos padroes de
crescimento da OMS (2006/2007), e os valores de L e S sao ESTIMATIVAS
suavizadas. Eles servem para o app funcionar, plotar curvas coerentes e
permitir teste da matematica de escore-Z.

ELES NAO SUBSTITUEM AS TABELAS OFICIAIS.

Antes de qualquer uso clinico real, baixe os arquivos LMS oficiais em
https://www.who.int/tools/child-growth-standards/standards e substitua o
conteudo de assets/data/who_reference.json. O formato ja e o mesmo: basta
trocar as listas por mes. Nenhuma linha de codigo Dart precisa mudar.

O que E confiavel neste projeto: a matematica LMS (`WhoReference.zScore`),
que segue a formula publicada pela OMS e esta coberta por testes.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "data")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# Ancoras: mes -> mediana. Interpoladas linearmente entre os pontos.
# ---------------------------------------------------------------------------

WEIGHT_M = {
    "male": {0: 3.3, 1: 4.5, 2: 5.6, 3: 6.4, 4: 7.0, 5: 7.5, 6: 7.9,
             9: 8.9, 12: 9.6, 18: 10.9, 24: 12.2, 36: 14.3, 48: 16.3,
             60: 18.3, 72: 20.5, 84: 22.9, 96: 25.4, 108: 28.1, 120: 31.2},
    "female": {0: 3.2, 1: 4.2, 2: 5.1, 3: 5.8, 4: 6.4, 5: 6.9, 6: 7.3,
               9: 8.2, 12: 8.9, 18: 10.2, 24: 11.5, 36: 13.9, 48: 16.1,
               60: 18.2, 72: 20.2, 84: 22.4, 96: 25.0, 108: 28.2, 120: 31.9},
}

HEIGHT_M = {
    "male": {0: 49.9, 1: 54.7, 2: 58.4, 3: 61.4, 4: 63.9, 5: 65.9, 6: 67.6,
             9: 72.0, 12: 75.7, 18: 82.3, 24: 87.1, 36: 96.1, 48: 103.3,
             60: 110.0, 72: 116.0, 84: 121.7, 96: 127.3, 108: 132.6,
             120: 137.8},
    "female": {0: 49.1, 1: 53.7, 2: 57.1, 3: 59.8, 4: 62.1, 5: 64.0, 6: 65.7,
               9: 70.1, 12: 74.0, 18: 80.7, 24: 85.7, 36: 95.1, 48: 102.7,
               60: 109.4, 72: 115.1, 84: 120.8, 96: 126.6, 108: 132.5,
               120: 138.6},
}

HEAD_M = {
    "male": {0: 34.5, 1: 37.3, 2: 39.1, 3: 40.5, 4: 41.6, 5: 42.6, 6: 43.3,
             9: 45.0, 12: 46.1, 18: 47.4, 24: 48.3, 30: 48.9, 36: 49.5},
    "female": {0: 33.9, 1: 36.5, 2: 38.3, 3: 39.5, 4: 40.6, 5: 41.5, 6: 42.2,
               9: 43.8, 12: 44.9, 18: 46.2, 24: 47.2, 30: 47.9, 36: 48.4},
}

# IMC: derivado de peso/altura nas ancoras, o que mantem os tres indicadores
# coerentes entre si.
def bmi_medians(sex):
    out = {}
    for month in sorted(HEIGHT_M[sex]):
        w = interpolate(WEIGHT_M[sex], month)
        h = interpolate(HEIGHT_M[sex], month) / 100
        out[month] = round(w / (h * h), 2)
    return out


def interpolate(anchors, month):
    keys = sorted(anchors)
    if month <= keys[0]:
        return anchors[keys[0]]
    if month >= keys[-1]:
        return anchors[keys[-1]]
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a <= month <= b:
            t = (month - a) / (b - a)
            return anchors[a] + (anchors[b] - anchors[a]) * t
    return anchors[keys[-1]]


# L e S estimados. A dispersao relativa (S) cai com a idade no peso e e
# praticamente constante na estatura.
def lms_for(indicator, month):
    if indicator == "weight_for_age":
        L = 0.35 if month < 6 else (0.2 if month < 24 else -0.2)
        S = 0.140 - 0.030 * min(month, 60) / 60
    elif indicator == "height_for_age":
        L = 1.0
        S = 0.037 + 0.005 * min(month, 60) / 60
    elif indicator == "bmi_for_age":
        L = -0.4
        S = 0.090
    else:  # head_for_age
        L = 1.0
        S = 0.031
    return round(L, 3), round(S, 4)


INDICATORS = {
    "weight_for_age": (WEIGHT_M, 120),
    "height_for_age": (HEIGHT_M, 120),
    "head_for_age": (HEAD_M, 36),
    "bmi_for_age": (None, 120),
}

data = {
    "_aviso": (
        "Valores APROXIMADOS, gerados para desenvolvimento. Substitua pelas "
        "tabelas LMS oficiais da OMS antes de uso clinico. Fonte oficial: "
        "https://www.who.int/tools/child-growth-standards/standards"
    ),
    "_formato": "indicador -> sexo -> lista de {mes, L, M, S}",
    "_versao": "aproximacao-1",
    "indicadores": {},
}

for indicator, (anchors, max_month) in INDICATORS.items():
    data["indicadores"][indicator] = {}
    for sex in ("male", "female"):
        table = bmi_medians(sex) if indicator == "bmi_for_age" else anchors[sex]
        rows = []
        for month in range(0, max_month + 1):
            L, S = lms_for(indicator, month)
            rows.append(
                {
                    "mes": month,
                    "L": L,
                    "M": round(interpolate(table, month), 3),
                    "S": S,
                }
            )
        data["indicadores"][indicator][sex] = rows

path = os.path.join(OUT_DIR, "who_reference.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

size = os.path.getsize(path)
print(f"gerado: assets/data/who_reference.json ({size / 1024:.1f} KB)")
for indicator in data["indicadores"]:
    n = len(data["indicadores"][indicator]["male"])
    print(f"  {indicator}: {n} meses x 2 sexos")
