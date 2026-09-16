"""Gera os icones dimensionais dos cartoes de modulo da home.

## Onde estes icones entram — e onde nao entram

Apenas nos cartoes da home, que sao grandes (56px+) e voltados a familia.

Nas telas clinicas os icones continuam sendo Material Icons planos. Sao 138
icones vivendo a 16-24px dentro de listas densas: profundidade nesse tamanho
vira borrao, e o pediatra que varre uma lista de pacientes precisa de
reconhecimento instantaneo, nao de volume.

Regra que segue o resto do sistema de design: calor no que a familia ve,
sobriedade no que o profissional usa.

## Tecnica

Nao sao renderizacoes 3D. Sao SVG com gradiente diagonal, camada de luz no
topo, sombra projetada e deslocamento de plano — o suficiente para dar volume
sem depender de bitmap, que perderia nitidez em tela de alta densidade.

Uso: python3 tool/generate_module_icons.py
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons", "modules")
os.makedirs(OUT, exist_ok=True)

SIZE = 96

# Paleta do sistema. Cada modulo tem a cor que ja usa no app — o icone reforca
# a associacao em vez de introduzir uma linguagem nova.
MODULES = {
    "growth": ("#2E7D8A", "#4FA8B8", "curva de crescimento"),
    "vaccines": ("#0E6E52", "#2FA37D", "seringa"),
    "library": ("#7A3F8F", "#A96BBF", "livro aberto"),
    "ai": ("#1B5E86", "#4A9BC7", "faisca"),
    "courses": ("#A8501E", "#D98B4A", "play"),
    "shop": ("#9C2A54", "#D45C86", "sacola"),
    "telemedicine": ("#155E75", "#3FA3BF", "camera"),
    "gamification": ("#A67C00", "#E0B94A", "medalha"),
    "emr": ("#14676B", "#3E979B", "prontuario"),
    "tools": ("#4A5568", "#8595AB", "calculadora"),
    "agenda": ("#B36A00", "#F5A623", "calendario"),
    "development": ("#8A2F6E", "#C15FA0", "estrela de marco"),
    "exams": ("#0E6E82", "#22B8D6", "tubo de ensaio"),
    "medications": ("#5B3FA8", "#9B7FE0", "capsula"),
    "allergies": ("#A8241A", "#EF5A4C", "alerta"),
    "administration": ("#3D4552", "#6B7686", "engrenagem"),
}


def gradients(name, dark, light):
    """Gradiente do corpo, luz superior e sombra."""
    return f"""  <defs>
    <linearGradient id="body-{name}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{light}"/>
      <stop offset="100%" stop-color="{dark}"/>
    </linearGradient>
    <linearGradient id="gloss-{name}" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.32"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <filter id="drop-{name}" x="-30%" y="-20%" width="160%" height="160%">
      <feDropShadow dx="0" dy="4" stdDeviation="5"
                    flood-color="{dark}" flood-opacity="0.35"/>
    </filter>
  </defs>"""


def plate(name):
    """Placa de fundo com cantos arredondados — a base do volume."""
    return f"""  <rect x="10" y="8" width="76" height="76" rx="22"
        fill="url(#body-{name})" filter="url(#drop-{name})"/>
  <rect x="10" y="8" width="76" height="38" rx="22"
        fill="url(#gloss-{name})"/>"""


# ---------------------------------------------------------------- Simbolos
# Cada simbolo e desenhado em duas camadas: uma escura deslocada para baixo
# (a "espessura") e a clara por cima. E o que cria a leitura de relevo.

def symbol_growth():
    return """  <path d="M30 62 L44 48 L54 56 L68 38" stroke="#0B3A42"
        stroke-opacity="0.35" stroke-width="6" fill="none"
        stroke-linecap="round" stroke-linejoin="round"
        transform="translate(0,3)"/>
  <path d="M30 62 L44 48 L54 56 L68 38" stroke="#FFFFFF" stroke-width="6"
        fill="none" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="68" cy="38" r="6" fill="#0B3A42" fill-opacity="0.3"
          transform="translate(0,3)"/>
  <circle cx="68" cy="38" r="6" fill="#FFFFFF"/>"""


def symbol_vaccines():
    return """  <g transform="rotate(-45 48 46)">
    <rect x="44" y="24" width="8" height="30" rx="3" fill="#0B3A42"
          fill-opacity="0.3" transform="translate(0,3)"/>
    <rect x="44" y="24" width="8" height="30" rx="3" fill="#FFFFFF"/>
    <rect x="41" y="52" width="14" height="8" rx="2" fill="#FFFFFF"
          fill-opacity="0.85"/>
    <rect x="47" y="60" width="2" height="10" fill="#FFFFFF"/>
  </g>"""


def symbol_library():
    return """  <path d="M26 34 Q48 28 48 36 L48 66 Q48 58 26 64 Z" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <path d="M26 34 Q48 28 48 36 L48 66 Q48 58 26 64 Z" fill="#FFFFFF"/>
  <path d="M70 34 Q48 28 48 36 L48 66 Q48 58 70 64 Z" fill="#FFFFFF"
        fill-opacity="0.78"/>"""


def symbol_ai():
    return """  <path d="M48 26 L54 42 L70 48 L54 54 L48 70 L42 54 L26 48 L42 42 Z"
        fill="#0B3A42" fill-opacity="0.3" transform="translate(0,3)"/>
  <path d="M48 26 L54 42 L70 48 L54 54 L48 70 L42 54 L26 48 L42 42 Z"
        fill="#FFFFFF"/>"""


def symbol_courses():
    return """  <circle cx="48" cy="46" r="22" fill="#0B3A42" fill-opacity="0.28"
          transform="translate(0,3)"/>
  <circle cx="48" cy="46" r="22" fill="#FFFFFF" fill-opacity="0.22"/>
  <path d="M42 36 L62 46 L42 56 Z" fill="#0B3A42" fill-opacity="0.3"
        transform="translate(0,3)"/>
  <path d="M42 36 L62 46 L42 56 Z" fill="#FFFFFF"/>"""


def symbol_shop():
    return """  <path d="M30 40 L66 40 L62 68 L34 68 Z" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <path d="M30 40 L66 40 L62 68 L34 68 Z" fill="#FFFFFF"/>
  <path d="M40 40 Q40 28 48 28 Q56 28 56 40" stroke="#FFFFFF"
        stroke-width="5" fill="none" stroke-linecap="round"/>"""


def symbol_telemedicine():
    return """  <rect x="26" y="34" width="34" height="26" rx="6" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <rect x="26" y="34" width="34" height="26" rx="6" fill="#FFFFFF"/>
  <path d="M62 42 L74 34 L74 60 L62 52 Z" fill="#FFFFFF"
        fill-opacity="0.8"/>"""


def symbol_gamification():
    return """  <circle cx="48" cy="42" r="16" fill="#0B3A42" fill-opacity="0.3"
          transform="translate(0,3)"/>
  <circle cx="48" cy="42" r="16" fill="#FFFFFF"/>
  <path d="M40 56 L36 74 L48 68 L60 74 L56 56 Z" fill="#FFFFFF"
        fill-opacity="0.82"/>
  <path d="M48 34 L51 40 L57 41 L52 45 L54 51 L48 48 L42 51 L44 45
           L39 41 L45 40 Z" fill="#E0B94A"/>"""


