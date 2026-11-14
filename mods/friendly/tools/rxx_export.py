#!/usr/bin/env python3
"""Export chosen sprites from KaM Remake .rxx archives to PNG, the way the engine's
F11 > Export Data > Resources does (TKMSpritePack.ExportFullImageData, KM_ResSprites.pas).

Per sprite <P>_<id:04>.png (+ <P>_<id:04>a.png team-colour mask, + <P>_<id:04>.txt pivot).
These names are exactly what 'Modding graphics/' loads back (AddImage: 'a.png' = smart mask,
'.txt' = pivot X then Y).

.rxx layout (LoadFromRXXFile / ReadRXZHeader):
  'RXX2' + u16 metaLen + meta | 'RXX1' + 32 bytes | bare zlib (legacy), then a zlib stream:
  i32 count, u8 flag[count], and per flagged sprite:
  u16 w, u16 h, i16 pivotX, i16 pivotY, [4 x i16 SizeNoShadow, Units only],
  w*h x u32 RGBA (bytes R,G,B,A), u8 hasMask, [w*h x u8 mask].
Sprite ids are 1-based.

Usage:  rxx_export.py            -> exports the spec section 4 list + manifest.json
        rxx_export.py ARCHIVE PREFIX OUTDIR ID...   -> ad-hoc export
"""
import json
import struct
import sys
import zlib
from pathlib import Path

from PIL import Image

FLAG_COLOR_DARK = 0xFF101010  # KM_ResTypes.pas


def read_rxx(path, units=False):
    raw = Path(path).read_bytes()
    if raw[:4] == b"RXX2":
        (meta_len,) = struct.unpack_from("<H", raw, 4)
        body = raw[6 + meta_len:]
    elif raw[:4] == b"RXX1":
        body = raw[4 + 32:]
    elif raw[:2] == b"\x78\xda":
        body = raw
    else:
        raise ValueError(f"{path}: unknown RXX header {raw[:4]!r}")
    data = zlib.decompress(body)
    (count,) = struct.unpack_from("<i", data, 0)
    flags = data[4:4 + count]
    pos = 4 + count
    sprites = {}
    for i, flag in enumerate(flags, start=1):
        if flag != 1:
            continue
        w, h, px, py = struct.unpack_from("<HHhh", data, pos)
        pos += 8
        if units:
            pos += 8
        rgba = data[pos:pos + 4 * w * h]
        pos += 4 * w * h
        has_mask = data[pos] != 0
        pos += 1
        mask = None
        if has_mask:
            mask = data[pos:pos + w * h]
            pos += w * h
        sprites[i] = dict(w=w, h=h, pivot=(px, py), rgba=rgba, mask=mask)
    # self-check: the stream must be consumed exactly, else the layout is misread (garbled output)
    assert pos == len(data), f"{path}: parsed {pos} of {len(data)} bytes"
    return count, sprites


def to_images(s):
    """Mirror ExportImage/ExportMask (non-Houses branch)."""
    w, h, rgba, mask = s["w"], s["h"], bytearray(s["rgba"]), s["mask"]
    mask_img = None
    if mask is not None:
        for p, m in enumerate(mask):
            if m == 0:
                continue
            o = 4 * p
            if struct.unpack_from("<I", rgba, o)[0] == FLAG_COLOR_DARK:
                rgba[o:o + 3] = bytes((m, 0, 0))  # dark flag: red at mask strength
            else:
                rgba[o:o + 3] = bytes((255, 255 - m, 255 - m))  # lite flag: white mixed to red
        mask_img = Image.frombytes("L", (w, h), bytes(255 if m else 0 for m in mask)).convert("RGBA")
    return Image.frombytes("RGBA", (w, h), bytes(rgba)), mask_img


def export(sprites, prefix, sid, out_dir):
    s = sprites[sid]
    img, mask = to_images(s)
    base = Path(out_dir) / f"{prefix}_{sid:04d}"
    img.save(f"{base}.png")
    if mask is not None:
        mask.save(f"{base}a.png")
    Path(f"{base}.txt").write_text(f"{s['pivot'][0]}\n{s['pivot'][1]}\n")
    return f"{base}.png"


