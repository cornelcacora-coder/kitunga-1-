#!/usr/bin/env python3
"""Version blanche du logo, pour l'afficher directement sur un fond rouge
(page de connexion administrateur). Le logo d'origine n'est pas modifié.
Lancement depuis la racine du projet : python3 tool/logo_white.py
"""
from PIL import Image

src = Image.open("assets/logo/kitunga_logo.png").convert("RGBA")
out = Image.new("RGBA", src.size)
pixels, result = src.load(), out.load()
for y in range(src.height):
    for x in range(src.width):
        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        # Panier, K et texte en blanc ; ailes grises en blanc transparent.
        is_grey = not r > g + 60 and max(r, g, b) > 95
        result[x, y] = (255, 255, 255, int(a * (0.55 if is_grey else 1.0)))
out.save("assets/logo/kitunga_logo_white.png", optimize=True)
print("assets/logo/kitunga_logo_white.png", out.size)