def symbol_emr():
    return """  <rect x="30" y="26" width="36" height="46" rx="5" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <rect x="30" y="26" width="36" height="46" rx="5" fill="#FFFFFF"/>
  <rect x="38" y="20" width="20" height="12" rx="3" fill="#FFFFFF"
        fill-opacity="0.85"/>
  <path d="M48 42 L48 58 M40 50 L56 50" stroke="#14676B" stroke-width="5"
        stroke-linecap="round"/>"""


def symbol_tools():
    return """  <rect x="30" y="26" width="36" height="46" rx="6" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <rect x="30" y="26" width="36" height="46" rx="6" fill="#FFFFFF"/>
  <rect x="36" y="32" width="24" height="10" rx="2" fill="#4A5568"
        fill-opacity="0.35"/>
  <circle cx="40" cy="52" r="3.5" fill="#4A5568" fill-opacity="0.6"/>
  <circle cx="52" cy="52" r="3.5" fill="#4A5568" fill-opacity="0.6"/>
  <circle cx="40" cy="63" r="3.5" fill="#4A5568" fill-opacity="0.6"/>
  <circle cx="52" cy="63" r="3.5" fill="#4A5568" fill-opacity="0.6"/>"""


def symbol_agenda():
    return """  <rect x="27" y="32" width="42" height="36" rx="6" fill="#0B3A42"
        fill-opacity="0.3" transform="translate(0,3)"/>
  <rect x="27" y="32" width="42" height="36" rx="6" fill="#FFFFFF"/>
  <rect x="34" y="26" width="4" height="10" rx="2" fill="#FFFFFF"/>
  <rect x="58" y="26" width="4" height="10" rx="2" fill="#FFFFFF"/>
  <rect x="27" y="32" width="42" height="10" rx="4" fill="#B36A00"
        fill-opacity="0.55"/>
  <circle cx="48" cy="55" r="6" fill="#B36A00" fill-opacity="0.55"/>"""


