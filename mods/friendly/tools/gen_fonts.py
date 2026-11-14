"""Build the Friendly Mod game fonts (.fntx) from the OFL faces in tools/downloads (spec sections 2 and 3).

  tools/.venv/bin/python tools/gen_fonts.py [--scale 1|1.5|2|all] [--only metal,grey] [--sheets]

--scale 1 writes "Modding graphics/fonts/", 1.5 and 2 write "Modding graphics/fonts@1.5x/" and "fonts@2x/" (all: the
three). The engine (KM_ResFonts.FontPath) loads <ExeDir>/Modding graphics/fonts<set>/<slot>.fntx over data/gfx/fonts,
so the mod never overwrites the game's fonts; touch hosts pick @1.5x from UI scale 1.4 and @2x from 3.5
(env KAM_FONT_SET=0|1|2 forces one). fonts@2x/ is git-ignored (37 MB): build it when needed.
--sheets skips building and renders contact sheets from the written files to _originals/fontsheets/.

Every slot keeps the original file's Used[] set (toolchain/kamres/.../fonts/<slot>.fntx), so coverage never shrinks,
and every glyph on the original's atlas 0 stays on atlas 0 (fllMinimal loads only that one).
Glyphs follow the original convention: Width is the tight ink box (it is also the advance), YOffset is from the
line top, and spacing comes from CharSpacing.

Hi-res sets (@1.5x, @2x) store 1x metrics: Width, Height, YOffset, BaseHeight and spacings are in UI units, and only
the atlas is denser. Each glyph's UI box is its hi-res ink box divided by the scale and rounded outwards; its UV rect
is that box times the scale (fractional texels), so the engine draws it at exactly 1/scale with no code change. Glyphs
sit HI_PAD transparent texels apart (the UV rect reaches < scale texels past the ink, linear filtering one more), and
transparent texels carry the outline (or fill) colour, so linear filtering does not darken the edges.
"""
import argparse
import math
import sys
from concurrent.futures import ProcessPoolExecutor
from fractions import Fraction
from pathlib import Path

import freetype
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
import fntx  # noqa: E402

MOD = Path(__file__).resolve().parents[1]
ORIG = MOD.parents[1] / "toolchain/kamres/app/data/gfx/fonts"
DL = MOD / "tools/downloads"
SHEETS = MOD / "_originals/fontsheets"

FRAUNCES = ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"wght": 900, "opsz": 9, "SOFT": 50})
# Labels, checkboxes and buttons (metal): a calmer weight and a 1 px rim, so a page of options reads, not shouts
FRAUNCES_LABEL = ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"wght": 600, "opsz": 9, "SOFT": 100})
NOTO_SERIF_BLACK = ("NotoSerif[wdth,wght].ttf", {"wght": 900})
NOTO_SERIF_LABEL = ("NotoSerif[wdth,wght].ttf", {"wght": 600})
JB_MONO = ("JetBrainsMono[wght].ttf", {"wght": 400})


def nunito(w):
    return ("Nunito[wght].ttf", {"wght": w})


def noto_sans(w):
    return ("NotoSans[wdth,wght].ttf", {"wght": w})