# Spec ~/Desktop/kam-friendly-mod-spec.md section 4: (ids, spec size w x h or None, new art)
SPEC = {
    "GUIMain.rxx": (5, [
        ([4], None, "Logo: Fraunces wordmark 'Knights & Merchants' with an oak ampersand and flourish"),
        ([5], None, "Crest becomes a hanging banner: moss with a tower"),
        ([6], None, "Crest becomes a hanging banner: oak with a wheat sheaf"),
        ([9], None, "bsMenu tile. Flat moss #526F31 (cream text 5.6:1), no baked light or lip (sampled in screen space at 2 screen px per texel)"),
        ([17], None, "Linen parchment with painted rolling hills and a small town"),
        ([18], None, "Torn burnt frame becomes a rounded honey-oak frame, radius 18, walnut inner line"),
    ]),
    "GUI.rxx": (4, [
        ([402], None, "bsGame tile: flat oak-light #C99A5E. Same screen-space rule as GUIMain 9"),
        ([404], (224, 400), "Sidebar planks, 224x400 tile, honey oak with walnut seams"),
        ([407], (224, 200), "Sidebar top 224x200: linen minimap frame, radius 12, walnut ring, plus the vine edge"),
        ([554], (224, 168), "Sidebar middle, 224x168, matching 407 and 404"),
        ([439], None, "Tab icon: hammer. Ink 2 px round strokes, one warm fill, about 24 px"),
        ([440], None, "Tab icon: scales. Ink 2 px round strokes, one warm fill, about 24 px"),
        ([441], None, "Tab icon: ledger. Ink 2 px round strokes, one warm fill, about 24 px"),
        ([442], None, "Tab icon: quill. Ink 2 px round strokes, one warm fill, about 24 px"),
        ([443], None, "Back arrow, same style as the tab icons"),
        (list(range(301, 330)), (32, 32), "Build icon, 32 px: own 30 px plate with 6 px corners and the house's product or tool in ink (plate colour by category: linen civic, moss food, honey materials, woad military)"),
        ([335], (32, 32), "Road, build-plate style"),
        ([336], (32, 32), "Wine, build-plate style"),
        ([337], (32, 32), "Field, build-plate style"),
        ([340], (32, 32), "Erase, build-plate style"),
        ([41], (32, 32), "Locked house: walnut plate with a linen padlock (also the unknown-ware fallback icon)"),
        (list(range(351, 379)), None, "Ware (351 + ware index; trunk 351, stone 352, timber 353 are the build costs), ink style"),
        ([654], (40, 40), "Construction stone, 40x40"),
        ([655], (40, 40), "Construction wood, 40x40"),
        ([657, 658, 659], None, "Ware group icon"),
        ([37], None, "House panel delivery-mode button: a cart"),
        ([40], None, "House panel repair button: a hammer with a green plus"),
        ([491], (30, 48), "Message token (text), 30x48: round 26 px honey token, 2 px walnut ring, baked drop below"),
        ([492], (30, 48), "Message token (house), 30x48: round 26 px honey token, 2 px walnut ring, baked drop below"),
        ([493], (30, 48), "Message token (group), 30x48: round 26 px honey token, 2 px walnut ring, baked drop below"),
        ([495], (30, 48), "Message token (quill / log), 30x48: round 26 px linen token, 2 px walnut ring, baked drop below"),
        ([494], (30, 48), "Chat token, 30x48, speech bubble, same style"),
        ([496], (30, 48), "Allies token, 30x48, woad with a shield"),
        ([409], (600, 500), "Message scroll, 600x500 (190 px shown): linen card, radius 18 top corners, 2 px walnut edge, inner tan line, dashed stitch"),
        ([52], (32, 32), "Close, 32x32: round linen button with an ink 'x'"),
        ([556], (67, 65), "Clock, 67x65: honey bezel, linen face, walnut hands"),
        ([132], None, "Slider thumb, stretched in width: plank with no corner detail, 2 px walnut edge, flat oak middle"),
        ([590], None, "Dropdown arrow: cream triangle with ink outline"),
        ([591], None, "Scroll arrow: cream triangle with ink outline"),
    ]),
}


