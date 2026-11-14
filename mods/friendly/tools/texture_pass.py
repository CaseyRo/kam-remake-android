"""Texture pass: give the flat Friendly Mod surfaces a quiet, hand-made texture.

The map is 1998 pre-rendered, dithered pixel art; flat vector fills look pasted on next to it. This adds
low-amplitude, zero-mean texture so the average colour of every surface (and so the contrast of any
label on it) stays where it was:

- wood grain with irregular, wavering lines and a few soft knots on the oak planks (GUI 404, 407, 554)
  and the in-game button face (GUI 402; the engine samples it in screen space at 2x, Write3DButton);
- paper fibres and mottling on the parchment backdrop and card (GUIMain 17, 18), a linen weave on the
  message scroll (GUI 409);
- vertical grain on the wall planks of the results hall (GUIMain 7);
- uniform per-pixel grain only on the menu button tile (GUIMain 9): it is sampled in screen space, so any
  structure would show as a pattern across buttons;
- slight edge wear on plates: darker, patchy rims on the cream plates (554 sign, 407 minimap card,
  409 scroll), lighter scuffs on the outer edge of the oak card rim (GUIMain 18).

Run after calm_planks.py (which repaints 404/407/554 flat) and after any new Paper export:
    tools/.venv/bin/python tools/texture_pass.py           # textures the PNGs in place
    tools/.venv/bin/python tools/texture_pass.py --check   # report only: luminance before/after per surface
A textured PNG carries the text chunk friendly-texture=<VERSION> and is skipped on the next run, so
running twice is safe. Seeds are fixed, so the result is reproducible. Sizes, alpha and the sRGB
colour space are unchanged (alpha is never touched).
"""
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, PngImagePlugin

sys.path.insert(0, str(Path(__file__).resolve().parent))
from calm_planks import BOARD_W, plank  # noqa: E402

GFX = Path(__file__).resolve().parent.parent / "Modding graphics"
VERSION = "1"
MARK = "friendly-texture"

CREAM = (244, 232, 204)   # plates (554 sign, 407 card, 409 scroll)
OAK_RIM = (176, 122, 62)  # GUIMain 18 card rim


# ---------- noise primitives (float32 arrays, roughly zero mean) ----------