WHITE = 0xFFFFFF
# char = CharSpacing at 1x. Outlined slots: today's value minus 1 (spec). antiqua and arial lose the 1 px dark rim
# their old glyphs had, so today's -1 would overlap the ink: they get +1 like game. gap = char + 2*outline is what
# scales (the empty space between two fills).
SLOTS = {
    "metal":     dict(faces=[FRAUNCES_LABEL, NOTO_SERIF_LABEL], cjk="Bold", px=(14, 21, 28), ol=(1, 1, 2),
                      fill=0xFFF6DF, line=0x5B3A21, onebit=True, base=14, word=5, char=0),
    "outline":   dict(faces=[FRAUNCES, NOTO_SERIF_BLACK], cjk="Black", px=(16, 24, 32), ol=(2, 3, 4),
                      fill=0xFFF6DF, line=0x5B3A21, onebit=True, base=16, word=6, char=-3),
    "antiqua":   dict(faces=[nunito(700), noto_sans(700)], cjk="Bold", px=(13, 20, 26), ol=(0, 0, 0),
                      fill=0x3A2A1C, line=0, onebit=True, base=13, word=9, char=1),
    "game":      dict(faces=[nunito(700), noto_sans(700)], cjk="Bold", px=(13, 20, 26), ol=(0, 0, 0),
                      fill=WHITE, line=0, onebit=False, base=13, word=5, char=1),
    "grey":      dict(faces=[nunito(700), noto_sans(700)], cjk="Bold", px=(13, 20, 26), ol=(1, 1, 2),
                      fill=0xE6D2A6, line=0x4A2E18, onebit=True, base=13, word=5, char=-1),
    "mini":      dict(faces=[nunito(800), noto_sans(800)], cjk=None, px=(10, 15, 20), ol=(0, 0, 0),
                      fill=WHITE, line=0, onebit=False, base=10, word=4, char=1),
    "arial":     dict(faces=[nunito(600), noto_sans(600)], cjk="Bold", px=(12, 18, 24), ol=(0, 0, 0),
                      fill=WHITE, line=0, onebit=False, base=12, word=4, char=1),
    "consolas8": dict(faces=[JB_MONO, noto_sans(400)], cjk=None, px=(10, 15, 20), ol=(0, 0, 0),
                      fill=WHITE, line=0, onebit=False, base=10, word=None, char=0, mono=True),
}
SCALES = (1, 1.5, 2)
LINE_SPACING = 5
PAD = 1
HI_PAD = 3  # hi-res sets: gap between glyphs and atlas margin, > max UV overhang (scale) + 1 for linear filtering


def rnd(x):
    return int(x + 0.5) if x >= 0 else -int(-x + 0.5)


def out_dir(scale):
    return MOD / "Modding graphics" / ("fonts" if scale == 1 else f"fonts@{scale:g}x")


def cjk_order(cp):
    if 0x1100 <= cp <= 0x11FF or 0x3130 <= cp <= 0x318F or 0xA960 <= cp <= 0xA97F or 0xAC00 <= cp <= 0xD7FF:
        return ("kr", "jp", "sc")
    if 0x3040 <= cp <= 0x30FF or 0x31F0 <= cp <= 0x31FF or 0xFF65 <= cp <= 0xFF9F:
        return ("jp", "sc", "kr")
    return ("sc", "jp", "kr")


def open_face(spec, px):
    path, axes = spec if isinstance(spec, tuple) else (spec, {})
    face = freetype.Face(str(DL / path))
    if axes:
        info = face.get_variation_info()
        face.set_var_design_coords([axes.get(a.tag, a.default) for a in info.axes])
    face.set_pixel_sizes(0, px)
    return face


def bitmap(face, onebit):
    """Rasterise the loaded glyph slot -> uint8 coverage (0/255 for 1-bit)."""
    face.glyph.render(freetype.FT_RENDER_MODE_MONO if onebit else freetype.FT_RENDER_MODE_LIGHT)
    bm = face.glyph.bitmap
    if bm.rows == 0 or bm.width == 0:
        return np.zeros((0, 0), np.uint8)
    buf = np.array(bm.buffer, np.uint8).reshape(bm.rows, abs(bm.pitch))
    if bm.pixel_mode == freetype.FT_PIXEL_MODE_MONO:
        return np.unpackbits(buf, axis=1)[:, :bm.width] * np.uint8(255)
    return buf[:, :bm.width]


def disc(r):
    # r=1 gives a plus (like the old grey font), r=2 a rounded square without corners
    return [(dy, dx) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= r * r + r / 2]


def rgb(c):
    return (c >> 16) & 255, (c >> 8) & 255, c & 255


