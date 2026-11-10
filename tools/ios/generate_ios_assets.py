#!/usr/bin/env python3
"""Generate the iOS app icon and launch image from the Android Hermes artwork.

The Android project is the source of truth for branding (adaptive icon layers
and splash mark). Re-run this after upstream changes the Android artwork:

    uv run --with pillow tools/ios/generate_ios_assets.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android/app/src/main/res"
ICONSET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
LAUNCH = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"


def master_icon() -> Image.Image:
    bg = Image.open(RES / "drawable-xxxhdpi/hermes_launcher_background.png").convert("RGBA")
    fg = Image.open(RES / "drawable-xxxhdpi/hermes_launcher_foreground.png").convert("RGBA")
    comp = Image.alpha_composite(bg, fg)
    # Adaptive icons draw on a 108dp canvas and show the central 72dp; iOS
    # icons are full-bleed squares, so keep exactly that visible window.
    side = comp.width * 72 // 108
    off = (comp.width - side) // 2
    comp = comp.crop((off, off, off + side, off + side))
    # App Store / springboard icons must be opaque.
    flat = Image.new("RGB", comp.size, (0x10, 0x0D, 0x09))
    flat.paste(comp, mask=comp.split()[3])
    return flat.resize((1024, 1024), Image.LANCZOS)


def write_icons() -> None:
    contents = json.loads((ICONSET / "Contents.json").read_text())
    master = master_icon()
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        pts = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(pts * scale)
        master.resize((px, px), Image.LANCZOS).save(ICONSET / name, optimize=True)
        print(f"icon {name}: {px}px")


def write_launch() -> None:
    mark = Image.open(RES / "drawable-xxhdpi/hermes_splash_mark.png").convert("RGBA")
    # drawable-xxhdpi is 3x, so the 3x launch image is the source size.
    base = mark.width // 3
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        px = base * scale
        out = LAUNCH / f"LaunchImage{suffix}.png"
        mark.resize((px, px), Image.LANCZOS).save(out, optimize=True)
        print(f"launch {out.name}: {px}px")


if __name__ == "__main__":
    write_icons()
    write_launch()
