#!/usr/bin/env python3
"""Fabrique les affiches de l'intro : l'affiche d'origine reste intacte au centre
et son décor est prolongé tout autour, de plus en plus flou, pour remplir
n'importe quel écran sans cadre. Les marges doivent rester égales à celles de
_introPoster (intro_widget.dart). Nécessite Pillow.
Lancement depuis la racine du projet : python3 tool/intro_posters.py
"""
import math

from PIL import Image, ImageFilter

CORE_WIDTH = 1080      # largeur de l'affiche dans le fichier final
MARGIN_X = 0.35        # marge de chaque côté, en largeurs d'affiche
MARGIN_Y = 0.60        # marge en haut et en bas, en largeurs d'affiche
SIGMAS = [2, 5, 10, 18, 30, 45, 65, 90]  # flou croissant avec la distance
RAMP = 0.20            # distance (en largeurs d'affiche) du flou maximal


def pad_edges(core, mx, my):
    """Prolonge les pixels du bord de l'affiche jusqu'aux limites du fichier."""
    w, h = core.size
    canvas = Image.new("RGB", (w + 2 * mx, h + 2 * my))
    box = lambda x0, y0, x1, y1: core.crop((x0, y0, x1, y1))
    canvas.paste(box(0, 0, w, 1).resize((w, my)), (mx, 0))
    canvas.paste(box(0, h - 1, w, h).resize((w, my)), (mx, my + h))
    canvas.paste(box(0, 0, 1, h).resize((mx, h)), (0, my))
    canvas.paste(box(w - 1, 0, w, h).resize((mx, h)), (mx + w, my))
    for x, cx in ((0, 0), (mx + w, w - 1)):
        for y, cy in ((0, 0), (my + h, h - 1)):
            canvas.paste(core.getpixel((cx, cy)), (x, y, x + mx, y + my))
    canvas.paste(core, (mx, my))
    return canvas


def level_mask(size, rect, width, level):
    """Masque d'un niveau de flou, selon la distance à l'affiche."""
    step = 8
    small = Image.new("L", (size[0] // step + 1, size[1] // step + 1))
    px = small.load()
    x0, y0, x1, y1 = rect
    for j in range(small.height):
        for i in range(small.width):
            x, y = i * step, j * step
            d = math.hypot(max(x0 - x, x - x1, 0), max(y0 - y, y - y1, 0))
            t = min(d / (RAMP * width), 1) ** 0.7 * len(SIGMAS)
            px[i, j] = round(255 * max(0.0, min(1.0, t - level)))
    return small.resize(size, Image.BILINEAR)


def extend(path, out):
    src = Image.open(path).convert("RGB")
    core = src.resize((CORE_WIDTH, round(src.height * CORE_WIDTH / src.width)),
                      Image.LANCZOS)
    w, h = core.size
    mx, my = round(MARGIN_X * w), round(MARGIN_Y * w)
    padded = pad_edges(core, mx, my)
    result = padded
    for level, sigma in enumerate(SIGMAS):
        blurred = padded.filter(ImageFilter.GaussianBlur(sigma))
        mask = level_mask(padded.size, (mx, my, mx + w, my + h), w, level)
        result = Image.composite(blurred, result, mask)
    result.paste(core, (mx, my))  # l'affiche reste strictement intacte
    result.save(out, quality=88, optimize=True, progressive=True)
    print(out, result.size, f"coeur {w}x{h} ratio {src.width / src.height:.4f}")


if __name__ == "__main__":
    for n in (1, 2, 3):
        extend(f"assets/images/image{n}.png",
               f"assets/images/intro_poster{n}.jpg")