class Slot:
    def __init__(self, name, scale):
        s = SLOTS[name]
        k = SCALES.index(scale)
        self.name, self.s, self.scale = name, s, scale
        self.px, self.r = s["px"][k], s["ol"][k]
        self.onebit, self.mono = s["onebit"], s.get("mono", False)
        self.load = freetype.FT_LOAD_TARGET_MONO if self.onebit else freetype.FT_LOAD_TARGET_LIGHT
        self.faces = [open_face(f, self.px) for f in s["faces"]]
        self.cjk = {}
        if s["cjk"]:
            cpx = max(self.px, rnd(14 * scale))  # spec: CJK minimum 14 px at 1x
            self.cjk = {r: open_face(f"NotoSansCJK{r}-{s['cjk']}.otf", cpx) for r in ("sc", "jp", "kr")}
        self.base = rnd(s["base"] * scale)
        self.char = rnd((s["char"] + 2 * s["ol"][0]) * scale) - 2 * self.r
        self.dilate = disc(self.r)
        prim = self.faces[0]
        if self.mono:
            prim.load_char("M", self.load)
            self.cell_w = rnd(prim.glyph.advance.x / 64)
            self.asc = rnd(prim.size.ascender / 64)
            self.cell_h = self.asc + rnd(-prim.size.descender / 64)
            self.word = self.cell_w  # KM_ResFonts: monospaced WordSpacing = any Char.Width
            self.baseline = self.asc
        else:
            self.word = rnd(s["word"] * scale)
            prim.load_char("H", self.load)
            cap = bitmap(prim, self.onebit).shape[0]
            # centre cap height plus outline in BaseHeight, like the old game font (caps 1..11 in 13)
            self.baseline = (self.base - cap - 2 * self.r) // 2 + self.r + cap
        self.used_face = {}
        self.missing = []

    def pick(self, cp):
        for i, f in enumerate(self.faces):
            if f.get_char_index(cp):
                return f, ("primary" if i == 0 else "fallback")
        for r in cjk_order(cp):
            f = self.cjk.get(r)
            if f and f.get_char_index(cp):
                return f, "cjk-" + r
        return None, "missing"

    def glyph(self, cp):
        """-> (rgba image h*w*4, yoff), from face, '.notdef' of the primary face when nothing covers cp."""
        face, src = self.pick(cp) if cp else (None, "notdef")
        self.used_face[src] = self.used_face.get(src, 0) + 1
        if src == "missing":
            self.missing.append(f"{cp:04X}")
        if face is None:
            face = self.faces[0]
            face.load_glyph(0, self.load)
        else:
            face.load_char(cp, self.load)
        adv = face.glyph.advance.x / 64
        left, top = face.glyph.bitmap_left, face.glyph.bitmap_top
        cov = bitmap(face, self.onebit)
        if self.mono:
            return self.mono_cell(cov, left, top), 0
        if cov.size == 0 or not cov.any():
            return np.zeros((1, max(1, rnd(adv)), 4), np.uint8), 0  # spaces: advance width, nothing drawn
        r = self.r
        h, w = cov.shape
        a = np.zeros((h + 2 * r, w + 2 * r), np.uint8)
        a[r:r + h, r:r + w] = cov
        img = np.zeros(a.shape + (4,), np.uint8)
        if self.onebit:
            fill = a >= 128
            edge = np.zeros_like(fill)
            for dy, dx in self.dilate:
                edge[max(0, dy):a.shape[0] + min(0, dy), max(0, dx):a.shape[1] + min(0, dx)] |= \
                    fill[max(0, -dy):a.shape[0] + min(0, -dy), max(0, -dx):a.shape[1] + min(0, -dx)]
            img[edge] = (*rgb(self.s["line"]), 255)
            img[fill] = (*rgb(self.s["fill"]), 255)
        else:
            img[..., :3] = rgb(self.s["fill"])
            img[..., 3] = a
        ys, xs = np.nonzero(img[..., 3])
        img = img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        return img, self.baseline - top - r + int(ys.min())

    def mono_cell(self, cov, left, top):
        cell = np.zeros((self.cell_h, self.cell_w, 4), np.uint8)
        cell[..., :3] = 255
        if cov.size:
            y0, x0 = self.asc - top, left
            h, w = cov.shape
            sy, sx = max(0, -y0), max(0, -x0)
            ey, ex = min(h, self.cell_h - y0), min(w, self.cell_w - x0)
            if ey > sy and ex > sx:  # glyphs wider than the cell are clipped, as a monospace console would
                cell[y0 + sy:y0 + ey, x0 + sx:x0 + ex, 3] = cov[sy:ey, sx:ex]
        return cell