def symbol_development():
    # Estrela de 5 pontas gerada matematicamente (centro 48,48, raio externo
    # 22, raio interno 9) — coordenada estimada a olho sai assimetrica.
    return """  <path d="M 48.0 26.0 L 53.3 40.7 L 68.9 41.2 L 56.6 50.8 L 60.9 65.8
           L 48.0 57.0 L 35.1 65.8 L 39.4 50.8 L 27.1 41.2 L 42.7 40.7 Z"
        fill="#0B3A42" fill-opacity="0.3" transform="translate(0,3)"/>
  <path d="M 48.0 26.0 L 53.3 40.7 L 68.9 41.2 L 56.6 50.8 L 60.9 65.8
           L 48.0 57.0 L 35.1 65.8 L 39.4 50.8 L 27.1 41.2 L 42.7 40.7 Z"
        fill="#FFFFFF"/>"""


def symbol_exams():
    return """  <g transform="rotate(-20 48 48)">
    <path d="M40 24 L40 52 A8 8 0 0 0 56 52 L56 24 Z" fill="#0B3A42"
          fill-opacity="0.3" transform="translate(0,3)"/>
    <path d="M40 24 L40 52 A8 8 0 0 0 56 52 L56 24 Z" fill="#FFFFFF"/>
    <path d="M40 42 L40 52 A8 8 0 0 0 56 52 L56 42 Z" fill="#0E6E82"
          fill-opacity="0.55"/>
    <rect x="37" y="20" width="22" height="6" rx="3" fill="#FFFFFF"/>
  </g>"""


def symbol_medications():
    return """  <g transform="rotate(-45 48 48)">
    <rect x="28" y="38" width="40" height="20" rx="10" fill="#0B3A42"
          fill-opacity="0.3" transform="translate(0,3)"/>
    <rect x="28" y="38" width="40" height="20" rx="10" fill="#FFFFFF"/>
    <path d="M48 38 L58 38 A10 10 0 0 1 58 58 L48 58 Z" fill="#5B3FA8"
          fill-opacity="0.55"/>
  </g>"""


def symbol_allergies():
    return """  <path d="M48 26 L72 66 L24 66 Z" fill="none" stroke="#0B3A42"
        stroke-opacity="0.3" stroke-width="6" stroke-linejoin="round"
        transform="translate(0,3)"/>
  <path d="M48 26 L72 66 L24 66 Z" fill="none" stroke="#FFFFFF"
        stroke-width="6" stroke-linejoin="round"/>
  <rect x="45" y="42" width="6" height="14" rx="3" fill="#FFFFFF"/>
  <circle cx="48" cy="60" r="3.5" fill="#FFFFFF"/>"""


def symbol_administration():
    # dasharray 6.28/6.28 fecha em exatamente 8 dentes (circunferencia do
    # raio 16 dividida por 16 segmentos iguais) — nao e valor estimado.
    return """  <circle cx="48" cy="46" r="16" fill="none" stroke="#0B3A42"
          stroke-opacity="0.3" stroke-width="8" stroke-dasharray="6.28 6.28"
          transform="translate(0,3)"/>
  <circle cx="48" cy="46" r="16" fill="none" stroke="#FFFFFF"
          stroke-width="8" stroke-dasharray="6.28 6.28"/>
  <circle cx="48" cy="46" r="7" fill="#3D4552"/>"""


SYMBOLS = {
    "growth": symbol_growth,
    "vaccines": symbol_vaccines,
    "library": symbol_library,
    "ai": symbol_ai,
    "courses": symbol_courses,
    "shop": symbol_shop,
    "telemedicine": symbol_telemedicine,
    "gamification": symbol_gamification,
    "emr": symbol_emr,
    "tools": symbol_tools,
    "agenda": symbol_agenda,
    "development": symbol_development,
    "exams": symbol_exams,
    "medications": symbol_medications,
    "allergies": symbol_allergies,
    "administration": symbol_administration,
}


def build(name, dark, light):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}"
     width="{SIZE}" height="{SIZE}" role="img" aria-label="{name}">
{gradients(name, dark, light)}
{plate(name)}
{SYMBOLS[name]()}
</svg>
"""


written = []
for name, (dark, light, description) in MODULES.items():
    path = os.path.join(OUT, f"{name}.svg")
    with open(path, "w", encoding="utf-8") as f:
        f.write(build(name, dark, light))
    written.append((name, description, os.path.getsize(path)))

print(f"{len(written)} icones gerados em assets/icons/modules/\n")
for name, description, size in written:
    print(f"  {name:14} {description:22} {size:>5} bytes")

total = sum(s for _, _, s in written)
print(f"\n  total: {total / 1024:.1f} KB")
print("\nSVG em vez de bitmap: mantem nitidez em tela de alta densidade e")
print("pesa menos que um unico PNG @3x do mesmo conjunto.")
