"""Make clock frames 4_0557..4_0571 from the painted 4_0556.png (hand at 12).

The engine animates the clock through GUI sprites 556-571 (KM_InterfaceGamePlay.pas), a hand turning
clockwise 22.5 degrees per frame. Only 556 is painted, so this redraws the hand for the other 15.
Run after re-exporting 4_0556.png:  tools/.venv/bin/python tools/clock_frames.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

GFX = Path(__file__).resolve().parent.parent / "Modding graphics"
CX, CY = 33.0, 32.0   # hub centre in 4_0556.png
HAND_LEN = 14.0       # hub to tip, px
SS = 8                # supersampling for smooth edges

src = Image.open(GFX / "4_0556.png").convert("RGBA")
hand_rgb = src.getpixel((33, 25))[:3]

# Face without the hand: the face is round, so the lower half mirrored up gives a clean upper half
# (with the 6 o'clock tick becoming the 12 o'clock tick).
face = src.copy()
lower = src.crop((29, 33, 38, 52)).transpose(Image.FLIP_TOP_BOTTOM)
face.paste(lower, (29, 64 - 52))
assert face.getpixel((33, 25))[:3] != hand_rgb, "hand still visible after erase; check CX/CY"


def frame(i):
    a = math.radians(22.5 * i)
    big = Image.new("RGBA", (src.width * SS, src.height * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    tip = ((CX + 0.5 + HAND_LEN * math.sin(a)) * SS, (CY + 0.5 - HAND_LEN * math.cos(a)) * SS)
    hub = ((CX + 0.5) * SS, (CY + 0.5) * SS)
    d.line([hub, tip], fill=hand_rgb + (255,), width=int(2.6 * SS))
    r = 2.6 * SS
    d.ellipse([hub[0] - r, hub[1] - r, hub[0] + r, hub[1] + r], fill=hand_rgb + (255,))
    out = face.copy()
    out.alpha_composite(big.resize(src.size, Image.LANCZOS))
    return out


for i in range(1, 16):
    im = frame(i)
    assert im.size == src.size
    im.save(GFX / f"4_{556 + i:04d}.png")
print("wrote 4_0557..4_0571")