def ui_box(w, h, yoff, k):
    """Hi-res ink box (w, h, yoff) at scale k -> UI box (w, h, yoff), rounded outwards, and the top overhang in texels."""
    y0 = math.floor(Fraction(yoff) / k)
    y1 = math.ceil(Fraction(yoff + h) / k)
    return math.ceil(Fraction(w) / k), y1 - y0, y0, yoff - y0 * k


def build(name, scale):
    sl = Slot(name, scale)
    s = sl.s
    orig = fntx.read(ORIG / f"{name}.fntx")
    used = sorted(orig.letters)
    orig_atlas0 = {cp for cp, L in orig.letters.items() if L.atlas == 0}
    k = Fraction(scale).limit_denominator(2)  # 1, 3/2, 2
    hi = k != 1
    pad, margin = (HI_PAD, HI_PAD) if hi else (PAD, 0)
    orig_w = 256
    orig_h = 256 if name == "consolas8" else 512
    tw, th = (orig_w, orig_h) if not hi else (orig_w * 2, orig_h * 2)  # 256x512 cannot hold CJK at 1.5x/2x in 255 atlases
    glyphs = {cp: sl.glyph(cp) for cp in used}

    if hi:
        # UI metrics: the 1x values; CharSpacing keeps the 1x gap between fills despite the outward rounding
        boxes = {cp: ui_box(img.shape[1], img.shape[0], yoff, k) for cp, (img, yoff) in glyphs.items()}
        if sl.mono:
            word, char = boxes[ord("M")][0], 0
        else:
            ascii_ = [cp for cp in range(0x21, 0x7F) if cp in glyphs]
            slack = sum(boxes[cp][0] - glyphs[cp][0].shape[1] / k for cp in ascii_) / len(ascii_)
            word, char = s["word"], rnd(s["char"] + 2 * s["ol"][0] - 2 * sl.r / k - float(slack))
        font = fntx.Font(s["base"], word, char, LINE_SPACING, tex_w=tw, tex_h=th)
    else:
        font = fntx.Font(sl.base, sl.word, sl.char, rnd(LINE_SPACING * scale), tex_w=tw, tex_h=th)

    atlas, x, y, row = None, margin, margin, 0
    for cp in used:
        img, yoff = glyphs[cp]
        h, w = img.shape[:2]
        if x + w + margin > tw:
            x, y, row = margin, y + row + pad, 0
        if atlas is None or y + h + margin > th:
            atlas = np.zeros((th, tw, 4), np.uint8)
            font.atlases.append(atlas)
            x, y, row = margin, margin, 0
        atlas[y:y + h, x:x + w] = img
        a = len(font.atlases) - 1
        if hi:
            bw, bh, by, over = boxes[cp]
            v1 = y - over
            font.letters[cp] = fntx.Letter(bw, bh, by, a, x / tw, float(v1 / th),
                                           float((x + bw * k) / tw), float((v1 + bh * k) / th))
        else:
            font.letters[cp] = fntx.Letter(w, h, yoff, a, x / tw, y / th, (x + w) / tw, (y + h) / th)
        x, row = x + w + pad, max(row, h)
    assert len(font.atlases) <= 255, f"{name}@{scale}: {len(font.atlases)} atlases, AtlasCount is a byte"
    # transparent texels take the rim colour: linear filtering then fades the rim out instead of darkening it
    bg = rgb(s["line"] if s["ol"][0] else s["fill"])
    for at in font.atlases:
        at[at[..., 3] == 0, :3] = bg
    path = out_dir(scale) / f"{name}.fntx"
    path.parent.mkdir(parents=True, exist_ok=True)
    fntx.write(path, font)

    # check the written file with the reader
    back = fntx.read(path)
    assert set(back.letters) == set(used), "glyph set differs from the original Used[]"
    assert (back.tex_w, back.tex_h) == (tw, th)
    new_atlas0 = {cp for cp, L in back.letters.items() if L.atlas == 0}
    assert orig_atlas0 <= new_atlas0, f"{name}@{scale}: {len(orig_atlas0 - new_atlas0)} atlas-0 glyphs moved off atlas 0"
    if hi:
        for cp, L in back.letters.items():  # UV rect stays inside the atlas and covers the ink at exactly 1/scale
            assert 0 <= L.u1 < L.u2 <= 1 and 0 <= L.v1 < L.v2 <= 1, f"U+{cp:04X} UV out of atlas"
            assert abs((L.u2 - L.u1) * tw - L.w * scale) < 1e-3 and abs((L.v2 - L.v1) * th - L.h * scale) < 1e-3
    first = max(new_atlas0, default=-1)
    return (f"{name:9s} @{scale:g}x px {sl.px:2d}+{sl.r} base {back.base_height} word {back.word_spacing} "
            f"char {back.char_spacing} line {back.line_spacing} | glyphs {len(back.letters)} (orig {len(used)}) | "
            f"atlases {len(back.atlases)} x {tw}x{th} (atlas 0 up to U+{first:04X}) | "
            f"{path.stat().st_size // 1024} KB | faces {sl.used_face} | box only: {' '.join(sl.missing)}")