def value_noise(rng, h, w, cell_y, cell_x):
    """Smooth noise in [-1, 1]: a coarse random grid resized bicubic."""
    gh, gw = max(2, h // cell_y + 2), max(2, w // cell_x + 2)
    small = Image.fromarray(rng.uniform(-1, 1, (gh, gw)).astype(np.float32), "F")
    big = small.resize((gw * cell_x, gh * cell_y), Image.BICUBIC)
    return np.asarray(big, dtype=np.float32)[:h, :w]


def profile(rng, n, smooth=0.9):
    """1-D random profile with irregular stripe spacing, unit std."""
    p = rng.normal(0, 1, n).astype(np.float32)
    k = np.exp(-0.5 * (np.arange(-4, 5) / smooth) ** 2)
    p = np.convolve(p, k / k.sum(), mode="same")
    return (p - p.mean()) / (p.std() + 1e-6)


def wood(rng, h, w, pitch=None, knots=()):
    """Horizontal wood grain. Lines waver along x, bend around knots and fade in and out."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    yy = y + 4.0 * value_noise(rng, h, w, 30, 45) + 1.2 * value_noise(rng, h, w, 6, 14)
    dark = np.zeros((h, w), np.float32)
    for cx, cy, r in knots:
        d2 = ((x - cx) / (2.6 * r)) ** 2 + ((y - cy) / r) ** 2
        yy += 1.6 * r * np.exp(-d2) * np.sign(y - cy)          # grain flows around the knot
        kd = ((x - cx) / (1.35 * r)) ** 2 + ((y - cy) / (0.8 * r)) ** 2
        dark += np.exp(-kd * 1.6) + 0.35 * np.exp(-((np.sqrt(kd) - 1.15) / 0.22) ** 2)  # core + soft ring
    if pitch:  # each plank its own board: shift the profile per plank
        yy += (y // pitch) * 211.0
    prof = profile(rng, int(h + 1600))
    t = np.clip(yy + 600, 0, len(prof) - 2)
    i = t.astype(np.int32)
    g = prof[i] * (1 - (t - i)) + prof[i + 1] * (t - i)
    fade = 0.55 + 0.45 * value_noise(rng, h, w, 4, 70)       # streaks fade in and out along the board
    return g * fade, dark


def fibres(rng, h, w, density, length=(3, 9), strength=(2.0, 4.5)):
    """Short light and dark fibres, like laid paper."""
    canvas = Image.new("F", (w, h), 0.0)
    dr = ImageDraw.Draw(canvas)
    for _ in range(int(h * w * density)):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h)
        a = rng.uniform(0, np.pi)
        L = rng.uniform(*length)
        v = rng.uniform(*strength) * rng.choice([-1, 1])
        dr.line([(x0, y0), (x0 + L * np.cos(a), y0 + L * np.sin(a))], fill=float(v), width=1)
    f = np.asarray(canvas, dtype=np.float32)
    for ax in (0, 1):  # soften the 1 px lines a little: [1 2 1] / 4 each way
        f = (np.roll(f, 1, ax) + 2 * f + np.roll(f, -1, ax)) / 4
    return f * 1.6


def weave(h, w):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return np.sin(x * np.pi / 1.5) * np.sin(y * np.pi / 1.5)  # 3 px over-under


def distance_in(mask, steps):
    """Distance (in px, capped at steps) of each mask pixel from the mask's edge."""
    m = Image.fromarray((mask * 255).astype(np.uint8), "L")
    d = np.zeros(mask.shape, np.float32)
    for _ in range(steps):
        d += np.asarray(m, dtype=np.float32) / 255
        m = m.filter(ImageFilter.MinFilter(3))
    return d


def wear(rng, mask, depth=3.0, patch=12):
    """0..1 weight of edge wear: strongest on the plate's edge, in patches."""
    d = distance_in(mask, 6)
    h, w = mask.shape
    patches = np.clip(value_noise(rng, h, w, patch, patch) * 1.6 + 0.3, 0, 1)
    return np.where(mask, np.exp(-(d - 1) / depth) * patches, 0).astype(np.float32)


# ---------- masks ----------

def near(a, rgb, tol):
    return (np.abs(a[..., :3].astype(np.int16) - np.array(rgb, np.int16)).max(-1) <= tol) & (a[..., 3] == 255)


def board_mask(a):
    """Plain plank pixels of the sidebar boards (x < BOARD_W, the calm_planks colour of that row)."""
    h, w = a.shape[:2]
    ref = np.array([plank(y, PITCH[NAME]) for y in range(h)], np.int16)[:, None, :]
    m = (np.abs(a[..., :3].astype(np.int16) - ref).max(-1) <= 4) & (a[..., 3] == 255)
    m[:, BOARD_W:] = False
    return m


def opaque(a):
    return a[..., 3] == 255


# ---------- per-sprite recipes: return a luminance delta (float, levels) ----------

PITCH = {"4_0404.png": 50, "4_0407.png": 50, "4_0554.png": 56}
NAME = ""


def recipe_planks(rng, a, knots, amp):
    h, w = a.shape[:2]
    g, dark = wood(rng, h, w, PITCH[NAME], knots)
    delta = amp * g - 11.0 * dark + rng.normal(0, 1.0, (h, w))
    delta = np.where(board_mask(a), delta, 0)
    cream = near(a, CREAM, 3)
    if cream.any():
        delta += np.where(cream, -7.0 * wear(rng, cream) + rng.normal(0, 0.8, (h, w)), 0)
    return delta


def r404(rng, a):
    return recipe_planks(rng, a, [(58, 122, 3.2), (150, 318, 2.6)], 3.0)


def r407(rng, a):
    return recipe_planks(rng, a, [], 3.0)


def r554(rng, a):
    return recipe_planks(rng, a, [(170, 20, 2.8), (24, 150, 3.0)], 3.0)


def r402(rng, a):
    h, w = a.shape[:2]
    g, dark = wood(rng, h, w, None, [(150, 90, 3.0)])
    return 2.6 * g - 8.0 * dark + rng.normal(0, 0.9, (h, w))


def r9(rng, a):
    h, w = a.shape[:2]
    return rng.normal(0, 1.6, (h, w))


def r_paper(rng, a, fib=0.012, mott=2.0):
    h, w = a.shape[:2]
    return mott * value_noise(rng, h, w, 22, 22) + fibres(rng, h, w, fib) + rng.normal(0, 0.9, (h, w))


def r17(rng, a):
    return r_paper(rng, a)


def r18(rng, a):
    h, w = a.shape[:2]
    rim = near(a, OAK_RIM, 6)
    inner = opaque(a) & ~rim & ~(a[..., :3].max(-1) < 110)  # card face (not the rim, not the dark line)
    delta = np.where(inner, r_paper(rng, a), 0)
    rimd = rng.normal(0, 1.2, (h, w)) + 2.0 * value_noise(rng, h, w, 5, 18)
    # The rim's outer edge: lighter scuffs where the oak has been handled.
    outer = rim & (distance_in(opaque(a), 6) <= 4)
    delta += np.where(rim, rimd + 20.0 * wear(rng, rim, 1.6, 9) * outer, 0)
    return delta


def r409(rng, a):
    h, w = a.shape[:2]
    cream = near(a, CREAM, 3)
    base = r_paper(rng, a, fib=0.006, mott=1.3) + 0.9 * weave(h, w)
    return np.where(cream, base - 9.0 * wear(rng, opaque(a), 3.0, 14), 0)


def r7(rng, a):
    """Results hall (GUIMain 7): vertical grain on the wall planks; the engine dims it 63% anyway."""
    h, w = a.shape[:2]
    g, dark = wood(rng, w, h, 64, [(300, 30, 3.0), (520, 290, 3.4), (130, 990, 3.0)])  # transposed: x is along the board
    g, dark = g.T, dark.T
    rgb = a[..., :3].astype(np.int16)
    L = lum(rgb.astype(np.float32))
    oak = (rgb[..., 0] > rgb[..., 1]) & (rgb[..., 1] > rgb[..., 2]) & (rgb[..., 0] - rgb[..., 2] > 70) & (L > 100)
    return np.where(oak, 5.0 * g - 14.0 * dark + rng.normal(0, 1.2, (h, w)), rng.normal(0, 1.0, (h, w)))


RECIPES = {
    "4_0404.png": r404, "4_0407.png": r407, "4_0554.png": r554, "4_0402.png": r402,
    "4_0409.png": r409, "5_0017.png": r17, "5_0018.png": r18, "5_0009.png": r9, "5_0007.png": r7,
}


def lum(rgb):
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def apply(a, delta):
    """Shift each pixel's lightness by delta levels, keeping its hue (scale RGB about its luminance)."""
    rgb = a[..., :3].astype(np.float32)
    L = lum(rgb)
    k = (L + delta) / np.maximum(L, 1)
    out = a.copy()
    out[..., :3] = np.clip(np.rint(rgb * k[..., None]), 0, 255).astype(np.uint8)
    return out


def textured(name, src):
    global NAME
    NAME = name
    a = np.array(src.convert("RGBA"))
    rng = np.random.default_rng(zlib.crc32(name.encode()))
    return apply(a, RECIPES[name](rng, a))


def report(name, before, after):
    """Mean luminance of the opaque surface before/after (label contrast depends on it), and 5th percentile."""
    m = before[..., 3] == 255
    lb, la = lum(before[..., :3].astype(np.float32))[m], lum(after[..., :3].astype(np.float32))[m]
    d = (la.mean() - lb.mean()) / lb.mean() * 100
    p = (np.percentile(la, 5) - np.percentile(lb, 5)) / max(np.percentile(lb, 5), 1) * 100
    print(f"{name}: mean L {lb.mean():6.1f} -> {la.mean():6.1f} ({d:+.2f}%), p5 {p:+.2f}%")
    return abs(d)


def check():
    rng = np.random.default_rng(1)
    n = value_noise(rng, 50, 80, 10, 10)
    assert n.shape == (50, 80) and np.abs(n).max() <= 1.6
    a = np.full((4, 4, 4), 200, np.uint8)
    assert (apply(a, np.zeros((4, 4)))[..., :3] == 200).all()
    assert (apply(a, np.full((4, 4), 10.0))[..., 3] == 200).all()  # alpha untouched
    m = np.zeros((9, 9), bool); m[2:7, 2:7] = True
    assert distance_in(m, 6)[4, 4] == 3 and distance_in(m, 6)[2, 2] == 1


def main():
    check()
    dry = "--check" in sys.argv
    worst = 0.0
    for name in RECIPES:
        path = GFX / name
        src = Image.open(path)
        if src.text.get(MARK) == VERSION and not dry:
            print(f"{name}: already textured, skipped")
            continue
        before = np.array(src.convert("RGBA"))
        after = textured(name, src)
        assert after.shape == before.shape and (after[..., 3] == before[..., 3]).all()
        worst = max(worst, report(name, before, after))
        if not dry:
            info = PngImagePlugin.PngInfo()
            info.add_text(MARK, VERSION)
            Image.fromarray(after, "RGBA").save(path, pnginfo=info)
    assert worst < 5.0, f"a surface's mean luminance moved {worst:.1f}% (limit 5%)"


if __name__ == "__main__":
    main()
