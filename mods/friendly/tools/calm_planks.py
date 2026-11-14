"""Repaint the sidebar planks (GUI 404, 407, 554) as calm, plain boards.

The build, stats and house grids are translucent and sit on GUI 404 (Panel_Controls in
KM_InterfaceGamePlay), so hard plank seams, butt joints and grain showed through the buttons.
This keeps the plank rhythm but drops joints and grain, flattens the per-plank gradient and
softens the seam to a 2 px line. 407 and 554 get the same seams so the sidebar reads as one wall.
The vine strip (x >= 198), the minimap frame (407), the sign and its ropes (554) are kept.

Usage: tools/.venv/bin/python tools/calm_planks.py   (rewrites the three PNGs in place; idempotent)
"""
from pathlib import Path
from PIL import Image

GFX = Path(__file__).resolve().parent.parent / "Modding graphics"
BOARD_W = 198  # x >= 198 is the dark edge and vine strip

TOP, BOTTOM = (184, 131, 69), (177, 124, 64)  # gentle per-plank gradient (was 188 -> 168)
SEAM = [(173, 120, 62), (159, 108, 55), (167, 115, 59)]  # last 3 rows of each plank (was 145/114/99)

# name: (plank pitch, reference column of plain board, boxes (x0, y0, x1, y1) where art is kept)
SPRITES = {
    "4_0404.png": (50, None, []),
    "4_0407.png": (50, 0, [(3, 3, 195, 197)]),  # minimap frame and its shadow
    "4_0554.png": (56, 3, [(14, 38, 185, 129), (42, 0, 46, 44), (152, 0, 156, 44)]),  # sign; two ropes
}


def plank(y, pitch):
    r = y % pitch
    if r >= pitch - 3:
        return SEAM[r - (pitch - 3)]
    t = r / (pitch - 4)
    return tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))


def inside(x, y, box):
    return box[0] <= x <= box[2] and box[1] <= y <= box[3]


def calm(name, pitch, ref_x, boxes):
    im = Image.open(GFX / name).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        ref = px[ref_x, y] if ref_x is not None else None
        new = plank(y, pitch) + (255,)
        for x in range(BOARD_W):
            # Inside a box keep anything that is not plain board (art, outline, shadow).
            if any(inside(x, y, b) for b in boxes) and max(abs(a - b) for a, b in zip(px[x, y][:3], ref[:3])) > 6:
                continue
            px[x, y] = new
    im.save(GFX / name)


def check():
    assert plank(0, 50) == TOP and plank(46, 50) == BOTTOM and plank(48, 50) == SEAM[1]
    assert plank(55, 56) == SEAM[2] and plank(56, 56) == TOP


if __name__ == "__main__":
    check()
    for name, args in SPRITES.items():
        calm(name, *args)
        print("calmed", name)
