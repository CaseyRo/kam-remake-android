#!/usr/bin/env python3
"""Install the 'wares' group PNGs exported from Paper (page "20 Sprites - wares") into
'Modding graphics/', check each against the original's pixel size, and draw a contact sheet.

Paper exports land in ~/Downloads as '4_<id> <name> <w>x<h>[ (n)].png'; the newest per id wins
and every export for that id is removed from Downloads.

Usage: wares_install.py [SHEET_PNG]
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

MOD = Path(__file__).resolve().parent.parent
OUT = MOD / "Modding graphics"
DL = Path.home() / "Downloads"
IDS = list(range(351, 379)) + [654, 655, 657, 658, 659, 37, 40, 491, 492, 493, 494, 495, 496]

orig = {s["id"]: s for s in json.load(open(MOD / "_originals/manifest.json"))["sprites"]
        if s["archive"] == "GUI.rxx" and s["id"] in IDS}
OUT.mkdir(exist_ok=True)

bad = []
for i in IDS:
    found = sorted(DL.glob(f"4_{i} *.png"), key=lambda p: p.stat().st_mtime)
    dst = OUT / f"4_{i}.png"
    if found:
        Image.open(found[-1]).convert("RGBA").save(dst)
        for p in found:
            p.unlink()
    if not dst.exists():
        bad.append(f"4_{i}: missing")
        continue
    im = Image.open(dst)
    want = (orig[i]["width"], orig[i]["height"])
    if im.size != want:
        bad.append(f"4_{i}: {im.size} != original {want}")
    if im.getpixel((0, 0))[3] != 0 and im.getpixel((im.width - 1, im.height - 1))[3] != 0:
        bad.append(f"4_{i}: corners are opaque (background not transparent?)")
    assert not orig[i]["hasMask"], f"4_{i} has a team-colour mask: write 4_{i}a.png"

print("\n".join(bad) or f"OK: {len(IDS)} PNGs match the original sizes")

# Contact sheet: original | new, each at 1x on oak and linen, plus new at 4x.
if len(sys.argv) > 1:
    cols, cw, ch = 7, 200, 230
    rows = (len(IDS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (58, 42, 28, 255))
    d = ImageDraw.Draw(sheet)
    for n, i in enumerate(IDS):
        x, y = (n % cols) * cw, (n // cols) * ch
        old = Image.open(MOD / orig[i]["png"]).convert("RGBA")
        new = Image.open(OUT / f"4_{i}.png").convert("RGBA")
        d.text((x + 4, y + 2), f"4_{i}", fill=(255, 246, 223, 255))
        for k, bg in enumerate([(201, 154, 94, 255), (244, 232, 204, 255)]):
            d.rectangle([x + 4 + k * 96, y + 16, x + 94 + k * 96, y + 66], fill=bg)
            sheet.alpha_composite(old, (x + 10 + k * 96, y + 20))
            sheet.alpha_composite(new, (x + 50 + k * 96, y + 20))
        big = new.resize((new.width * 4, new.height * 4), Image.NEAREST)
        if big.height > 150:
            big = new.resize((new.width * 3, new.height * 3), Image.NEAREST)
        d.rectangle([x + 4, y + 70, x + 194, y + 226], fill=(201, 154, 94, 255))
        sheet.alpha_composite(big, (x + 8, y + 74))
    sheet.save(sys.argv[1])
    print("sheet:", sys.argv[1])
sys.exit(1 if bad else 0)
