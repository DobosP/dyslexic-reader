#!/usr/bin/env python3
"""Generate the Dyslexic Reader launcher icon set + Play Store assets.

Design: a calm teal card (a "reading surface") with text lines, the focus line
highlighted by an amber "reading ruler" band — the app's signature feature.

Pure **Pillow** (no cairosvg/cairo): shapes are drawn directly and supersampled
for crisp edges; the feature-graphic wordmark uses a bundled app font. Produces
legacy square + round mipmaps, adaptive foreground PNGs, an Android-13 monochrome
layer, the 512px Play Store icon, a 1024x500 feature graphic, and the in-app
branding asset.

Setup (once):  python3 -m pip install --user Pillow
Re-run:        python3 tool/generate_icons.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "docs", "store")
FONTS = os.path.join(ROOT, "assets", "fonts")

# --- Palette ---------------------------------------------------------------
TEAL_TOP = (28, 140, 130)    # #1C8C82
TEAL_BOT = (14, 95, 88)      # #0E5F58
BG_SOLID = (19, 113, 106)    # #13716A (adaptive background)
CARD = (251, 244, 230)       # #FBF4E6 cream reading surface
TEXT = (124, 106, 85)        # #7C6A55 ordinary line
TEXT_FOCUS = (58, 46, 34)    # #3A2E22 focused line
AMBER = (244, 169, 60)       # #F4A93C reading-ruler band

C = 512.0   # design centre (1024 box)
SS = 4      # supersample factor for crisp edges


def shapes(scale):
    """Geometry (card, band, lines) in 1024-design space, scaled about centre."""
    card_w, card_h, r = 600.0, 680.0, 64.0
    x0, y0 = C - card_w / 2, C - card_h / 2
    pad, line_h, line_r = 70.0, 46.0, 23.0
    first_y, gap = y0 + 96.0, 108.0
    lengths = [380.0, 412.0, 300.0, 412.0, 250.0]
    focus = 1

    def sc(x, y, w, h, rad):
        return {
            "x": C + (x - C) * scale, "y": C + (y - C) * scale,
            "w": w * scale, "h": h * scale, "r": rad * scale,
        }

    card = sc(x0, y0, card_w, card_h, r)
    fy = first_y + focus * gap
    band_h = 86.0
    band = sc(x0 + 34, fy + line_h / 2 - band_h / 2, card_w - 68, band_h, band_h / 2)
    lines = []
    for i, ln in enumerate(lengths):
        s = sc(x0 + pad, first_y + i * gap, ln, line_h, line_r)
        s["focus"] = i == focus
        lines.append(s)
    return card, band, lines


def _rr(draw, s, fill, k):
    """Draw a scaled rounded rect (s in design space, k = px-per-design-unit)."""
    draw.rounded_rectangle(
        [s["x"] * k, s["y"] * k, (s["x"] + s["w"]) * k, (s["y"] + s["h"]) * k],
        radius=max(1.0, s["r"] * k), fill=fill,
    )


def _gradient(size):
    """Vertical teal gradient, RGB, size x size."""
    col = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        col.putpixel((0, y), tuple(
            round(TEAL_TOP[i] + (TEAL_BOT[i] - TEAL_TOP[i]) * t) for i in range(3)))
    return col.resize((size, size))


def _motif(scale, size):
    """Transparent RGBA layer of size x size with the card/lines/band motif."""
    big = size * SS
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    k = big / 1024.0
    card, band, lines = shapes(scale)
    _rr(d, card, CARD + (255,), k)
    _rr(d, band, AMBER + (255,), k)
    for s in lines:
        _rr(d, s, (TEXT_FOCUS if s["focus"] else TEXT) + (255,), k)
    return layer.resize((size, size), Image.LANCZOS)


def base_icon(size):
    """Full-bleed gradient + motif (legacy/round/store/branding)."""
    img = _gradient(size).convert("RGBA")
    img.alpha_composite(_motif(0.92, size))
    return img


def foreground(size):
    """Transparent + motif at the adaptive safe-zone scale."""
    return _motif(0.88, size)


def monochrome(size):
    """White card silhouette with the lines + band knocked out (themed icon)."""
    big = size * SS
    alpha = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(alpha)
    k = big / 1024.0
    card, band, lines = shapes(0.88)
    _rr(d, card, 255, k)          # card visible
    _rr(d, band, 0, k)            # punch the focus band (encloses the focus line)
    for s in lines:
        if not s["focus"]:
            _rr(d, s, 0, k)       # punch ordinary lines
    alpha = alpha.resize((size, size), Image.LANCZOS)
    white = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    white.putalpha(alpha)
    return white


def _mask(size, kind):
    big = size * SS
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    if kind == "round":
        d.ellipse([0, 0, big - 1, big - 1], fill=255)
    else:
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def _font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def feature_graphic():
    """1024x500 Play feature graphic: icon + wordmark + tagline on teal."""
    h = 500 * 2
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(
            round(TEAL_TOP[i] + (TEAL_BOT[i] - TEAL_TOP[i]) * t) for i in range(3)))
    img = col.resize((1024 * 2, h)).convert("RGBA")

    icon = base_icon(300 * 2)
    icon.putalpha(_mask(300 * 2, "square"))
    img.alpha_composite(icon, (60 * 2, 100 * 2))

    d = ImageDraw.Draw(img)
    title = _font("AtkinsonHyperlegible-Bold.ttf", 96 * 2)
    x = 470 * 2
    d.text((x, 150 * 2), "Dyslexic", font=title, fill=CARD)
    d.text((x, 248 * 2), "Reader", font=title, fill=AMBER)

    # Tagline: shrink to fit the remaining width (keeps it from clipping).
    tagline = "Free, private, on-device reading"
    avail = 1024 * 2 - x - 40 * 2
    for pt in range(34, 20, -1):
        tag = _font("AtkinsonHyperlegible-Regular.ttf", pt * 2)
        if d.textlength(tagline, font=tag) <= avail:
            break
    d.text((x, 384 * 2), tagline, font=tag, fill=CARD)
    return img.convert("RGB").resize((1024, 500), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def main():
    for bucket, size in LEGACY.items():
        sq = base_icon(size)
        sq.putalpha(_mask(size, "square"))
        save(sq, os.path.join(RES, f"mipmap-{bucket}", "ic_launcher.png"))
        rnd = base_icon(size)
        rnd.putalpha(_mask(size, "round"))
        save(rnd, os.path.join(RES, f"mipmap-{bucket}", "ic_launcher_round.png"))

    for bucket, size in ADAPTIVE.items():
        save(foreground(size),
             os.path.join(RES, f"mipmap-{bucket}", "ic_launcher_foreground.png"))
        save(monochrome(size),
             os.path.join(RES, f"mipmap-{bucket}", "ic_launcher_monochrome.png"))

    save(base_icon(512).convert("RGB"), os.path.join(STORE, "play_icon_512.png"))
    save(feature_graphic(), os.path.join(STORE, "feature_graphic_1024x500.png"))
    save(base_icon(256), os.path.join(ROOT, "assets", "branding", "app_icon.png"))


if __name__ == "__main__":
    main()
