"""Read and write KaM Remake .fntx fonts (layout from src/res/KM_ResFonts.pas LoadFontX and
KM_ResFontsEdit.pas SaveToFontX).

The whole file is one zlib stream holding, little-endian:
  'FNTX' | BaseHeight i16 | WordSpacing i16 | CharSpacing i16 | LineSpacing u8 | Used[65536] u8
  | TKMLetter (24 bytes: Width u16, Height u16, YOffset i16, AtlasId u16, u1 v1 u2 v2 f32) per Used<>0, ascending
  | AtlasCount u8 | TexSizeX u16 | TexSizeY u16 | AtlasCount * TexSizeX*TexSizeY*4 bytes RGBA (R first in memory)

Usage: python fntx.py FILE.fntx [--roundtrip]
"""
import struct
import sys
import zlib
from dataclasses import dataclass, field

import numpy as np

HEAD = b"FNTX"
LETTER = struct.Struct("<HHhHffff")  # 24 bytes, packed record TKMLetter


@dataclass
class Letter:
    w: int
    h: int
    yoff: int
    atlas: int
    u1: float
    v1: float
    u2: float
    v2: float


@dataclass
class Font:
    base_height: int
    word_spacing: int
    char_spacing: int
    line_spacing: int
    letters: dict = field(default_factory=dict)  # codepoint -> Letter (Used[cp] <> 0)
    used_raw: bytes = b""  # original Used[] bytes (values other than 0/1 survive a round trip)
    tex_w: int = 256
    tex_h: int = 512
    atlases: list = field(default_factory=list)  # numpy uint8 arrays (tex_h, tex_w, 4) RGBA


def parse(raw: bytes) -> Font:
    assert raw[:4] == HEAD, "not an FNTX stream"
    bh, ws, cs, ls = struct.unpack_from("<hhhB", raw, 4)
    p = 11
    used = raw[p:p + 65536]
    p += 65536
    f = Font(bh, ws, cs, ls, used_raw=bytes(used))
    for cp in range(65536):
        if used[cp]:
            f.letters[cp] = Letter(*LETTER.unpack_from(raw, p))
            p += LETTER.size
    n, f.tex_w, f.tex_h = struct.unpack_from("<BHH", raw, p)
    p += 5
    size = f.tex_w * f.tex_h * 4
    for _ in range(n):
        f.atlases.append(np.frombuffer(raw[p:p + size], np.uint8).reshape(f.tex_h, f.tex_w, 4).copy())
        p += size
    assert p == len(raw), f"{len(raw) - p} trailing bytes"
    return f


def serialize(f: Font) -> bytes:
    used = bytearray(65536)
    if f.used_raw:
        used[:] = f.used_raw
    for cp in f.letters:
        used[cp] = used[cp] or 1
    assert all((used[cp] != 0) == (cp in f.letters) for cp in range(65536)), "Used[] and letters disagree"
    out = [HEAD, struct.pack("<hhhB", f.base_height, f.word_spacing, f.char_spacing, f.line_spacing), bytes(used)]
    for cp in sorted(f.letters):
        L = f.letters[cp]
        out.append(LETTER.pack(L.w, L.h, L.yoff, L.atlas, L.u1, L.v1, L.u2, L.v2))
    out.append(struct.pack("<BHH", len(f.atlases), f.tex_w, f.tex_h))
    for a in f.atlases:
        assert a.shape == (f.tex_h, f.tex_w, 4) and a.dtype == np.uint8
        out.append(a.tobytes())
    return b"".join(out)


def read(path) -> Font:
    with open(path, "rb") as fh:
        return parse(zlib.decompress(fh.read()))


def read_used(path) -> set:
    """Only the Used[] set, without inflating the atlases."""
    raw = zlib.decompressobj().decompress(open(path, "rb").read(), 11 + 65536)
    assert raw[:4] == HEAD
    return {cp for cp, u in enumerate(raw[11:11 + 65536]) if u}


def write(path, f: Font):
    with open(path, "wb") as fh:
        fh.write(zlib.compress(serialize(f), 9))  # Delphi TCompressionStream(clMax) is level 9 too


def summary(f: Font) -> str:
    hs = [L.h for L in f.letters.values()]
    ys = [L.yoff for L in f.letters.values()]
    return (f"base {f.base_height} word {f.word_spacing} char {f.char_spacing} line {f.line_spacing} | "
            f"glyphs {len(f.letters)} | atlases {len(f.atlases)} x {f.tex_w}x{f.tex_h} | "
            f"h {min(hs)}..{max(hs)} yoff {min(ys)}..{max(ys)}")


if __name__ == "__main__":
    path = sys.argv[1]
    data = open(path, "rb").read()
    raw = zlib.decompress(data)
    font = parse(raw)
    print(path, "|", summary(font))
    if "--roundtrip" in sys.argv:
        again = serialize(font)
        print("  decompressed stream identical:", again == raw, f"({len(raw)} bytes)")
        print("  compressed file identical:   ", zlib.compress(again, 9) == data, f"({len(data)} bytes)")
