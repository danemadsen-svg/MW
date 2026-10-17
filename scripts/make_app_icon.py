#!/usr/bin/env python3
"""Draws the 1024x1024 app icon: a brass coat hanger on near-black.

Run from the repo root: python3 scripts/make_app_icon.py
Writes Wardrobe/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png.
Requires Pillow. The icon is opaque with no text, as the App Store requires.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4
BACKGROUND = (0x0E, 0x0E, 0x10)
BRASS = (0xC9, 0xA6, 0x6B)
OUTPUT = Path("Wardrobe/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")


def draw_icon() -> Image.Image:
    s = SIZE * SUPERSAMPLE
    image = Image.new("RGB", (s, s), BACKGROUND)
    draw = ImageDraw.Draw(image)

    def px(value: float) -> int:
        return round(value * s)

    stroke = px(0.045)

    # Hook: a curl that runs from its tip over the top and down into the neck.
    center = (0.50, 0.245)
    hook_radius = 0.07
    hook_box = [
        px(center[0] - hook_radius), px(center[1] - hook_radius),
        px(center[0] + hook_radius), px(center[1] + hook_radius),
    ]
    tip_angle = 165
    draw.arc(hook_box, start=tip_angle, end=450, fill=BRASS, width=stroke)
    tip = (
        px(center[0] + (hook_radius - 0.0225) * math.cos(math.radians(tip_angle))),
        px(center[1] + (hook_radius - 0.0225) * math.sin(math.radians(tip_angle))),
    )

    # Neck from the bottom of the curl down to the shoulders.
    neck_top = (px(0.50), px(center[1] + hook_radius - 0.0225))
    neck_bottom = (px(0.50), px(0.39))
    draw.line([neck_top, neck_bottom], fill=BRASS, width=stroke)

    # Shoulders and bar: a triangle with rounded joints.
    apex = (px(0.50), px(0.38))
    left = (px(0.16), px(0.68))
    right = (px(0.84), px(0.68))
    for start, end in ((apex, left), (apex, right), (left, right)):
        draw.line([start, end], fill=BRASS, width=stroke)
    radius = stroke // 2
    for x, y in (apex, left, right, neck_top, tip):
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=BRASS)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    draw_icon().save(OUTPUT, format="PNG", optimize=True)
    print(f"Wrote {OUTPUT}")


if __name__ == "__main__":
    main()
