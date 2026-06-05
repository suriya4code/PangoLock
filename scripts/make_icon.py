#!/usr/bin/env python3
"""Build the macOS AppIcon set from the brand logo (logo_final.png).

Squares the logo on its cream background, insets it with the standard macOS
icon margin, and applies a rounded-rect mask so it matches the system icon
shape. Writes all required PNG sizes into the AppIcon.appiconset.

Usage: python3 scripts/make_icon.py [source_logo.png]
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "assets/logo.png")
ICONSET = os.path.join(ROOT, "Sources/Resources/Assets.xcassets/AppIcon.appiconset")
CREAM = (252, 245, 226, 255)

# macOS app-icon layout: artwork sits in a rounded rect inset from the tile.
TILE = 1024
INNER = 824                      # rounded-rect size within the 1024 tile
OFFSET = (TILE - INNER) // 2
RADIUS = round(INNER * 0.2235)   # Apple's "squircle"-ish corner radius

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m

def main():
    logo = Image.open(SRC).convert("RGBA")
    w, h = logo.size
    side = max(w, h)
    # Square the logo onto a cream canvas (no cropping of the artwork).
    square = Image.new("RGBA", (side, side), CREAM)
    square.alpha_composite(logo, ((side - w) // 2, (side - h) // 2))
    inner = square.resize((INNER, INNER), Image.LANCZOS)

    tile = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    tile.paste(inner, (OFFSET, OFFSET), rounded_mask(INNER, RADIUS))

    os.makedirs(ICONSET, exist_ok=True)
    for px in (16, 32, 64, 128, 256, 512, 1024):
        tile.resize((px, px), Image.LANCZOS).save(
            os.path.join(ICONSET, f"icon_{px}.png"))
        print(f"wrote icon_{px}.png")

if __name__ == "__main__":
    main()
