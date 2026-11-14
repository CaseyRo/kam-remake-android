"""Draw GUIMain 10 (a locked mission on the campaign map) from the unlocked banner GUIMain 11.

The original locked node is a dark-grey skull shield that dominates a first-run map. This keeps the
unlocked banner's pixel silhouette and its fold shading, recolours the cloth to linen and the pole to
walnut at about 58% opacity, and puts a small walnut padlock on the cloth (locked flags show no number,
KM_GUIMenuCampaign). Same 23x29 canvas as GUIMain 11, so both sit in the same place.

Usage: tools/.venv/bin/python tools/locked_banner.py   (reads _originals/5_0011.png, writes 5_0010.png)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "_originals" / "5_0011.png"
OUT = ROOT / "Modding graphics" / "5_0010.png"

LINEN_DARK, LINEN = np.array((196, 174, 132)), np.array((236, 222, 186))
WALNUT, OAK = np.array((91, 58, 33)), np.array((140, 104, 66))
ALPHA = 148  # ~58%

# Padlock, 7x8, drawn over the cloth: W walnut, L linen keyhole, . nothing
LOCK = [
    "..WWW..",
    ".W...W.",
    ".W...W.",
    "WWWWWWW",
    "WWWLWWW",
    "WWWLWWW",
    "WWWWWWW",
]
LOCK_AT = (7, 8)  # top-left on the 23x29 canvas: centred on the cloth (x 3..17, y 6..17)


def build(src):
    a = np.array(src.convert("RGBA")).astype(np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    L = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    cloth = (rgb[..., 0] > rgb[..., 1] + 40) & (alpha > 0)
    out = np.zeros_like(a)
    t = np.clip((L - L[cloth].min()) / max(np.ptp(L[cloth]), 1), 0, 1)[..., None]
    out[..., :3] = np.where(cloth[..., None], LINEN_DARK + (LINEN - LINEN_DARK) * t,
                            WALNUT + (OAK - WALNUT) * np.clip(L / 120, 0, 1)[..., None])
    out[..., 3] = np.where(alpha > 0, ALPHA, 0)
    x0, y0 = LOCK_AT
    for dy, row in enumerate(LOCK):
        for dx, c in enumerate(row):
            if c != ".":
                out[y0 + dy, x0 + dx] = (*(WALNUT if c == "W" else LINEN), 225)
    return Image.fromarray(np.rint(out).astype(np.uint8), "RGBA")


if __name__ == "__main__":
    im = build(Image.open(SRC))
    src_alpha = np.array(Image.open(SRC).convert("RGBA"))[..., 3]
    assert im.size == (23, 29) and ((np.array(im)[..., 3] > 0) == (src_alpha > 0)).all()  # same silhouette
    im.save(OUT)
    print("wrote", OUT)