# ---------------------------------------------------------------- contact sheets (draws like KM_RenderUI.WriteText)

SAMPLES = [
    "Single Player  Options  Quit  0123456789 (10/20) 75%",
    "Größe Ärger Œuvre ąćęłńóśźż čďěňřšťůž ğışİ şţ ėįųū ÉÇÑ ¿¡?!",
    "Съешь же ещё этих мягких французских булок. ЁЖЩЯ",
    "中文游戏 开始战斗 日本語 ゲーム開始 カタカナ 한국어 게임 시작",
]
BG = {"metal": 0x55623A, "outline": 0x55623A, "grey": 0x55623A, "antiqua": 0xEADBB8}


def rgb5a1(img):
    out = img.copy()
    out[..., :3] = (img[..., :3] & 0xF8) | (img[..., :3] >> 5)
    return out


def draw_text(canvas, font, text, x, y, tint5551, k=1):
    """Draws like WriteText; x, y and the metrics are UI units, the canvas has k px per unit (k = the set's scale)."""
    for ch in text:
        if ch == " ":
            x += font.word_spacing
            continue
        cp = ord(ch)
        L = font.letters.get(cp, font.letters.get(0, fntx.Letter(0, 0, 0, 0, 0, 0, 0, 0)))  # engine: Letters[0]
        a = font.atlases[L.atlas]
        u, v = round(L.u1 * font.tex_w), round(L.v1 * font.tex_h)
        g = a[v:v + round(L.h * k), u:u + round(L.w * k)]
        if tint5551:
            g = rgb5a1(g)
        canvas.alpha_composite(Image.fromarray(np.ascontiguousarray(g), "RGBA"), (round(x * k), round((y + L.yoff) * k)))
        x += max(0, L.w + font.char_spacing)
    return x


