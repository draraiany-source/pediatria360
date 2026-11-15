"""Gera as tabelas LMS da OMS usadas pelas curvas de crescimento.

Fonte: arquivos LMS oficiais publicados pela Organizacao Mundial da Saude
nos repositorios dos pacotes anthro (Padroes de Crescimento 2006, 0 a 5
anos, por dia de idade) e anthroplus (Referencia 2007, 5 a 19 anos, por
mes de idade):

  https://github.com/WorldHealthOrganization/anthro/tree/master/data-raw/growthstandards
  https://github.com/WorldHealthOrganization/anthroplus/tree/main/data-raw

Uso:

  python tool/generate_who_reference.py <pasta com os .txt oficiais>

Arquivos esperados na pasta: weianthro.txt, lenanthro.txt, hcanthro.txt,
bmianthro.txt, wfawho2007.txt, hfawho2007.txt, bfawho2007.txt.

Saidas:

  assets/data/who_growth_lms.json  tabela completa (dia a dia ate 60 meses,
                                   mes a mes depois), usada pelo modulo
                                   lib/shared/clinical/growth.dart.
  assets/data/who_reference.json   formato mensal contiguo lido por
                                   lib/features/growth/domain/who_reference.dart.

Os valores numericos sao copiados sem alteracao. Nenhum valor e estimado.
"""

import hashlib
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "data")

SOURCES = {
    "anthro": {
        "repo": "https://github.com/WorldHealthOrganization/anthro",
        "commit": "02aa59cdc41449c0bf101f893215552fe167bda2",
        "path": "data-raw/growthstandards",
    },
    "anthroplus": {
        "repo": "https://github.com/WorldHealthOrganization/anthroplus",
        "commit": "7cfcdb39026e9a55de55732bc3cf14c82261bcf7",
        "path": "data-raw",
    },
}

SEXES = {"1": "male", "2": "female"}
DAYS_PER_MONTH = 30.4375
LAST_LENGTH_DAY = 730
LAST_STANDARD_DAY = 1826


def read_table(folder, name):
    path = os.path.join(folder, name)
    raw = open(path, "rb").read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        text = raw.decode("utf-16")
    else:
        text = raw.decode("utf-8-sig")
    lines = [line for line in text.splitlines() if line.strip()]
    header = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        values = dict(zip(header, line.split("\t")))
        rows.append(values)
    digest = hashlib.sha256(text.replace("\r\n", "\n").encode("utf-8")).hexdigest()
    return rows, digest


def num(value):
    x = float(value)
    return int(x) if x == int(x) and abs(x) < 1e6 and "." not in value else x


def by_sex(rows, lo=None, hi=None, loh=None):
    """Agrupa linhas por sexo, em ordem de idade, filtrando a faixa."""
    out = {"male": [], "female": []}
    for r in rows:
        age = int(r["age"])
        if lo is not None and age < lo:
            continue
        if hi is not None and age > hi:
            continue
        if loh is not None and r.get("loh") and r["loh"] != loh:
            continue
        out[SEXES[r["sex"]]].append((age, [num(r["l"]), num(r["m"]), num(r["s"])]))
    result = {}
    for sex, items in out.items():
        items.sort(key=lambda t: t[0])
        ages = [a for a, _ in items]
        start = ages[0]
        if ages != list(range(start, start + len(ages))):
            raise SystemExit(f"idades nao contiguas em {sex}: {start}..{ages[-1]}")
        result[sex] = {"start": start, "rows": [v for _, v in items]}
    return result