def main_spec():
    root = Path(__file__).resolve().parent.parent
    data = root.parent.parent / "toolchain/kamres/app/data/Sprites"
    out = root / "_originals"
    out.mkdir(exist_ok=True)
    entries, problems = [], []
    for archive, (prefix, rows) in SPEC.items():
        _, sprites = read_rxx(data / archive)
        # The menu loads GUI with alpha shadows, i.e. GUI_a.rxx (LoadMenuResources); note any differences.
        alt = data / archive.replace(".rxx", "_a.rxx")
        alt_sprites = read_rxx(alt)[1] if alt.exists() else None
        for ids, spec_size, art in rows:
            for sid in ids:
                e = dict(archive=archive, id=sid, newArt=art, specSize=list(spec_size) if spec_size else None)
                s = sprites.get(sid)
                if s is None:
                    e.update(exists=False)
                    problems.append(f"{prefix}_{sid}: not present in {archive}")
                    entries.append(e)
                    continue
                png = export(sprites, prefix, sid, out)
                e.update(exists=True, width=s["w"], height=s["h"], pivot=list(s["pivot"]),
                         hasMask=s["mask"] is not None, png=str(Path(png).relative_to(root)),
                         mask=str(Path(png[:-4] + "a.png").relative_to(root)) if s["mask"] is not None else None,
                         overrideName=f"Modding graphics/{prefix}_{sid:04d}.png")
                if spec_size and tuple(spec_size) != (s["w"], s["h"]):
                    e["sizeMismatch"] = True
                    problems.append(f"{prefix}_{sid}: spec says {spec_size[0]}x{spec_size[1]}, original is {s['w']}x{s['h']}")
                if alt_sprites is not None:
                    a = alt_sprites.get(sid)
                    same = a is not None and (a["w"], a["h"], a["rgba"], a["mask"]) == (s["w"], s["h"], s["rgba"], s["mask"])
                    e["sameIn_" + alt.name] = same
                    if not same:
                        problems.append(f"{prefix}_{sid}: differs in {alt.name} (the file the menu actually loads)")
                entries.append(e)
    manifest = dict(
        source="toolchain/kamres/app/data/Sprites (r16397)",
        exporter="mods/friendly/tools/rxx_export.py",
        notes=[
            "Overrides go to 'Modding graphics/<prefix>_<id>.png' (4 = GUI.rxx, 5 = GUIMain.rxx); zero padding is optional.",
            "Team-colour mask: '<prefix>_<id>a.png' next to the png (white = player colour). '<prefix>_<id>m.png' is a plain greyscale mask and wins over 'a'.",
            "Pivot: '<prefix>_<id>.txt', two lines X and Y. Without it the original pivot is kept.",
            "In the exported png, team-colour pixels are drawn red (as F11 export does); repaint them in red/white shades and keep the a.png mask.",
            "Keep each sprite the same pixel size as the original.",
            "specSize for 301-329 comes from the spec's '32 px'; for 335-340 and 41 it is inferred from 'same plate style'.",
            "Build icons are trimmed today (14x18 to 30x30), not 32x32: a 32 px plate is a size change. The engine accepts any size, but the art then fills the whole 33 px build button.",
            "301-329 are 29 icons, all used as BuildIcon (KM_ResHouses), not 28.",
            "GUI #41 is a question mark today, not a padlock. It is also used by school WIP, market, stats, ratios and the map-editor mission tab.",
            "The menu loads GUI_a.rxx (LoadMenuResources, alpha shadows); every listed GUI sprite is byte-identical there (sameIn_GUI_a.rxx).",
            "None of the listed sprites has a team-colour mask in the originals.",
        ],
        problems=problems,
        sprites=entries,
    )
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{sum(e['exists'] for e in entries)} exported, {len(problems)} problems -> {out / 'manifest.json'}")
    for p in problems:
        print("  " + p)


if __name__ == "__main__":
    if len(sys.argv) == 1:
        main_spec()
    else:
        archive, prefix, out_dir, *ids = sys.argv[1:]
        _, sp = read_rxx(archive, units="Units" in Path(archive).name)
        Path(out_dir).mkdir(parents=True, exist_ok=True)
        for i in map(int, ids):
            print(export(sp, int(prefix), i, out_dir))
