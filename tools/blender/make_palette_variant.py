#!/usr/bin/env python3
"""Regional palette variants of the shared 8 x 12 swatch atlas (Dhaba Rush, core-and-feel C6.3).

The NH 48 (Rajasthan) dhaba is the same world with a recoloured palette: Godot puts this atlas on
the dhaba_v3, street_v3 and family_hall meshes only (a per-instance copy of the palette material,
scripts/v3/world/region_look.gd), so people, food, vehicles and UI keep their colours. Only world
swatches change:
  wall paints   -> sandstone pink / ochre (#D9A066, #E8B98A, #C98B5A)
  grass, field and foliage greens -> khaki and dusty olive (#B8A26A, #8C8A4E)
  earth / dust  -> light sand (#E6C99A, with lighter / darker sands for the yard, lot and track
                   shades so the ground keeps its value steps)
Skin, cloth, food, steel, UI and light colours are unchanged. The festive mango-leaf green (MANGO)
stays, so torans still read as fresh leaves.

Plain Python (no Blender, no PIL): reads and writes 8-bit PNGs with zlib.

  python3 -I tools/blender/make_palette_variant.py [--in themes/dhaba/models/palette.png]
                                                    [--out themes/dhaba/models/palette_nh48.png]

It checks that the input atlas is the palette of build_assets.py (every swatch cell's centre),
then repaints whole 16 x 16 cells and prints every swatch it changed.
"""
import os
import re
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
COLS, ROWS, SW = 8, 12, 16

# swatch name -> new hex (NH 48, Rajasthan)
NH48 = {
    # wall paints -> sandstone
    "WALL_PINK": "D9A066", "PLASTER": "E8B98A", "WALL_CREAM": "E8B98A", "KURTA": "E8B98A", "BRICK_RED": "C98B5A",
    # grass / field / foliage greens -> khaki, dusty olive
    "GRASS": "B8A26A", "LIME": "B8A26A", "LEAF_LIGHT": "B8A26A", "NEEM_LT": "B8A26A",
    "LEAF": "8C8A4E", "LIME_DARK": "8C8A4E", "FOLIAGE": "8C8A4E", "NEEM": "8C8A4E",
    # earth / dust -> light sand (and its shades)
    # art audit S11 (4 Nov): a rosy sandstone floor and a Jodhpur-blue wall wash, so the move shows
    "TILE_A": "D99A7E", "TILE_B": "B97A62", "TEAL": "5C9BD6", "DADO": "3E6FA3",
    "DUST": "E6C99A", "DUST_LT": "DCC69C", "DUST_DARK": "D6B57F", "DUST_LOT": "DDC08C", "TRACK": "C9AA76",
}
VARIANTS = {"nh48": NH48}


def palette_from_builder(path=os.path.join(HERE, "build_assets.py")):
    """(hex list, name -> index) parsed from build_assets.py's PALETTE and its range() unpacks."""
    src = open(path, encoding="utf-8").read()
    body = src[src.index("PALETTE = ["):]
    body = body[:body.index("]") + 1]
    hexes = re.findall(r'"([0-9A-Fa-f]{6})"', body)
    names = {}
    for m in re.finditer(r"\(([A-Z0-9_,\s]+)\)\s*=\s*range\((\d+)(?:,\s*(\d+))?\)", src):
        ids = [n.strip() for n in m.group(1).replace("\n", " ").split(",") if n.strip()]
        start = int(m.group(2)) if m.group(3) else 0
        for k, n in enumerate(ids):
            names[n] = start + k
    return hexes, names


def variant_hexes(kind="nh48"):
    """The full 96-entry hex list of a variant (the base palette with its overrides)."""
    hexes, names = palette_from_builder()
    out = list(hexes)
    for n, hx in VARIANTS[kind].items():
        out[names[n]] = hx
    return out


# ---------------------------------------------------------------- PNG io (8-bit, non-interlaced)
def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path + ": not a PNG"
    pos, idat, w = 8, b"", None
    while pos < len(data):
        ln, typ = struct.unpack(">I4s", data[pos:pos + 8])
        chunk = data[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype, _c, _f, inter = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and inter == 0 and ctype in (2, 6), "only 8-bit RGB / RGBA, non-interlaced"
            bpp = 3 if ctype == 2 else 4
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
        pos += 12 + ln
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _y in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append([tuple(line[x:x + 3]) for x in range(0, stride, bpp)])
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    with open(path, "wb") as fh:
        fh.write(png)


def rgb(hx):
    return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))


def main(argv):
    args = argv[1:]
    src = args[args.index("--in") + 1] if "--in" in args else os.path.join(ROOT, "assets", "models", "palette.png")
    kind = args[args.index("--variant") + 1] if "--variant" in args else "nh48"
    dst = (args[args.index("--out") + 1] if "--out" in args
           else os.path.join(ROOT, "assets", "models", "palette_%s.png" % kind))
    hexes, names = palette_from_builder()
    assert len(hexes) == COLS * ROWS, "PALETTE has %d swatches" % len(hexes)
    w, h, rows = read_png(src)
    assert (w, h) == (COLS * SW, ROWS * SW), "atlas is %dx%d, expected %dx%d" % (w, h, COLS * SW, ROWS * SW)
    for idx, hx in enumerate(hexes):                       # the atlas must be this palette
        col, row = idx % COLS, idx // COLS
        got = rows[row * SW + SW // 2][col * SW + SW // 2]
        if max(abs(a - b) for a, b in zip(got, rgb(hx))) > 2:
            raise SystemExit("%s: swatch %d is %s, PALETTE says %s" % (src, idx, "%02X%02X%02X" % got, hx))
    by_index = {i: n for n, i in names.items()}
    changed = []
    for n, hx in VARIANTS[kind].items():
        idx = names[n]
        col, row = idx % COLS, idx // COLS
        c = rgb(hx)
        for y in range(row * SW, (row + 1) * SW):
            for x in range(col * SW, (col + 1) * SW):
                rows[y][x] = c
        changed.append("%s (%d) %s -> %s" % (n, idx, hexes[idx], hx.upper()))
    write_png(dst, w, h, rows)
    print("[palette] %s: %d swatches changed -> %s" % (kind, len(changed), dst))
    for c in changed:
        print("[palette]   " + c)
    assert all(by_index.get(names[n]) == n for n in VARIANTS[kind])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