def segment(source, table, age_unit, data, measure=None):
    seg = {
        "source": source,
        "table": table,
        "ageUnit": age_unit,
        "start": data["male"]["start"],
        "end": data["male"]["start"] + len(data["male"]["rows"]) - 1,
        "male": data["male"]["rows"],
        "female": data["female"]["rows"],
    }
    if measure:
        seg["measure"] = measure
    return seg


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    folder = sys.argv[1]

    tables = {}
    digests = {}
    for name in ("weianthro", "lenanthro", "hcanthro", "bmianthro",
                 "wfawho2007", "hfawho2007", "bfawho2007"):
        tables[name], digests[name + ".txt"] = read_table(folder, name + ".txt")

    std = "who2006"
    ref = "who2007"
    indicators = {
        "weight_for_age": {
            "unit": "kg",
            "restricted": True,
            "segments": [
                segment(std, "weianthro", "day", by_sex(tables["weianthro"])),
                segment(ref, "wfawho2007", "month", by_sex(tables["wfawho2007"], hi=120)),
            ],
        },
        "length_height_for_age": {
            "unit": "cm",
            "restricted": False,
            "segments": [
                segment(std, "lenanthro", "day",
                        by_sex(tables["lenanthro"], hi=LAST_LENGTH_DAY, loh="L"), "length"),
                segment(std, "lenanthro", "day",
                        by_sex(tables["lenanthro"], lo=LAST_LENGTH_DAY + 1, loh="H"), "height"),
                segment(ref, "hfawho2007", "month",
                        by_sex(tables["hfawho2007"], hi=228), "height"),
            ],
        },
        "bmi_for_age": {
            "unit": "kg/m2",
            "restricted": True,
            "segments": [
                segment(std, "bmianthro", "day",
                        by_sex(tables["bmianthro"], hi=LAST_LENGTH_DAY, loh="L"), "length"),
                segment(std, "bmianthro", "day",
                        by_sex(tables["bmianthro"], lo=LAST_LENGTH_DAY + 1, loh="H"), "height"),
                segment(ref, "bfawho2007", "month",
                        by_sex(tables["bfawho2007"], hi=228), "height"),
            ],
        },
        "head_for_age": {
            "unit": "cm",
            "restricted": False,
            "segments": [
                segment(std, "hcanthro", "day", by_sex(tables["hcanthro"])),
            ],
        },
    }

    full = {
        "_fonte": "Organizacao Mundial da Saude. WHO Child Growth Standards (2006), "
                  "0 a 5 anos, e WHO Growth Reference (2007), 5 a 19 anos. Valores "
                  "LMS copiados sem alteracao dos arquivos oficiais.",
        "_origem": SOURCES,
        "_sha256": digests,
        "_versao": "oms-lms-oficial-1",
        "_formato": "segments[].male/female: lista [L, M, S] por idade inteira, "
                    "de start a end, na unidade ageUnit (day ou month).",
        "references": {
            "who2006": "OMS 2006 - Padroes de Crescimento (0 a 5 anos)",
            "who2007": "OMS 2007 - Referencia de Crescimento (5 a 19 anos)",
        },
        "indicators": indicators,
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    full_path = os.path.join(OUT_DIR, "who_growth_lms.json")
    with open(full_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(full, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")

    # Formato mensal contiguo do app real: mes 0..N, LMS amostrado no dia
    # arredondado (mes x 30,4375) dos Padroes 2006 e no proprio mes da
    # Referencia 2007 a partir de 61 meses. Comprimento ate 24 meses.
    def monthly(daily_parts, ref_rows, last_month, length_until_month=None):
        out = {}
        for sex in ("male", "female"):
            points = []
            for month in range(0, last_month + 1):
                if month <= 60:
                    day = int(math.floor(month * DAYS_PER_MONTH + 0.5))
                    if length_until_month is not None and month <= length_until_month:
                        day = min(day, LAST_LENGTH_DAY)
                    day = min(day, LAST_STANDARD_DAY)
                    lms = None
                    for part in daily_parts:
                        start = part[sex]["start"]
                        rows = part[sex]["rows"]
                        if start <= day < start + len(rows):
                            lms = rows[day - start]
                            break
                else:
                    start = ref_rows[sex]["start"]
                    lms = ref_rows[sex]["rows"][month - start]
                points.append({"mes": month, "L": lms[0], "M": lms[1], "S": lms[2]})
            out[sex] = points
        return out

    wfa_d = by_sex(tables["weianthro"])
    len_d = by_sex(tables["lenanthro"], hi=LAST_LENGTH_DAY, loh="L")
    hei_d = by_sex(tables["lenanthro"], lo=LAST_LENGTH_DAY + 1, loh="H")
    bmi_l = by_sex(tables["bmianthro"], hi=LAST_LENGTH_DAY, loh="L")
    bmi_h = by_sex(tables["bmianthro"], lo=LAST_LENGTH_DAY + 1, loh="H")
    hc_d = by_sex(tables["hcanthro"])

    legacy = {
        "_aviso": "Tabelas LMS oficiais da OMS (Padroes 2006 e Referencia 2007), "
                  "amostradas por mes. Comprimento ate 24 meses e altura depois. "
                  "Conferencia clinica pendente antes do uso em producao.",
        "_formato": "Cada indicador contem, por sexo, uma lista mensal com L, M e S.",
        "_versao": "oms-lms-oficial-1",
        "_origem": SOURCES,
        "indicadores": {
            "weight_for_age": monthly([wfa_d], by_sex(tables["wfawho2007"]), 120),
            "height_for_age": monthly([len_d, hei_d], by_sex(tables["hfawho2007"], hi=228),
                                      228, length_until_month=24),
            "bmi_for_age": monthly([bmi_l, bmi_h], by_sex(tables["bfawho2007"], hi=228),
                                   228, length_until_month=24),
            "head_for_age": monthly([hc_d], None, 60),
        },
    }
    legacy_path = os.path.join(OUT_DIR, "who_reference.json")
    with open(legacy_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(legacy, f, ensure_ascii=False, indent=1)
        f.write("\n")

    for p in (full_path, legacy_path):
        print(f"gerado: {os.path.relpath(p, ROOT)} ({os.path.getsize(p) / 1024:.1f} KB)")


if __name__ == "__main__":
    main()