def ink_extent(font, cps):
    ls = [font.letters[c] for c in cps if c in font.letters and font.letters[c].h > 1]
    return (min(L.yoff for L in ls), max(L.yoff + L.h for L in ls)) if ls else (0, 0)


def sheet(name):
    rows = []
    orig = fntx.read(ORIG / f"{name}.fntx")
    latin = [c for c in range(0x21, 0x250)] + list(range(0x400, 0x460))
    report = [f"{name}: original base {orig.base_height}, Latin/Cyr ink {ink_extent(orig, latin)}"]
    # every row at 3x UI size, as on an iPad: the 1x rows magnified 3x, the hi-res rows 2x and 1.5x
    for scale, zoom in ((0, 3), (1, 3), (1.5, 2), (2, 1.5)):
        f = orig if scale == 0 else fntx.read(out_dir(scale) / f"{name}.fntx")
        k = max(scale, 1)
        lh = f.base_height + f.line_spacing
        W = max(40 + draw_text(Image.new("RGBA", (4000, 200)), f, t, 0, 20, False) for t in SAMPLES)
        img = Image.new("RGBA", (round(W * k), round((26 + lh * len(SAMPLES) + 6) * k)), (*rgb(BG.get(name, 0x2B2B2B)), 255))
        d = ImageDraw.Draw(img)
        d.text((4, 2), f"{name} {'ORIGINAL' if scale == 0 else f'{scale:g}x'}", fill=(255, 80, 80, 255))
        for i, t in enumerate(SAMPLES):
            top = 24 + i * lh
            d.line([(0, top * k), (W * k, top * k)], fill=(255, 255, 255, 50))  # line top
            d.line([(0, (top + f.base_height) * k), (W * k, (top + f.base_height) * k)], fill=(255, 60, 60, 110))  # BaseHeight
            draw_text(img, f, t, 8, top, FONT_MODE[name] == "RGB5A1", k)
        rows.append(img.resize((round(img.width * zoom), round(img.height * zoom)),
                               Image.NEAREST if k == 1 else Image.BILINEAR))
        if scale:
            cjk = [c for c in f.letters if 0x3040 <= c <= 0xD7AF]
            report.append(f"  {scale:g}x base {f.base_height} line {lh} Latin/Cyr ink {ink_extent(f, latin)} "
                          f"CJK ink {ink_extent(f, cjk)}")
    out = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), (0, 0, 0, 255))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.height
    SHEETS.mkdir(parents=True, exist_ok=True)
    out.convert("RGB").save(SHEETS / f"{name}.png")
    return "\n".join(report)


FONT_MODE = {"metal": "RGB5A1", "outline": "RGB5A1", "antiqua": "RGB5A1", "grey": "RGB5A1",
             "game": "Alpha8", "mini": "Alpha8", "arial": "RGBA8", "consolas8": "RGBA8"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", default="1", choices=["1", "1.5", "2", "all"])
    ap.add_argument("--only", default=",".join(SLOTS))
    ap.add_argument("--sheets", action="store_true")
    a = ap.parse_args()
    names = a.only.split(",")
    scales = SCALES if a.scale == "all" else [SCALES[["1", "1.5", "2"].index(a.scale)]]
    with ProcessPoolExecutor(max_workers=4) as ex:
        jobs = [ex.submit(sheet, n) for n in names] if a.sheets else \
               [ex.submit(build, n, sc) for sc in scales for n in names]
        for j in jobs:
            print(j.result(), flush=True)


if __name__ == "__main__":
    assert rnd(-4.5) == -5 and rnd(2.5) == 3 and disc(1) == [(-1, 0), (0, -1), (0, 0), (0, 1), (1, 0)]
    assert ui_box(7, 10, -3, Fraction(3, 2)) == (5, 7, -2, 0) and ui_box(4, 5, 1, Fraction(3, 2)) == (3, 4, 0, 1)
    main()
