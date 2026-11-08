# SPDX-License-Identifier: AGPL-3.0-or-later
"""Génère les icônes de l'application installable (PWA). Usage : python scripts/generer-icones.py"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "app" / "static" / "icons"
BG, FG = (47, 93, 80), (255, 255, 255)  # vert sapin / blanc


def draw(size: int, maskable: bool) -> Image.Image:
    s = 4
    S = size * s
    im = Image.new("RGB" if maskable else "RGBA", (S, S), BG if maskable else (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if not maskable:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=BG)
    pad = S * (0.25 if maskable else 0.2)
    w = S - 2 * pad
    # bouton lecture
    x0, y0 = pad, pad + w * 0.08
    d.polygon([(x0, y0), (x0, y0 + w * 0.5), (x0 + w * 0.42, y0 + w * 0.25)], fill=FG)
    # étapes (lignes de texte)
    lw = int(w * 0.075)
    for i, length in enumerate((1.0, 0.8, 0.9)):
        y = pad + w * (0.70 + i * 0.13) - w * 0.1
        d.rounded_rectangle([pad, y, pad + w * length, y + lw], radius=lw // 2, fill=FG)
    # coche « pas à pas »
    cx, cy = pad + w * 0.62, pad + w * 0.12
    d.line([(cx, cy + w * 0.17), (cx + w * 0.1, cy + w * 0.27), (cx + w * 0.34, cy)], fill=FG, width=lw, joint="curve")
    return im.resize((size, size), Image.Resampling.LANCZOS)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (192, 512):
        draw(size, False).save(OUT / f"icon-{size}.png", optimize=True)
    draw(512, True).save(OUT / "icon-maskable-512.png", optimize=True)
    draw(180, True).save(OUT / "apple-touch-icon.png", optimize=True)
    draw(32, False).save(OUT / "favicon-32.png", optimize=True)
    print("Icônes générées dans", OUT)
