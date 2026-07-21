#!/usr/bin/env python3
"""Reproduce lib/presentation/widgets/crest_logo.dart como PNG (icono de la app)."""
import os
from PIL import Image, ImageDraw, ImageFont

TOP = (0xBD, 0xF7, 0xD3)   # #BDF7D3 (arriba del degradado)
BOT = (0x12, 0xA3, 0x55)   # #12A355 (abajo)
DARK = (10, 20, 14, 240)   # relleno del escudo 0xF00A140E
BG   = (10, 20, 14, 255)   # fondo del icono (opaco, iOS no admite alfa)
SS = 4                     # supersampling para antialias

def lerp(a, b, t): return a + (b - a) * t

def bez(p0, p1, p2, p3, n=80):
    out = []
    for i in range(n + 1):
        t = i / n; mt = 1 - t
        x = mt**3*p0[0] + 3*mt*mt*t*p1[0] + 3*mt*t*t*p2[0] + t**3*p3[0]
        y = mt**3*p0[1] + 3*mt*mt*t*p1[1] + 3*mt*t*t*p2[1] + t**3*p3[1]
        out.append((x, y))
    return out

def load_font(px):
    for path in [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
    ]:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except Exception:
                continue
    return ImageFont.load_default()

def char_w(font, ch):
    b = font.getbbox(ch)
    return b[2] - b[0]

def make_crest(H):
    """Dibuja el escudo con altura H px (diseno base 100x112)."""
    k = H / 112.0
    W = int(round(100 * k)); Hpx = int(round(H))
    def P(x, y): return (x * k, y * k)

    # Degradado vertical (rapido: columna 1px y luego resize).
    col = Image.new('RGB', (1, Hpx))
    cp = col.load()
    for yy in range(Hpx):
        t = yy / (Hpx - 1)
        cp[0, yy] = (int(lerp(TOP[0], BOT[0], t)),
                     int(lerp(TOP[1], BOT[1], t)),
                     int(lerp(TOP[2], BOT[2], t)))
    grad = col.resize((W, Hpx))

    base = Image.new('RGBA', (W, Hpx), (0, 0, 0, 0))
    bd = ImageDraw.Draw(base)

    # Contorno del escudo (con beziers aplanadas).
    b1 = bez(P(94, 57), P(94, 85), P(74, 102), P(50, 109))
    b2 = bez(P(50, 109), P(26, 102), P(6, 85), P(6, 57))
    shield = [P(50, 3), P(94, 19), P(94, 57)] + b1 + b2 + [P(6, 19)]
    bd.polygon(shield, fill=DARK)  # relleno oscuro

    # Mascara de todo lo que lleva degradado.
    mask = Image.new('L', (W, Hpx), 0)
    md = ImageDraw.Draw(mask)

    sw = max(1, int(round(3.5 * k)))
    md.line(shield + [shield[0]], fill=255, width=sw, joint='curve')

    cx, cy = P(50, 63); r = 23 * k
    lw = max(1, int(round(2.2 * k)))
    md.ellipse([cx - r, cy - r, cx + r, cy + r], outline=255, width=lw)

    def cap(pt):  # cabo redondo
        md.ellipse([pt[0]-lw/2, pt[1]-lw/2, pt[0]+lw/2, pt[1]+lw/2], fill=255)

    seams = [[50,49,50,40],[59.1,57.5,67.9,53.9],[55.6,69.5,61.6,77.6],
             [44.4,69.5,38.4,77.6],[40.9,57.5,32.1,53.9]]
    for l in seams:
        a, b = P(l[0], l[1]), P(l[2], l[3])
        md.line([a, b], fill=255, width=lw, joint='curve')
        cap(a); cap(b)

    pent = [P(50,55), P(57.6,60.5), P(54.7,69.5), P(45.3,69.5), P(42.4,60.5)]
    md.polygon(pent, fill=255)

    # Monograma UTM (con letter-spacing 2 y centrado en x=50).
    fpx = int(round(13 * k)); font = load_font(fpx); ls = 2 * k
    chars = list('UTM')
    widths = [char_w(font, c) for c in chars]
    total = sum(widths) + ls * len(chars)
    x = 50 * k - total / 2
    for c, w in zip(chars, widths):
        md.text((x, 14 * k), c, font=font, fill=255, anchor='lt')
        x += w + ls

    grad_rgba = grad.convert('RGBA'); grad_rgba.putalpha(mask)
    return Image.alpha_composite(base, grad_rgba)

def compose(canvas_px, crest_frac, bg):
    """Icono cuadrado con el escudo centrado."""
    crest_h = canvas_px * crest_frac
    crest = make_crest(crest_h * SS).resize(
        (int(round(crest_h * 100/112)), int(round(crest_h))), Image.LANCZOS)
    img = Image.new('RGBA', (canvas_px, canvas_px), bg)
    x = (canvas_px - crest.width) // 2
    y = (canvas_px - crest.height) // 2
    img.alpha_composite(crest, (x, y))
    return img

# Escribe directo en los assets del proyecto (scripts/ -> ../assets/icon).
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
os.makedirs(OUT, exist_ok=True)

# Icono principal: fondo oscuro opaco, escudo al 66%.
compose(1024, 0.66, BG).save(os.path.join(OUT, 'icon.png'))
# Foreground adaptativo Android: transparente, escudo al 55% (zona segura).
compose(1024, 0.55, (0, 0, 0, 0)).save(os.path.join(OUT, 'icon_foreground.png'))
# Vista previa grande solo del escudo sobre transparente.
make_crest(700 * SS).resize((625, 700), Image.LANCZOS).save(os.path.join(OUT, 'crest_only.png'))
print('OK ->', OUT)
