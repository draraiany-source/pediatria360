"""Gera todos os assets do Pediatria 360.

SVG e Lottie sao escritos como texto (formato aberto). Os PNG (logo, splash,
mascote, placeholders, banners) sao desenhados com Pillow a partir da paleta do
app, para que nenhuma referencia do pubspec fique quebrada.
"""

from PIL import Image, ImageDraw, ImageFont
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMAGES = os.path.join(ROOT, "assets", "images")
ICONS = os.path.join(ROOT, "assets", "icons")
LOTTIE = os.path.join(ROOT, "assets", "lottie")

for d in (IMAGES, ICONS, LOTTIE):
    os.makedirs(d, exist_ok=True)

PETROL = (20, 103, 107)
PETROL_DEEP = (11, 61, 64)
PETROL_SOFT = (62, 151, 155)
RASPBERRY = (232, 85, 109)
HONEY = (242, 183, 5)
LIGHT = (244, 247, 247)
WHITE = (255, 255, 255)
INK = (11, 31, 36)

# ----------------------------------------------------------------- SVG icons

SVGS = {
    # Marca: um "360" que tambem e a curva de crescimento fechando um circulo.
    "logo.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="none">
  <circle cx="32" cy="32" r="28" stroke="#14676B" stroke-width="4"/>
  <path d="M14 42C20 42 22 22 32 22C42 22 44 34 50 34" stroke="#E8556D" stroke-width="4" stroke-linecap="round"/>
  <circle cx="32" cy="22" r="4" fill="#F2B705"/>
</svg>""",
    "ai.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <rect x="4" y="6" width="16" height="12" rx="4" stroke="currentColor" stroke-width="1.8"/>
  <circle cx="9.5" cy="12" r="1.4" fill="currentColor"/>
  <circle cx="14.5" cy="12" r="1.4" fill="currentColor"/>
  <path d="M12 6V3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <circle cx="12" cy="2.5" r="1.2" fill="currentColor"/>
</svg>""",
    "growth.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <path d="M3 21V3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M3 21H21" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M6 17C9 17 10 8 14 8C17 8 18 12 21 12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>""",
    "vaccine.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <path d="M14 4L20 10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M17 7L7.5 16.5L4 20L7.5 16.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M11 10L14 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M8.5 12.5L11.5 15.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
  <path d="M4 20L3 21" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>""",
    "library.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <path d="M4 5C4 4 4.8 3.5 6 3.5H11V20H6C4.8 20 4 20.5 4 21V5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M20 5C20 4 19.2 3.5 18 3.5H13V20H18C19.2 20 20 20.5 20 21V5Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
</svg>""",
    "nutrition.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <path d="M12 21C8 21 5 17.5 5 13C5 9.5 7.5 7 12 7C16.5 7 19 9.5 19 13C19 17.5 16 21 12 21Z" stroke="currentColor" stroke-width="1.8"/>
  <path d="M12 7C12 5 13 3 15.5 2.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>""",
    "first_aid.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <rect x="3" y="7" width="18" height="13" rx="3" stroke="currentColor" stroke-width="1.8"/>
  <path d="M9 7V5C9 4 9.5 3.5 10.5 3.5H13.5C14.5 3.5 15 4 15 5V7" stroke="currentColor" stroke-width="1.8"/>
  <path d="M12 11V16M9.5 13.5H14.5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>""",
    "telemedicine.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <rect x="2.5" y="6" width="13" height="12" rx="3" stroke="currentColor" stroke-width="1.8"/>
  <path d="M15.5 11L21.5 7.5V16.5L15.5 13V11Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
</svg>""",
    "shop.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <path d="M4 7H20L18.5 19C18.4 20 17.6 20.5 16.6 20.5H7.4C6.4 20.5 5.6 20 5.5 19L4 7Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
  <path d="M8.5 10V6.5C8.5 4.8 10 3.5 12 3.5C14 3.5 15.5 4.8 15.5 6.5V10" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
</svg>""",
    "badge.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none">
  <circle cx="12" cy="9" r="6" stroke="currentColor" stroke-width="1.8"/>
  <path d="M8.5 14L7 21L12 18.5L17 21L15.5 14" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/>
</svg>""",
    "google.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path fill="#4285F4" d="M23 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.2a5.3 5.3 0 0 1-2.3 3.5v2.9h3.7c2.2-2 3.4-5 3.4-8.6z"/>
  <path fill="#34A853" d="M12 23.5c3.1 0 5.7-1 7.6-2.8l-3.7-2.9c-1 .7-2.3 1.1-3.9 1.1-3 0-5.6-2-6.5-4.8H1.7v3A11.5 11.5 0 0 0 12 23.5z"/>
  <path fill="#FBBC05" d="M5.5 14.1a6.9 6.9 0 0 1 0-4.4v-3H1.7a11.5 11.5 0 0 0 0 10.4l3.8-3z"/>
  <path fill="#EA4335" d="M12 5.4c1.7 0 3.2.6 4.4 1.7l3.3-3.3A11.5 11.5 0 0 0 1.7 6.7l3.8 3c.9-2.8 3.5-4.8 6.5-4.8z"/>
</svg>""",
    "empty_children.svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" fill="none">
  <circle cx="60" cy="60" r="52" fill="#E9F1F1"/>
  <circle cx="60" cy="48" r="18" stroke="#14676B" stroke-width="3"/>
  <path d="M30 92C30 78 43 70 60 70C77 70 90 78 90 92" stroke="#14676B" stroke-width="3" stroke-linecap="round"/>
  <path d="M84 34L84 46M78 40H90" stroke="#E8556D" stroke-width="3" stroke-linecap="round"/>
</svg>""",
}

for name, content in SVGS.items():
    with open(os.path.join(ICONS, name), "w", encoding="utf-8") as f:
        f.write(content)

# ---------------------------------------------------------------- Lottie

def pulse_lottie(name, color, width=200, height=200):
    """Animacao de pulso: um circulo que respira. Usada em carregamento e vazio."""
    r, g, b = [c / 255 for c in color]
    return {
        "v": "5.7.4",
        "fr": 60,
        "ip": 0,
        "op": 90,
        "w": width,
        "h": height,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": [
            {
                "ddd": 0,
                "ind": 1,
                "ty": 4,
                "nm": "pulse",
                "sr": 1,
                "ks": {
                    "o": {
                        "a": 1,
                        "k": [
                            {"t": 0, "s": [100], "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                            {"t": 45, "s": [40], "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                            {"t": 90, "s": [100]},
                        ],
                    },
                    "r": {"a": 0, "k": 0},
                    "p": {"a": 0, "k": [width / 2, height / 2, 0]},
                    "a": {"a": 0, "k": [0, 0, 0]},
                    "s": {
                        "a": 1,
                        "k": [
                            {"t": 0, "s": [70, 70, 100], "i": {"x": [0.4, 0.4, 0.4], "y": [1, 1, 1]}, "o": {"x": [0.6, 0.6, 0.6], "y": [0, 0, 0]}},
                            {"t": 45, "s": [110, 110, 100], "i": {"x": [0.4, 0.4, 0.4], "y": [1, 1, 1]}, "o": {"x": [0.6, 0.6, 0.6], "y": [0, 0, 0]}},
                            {"t": 90, "s": [70, 70, 100]},
                        ],
                    },
                },
                "ao": 0,
                "shapes": [
                    {
                        "ty": "gr",
                        "nm": "circle",
                        "it": [
                            {"ty": "el", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [90, 90]}, "nm": "e"},
                            {"ty": "fl", "c": {"a": 0, "k": [r, g, b, 1]}, "o": {"a": 0, "k": 100}, "nm": "f"},
                            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}},
                        ],
                    }
                ],
                "ip": 0,
                "op": 90,
                "st": 0,
                "bm": 0,
            }
        ],
        "markers": [],
    }


def spinner_lottie(name, color, width=200, height=200):
    """Arco que gira — carregamento."""
    r, g, b = [c / 255 for c in color]
    return {
        "v": "5.7.4",
        "fr": 60,
        "ip": 0,
        "op": 60,
        "w": width,
        "h": height,
        "nm": name,
        "ddd": 0,
        "assets": [],
        "layers": [
            {
                "ddd": 0,
                "ind": 1,
                "ty": 4,
                "nm": "arc",
                "sr": 1,
                "ks": {
                    "o": {"a": 0, "k": 100},
                    "r": {
                        "a": 1,
                        "k": [
                            {"t": 0, "s": [0], "i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}},
                            {"t": 60, "s": [360]},
                        ],
                    },
                    "p": {"a": 0, "k": [width / 2, height / 2, 0]},
                    "a": {"a": 0, "k": [0, 0, 0]},
                    "s": {"a": 0, "k": [100, 100, 100]},
                },
                "ao": 0,
                "shapes": [
                    {
                        "ty": "gr",
                        "nm": "g",
                        "it": [
                            {"ty": "el", "p": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [110, 110]}, "nm": "e"},
                            {"ty": "st", "c": {"a": 0, "k": [r, g, b, 1]}, "o": {"a": 0, "k": 100}, "w": {"a": 0, "k": 10}, "lc": 2, "lj": 1, "nm": "s"},
                            {"ty": "tm", "s": {"a": 0, "k": 0}, "e": {"a": 0, "k": 28}, "o": {"a": 0, "k": 0}, "m": 1, "nm": "trim"},
                            {"ty": "tr", "p": {"a": 0, "k": [0, 0]}, "a": {"a": 0, "k": [0, 0]}, "s": {"a": 0, "k": [100, 100]}, "r": {"a": 0, "k": 0}, "o": {"a": 0, "k": 100}},
                        ],
                    }
                ],
                "ip": 0,
                "op": 60,
                "st": 0,
                "bm": 0,
            }
        ],
        "markers": [],
    }


LOTTIES = {
    "loading.json": spinner_lottie("loading", PETROL),
    "success.json": pulse_lottie("success", (30, 158, 106)),
    "empty.json": pulse_lottie("empty", PETROL_SOFT),
    "heartbeat.json": pulse_lottie("heartbeat", RASPBERRY),
    "confetti.json": pulse_lottie("confetti", HONEY),
    "ai_thinking.json": spinner_lottie("ai_thinking", PETROL_SOFT),
}

for name, data in LOTTIES.items():
    with open(os.path.join(LOTTIE, name), "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))


# ------------------------------------------------------------------- PNG

def font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    ):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def vertical_gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        draw.line(
            [(0, y), (w, y)],
            fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return img


def mark(draw, cx, cy, r, ring=PETROL, curve=RASPBERRY, dot=HONEY, width=None):
    """Desenha a marca: circulo + curva de crescimento + ponto."""
    w = width or max(3, r // 8)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ring, width=w)
    pts = []
    for i in range(41):
        t = i / 40
        x = cx - r * 0.62 + t * r * 1.24
        y = cy + r * 0.34 - (r * 0.72) * (t ** 1.7)
        pts.append((x, y))
    draw.line(pts, fill=curve, width=w, joint="curve")
    dr = max(3, r // 7)
    px, py = pts[-1]
    draw.ellipse([px - dr, py - dr, px + dr, py + dr], fill=dot)


# Logo (transparente)
logo = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
mark(ImageDraw.Draw(logo), 256, 256, 200)
logo.save(os.path.join(IMAGES, "logo.png"))

# Logo monocromatico claro (para fundo escuro)
logo_light = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
mark(ImageDraw.Draw(logo_light), 256, 256, 200, ring=WHITE, curve=(246, 165, 178), dot=HONEY)
logo_light.save(os.path.join(IMAGES, "logo_light.png"))

# Splash (fundo claro e escuro)
for suffix, top, bottom, ring in (
    ("", (233, 241, 241), (247, 250, 250), PETROL),
    ("_dark", (11, 36, 41), (7, 23, 27), PETROL_SOFT),
):
    splash = vertical_gradient((1080, 1920), top, bottom).convert("RGBA")
    d = ImageDraw.Draw(splash)
    mark(d, 540, 860, 190, ring=ring)
    label = "PEDIATRIA 360"
    f = font(48)
    bbox = d.textbbox((0, 0), label, font=f)
    d.text(
        ((1080 - (bbox[2] - bbox[0])) / 2, 1130),
        label,
        font=f,
        fill=ring,
    )
    splash.convert("RGB").save(os.path.join(IMAGES, f"splash{suffix}.png"))

# Icone do app (Android/iOS)
icon = vertical_gradient((1024, 1024), PETROL_DEEP, PETROL).convert("RGBA")
mark(ImageDraw.Draw(icon), 512, 512, 340, ring=WHITE, curve=(246, 165, 178), dot=HONEY, width=44)
icon.convert("RGB").save(os.path.join(IMAGES, "app_icon.png"))

# Avatar padrao
avatar = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
ad = ImageDraw.Draw(avatar)
ad.ellipse([0, 0, 256, 256], fill=(233, 241, 241, 255))
ad.ellipse([88, 62, 168, 142], fill=PETROL_SOFT)
ad.pieslice([48, 140, 208, 300], 180, 360, fill=PETROL_SOFT)
avatar.save(os.path.join(IMAGES, "avatar_placeholder.png"))

# Placeholder de midia (16:9) — usado enquanto a capa do video carrega
ph = vertical_gradient((640, 360), (233, 241, 241), (214, 230, 230)).convert("RGBA")
pd = ImageDraw.Draw(ph)
mark(pd, 320, 180, 56, width=6)
ph.convert("RGB").save(os.path.join(IMAGES, "media_placeholder.png"))

# Placeholder de produto (1:1)
prod = Image.new("RGB", (512, 512), (233, 241, 241))
pdd = ImageDraw.Draw(prod)
mark(pdd, 256, 256, 96, width=8)
prod.save(os.path.join(IMAGES, "product_placeholder.png"))

# Banners de onboarding (3 telas)
onboarding = [
    ("Acompanhe cada fase", PETROL_DEEP, PETROL),
    ("Respostas com base clinica", (90, 38, 50), RASPBERRY),
    ("Nunca perca uma vacina", (92, 71, 8), HONEY),
]
for i, (title, top, bottom) in enumerate(onboarding, start=1):
    banner = vertical_gradient((900, 900), top, bottom).convert("RGBA")
    bd = ImageDraw.Draw(banner)
    mark(bd, 450, 400, 190, ring=WHITE, curve=(255, 255, 255), dot=WHITE, width=14)
    f = font(44)
    bbox = bd.textbbox((0, 0), title, font=f)
    bd.text(((900 - (bbox[2] - bbox[0])) / 2, 660), title, font=f, fill=WHITE)
    banner.convert("RGB").save(os.path.join(IMAGES, f"onboarding_{i}.png"))

# Textura sutil para o fundo ambiente (ruido leve evita banding no gradiente)
import random

random.seed(360)
noise = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
np_draw = ImageDraw.Draw(noise)
for _ in range(3000):
    x = random.randint(0, 255)
    y = random.randint(0, 255)
    a = random.randint(2, 8)
    np_draw.point((x, y), fill=(255, 255, 255, a))
noise.save(os.path.join(IMAGES, "noise.png"))

print("assets gerados:")
for d in (IMAGES, ICONS, LOTTIE):
    print(" ", os.path.relpath(d, ROOT), "->", len(os.listdir(d)), "arquivos")
