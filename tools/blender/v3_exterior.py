"""Dhaba Rush v0.3 - Indian highway exterior (user change requests #10-#12, 2026-10-19/20).

Restyles everything outside the dhaba walls as a North-Indian highway dhaba (GT Road /
Murthal feel) and adds the festive fairy lights. All positions follow Layout3 (sim owner):
side gate z 3.45..4.65 in the x = 9 wall, open-air charpai COURTYARD x 9.3..15, z 0.3..7.9
(tables 2-4 - kept free), TRUCK PARKING bays (PARK_BAYS_X, nose line z 18.0, 7.4 deep, board
over the walkway at (3.8, 0, 17.55)), PEEPAL (-6.8, 0, 20.4), MILESTONE (-5.6, 0, 16.9).

WORLD-COORD glbs (origin = world origin), each exported with several top-level nodes:

  dhaba_v3.glb
    dhaba_v3            store shell + interior (v3_world) + the building-side exterior built
                        here: REAR TERRACE block behind the z = 0 wall (x -0.3..9.2,
                        z -3.6..-0.3, roof y 2.82) carrying the big SIGNBOARD (board only - text
                        by Label3D, see SIGN_TEXT), WEST BLOCK (x -7.45..-0.3, z -3.6..-0.3) with
                        the hand-painted CEMENT ad on its +Z face and a black Sintex-style tank,
                        EAST BLOCK + VERANDAH (tin roof on wooden poles along the back of the
                        courtyard, x 9.2..15.4, front edge z 0.3, y 2.85) with the TYRES and
                        PUMP SETS ads on its x = 15.4 end wall, rooftop buntings and marigold
                        strings, mango-leaf torans (door, chai counter, galla wall), wall fan,
                        film-style posters, the side-gate opening.
    fairy_bulb_<key>    fairy-light bulbs (see below)
    fairy_wire_dhaba    their wires

  street_v3.glb
    street_v3           ground, highway (unchanged lanes / divider / zebra), dusty shoulders,
                        yellow-black kerb along the highway edges only, the courtyard floor +
                        low boundary wall + the KITCHEN ANNEX floor (tiled patch x 9.3..12.25,
                        z 0.3..2.95, drawn in courtyard(); the kadai station
                        stands on it) with table sets 2-4 at (11.0, 6.1), (13.45, 6.1), (13.6, 2.0),
                        the WEST YARD (neem tree on a chabutra, decor
                        charpais, clay tandoor with smoke, bhatti + steel chai kettle, kulhad
                        stacks, matkas, plastic chairs, scooter), pyau + cycle at the front,
                        hand pump, TRUCK PARKING lot (whitewashed stones, lime lines, bay
                        numbers, tyre tracks, PARK board), paan gumti, sugarcane cart, peepal,
                        milestone "NH 44 / DELHI 120 km", electric poles with sagging wires, a
                        parked decorated lorry outside the bays, tyre-puncture corner, temple,
                        fields.
    fairy_bulb_<key>    fairy-light bulbs
    fairy_wire_street   their wires

  dog.glb               sleeping dog (prop, origin on the ground under its middle, head toward
                        +Z) for Layout3.DOG.

FAIRY LIGHTS (for the fixer)
  * Every node whose name starts with "fairy_bulb_" is one string (or one group of strings) of
    small bulbs: 12-tri beads, material `fairy_bulb` = KHR_materials_unlit, so with no
    code Godot shows them UNSHADED in their own colours (vertex colour = albedo).
  * COLOR_0 per vertex: rgb = bulb colour (linear), a = animation code:
        a <  0.5 : twinkle, phase = 2a (0..1, random per bulb)
        a >= 0.5 : chase,   step  = round(4 * (2a - 1)) in 0..3 along the string
  * To animate: give every fairy_bulb_* MeshInstance3D the shared material
        res://themes/dhaba/models/fairy_bulb_material.tres   (ShaderMaterial, shader
        res://themes/dhaba/models/fairy_bulb.gdshader: brightness 0.6..1.0 at 1.5..3 Hz with the
        per-bulb phase, chase strings step every 0.18 s, x1.25 boost so they read brighter
        than the lit scene). One draw call per node, no per-frame CPU work, no lights.
  * Chase strings: fairy_bulb_sign_top, fairy_bulb_sign_bottom, fairy_bulb_gate_board,
    fairy_bulb_parking_board, fairy_bulb_gumti. All the others twinkle.
"""
import math
import random

from mathutils import Vector

# ------------------------------------------------------------------ layout mirrors (Layout3)
COURTYARD = (9.3, 15.0, 0.3, 7.9)            # x0, x1, z0, z1 - keep free: annex floor x 9.3..12.25
                                             # z 0.3..2.95 (drawn here) + table sets 2-4 at (11.0, 6.1),
                                             # (13.45, 6.1), (13.6, 2.0)
ANNEX = (9.3, 12.25, 0.3, 2.95)              # kitchen annex floor (Layout3.ANNEX_MIN / ANNEX_MAX)
SIDE_GATE_Z = (3.45, 4.65)
# bamboo pole for the courtyard's overhead strings on the store's low x = 9 wall, just past
# the side gate's front post (z 4.65..4.89): (x, z)
COURTYARD_WEST_POLE = (9.0, 5.05)
PARK_BAYS_X = (-2.6, 0.3, 7.3, 10.2)
PARK_BAY_W, PARK_NOSE_Z, PARK_DEPTH = 2.9, 18.0, 7.4
PARK_LOT = (-4.3, 11.9, 17.6, 25.6)          # x0, x1, z0, z1
PARK_BOARD = (3.8, 17.55)
WALKWAY_X = (1.75, 5.85)
PEEPAL = (-6.8, 20.4)
MILESTONE = (-5.6, 16.9)
GUMTI = (-6.35, 18.45)                        # paan gumti
MILESTONE_TEXT = []                           # the street build's milestone_text Asset (lot_corner)
TERR_Y = 2.82                                # terrace roof top (= wall cap top)
PAR_H = 0.48                                 # parapet height above the terrace

# Big rooftop signboard (board model only). Front face plane z = SIGN_Z, faces +Z.
SIGN_X, SIGN_Y, SIGN_Z = (1.3, 7.7), (3.12, 4.72), -0.12
# Label3D text areas for the fixer: (text, centre (Godot), max width, cap height, colour,
# font). Face +Z, sit 0.012 in front of the board. Hindi needs a Devanagari font
# (res://assets/fonts/NotoSansDevanagari.ttf or Baloo2.ttf); Godot shapes it correctly.
SIGN_TEXT = (
    ("ढाबा रश", (4.5, 4.36, -0.105), 2.6, 0.34, "FFFFFF", "Baloo2.ttf"),
    ("DHABA RUSH", (4.5, 3.86, -0.105), 4.4, 0.44, "FFD23F", "Baloo2.ttf (main_font)"),
    ("24 घंटे खुला", (3.0, 3.36, -0.105), 2.3, 0.17, "FFFFFF", "NotoSansDevanagari.ttf"),
    ("FAMILY DHABA", (6.0, 3.36, -0.105), 2.3, 0.17, "FFFFFF", "Baloo2.ttf (main_font)"),
)
# A small marigold rosette between the two bottom texts is baked at (4.5, 3.36).
# Static smoke puffs are baked over the outdoor tandoor; optional live smoke (Fx) can rise
# from these points (tandoor mouth, west bhatti kettle).
SMOKE_ANCHORS = ((-1.25, 1.1, 8.35), (-2.92, 0.95, 8.4))


# ------------------------------------------------------------------ small helpers (Godot space)
def _prof(a, label, _last={}):
    """DHABA_PROFILE=1: print the triangles each section added."""
    if not os.environ.get("DHABA_PROFILE"):
        return
    t = a.tris()
    print("[prof] %-28s %6d" % (label, t - _last.get(a.name, 0)))
    _last[a.name] = t


def yrot(p, yaw_deg):
    """Rotate a Godot vector about +Y like Node3D.rotation_degrees.y = yaw_deg."""
    t = math.radians(yaw_deg)
    c, s = math.cos(t), math.sin(t)
    return Vector((p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c))


def local_pts(pts, x, z, yaw, y=0.0):
    o = Vector((x, y, z))
    return [o + yrot(p, yaw) for p in pts]


def at(a, x, z, yaw, fn, y=0.0, s=1.0):
    """fn(a) builds around the origin (Blender or Godot helpers); the new geometry is turned
    by yaw (Godot degrees, == Blender rz) and moved to Godot (x, y, z)."""
    a.place(fn, loc=B(x, y, z), rz=yaw, s=s)
    return a


def _n(r, u):
    return Vector(r).cross(Vector(u)).normalized()


def pdec(a, c, r, u, w, h, color, off=0.0):
    """w x h rectangle centred at Godot c in the plane of unit Godot vectors r (right) and
    u (up), facing r x u, lifted `off` along that normal."""
    r, u = Vector(r), Vector(u)
    n = _n(r, u)
    c = Vector(c) + n * off
    pts = [c - r * (w / 2) - u * (h / 2), c + r * (w / 2) - u * (h / 2), c + r * (w / 2) + u * (h / 2),
           c - r * (w / 2) + u * (h / 2)]
    return a.face([B(*p) for p in pts], color, normal=B(*n))


def ppoly(a, c, r, u, pts2, color, off=0.0):
    """Flat polygon from 2-D points (right, up) around Godot c in the r/u plane."""
    r, u = Vector(r), Vector(u)
    n = _n(r, u)
    c = Vector(c) + n * off
    return a.face([B(*(c + r * p[0] + u * p[1])) for p in pts2], color, normal=B(*n))


def pdisc(a, c, r, u, rad, color, n=12, off=0.0, sx=1.0, sy=1.0, rot=0.0):
    return ppoly(a, c, r, u, [(rad * sx * math.cos(rot + 2 * math.pi * k / n),
                               rad * sy * math.sin(rot + 2 * math.pi * k / n)) for k in range(n)], color, off)


def ptext(a, text, c, r, u, w, h, color, off=0.006, bold=0.03, spacing=1.0):
    c = Vector(c) + _n(r, u) * off
    return text_geo(a, text, tuple(c), tuple(r), tuple(u), w, h, color, bold=bold, spacing=spacing)


def cyl_dec(a, cx, y, cz, rad, t, w, h, color, rot=0.0):
    """w x h decal on the outside of a vertical cylinder (centre cx/cz, radius rad) at angle t."""
    n = Vector((math.cos(t), 0.0, math.sin(t)))
    r = Vector((math.sin(t), 0.0, -math.cos(t)))
    c = Vector((cx, y, cz)) + n * rad
    ca, sa = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    pts = [(u * ca - v * sa, u * sa + v * ca) for (u, v) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2),
                                                             (-w / 2, h / 2))]
    return ppoly(a, c, r, (0, 1, 0), pts, color, 0.0)


def wire(a, pts, r=0.012, color=HAIR, seg=3):
    for i in range(len(pts) - 1):
        p0, p1 = Vector(B(*pts[i])), Vector(B(*pts[i + 1]))
        if (p1 - p0).length > 1e-4:
            a.tube(p0, p1, r, color, seg=seg, caps=False)


def swag_line(pts, sag_per_m=0.05, step=0.22, min_sag=0.04):
    """Polyline through `pts` that sags between consecutive points (Godot)."""
    out = []
    for i in range(len(pts) - 1):
        p0, p1 = Vector(pts[i]), Vector(pts[i + 1])
        L = (p1 - p0).length
        n = max(2, int(L / step))
        seg = gsag(p0, p1, max(min_sag, sag_per_m * L), n)
        out.extend(seg if i == 0 else seg[1:])
    return out


def straight(p0, p1, n=2):
    p0, p1 = Vector(p0), Vector(p1)
    return [p0.lerp(p1, i / n) for i in range(n + 1)]


def toran(a, p0, p1, n=12, sag_amt=0.08, normal=(0, 0, 1), strands=(0.0, 0.5, 1.0), leaf=0.2):
    """Marigold-and-mango-leaf toran between Godot points p0 and p1."""
    pts = gsag(p0, p1, sag_amt, n * 2)
    nb = B(*normal)
    d = (Vector(p1) - Vector(p0)).normalized()
    for i, p in enumerate(pts):
        flower(a, B(*p), 0.045, (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK)[i % 3])
    for i in range(1, len(pts) - 1, 2):
        p = pts[i]
        tip = Vector((p.x, p.y - leaf, p.z))
        side = d * 0.05
        a.face([B(*(p - side)), B(*(p + side)), B(*tip)], MANGO if (i // 2) % 2 == 0 else LIME_DARK, normal=nb)
    for t in strands:
        q = Vector(p0).lerp(Vector(p1), t)
        q.y -= sag_amt * 4 * t * (1 - t)
        for k in range(1, 5):
            flower(a, B(q.x, q.y - k * 0.07, q.z), 0.036, (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK)[k % 3])
    return a


def gbunting(a, p0, p1, sag_amt, flags, colors=(RED, PAINT_YELLOW, GREEN, MARIGOLD, BLUE, NEON_PINK),
             depth=0.2, normal=(0, 0, 1)):
    """Pennant string between Godot points (wraps build_assets.bunting)."""
    return bunting(a, B(*p0), B(*p1), sag_amt, flags, colors, depth=depth, wire=ROPE, normal=B(*normal))


def stone(a, x, z, color=WHITEWASH, r=0.11, rng=None):
    rng = rng or random
    a.ball(r, B(x, 0.03, z), color, seg=5, rings=2,
           scale=(1.0 + rng.uniform(-0.15, 0.2), 0.85 + rng.uniform(-0.1, 0.15), 0.62))


# ------------------------------------------------------------------ reusable props (Blender local)
def matka_geo(b, r=0.22, cloth=None):
    """Clay water pot, origin at its bottom; ~0.5 tall."""
    b.ball(r, (0, 0, r * 0.95), CLAY, seg=8, rings=5, scale=(1.0, 1.0, 0.92))
    b.tube((0, 0, r * 1.7), (0, 0, r * 1.95), r * 0.42, CLAY, r1=r * 0.5, seg=8, caps=False)
    b.tube((0, 0, r * 0.95 - 0.02), (0, 0, r * 0.95 + 0.02), r + 0.004, WHITEWASH, seg=8, caps=False)
    if cloth is not None:
        b.ell((0, 0, r * 1.97), (r * 0.55, r * 0.55, r * 0.12), cloth, seg=8, rings=3)
    return b


def plastic_chair_geo(b, col=RED, legs=True):
    """Moulded plastic chair facing -Y (Godot +Z), seat top 0.44 (~70 tris)."""
    b.box((0.44, 0.42, 0.04), (0, 0, 0.42), col)
    if legs:
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.tube((sx * 0.19, sy * 0.18, 0.41), (sx * 0.22, sy * 0.21, 0.0), 0.025, col, r1=0.02, seg=4,
                       caps=False)
    b.box((0.42, 0.04, 0.4), (0, 0.22, 0.66), col, rot=(-10, 0, 0))
    for sx in (-1, 1):
        b.box((0.04, 0.3, 0.035), (sx * 0.21, 0.04, 0.6), col)
    return b


def chair_stack_geo(b, n=5, col=RED):
    for k in range(n):
        b.place(lambda c, k=k: plastic_chair_geo(c, col, legs=(k == 0)), loc=(0, 0.02 * k, 0.07 * k))
    return b


def kulhad_lo(b, x, y, z, r=0.055, h=0.085):
    b.tube((x, y, z), (x, y, z + h), r * 0.72, CLAY, r1=r, seg=6, caps=False)
    b.face([(x + r * 0.9 * math.cos(k * math.pi / 3), y + r * 0.9 * math.sin(k * math.pi / 3), z + h + 0.001)
            for k in range(6)], BRICK, up=True)
    return b


def scooter_geo(b, col=BLUE):
    """Scooter facing +X, ~1.7 long, 1.0 tall."""
    for x in (-0.55, 0.6):
        b.wheel(0.21, 0.11, (x, 0, 0.21), DARK_STEEL, seg=10)
        b.wheel(0.11, 0.12, (x, 0, 0.21), STEEL, seg=8)
    b.rbox((0.78, 0.42, 0.32), (-0.32, 0, 0.44), col, bevel=0.09, seg=2)
    b.rbox((0.62, 0.3, 0.1), (-0.32, 0, 0.64), TRUNK, bevel=0.04)
    b.rbox((0.4, 0.34, 0.07), (0.18, 0, 0.3), col, bevel=0.02)
    b.rbox((0.12, 0.42, 0.58), (0.48, 0, 0.56), col, rot=(0, 12, 0), bevel=0.04)
    b.rod((0.53, 0, 0.78), (0.6, 0, 1.0), 0.03, DARK_STEEL)
    b.rbox((0.1, 0.64, 0.06), (0.6, 0, 1.01), DARK_STEEL, bevel=0.02)
    b.ball(0.065, (0.66, 0, 0.94), BULB, seg=8, rings=4)
    b.rbox((0.28, 0.16, 0.1), (0.6, 0, 0.36), col, bevel=0.03)
    b.rbox((0.3, 0.2, 0.05), (-0.75, 0, 0.5), RED, bevel=0.015)                    # tail light
    b.decal((-0.05, -0.211, 0.44), 0.4, 0.06, "-y", WHITE)                          # stripe
    return b


def cycle_geo(b, frame_col=DARK_GREEN):
    """Roadster bicycle facing +X with a milk can on the carrier, ~1.7 long."""
    for x in (-0.55, 0.55):
        n = 12
        for k in range(n):
            t0, t1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
            b.rod((x + 0.32 * math.cos(t0), 0, 0.33 + 0.32 * math.sin(t0)),
                  (x + 0.32 * math.cos(t1), 0, 0.33 + 0.32 * math.sin(t1)), 0.022, DARK_STEEL, seg=4)
        b.wheel(0.05, 0.06, (x, 0, 0.33), STEEL, seg=6)
        for k in range(3):
            t = math.pi * k / 3
            b.rod((x - 0.3 * math.cos(t), 0, 0.33 - 0.3 * math.sin(t)), (x + 0.3 * math.cos(t), 0, 0.33 + 0.3 * math.sin(t)),
                  0.006, STEEL, seg=3)
    for (p0, p1) in (((-0.55, 0, 0.33), (-0.1, 0, 0.36)), ((-0.1, 0, 0.36), (0.42, 0, 0.78)), ((-0.18, 0, 0.82), (0.42, 0, 0.78)),
                     ((-0.1, 0, 0.36), (-0.18, 0, 0.82)), ((-0.55, 0, 0.33), (-0.18, 0, 0.82)),
                     ((0.55, 0, 0.33), (0.45, 0, 0.92))):
        b.rod(p0, p1, 0.025, frame_col, seg=5)
    b.rbox((0.22, 0.12, 0.05), (-0.2, 0, 0.87), TRUNK, bevel=0.02)
    b.rod((0.45, -0.28, 0.95), (0.45, 0.28, 0.95), 0.018, STEEL, seg=5)
    b.rbox((0.42, 0.24, 0.03), (-0.55, 0, 0.66), STEEL, bevel=0.01)                 # carrier
    b.tube((-0.55, 0, 0.68), (-0.55, 0, 0.95), 0.11, STEEL, r1=0.09, seg=10)       # milk can
    b.tube((-0.55, 0, 0.95), (-0.55, 0, 1.0), 0.06, STEEL, seg=8)
    b.ball(0.05, (0.62, 0, 0.84), BULB, seg=6, rings=4)
    return b


def kulhad_stack_geo(b, rows=4):
    for n in range(rows, 0, -1):
        z = (rows - n) * 0.085
        for i in range(n):
            kulhad_lo(b, (i - (n - 1) / 2) * 0.11, 0.0, z)
    return b


def bhatti_geo(b):
    """Mud bhatti with a big steel chai kettle and a saucepan; fire mouth faces -Y."""
    b.rbox((0.8, 0.6, 0.55), (0, 0, 0.275), MUD, bevel=0.06, seg=2)
    b.rbox((0.84, 0.64, 0.05), (0, 0, 0.56), CLAY, bevel=0.02)
    b.decal((0, -0.302, 0.25), 0.34, 0.24, "-y", TRUNK)
    b.decal((0, -0.304, 0.22), 0.28, 0.14, "-y", FIRE)
    for i, c in enumerate((FIRE, SAFFRON, MARIGOLD)):
        b.cyl(0.04, 0.12, (-0.08 + i * 0.08, -0.29, 0.14), c, seg=4, r2=0.0, nb=True)
    # big steel kettle (left) + patila of boiling chai (right)
    X = -0.17
    b.tube((X, 0, 0.585), (X, 0, 0.86), 0.2, STEEL, r1=0.15, seg=10, caps=False)
    b.tube((X, 0, 0.86), (X, 0, 0.91), 0.15, STEEL, r1=0.05, seg=10)
    b.ball(0.03, (X, 0, 0.94), DARK_STEEL, seg=6, rings=4)
    b.tube((X + 0.15, 0, 0.66), (X + 0.33, -0.02, 0.86), 0.045, STEEL, r1=0.02, seg=8)
    limb(b, [(X - 0.17, 0, 0.82), (X - 0.1, 0, 1.02), (X + 0.1, 0, 1.02), (X + 0.15, 0, 0.84)], [0.016] * 4,
         DARK_STEEL, seg=5, joint_seg=5, joint_rings=3)
    X2 = 0.22
    b.tube((X2, 0.02, 0.585), (X2, 0.02, 0.74), 0.16, STEEL, seg=10, caps=False)
    disc(b, (X2, 0.02, 0.72), 0.15, CHAI, n=10, facing="+z")
    b.rod((X2 + 0.15, 0.02, 0.7), (X2 + 0.38, 0.06, 0.74), 0.015, DARK_STEEL, seg=4)
    for k in range(3):                                                              # steam
        b.ico(0.05 + 0.015 * k, (X2 - 0.02 + 0.03 * k, 0.04, 0.82 + 0.12 * k), SMOKE, subdiv=0)
    for k in range(3):                                                              # firewood
        b.tube((-0.36, -0.42 + k * 0.1, 0.05), (0.36, -0.4 + k * 0.1, 0.07), 0.04, TRUNK, seg=6)
    return b


def egg_crates_geo(b):
    """Two towers of grey-beige egg trays on a low pallet, eggs on top (~0.4 tall)."""
    b.box((0.62, 0.34, 0.05), (0, 0, 0.025), WOOD)
    for (x, n, ne) in ((-0.15, 8, 3), (0.16, 5, 2)):
        for k in range(n):
            b.box((0.28, 0.28, 0.034), (x, 0, 0.068 + k * 0.036), GRAVEL if k % 3 else KERB)
        z = 0.05 + n * 0.036 + 0.03
        for i in range(ne):
            for j in range(ne):
                b.ell((x + (i - (ne - 1) / 2) * 0.085, (j - (ne - 1) / 2) * 0.085, z), (0.032, 0.032, 0.04),
                      MUD if (i + 2 * j) % 3 == 0 else WHITE, seg=5, rings=3)
    return b


def onion_sacks_geo(b):
    """Two jute sacks, open at the top with red onions peeking out."""
    for (x, y, s) in ((-0.2, 0.02, 1.0), (0.2, -0.04, 0.9)):
        b.ico(0.28 * s, (x, y, 0.22 * s), ROPE, subdiv=1, scale=(1.0, 0.9, 1.0))
        b.tube((x, y, 0.4 * s), (x, y, 0.48 * s), 0.17 * s, ROPE, r1=0.2 * s, seg=7, caps=False)
        for k in range(3):
            t = 2 * math.pi * k / 3
            b.ball(0.065 * s, (x + 0.075 * s * math.cos(t), y + 0.075 * s * math.sin(t), 0.46 * s), PINK, seg=5, rings=3)
        b.ball(0.06 * s, (x, y, 0.51 * s), PINK, seg=5, rings=3)
    return b


def dal_drum_geo(b):
    """Steel storage drum (dal) with dark bands and a lid."""
    b.tube((0, 0, 0), (0, 0, 0.62), 0.22, STEEL, seg=12)
    for z in (0.08, 0.3, 0.52):
        b.tube((0, 0, z), (0, 0, z + 0.035), 0.226, DARK_STEEL, seg=12, caps=False)
    b.tube((0, 0, 0.62), (0, 0, 0.66), 0.235, DARK_STEEL, seg=12)
    b.ball(0.035, (0, 0, 0.675), STEEL, seg=5, rings=3)
    return b


def pav_crate_geo(b):
    """Wooden crate full of pav (golden buns with brown tops)."""
    b.box((0.46, 0.34, 0.2), (0, 0, 0.1), WOOD, nb=True)
    for z in (0.06, 0.15):
        b.decal((0, -0.171, z), 0.44, 0.025, "-y", TRUNK)
    for i in range(3):
        for j in range(2):
            x, y = -0.13 + i * 0.13, -0.075 + j * 0.15
            b.ell((x, y, 0.215), (0.065, 0.07, 0.035), ROTI, seg=6, rings=3)
            b.ell((x, y, 0.235), (0.055, 0.06, 0.022), MUD, seg=6, rings=3)
    return b


def tandoor_out_geo(b, smoke=True):
    """Outdoor clay tandoor on a brick base with a column of smoke; ~1 m tall."""
    b.block((0.95, 0.95, 0.18), (0, 0, 0.0), BRICK_RED)
    b.tube((0, 0, 0.18), (0, 0, 1.0), 0.43, CLAY, r1=0.33, seg=12, caps=False)
    for z, r in ((0.32, 0.41), (0.72, 0.36)):
        b.tube((0, 0, z), (0, 0, z + 0.05), r + 0.006, WHITEWASH, r1=r + 0.002, seg=12, caps=False)
    for k in range(7):
        t = math.radians(-150 + k * 20)
        b.ball(0.022, (0.39 * math.cos(t), 0.39 * math.sin(t), 0.52), WHITEWASH, seg=5, rings=3)
    b.tube((0, 0, 0.99), (0, 0, 1.04), 0.36, MUD, seg=16)
    disc(b, (0, 0, 1.042), 0.27, TRUNK, n=14, facing="+z")
    disc(b, (0, 0, 1.045), 0.2, FIRE, n=12, facing="+z")
    for i, c in enumerate((FIRE, SAFFRON, MARIGOLD)):
        t = 2 * math.pi * i / 3
        b.cyl(0.06, 0.15, (0.07 * math.cos(t), 0.07 * math.sin(t), 1.04), c, seg=5, r2=0.0, nb=True)
    b.rod((0.32, -0.3, 0.0), (0.18, -0.2, 1.25), 0.012, DARK_STEEL, seg=4)            # seekh rod
    if smoke:                     # soft grey puffs drifting back; Fx may add live smoke at SMOKE_ANCHOR
        for k, (dx, dy, dz, r) in enumerate(((0.0, 0.0, 1.22, 0.11), (-0.1, 0.06, 1.48, 0.15),
                                             (-0.26, 0.14, 1.8, 0.19), (-0.48, 0.24, 2.18, 0.22))):
            b.ball(r, (dx, dy, dz), SMOKE, seg=8, rings=4, scale=(1.15, 1.0, 0.8))
            b.ball(r * 0.7, (dx + r * 0.7, dy - 0.03, dz + r * 0.25), SMOKE, seg=7, rings=3)
    return b


def gumti_geo(b):
    """Paan gumti: tin kiosk on legs, open front (-Y) under a propped flap; 1.4 x 1.0."""
    W, D, Y0, H = 1.4, 1.0, 0.3, 1.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.block((0.07, 0.07, Y0), (sx * 0.6, sy * 0.42, 0), DARK_STEEL)
    b.block((W, D, H), (0, 0, Y0), TRUCK_TEAL, nb=False)
    b.block((W + 0.08, D + 0.08, 0.06), (0, 0, Y0 + H), TIN)
    for sx in (-1, 1):                                                               # side art
        b.decal((sx * (W / 2 + 0.002), 0, Y0 + 0.75), 0.6, 0.6, "+x" if sx > 0 else "-x", PAINT_YELLOW, rot=45)
        b.decal((sx * (W / 2 + 0.004), 0, Y0 + 0.75), 0.36, 0.36, "+x" if sx > 0 else "-x", RED, rot=45)
    F = -D / 2 - 0.003
    b.decal((0, F, Y0 + 0.9), W - 0.16, 0.95, "-y", TARP)                            # opening
    for z in (Y0 + 0.65, Y0 + 1.05):                                                 # shelves + jars
        b.decal((0, F - 0.002, z), W - 0.2, 0.03, "-y", WOOD)
        for k in range(6):
            b.decal((-0.5 + k * 0.2, F - 0.004, z + 0.09), 0.12, 0.16, "-y",
                    (RED, PAINT_YELLOW, GLASS, MARIGOLD, GREEN, PINK)[(k + int(z * 10)) % 6])
    for k in range(7):                                                               # hanging packet strips
        b.decal((-0.6 + k * 0.2, F - 0.006, Y0 + 1.2), 0.1, 0.3, "-y",
                (NEON_PINK, PAINT_YELLOW, BLUE, GREEN, RED, MARIGOLD, NEON_CYAN)[k])
    b.rbox((W + 0.04, 0.22, 0.06), (0, -D / 2 - 0.09, Y0 + 0.42), WOOD, bevel=0.015)  # counter
    b.rbox((0.7, 0.2, 0.012), (-0.2, -D / 2 - 0.09, Y0 + 0.456), RED, bevel=0.004)
    for k in range(5):                                                               # paan leaves
        b.ell((-0.45 + k * 0.12, -D / 2 - 0.09, Y0 + 0.47), (0.05, 0.035, 0.008), LIME_DARK, seg=6, rings=3)
    b.tube((0.45, -D / 2 - 0.09, Y0 + 0.45), (0.45, -D / 2 - 0.09, Y0 + 0.58), 0.05, GOLD, r1=0.035, seg=8)
    # propped flap awning
    b.face([(-W / 2 - 0.05, -D / 2, Y0 + H), (W / 2 + 0.05, -D / 2, Y0 + H), (W / 2 + 0.05, -D / 2 - 0.6, Y0 + H + 0.22),
            (-W / 2 - 0.05, -D / 2 - 0.6, Y0 + H + 0.22)], TIN_BLUE, normal=(0, -0.3, 1))
    for sx in (-1, 1):
        b.rod((sx * 0.62, -D / 2 - 0.55, Y0 + 0.44), (sx * 0.62, -D / 2 - 0.55, Y0 + H + 0.2), 0.015, TRUNK, seg=4)
    # PAAN board on the roof (Godot-local helpers; the caller's place() moves it too)
    b.block((0.9, 0.05, 0.32), (0, -0.2, Y0 + H + 0.06), PAINT_YELLOW)
    framed_board(b, (0.0, Y0 + H + 0.22, 0.235), 0.82, 0.28, "paan")
    return b


def cart_geo(b):
    """Sugarcane-juice cart (long side X, handles +X) with the crusher and a cane bundle."""
    b.rbox((1.6, 0.9, 0.1), (0, 0, 0.6), WOOD, bevel=0.02)
    for sy in (-1, 1):
        b.wheel(0.32, 0.06, (-0.3, sy * 0.5, 0.32), TRUNK, seg=10)
        b.wheel(0.12, 0.07, (-0.3, sy * 0.5, 0.32), PAINT_YELLOW, seg=6)
    for sy in (-1, 1):
        b.rod((0.8, sy * 0.3, 0.6), (1.4, sy * 0.3, 0.45), 0.025, TRUNK, seg=4)
    for (sx, sy) in ((-0.7, -0.35), (0.7, -0.35), (-0.7, 0.35), (0.7, 0.35)):
        b.rod((sx, sy, 0.65), (sx, sy, 1.9), 0.02, DARK_STEEL, seg=4)
    b.block((1.9, 1.1, 0.06), (0, 0, 1.9), MARIGOLD)
    b.decal((0, -0.553, 1.93), 1.9, 0.06, "-y", GREEN)
    for k in range(7):                                                               # cane bundle
        b.rod((-0.6, -0.3 + k * 0.1, 0.72 + (k % 2) * 0.06), (0.6, -0.3 + k * 0.1, 0.72 + (k % 2) * 0.06), 0.03,
              LIME_DARK, seg=5)
    b.rbox((0.5, 0.4, 0.5), (0.4, 0.0, 0.9), DADO, bevel=0.02)                      # crusher
    b.wheel(0.22, 0.05, (0.4, -0.23, 0.98), STEEL, seg=12)
    b.rod((0.4, -0.27, 0.98), (0.4, -0.27, 1.3), 0.02, DARK_STEEL, seg=4)
    # core-and-feel W3-LOOK (lead decision 9): the juice glasses use WALL_GREEN (#9ED98B, pale green)
    # and the lemons NOTE (#86D07A, lime green), like the door nimbu-mirchi (W1-FIX-other):
    # palette_nh48.png repaints LEAF_LIGHT and LIME (foliage swatches) khaki, these two it keeps.
    for k in range(4):                                                               # glasses of juice
        b.tube((-0.65 + k * 0.12, -0.25, 0.65), (-0.65 + k * 0.12, -0.25, 0.79), 0.035, WALL_GREEN, r1=0.04, seg=8)
    b.ico(0.08, (-0.3, 0.25, 0.72), NOTE, subdiv=0)                                  # lemons
    b.ico(0.08, (-0.15, 0.28, 0.72), NOTE, subdiv=0)
    return b


def dog_geo(b):
    """Sleeping street dog curled up (Blender local), head toward -Y (Godot +Z)."""
    b.ell((0, 0.02, 0.12), (0.3, 0.2, 0.12), DOG, seg=12, rings=6)                     # body
    b.ell((-0.2, 0.05, 0.13), (0.14, 0.15, 0.11), DOG, seg=10, rings=6)               # haunch
    b.ell((0.06, -0.12, 0.17), (0.14, 0.1, 0.1), WHITE, seg=10, rings=6)               # chest patch
    b.ell((0.2, -0.17, 0.1), (0.12, 0.11, 0.085), DOG, seg=10, rings=6)               # head on paws
    b.ell((0.31, -0.21, 0.08), (0.07, 0.055, 0.045), DOG, seg=8, rings=5)             # snout
    b.ell((0.37, -0.23, 0.085), (0.02, 0.018, 0.016), HAIR, seg=6, rings=3)           # nose
    for s in (-1, 1):                                                               # ears (floppy)
        b.ell((0.15 + 0.02 * s, -0.12 + 0.07 * s, 0.17), (0.05, 0.035, 0.022), TRUNK, seg=6, rings=3)
    b.ell((0.24, -0.27, 0.13), (0.025, 0.006, 0.004), HAIR, seg=4, rings=2)            # closed eye
    b.ell((0.15, -0.3, 0.035), (0.13, 0.04, 0.035), DOG, seg=8, rings=4)              # front paws
    b.ell((0.24, -0.3, 0.035), (0.04, 0.035, 0.03), WHITE, seg=6, rings=3)
    limb(b, [(-0.32, 0.08, 0.1), (-0.32, -0.12, 0.05), (-0.15, -0.28, 0.04), (0.02, -0.3, 0.04)],
         [0.04, 0.035, 0.03, 0.024], DOG, seg=6, joint_seg=6, joint_rings=4)               # tail round the front
    b.ell((0.04, -0.3, 0.04), (0.04, 0.025, 0.024), WHITE, seg=6, rings=3)
    return b


# ------------------------------------------------------------------ painted wall ads
def wall_ad(a, c, r, u, w, h, kind):
    """Hand-painted wall ad (fictional, generic brands) on plaster. c = centre on the wall
    surface (Godot), r / u = unit right / up vectors of the wall plane (ad faces r x u)."""
    r, u = Vector(r), Vector(u)
    c = Vector(c)

    def q(dx, dy):
        return c + r * dx + u * dy
    pdec(a, c, r, u, w, h, WHITEWASH, 0.004)
    if kind == "cement":
        pdec(a, c, r, u, w - 0.1, h - 0.1, PAINT_YELLOW, 0.006)
        pdec(a, q(0, h * 0.27), r, u, w - 0.1, h * 0.36, RED, 0.008)
        ptext(a, "PAKKA CEMENT", q(0, h * 0.27), r, u, w * 0.84, h * 0.22, WHITE, off=0.01, bold=0.035)
        bx = -w * 0.32                                                                  # cement bag
        pdec(a, q(bx, -h * 0.17), r, u, w * 0.17, h * 0.42, CONCRETE, 0.01)
        pdec(a, q(bx, -h * 0.1), r, u, w * 0.17, h * 0.08, RED, 0.012)
        ppoly(a, q(bx, -h * 0.25), r, u, [(-0.12, -0.05), (0.12, -0.05), (0.0, 0.08)], RED, 0.012)
        ptext(a, "STRONG AS A", q(w * 0.12, -h * 0.07), r, u, w * 0.55, h * 0.14, RED, off=0.01, bold=0.03)
        ptext(a, "TRUCK", q(w * 0.12, -h * 0.29), r, u, w * 0.4, h * 0.2, BLUE, off=0.01, bold=0.04)
        pdec(a, q(0, -h * 0.47), r, u, w - 0.1, h * 0.04, RED, 0.008)
    elif kind == "tyres":
        pdec(a, c, r, u, w - 0.1, h - 0.1, WALL_BLUE, 0.006)
        tx = -w * 0.26
        pdisc(a, q(tx, -h * 0.05), r, u, h * 0.36, DARK_STEEL, n=18, off=0.008)
        for k in range(12):
            t = 2 * math.pi * k / 12
            pdec(a, q(tx + h * 0.33 * math.cos(t), -h * 0.05 + h * 0.33 * math.sin(t)), r, u, h * 0.07, h * 0.07,
                 SLATE, 0.01)
        pdisc(a, q(tx, -h * 0.05), r, u, h * 0.22, SLATE, n=16, off=0.012)
        pdisc(a, q(tx, -h * 0.05), r, u, h * 0.13, STEEL, n=12, off=0.014)
        pdisc(a, q(tx, -h * 0.05), r, u, h * 0.04, DARK_STEEL, n=8, off=0.016)
        ptext(a, "SADAK", q(w * 0.2, h * 0.24), r, u, w * 0.5, h * 0.26, PAINT_YELLOW, off=0.01, bold=0.045)
        ptext(a, "TYRES", q(w * 0.2, -h * 0.04), r, u, w * 0.46, h * 0.24, WHITE, off=0.01, bold=0.045)
        pdec(a, q(w * 0.2, -h * 0.3), r, u, w * 0.5, h * 0.15, RED, 0.008)
        ptext(a, "RUNS & RUNS", q(w * 0.2, -h * 0.3), r, u, w * 0.44, h * 0.09, WHITE, off=0.012, bold=0.03)
    else:  # "pump"
        pdec(a, c, r, u, w - 0.1, h - 0.1, WALL_GREEN, 0.006)
        px = -w * 0.3
        pdec(a, q(px, -h * 0.12), r, u, w * 0.16, h * 0.3, BLUE, 0.008)                  # motor
        pdisc(a, q(px, -h * 0.12), r, u, h * 0.1, STEEL, n=10, off=0.01)
        pdec(a, q(px + w * 0.06, h * 0.1), r, u, w * 0.04, h * 0.24, DARK_STEEL, 0.009)  # pipe
        pdec(a, q(px + w * 0.11, h * 0.21), r, u, w * 0.1, h * 0.04, DARK_STEEL, 0.009)
        for k in range(5):                                                              # water jet
            pdisc(a, q(px + w * 0.17 + k * w * 0.035, h * 0.16 - k * k * h * 0.02), r, u, h * 0.035, GLASS, n=8, off=0.011)
        ptext(a, "KHET", q(w * 0.17, h * 0.27), r, u, w * 0.4, h * 0.2, RED, off=0.01, bold=0.045)
        ptext(a, "PUMP SETS", q(w * 0.17, h * 0.02), r, u, w * 0.6, h * 0.2, DARK_GREEN, off=0.01, bold=0.04)
        pdec(a, q(w * 0.17, -h * 0.26), r, u, w * 0.56, h * 0.15, PAINT_YELLOW, 0.008)
        ptext(a, "PAANI HI PAANI", q(w * 0.17, -h * 0.26), r, u, w * 0.5, h * 0.09, DARK_GREEN, off=0.012, bold=0.03)
    return a


def framed_board(a, c, w, h, kind, r=(1, 0, 0), u=(0, 1, 0)):
    """Framed shop board facing r x u: 'family_open24', 'family', 'open24', 'puncture', 'pyau',
    'paan'."""
    r, u = Vector(r), Vector(u)
    n = _n(r, u)
    c = Vector(c)
    # slab
    ppoly(a, c - n * 0.04, r, u, [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], WOOD, 0.0)
    pdec(a, c, r, u, w, h, WOOD, 0.0)
    if kind == "family_open24":
        # GOLD frame; JACKET field (top 60 %) with FAMILY DHABA, PAINT_YELLOW strip (bottom 40 %)
        # with OPEN 24 HRS
        pdec(a, c, r, u, w - 0.07, h - 0.07, GOLD, 0.004)
        iw, ih = w - 0.13, h - 0.13
        ct, cb = c + u * (ih * 0.2), c - u * (ih * 0.3)
        pdec(a, ct, r, u, iw, ih * 0.6, JACKET, 0.006)
        pdec(a, cb, r, u, iw, ih * 0.4, PAINT_YELLOW, 0.006)
        ptext(a, "FAMILY DHABA", ct, r, u, iw * 0.9, ih * 0.6 * 0.66, PAINT_YELLOW, off=0.008, bold=0.04)
        ptext(a, "OPEN 24 HRS", cb, r, u, iw * 0.8, ih * 0.4 * 0.7, RED, off=0.008, bold=0.04)
    elif kind == "family":
        pdec(a, c, r, u, w - 0.07, h - 0.07, GOLD, 0.004)
        pdec(a, c, r, u, w - 0.13, h - 0.13, JACKET, 0.006)
        ptext(a, "FAMILY DHABA", c, r, u, w * 0.84, h * 0.46, PAINT_YELLOW, off=0.008, bold=0.04)
    elif kind == "open24":
        pdec(a, c, r, u, w - 0.07, h - 0.07, PAINT_YELLOW, 0.004)
        ptext(a, "OPEN 24 HRS", c, r, u, w * 0.84, h * 0.46, RED, off=0.008, bold=0.04)
    elif kind == "puncture":
        pdec(a, c, r, u, w - 0.07, h - 0.07, PAINT_YELLOW, 0.004)
        ptext(a, "PUNCTURE", c, r, u, w * 0.84, h * 0.5, RED, off=0.008, bold=0.045)
    elif kind == "pyau":
        pdec(a, c, r, u, w - 0.07, h - 0.07, DADO, 0.004)
        ptext(a, "PYAU", c, r, u, w * 0.7, h * 0.5, WHITE, off=0.008, bold=0.04)
    elif kind == "paan":
        pdec(a, c, r, u, w - 0.07, h - 0.07, PAINT_YELLOW, 0.004)
        ptext(a, "PAAN", c, r, u, w * 0.7, h * 0.6, RED, off=0.008, bold=0.05)
    return a


# ------------------------------------------------------------------ dhaba_v3 additions
def ext_dhaba(a, fs):
    """Building-side exterior + interior decor, added to the dhaba_v3 Asset `a`; strings
    go to FairySet `fs`."""
    rng = random.Random(11)
    _prof(a, "dhaba base")
    blocks(a, rng)
    _prof(a, "blocks+ads")
    terrace_dressing(a, fs, rng)
    _prof(a, "terrace")
    signboard(a, fs)
    _prof(a, "signboard")
    east_verandah(a, fs)
    _prof(a, "verandah")
    side_gate(a)
    door_and_interior(a, fs)
    _prof(a, "door+interior")
    parapet_lights(fs)


def blocks(a, rng):
    # rear block (behind the z = 0 wall), west block, east block (behind the verandah)
    gbox(a, -0.3, 9.2, 0.0, 2.7, -3.6, -0.3, WALL_PINK)
    gbox(a, -7.45, -0.3, 0.0, 2.7, -3.6, -0.3, WALL_CREAM)
    gbox(a, 9.2, 15.45, 0.0, 2.7, -3.6, -2.3, WALL_PINK)
    gbox(a, -7.5, 15.5, 2.7, TERR_Y, -3.65, -0.3, CONCRETE)
    gbox(a, 9.2, 15.5, 2.7, TERR_Y, -2.3, -2.05, CONCRETE)
    a.grect(-7.45, -3.4, 15.25, -0.36, TERR_Y + 0.002, MORTAR)
    for k in range(9):                                                                # rain stains
        gdec(a, rng.uniform(-6.5, 14.5), TERR_Y + 0.004, rng.uniform(-3.2, -0.6), rng.uniform(0.4, 1.0), 0.08,
             "+y", CONCRETE, rot=rng.uniform(0, 180))
    # parapets: back (z -3.65..-3.4), west end, east end, front of the west & east blocks
    P1 = TERR_Y + PAR_H
    gbox(a, -7.5, 15.5, TERR_Y, P1, -3.65, -3.4, WALL_PINK)
    gbox(a, -7.5, -7.25, TERR_Y, P1, -3.4, -0.3, WALL_CREAM)
    gbox(a, 15.25, 15.5, TERR_Y, P1, -3.4, -2.05, WALL_PINK)
    gbox(a, -7.25, -0.36, TERR_Y, P1, -0.55, -0.3, WALL_CREAM)
    gbox(a, 9.25, 15.25, TERR_Y, P1, -2.3, -2.05, WALL_PINK)
    for (x0, x1, z0, z1) in ((-7.55, 15.55, -3.7, -3.35), (-7.55, -7.2, -3.35, -0.25), (15.2, 15.55, -3.35, -2.0),
                             (-7.2, -0.36, -0.6, -0.25), (9.2, 15.2, -2.35, -2.0)):
        gbox(a, x0, x1, P1, P1 + 0.05, z0, z1, WHITEWASH)
    # jaali-style painted diamonds on the inner face of the back parapet (seen over the roof)
    for k in range(30):
        x = -7.0 + k * 0.75
        gdec(a, x, TERR_Y + 0.24, -3.398, 0.16, 0.16, "+z", (MARIGOLD, DADO, NEON_PINK)[k % 3], rot=45)
    # west block front (+Z face, x -7.45..-0.3, faces the highway): plaster, dado, CEMENT ad
    gdec(a, -3.875, 0.3, -0.297, 7.1, 0.6, "+z", BRICK_RED)
    wall_ad(a, (-5.55, 1.58, -0.295), (1, 0, 0), (0, 1, 0), 3.3, 1.85, "cement")
    wall_ad(a, (-2.0, 1.58, -0.295), (1, 0, 0), (0, 1, 0), 3.0, 1.85, "pump")
    # east end wall x = 15.45 (block + verandah end): TYRES and PUMP SETS ads facing +X
    gbox(a, 15.25, 15.45, 0.0, 2.7, -2.3, 0.3, WALL_PINK)
    gdec(a, 15.452, 0.25, -1.65, 3.9, 0.5, "+x", BRICK_RED)
    wall_ad(a, (15.455, 1.45, -1.0), (0, 0, -1), (0, 1, 0), 2.4, 1.9, "tyres")
    window(a, (15.452, 1.6, -2.95), 0.7, 0.7, "+x")


def terrace_dressing(a, fs, rng):
    # black Sintex-style tank on the west block + a second one on the east block
    for (tx, tz, s) in ((-2.4, -2.1, 1.0), (13.4, -2.9, 0.85)):
        gbox(a, tx - 0.5 * s, tx + 0.5 * s, TERR_Y, TERR_Y + 0.34, tz - 0.5 * s, tz + 0.5 * s, BRICK_RED)
        gbox(a, tx - 0.54 * s, tx + 0.54 * s, TERR_Y + 0.34, TERR_Y + 0.39, tz - 0.54 * s, tz + 0.54 * s, CONCRETE)
        y0 = TERR_Y + 0.39
        gtube(a, (tx, y0, tz), (tx, y0 + 0.95 * s, tz), 0.48 * s, TANK, r1=0.45 * s, seg=14)
        for k in range(4):
            y = y0 + (0.1 + k * 0.22) * s
            rr = (0.48 - 0.03 * (y - y0) / 0.95) * s + 0.008
            gtube(a, (tx, y, tz), (tx, y + 0.045 * s, tz), rr, DARK_STEEL, seg=14, caps=False)
        a.ell(B(tx, y0 + 0.95 * s, tz), (0.45 * s, 0.45 * s, 0.16 * s), TANK, seg=14, rings=4)
        gtube(a, (tx, y0 + 1.06 * s, tz), (tx, y0 + 1.15 * s, tz), 0.16 * s, DARK_STEEL, seg=10)
        gtube(a, (tx + 0.47 * s, TERR_Y + 0.05, tz), (tx + 0.47 * s, y0 + 0.15, tz), 0.03, WHITEWASH, seg=5)
    # stair head-room (mumty) on the west block with a door and a saffron pennant
    mx0, mx1, mz0, mz1 = -6.9, -5.4, -3.3, -2.0
    gbox(a, mx0, mx1, TERR_Y, TERR_Y + 2.0, mz0, mz1, WALL_CREAM)
    gbox(a, mx0 - 0.08, mx1 + 0.08, TERR_Y + 2.0, TERR_Y + 2.1, mz0 - 0.08, mz1 + 0.08, CONCRETE)
    gdec(a, -6.15, TERR_Y + 0.85, mz1 + 0.003, 0.7, 1.6, "+z", TRUCK_TEAL)
    gdec(a, -6.15, TERR_Y + 1.73, mz1 + 0.006, 0.7, 0.1, "+z", MARIGOLD)
    gdec(a, mx1 + 0.003, TERR_Y + 1.2, -2.65, 0.6, 0.5, "+x", NAVY)
    for k in range(3):
        gdec(a, mx1 + 0.006, TERR_Y + 1.2, -2.85 + k * 0.2, 0.03, 0.5, "+x", STEEL)
    # red chillies + yellow haldi drying on mats (rear terrace, behind the signboard's side)
    for (x, z, col) in ((0.4, -1.6, RED), (1.4, -2.6, RED), (8.2, -0.9, PAINT_YELLOW)):
        a.grect(x - 0.45, z - 0.35, x + 0.45, z + 0.35, TERR_Y + 0.006, ROPE)
        a.grect(x - 0.38, z - 0.28, x + 0.38, z + 0.28, TERR_Y + 0.009, col)
    # dish antenna, clothesline, pots, bamboo flag pole on the rear terrace
    gtube(a, (0.6, TERR_Y, -2.9), (0.6, TERR_Y + 0.75, -2.9), 0.03, DARK_STEEL, seg=5)
    a.ell(B(0.62, TERR_Y + 0.9, -2.82), (0.34, 0.34, 0.07), WHITE, seg=12, rings=3)
    for x in (-5.0, -3.2):
        gtube(a, (x, TERR_Y, -3.0), (x, TERR_Y + 1.25, -3.0), 0.025, DARK_STEEL, seg=4)
    wire(a, [(-5.0, TERR_Y + 1.2, -3.0), (-3.2, TERR_Y + 1.2, -3.0)], r=0.008)
    for k, col in enumerate((RED, PAINT_YELLOW, BLUE, NEON_PINK)):
        gbox(a, -4.85 + k * 0.42, -4.55 + k * 0.42, TERR_Y + 0.72, TERR_Y + 1.19, -3.02, -2.98, col)
    for (x, z) in ((-6.8, -0.95), (14.6, -2.75)):
        a.place(lambda b: plant_geo(b, 0.75), loc=B(x, TERR_Y, z))
    fx, fz = 9.6, -3.0
    gtube(a, (fx, TERR_Y, fz), (fx, TERR_Y + 2.4, fz), 0.035, BAMBOO, seg=6)
    a.face([B(fx, TERR_Y + 2.4, fz), B(fx + 0.75, TERR_Y + 2.2, fz), B(fx, TERR_Y + 1.95, fz)], SAFFRON, normal=(0, -1, 0))
    # rooftop buntings: along the back parapet on short bamboo stubs, and diagonals to the flag
    stubs = [(-7.35, -3.5), (-2.8, -3.5), (2.0, -3.5), (6.0, -3.5), (9.6, -3.5), (15.35, -3.5)]
    for (x, z) in stubs:
        gtube(a, (x, TERR_Y + PAR_H, z), (x, TERR_Y + PAR_H + 0.75, z), 0.025, BAMBOO, seg=5)
    for i in range(len(stubs) - 1):
        (x0, z0), (x1, z1) = stubs[i], stubs[i + 1]
        n = max(6, int(abs(x1 - x0) / 0.38))
        gbunting(a, (x0, TERR_Y + PAR_H + 0.72, z0), (x1, TERR_Y + PAR_H + 0.72, z1), 0.28, n, depth=0.2)
    top = (fx, TERR_Y + 2.3, fz)
    for p in ((15.3, TERR_Y + PAR_H + 0.3, -2.15), (8.85, TERR_Y + 0.08, -0.55)):
        gbunting(a, top, p, 0.25, 12, colors=(SAFFRON, WHITE, GREEN, MARIGOLD, PINK), depth=0.18)
    # marigold strings hanging along the back parapet and the west block front parapet
    for (x0, x1, z, y) in ((-7.3, 15.3, -3.34, TERR_Y + PAR_H), (-7.2, -0.4, -0.24, TERR_Y + PAR_H)):
        n = int((x1 - x0) / 1.2)
        for i in range(n):
            xa, xb = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
            pts = gsag((xa, y, z), (xb, y, z), 0.2, 6)
            for j, p in enumerate(pts[1:-1]):
                flower(a, B(*p), 0.05, (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK)[j % 3])


def signboard(a, fs):
    x0, x1 = SIGN_X
    y0, y1 = SIGN_Y
    Z = SIGN_Z
    cx = (x0 + x1) / 2
    # steel legs + braces from the rear terrace
    for x in (x0 + 0.35, cx, x1 - 0.35):
        gtube(a, (x, TERR_Y, -0.5), (x, y0 + 0.1, Z - 0.06), 0.04, DARK_STEEL, seg=5)
        gtube(a, (x, TERR_Y, -1.7), (x, y0 + 0.75, Z - 0.07), 0.032, DARK_STEEL, seg=5)
        gbox(a, x - 0.12, x + 0.12, TERR_Y, TERR_Y + 0.08, -1.82, -0.38, CONCRETE)
    gbox(a, x0 + 0.1, x1 - 0.1, y0 + 0.2, y0 + 0.26, Z - 0.16, Z - 0.08, DARK_STEEL)
    # board: marigold border slab, maroon field, green bottom strip
    gbox(a, x0, x1, y0, y1, Z - 0.08, Z, MARIGOLD, bevel=0.02)
    R, U = (1, 0, 0), (0, 1, 0)
    pdec(a, (cx, 4.07, Z), R, U, x1 - x0 - 0.22, 1.06, JACKET, 0.004)
    pdec(a, (cx, 3.36, Z), R, U, x1 - x0 - 0.22, 0.3, DARK_GREEN, 0.004)
    pdec(a, (cx, 3.525, Z), R, U, x1 - x0 - 0.22, 0.03, GOLD, 0.006)
    pdec(a, (cx, 4.6, Z), R, U, x1 - x0 - 0.22, 0.03, GOLD, 0.006)
    # rosettes at both ends of the main field (painted marigold flowers)
    for x in (x0 + 0.5, x1 - 0.5):
        for k, (rad, col) in enumerate(((0.3, PAINT_YELLOW), (0.24, MARIGOLD), (0.15, RED), (0.07, PAINT_YELLOW))):
            pdisc(a, (x, 4.1, Z), R, U, rad, col, n=16 if k < 2 else 10, off=0.006 + 0.002 * k)
        for k in range(8):
            t = 2 * math.pi * k / 8
            pdisc(a, (x + 0.27 * math.cos(t), 4.1 + 0.27 * math.sin(t), Z), R, U, 0.06, MARIGOLD_DARK, n=8, off=0.014)
    # small marigold rosette between the two bottom texts
    for k, (rad, col) in enumerate(((0.1, PAINT_YELLOW), (0.07, MARIGOLD), (0.035, RED))):
        pdisc(a, (cx, 3.36, Z), R, U, rad, col, n=12 if k < 2 else 8, off=0.006 + 0.002 * k)
    # pennant crest on top
    for k in range(12):
        x = x0 + 0.3 + k * (x1 - x0 - 0.6) / 11
        a.face([B(x - 0.13, y1, Z - 0.04), B(x + 0.13, y1, Z - 0.04), B(x, y1 + 0.24, Z - 0.04)],
               (RED, PAINT_YELLOW, GREEN, NEON_PINK, BLUE, MARIGOLD)[k % 6], normal=(0, -1, 0))
    # marigold strands hanging under the board
    for k in range(9):
        x = x0 + 0.4 + k * (x1 - x0 - 0.8) / 8
        for j in range(4):
            flower(a, B(x, y0 - 0.05 - j * 0.07, Z - 0.02), 0.042, (MARIGOLD, PAINT_YELLOW)[j % 2])
    # marquee bulbs (chase)
    fs.string("sign_top", straight((x0 + 0.08, y1 + 0.04, Z + 0.035), (x1 - 0.08, y1 + 0.04, Z + 0.035)),
              spacing=0.24, r=0.05, colors=FAIRY_GOLDS, chase=True, wire=False)
    fs.string("sign_bottom", straight((x0 + 0.08, y0 + 0.06, Z + 0.035), (x1 - 0.08, y0 + 0.06, Z + 0.035)),
              spacing=0.24, r=0.05, colors=FAIRY_GOLDS, chase=True, wire=False)


def east_verandah(a, fs):
    """Lean-to tin verandah along the back of the courtyard: from the east block's front
    parapet (z -2.3, y 3.3) down to wooden poles on z 0.22 (front edge y 2.85)."""
    X0, X1 = 9.2, 15.25
    ZB, ZF = -2.2, 0.32
    YB, YF = TERR_Y + PAR_H + 0.07, 2.86
    n = 18
    for i in range(n):
        xa, xb = X0 + (X1 - X0) * i / n, X0 + (X1 - X0) * (i + 1) / n
        col = (TIN, TIN_BLUE, TIN, RUST if i % 7 == 3 else TIN_BLUE)[i % 4]
        a.face([B(xa, YB, ZB), B(xb, YB, ZB), B(xb, YF, ZF), B(xa, YF, ZF)], col, up=True)
        a.face([B(xa + 0.02, YB + 0.005, ZB), B(xa + 0.05, YB + 0.005, ZB), B(xa + 0.05, YF + 0.005, ZF),
                B(xa + 0.02, YF + 0.005, ZF)], DARK_STEEL if col != TIN else TIN_BLUE, up=True)
    # fascia beam with painted triangles
    gbox(a, X0, X1, YF - 0.16, YF + 0.02, ZF - 0.04, ZF + 0.06, WOOD)
    for k in range(int((X1 - X0) / 0.3)):
        x = X0 + 0.15 + k * 0.3
        a.face([B(x - 0.12, YF - 0.01, ZF + 0.062), B(x + 0.12, YF - 0.01, ZF + 0.062), B(x, YF - 0.15, ZF + 0.062)],
               (RED, PAINT_YELLOW, GREEN)[k % 3], normal=(0, -1, 0))
    # wooden poles with painted bands (front edge z 0.12..0.3, outside the courtyard)
    for x in (9.42, 11.35, 13.3, 15.1):
        gbox(a, x - 0.07, x + 0.07, 0.0, YF - 0.15, 0.13, 0.27, TRUNK, bevel=0.012)
        for (yy, col) in ((0.15, RED), (0.3, WHITEWASH), (0.45, RED), (0.6, WHITEWASH)):
            gbox(a, x - 0.075, x + 0.075, yy, yy + 0.12, 0.125, 0.275, col)
        gbox(a, x - 0.12, x + 0.12, -0.02, 0.08, 0.08, 0.32, CONCRETE)
        gtube(a, (x, YF - 0.5, 0.2), (x, YF - 0.12, -0.25), 0.03, TRUNK, seg=4)     # knee brace
    # rafters (seen through the front edge)
    for x in (10.4, 12.3, 14.2):
        gtube(a, (x, YB - 0.08, ZB), (x, YF - 0.08, ZF), 0.04, TRUNK, seg=4)
    # boards hanging from the fascia (face +Z)
    for (x, w, kind) in ((10.35, 1.25, "family_open24"), (12.32, 1.55, "family"), (14.22, 1.25, "open24")):
        framed_board(a, (x, YF - 0.48, ZF + 0.1), w, 0.42, kind)
        for dx in (-w * 0.35, w * 0.35):
            gtube(a, (x + dx, YF - 0.27, ZF + 0.08), (x + dx, YF - 0.15, ZF + 0.03), 0.008, DARK_STEEL, seg=3)
    # under the verandah front, behind the kitchen annex: kitchen stores (egg crates, onion
    # sacks, dal drum, pav crate), water cooler, matkas, chair stack (all at z <= 0.1)
    at(a, 11.0, -0.35, 0, egg_crates_geo)
    at(a, 11.6, -0.3, 0, onion_sacks_geo)
    at(a, 12.4, -0.4, 0, dal_drum_geo)
    at(a, 12.9, -0.3, 8, pav_crate_geo)
    gbox(a, 13.65, 14.25, 0.0, 0.92, -0.55, -0.1, STEEL, bevel=0.03)                 # water cooler
    gdec(a, 13.95, 0.6, -0.098, 0.46, 0.18, "+z", DADO)
    ptext(a, "THANDA PAANI", (13.95, 0.6, -0.098), (1, 0, 0), (0, 1, 0), 0.42, 0.1, WHITE, off=0.004, bold=0.02)
    for x in (13.82, 14.08):
        gtube(a, (x, 0.42, -0.1), (x, 0.42, 0.0), 0.018, DARK_STEEL, seg=5)
    at(a, 14.75, -0.35, 0, lambda b: chair_stack_geo(b, 6, RED))
    at(a, 10.05, -0.4, 0, lambda b: matka_geo(b, 0.21, RED))
    at(a, 10.5, -0.5, 0, lambda b: matka_geo(b, 0.2))
    # fairy lights along the verandah edge (swags) and down the end poles
    xs = [9.25, 11.35, 13.3, 15.2]
    fs.string("verandah", swag_line([(x, YF + 0.02, ZF + 0.1) for x in xs], sag_per_m=0.09),
              spacing=0.26, r=0.045)
    for x in (9.42, 15.1):
        pts = []
        for i in range(41):
            t = i / 40
            ang = 2 * math.pi * 3.0 * t
            pts.append((x + 0.13 * math.cos(ang), 0.3 + (YF - 0.5) * t, 0.2 + 0.13 * math.sin(ang)))
        fs.string("verandah", pts, spacing=0.2, r=0.04)


def side_gate(a):
    """Posts and a small toran-less opening in the x = 9 low wall (Layout3.SIDE_GATE)."""
    for z in (3.33, 4.77):
        gbox(a, 8.93, 9.17, 0.0, 0.95, z - 0.12, z + 0.12, BRICK_RED, bevel=0.02)
        gbox(a, 8.9, 9.2, 0.95, 1.02, z - 0.15, z + 0.15, CONCRETE, bevel=0.012)
        gdec(a, 9.172, 0.55, z, 0.14, 0.14, "+x", MARIGOLD, rot=45)
        a.place(lambda b: mini_pot(b, (0, 0, 0)), loc=B(9.05, 1.02, z), s=0.8)
    a.grect(8.85, 3.45, 9.3, 4.65, 0.004, MORTAR)                                     # threshold


def door_and_interior(a, fs):
    # mango-leaf toran on the door awning front edge
    toran(a, (2.47, 1.99, 10.16), (5.13, 1.99, 10.16), n=13, sag_amt=0.1, strands=(0.0, 0.5, 1.0))
    # name-board marquee (replaces the old static bulbs) + spirals up the gate posts
    fs.string("gate_board", straight((2.5, 2.72, 10.08), (5.1, 2.72, 10.08)), spacing=0.22, r=0.05,
              colors=FAIRY_GOLDS, chase=True, wire=False)
    for x in (2.89, 4.71):
        pts = []
        for i in range(61):
            t = i / 60
            ang = 2 * math.pi * 4.0 * t + (0 if x < 3.8 else math.pi)
            pts.append((x + 0.15 * math.cos(ang), 0.25 + 2.1 * t, 9.0 + 0.15 * math.sin(ang)))
        fs.string("gate_posts", pts, spacing=0.2, r=0.04)
    # torans over the chai counter and over the gallas (both on the x = 0 wall since the
    # fixer re-layout put the chai counter there)
    toran(a, (0.07, 2.36, 0.55), (0.07, 2.36, 2.95), n=11, sag_amt=0.06, normal=(1, 0, 0))
    toran(a, (0.07, 2.36, 6.35), (0.07, 2.36, 8.4), n=10, sag_amt=0.06, normal=(1, 0, 0))
    # wall fan on the x = 0 wall between the portrait and the radio shelf
    fy, fz = 1.98, 6.08
    gbox(a, 0.0, 0.06, fy - 0.3, fy - 0.12, fz - 0.06, fz + 0.06, WHITE)
    gtube(a, (0.03, fy, fz), (0.2, fy, fz), 0.07, WHITE, r1=0.06, seg=10)
    for k in range(3):
        t = 2 * math.pi * k / 3 + 0.3
        pdisc(a, (0.23, fy + 0.11 * math.sin(t), fz - 0.11 * math.cos(t)), (0, 0, -1), (0, 1, 0), 0.09, BLUE, n=8,
              sx=1.0, sy=0.55, rot=t)
    for k in range(14):
        t0, t1 = 2 * math.pi * k / 14, 2 * math.pi * (k + 1) / 14
        gtube(a, (0.25, fy + 0.22 * math.sin(t0), fz + 0.22 * math.cos(t0)),
              (0.25, fy + 0.22 * math.sin(t1), fz + 0.22 * math.cos(t1)), 0.008, DARK_STEEL, seg=3, caps=False)
    gball(a, (0.25, fy, fz), 0.035, DARK_STEEL, seg=6, rings=4)
    # film-style posters (generic art, fictional titles) on the x = 0 wall
    for (z, title, bg, fg, art) in ((4.55, "DHABA DIWANE", NAVY, MARIGOLD, 0), (8.45, "TRUCK RAJA", JACKET, PAINT_YELLOW, 1)):
        R, U = (0, 0, -1), (0, 1, 0)
        c = Vector((0.004, 1.68, z))
        pdec(a, c, R, U, 0.56, 0.78, WHITE, 0.0)
        pdec(a, c, R, U, 0.5, 0.72, bg, 0.002)
        pdec(a, c + Vector((0, -0.18, 0)), R, U, 0.5, 0.3, MARIGOLD_DARK if art == 0 else TEAL, 0.003)
        pdisc(a, c + Vector((0, 0.12, 0)), R, U, 0.13, PAINT_YELLOW if art == 0 else RED, n=12, off=0.004)
        if art == 0:                                                                   # two silhouettes
            for dz, col in ((0.09, SAFFRON), (-0.09, NEON_PINK)):
                pdisc(a, c + Vector((0, 0.06, -dz)), R, U, 0.05, col, n=8, off=0.006)
                ppoly(a, c + Vector((0, -0.12, -dz)), R, U, [(-0.07, -0.12), (0.07, -0.12), (0.03, 0.12), (-0.03, 0.12)],
                      col, 0.006)
        else:                                                                          # truck silhouette
            ppoly(a, c + Vector((0, -0.02, 0)), R, U, [(-0.2, -0.08), (0.2, -0.08), (0.2, 0.0), (0.12, 0.0), (0.12, 0.07),
                                                        (-0.2, 0.07)], PAINT_YELLOW, 0.006)
            for dz in (-0.12, 0.12):
                pdisc(a, c + Vector((0, -0.1, -dz)), R, U, 0.035, WHITE, n=8, off=0.008)
        ptext(a, title, c + Vector((0, -0.3, 0)), R, U, 0.46, 0.09, fg, off=0.006, bold=0.03)
    # outside rangoli at the entrance (on the threshold, under the door line)
    rc = (3.8, 9.78)
    for k, (rad, col, n) in enumerate(((0.46, MARIGOLD, 16), (0.38, NEON_PINK, 8), (0.29, PAINT_YELLOW, 16),
                                        (0.19, DADO, 8), (0.09, WHITE, 8))):
        y = 0.008 + 0.0015 * k
        if n == 8:
            pts = []
            for q in range(16):
                rr = rad if q % 2 == 0 else rad * 0.62
                t = 2 * math.pi * q / 16
                pts.append((rc[0] + rr * math.cos(t), rc[1] + rr * math.sin(t)))
            gpoly(a, pts, y, col)
        else:
            gpoly(a, [(rc[0] + rad * math.cos(2 * math.pi * q / n), rc[1] + rad * math.sin(2 * math.pi * q / n))
                      for q in range(n)], y, col)
    for k in range(8):                                                                 # petal dots
        t = 2 * math.pi * k / 8 + 0.2
        gdisc(a, rc[0] + 0.53 * math.cos(t), 0.008, rc[1] + 0.53 * math.sin(t), 0.045, (RED, WHITE)[k % 2], n=8)


def parapet_lights(fs):
    """Bulbs swagging along the inner top edge of both tall walls (the rooftop parapet)."""
    xs = [0.12 + k * (9.0 - 0.12) / 8 for k in range(9)]
    fs.string("parapet", swag_line([(x, TERR_Y - 0.04, 0.12) for x in xs], sag_per_m=0.12), spacing=0.3)
    zs = [0.25 + k * (9.0 - 0.25) / 8 for k in range(9)]
    fs.string("parapet", swag_line([(0.12, TERR_Y - 0.04, z) for z in zs], sag_per_m=0.12), spacing=0.3)


# ------------------------------------------------------------------ street_v3
def build_street_v3(mat):
    """Returns (street_v3 object, FairySet 'street', milestone_text object). milestone_text is
    the milestone's baked "NH 44 / DELHI / 120 km" (world coords), exported as its own node."""
    a = Asset("street_v3")
    fs = FairySet("street", seed=19)
    rng = random.Random(33)
    MILESTONE_TEXT[:] = [Asset("milestone_text")]
    for fn in (ground, highway, near_side, courtyard, west_yard, east_side, truck_parking, lot_corner, power_lines,
               background):
        if fn in (ground, highway, power_lines):
            fn(a) if fn is not ground else fn(a, rng)
        elif fn is background:
            fn(a, rng)
        else:
            fn(a, fs, rng)
        _prof(a, fn.__name__)
    mt = MILESTONE_TEXT[0].finish(mat, 30)
    MILESTONE_TEXT[:] = []
    return a.finish(mat, 30), fs, mt


XA, XB = -40.0, 60.0


def ground(a, rng):
    a.grect(XA, -40, XB, 60, -0.035, DUST)
    # grassy fields behind and to the sides; the yards and lot are dust
    a.grect(XA, -40, -7.7, 9.15, -0.03, GRASS)
    a.grect(16.4, -40, XB, 9.15, -0.03, GRASS)
    a.grect(-7.7, -40, 16.4, -6.6, -0.03, GRASS)
    for i in range(-8, 12):                                                            # crops behind
        for j in range(4):
            x0, z0 = i * 5.0 - 2.0, -10.6 - j * 3.6
            col = (YELLOW, LIME, GOLD, LIME_DARK, YELLOW)[(i * 3 + j * 2) % 5]
            a.grect(x0, z0, x0 + 4.7, z0 + 3.3, -0.028, col)
    for (x, z, r) in ((-9.0, 3.0, 1.4), (-10.5, -4.0, 1.8), (19.0, 4.0, 1.6), (21.0, -3.0, 1.3)):
        a.gblob(x, z, r, -0.025, LIME_DARK, rng, n=8)
    # beyond the lot: grass verge + plots
    a.grect(XA, 25.9, XB, 26.5, -0.03, LIME)
    a.grect(XA, 26.5, XB, 60, -0.032, DUST_DARK)
    for i in range(-8, 12):
        for j in range(5):
            x0, z0 = i * 5.0 + 0.15, 26.65 + j * 3.6
            col = (YELLOW, GRASS, GOLD, LIME_DARK)[(i * 3 + j * 2) % 4]
            a.grect(x0, z0, x0 + 4.7, z0 + 3.3, -0.028, col)
    # dusty yards: behind the blocks, west yard, east strip, alley
    a.grect(-7.7, -6.6, 16.4, -3.6, -0.022, DUST_DARK)
    a.grect(-7.7, -0.3, -0.3, 9.15, -0.012, DUST_LT)
    a.grect(9.15, -0.3, 16.4, 9.15, -0.014, DUST_LT)
    for k in range(10):                                                                # dust patches
        x, z = rng.uniform(-7.0, -0.8), rng.uniform(0.2, 8.6)
        a.gblob(x, z, rng.uniform(0.3, 0.6), -0.0105, DUST, rng, n=7)


def kerb(a, x0, x1, z0, z1, top=0.06, painted=True):
    gbox(a, x0, x1, -0.03, top, z0, z1, KERB)
    if not painted:
        return
    n = int((x1 - x0) / 0.6)
    for i in range(n):
        xa = x0 + i * 0.6
        col = INK if i % 2 else PAINT_YELLOW
        gdec(a, xa + 0.3, top + 0.002, (z0 + z1) / 2, 0.6, z1 - z0, "+y", col)
        gdec(a, xa + 0.3, (top - 0.03) / 2, z1 + 0.002, 0.6, top + 0.03, "+z", col)


def highway(a):
    """Highway z 10.5..16 (top y -0.03): lanes, edge lines, divider with oleander, zebra.
    Yellow-black kerb only along the two highway edges (and the divider)."""
    kerb(a, XA, -12.0, 10.36, 10.5, painted=False)
    kerb(a, -12.0, 2.9, 10.36, 10.5)
    kerb(a, 4.7, 24.0, 10.36, 10.5)
    kerb(a, 24.0, XB, 10.36, 10.5, painted=False)
    kerb(a, XA, -12.0, 16.0, 16.14, painted=False)
    kerb(a, -12.0, 2.9, 16.0, 16.14)
    kerb(a, 4.7, 24.0, 16.0, 16.14)
    kerb(a, 24.0, XB, 16.0, 16.14, painted=False)
    a.grect(XA, 10.5, XB, 16.0, -0.03, ROAD)
    for zl in (10.75, 15.75):
        for k in range(-14, 22):
            x = k * 2.6
            if 2.6 < x + 0.75 < 5.0:
                continue
            gdec(a, x, -0.028, zl, 1.4, 0.1, "+y", LINE)
    for (x, z, w, h) in ((-6.5, 11.4, 1.4, 0.6), (8.6, 14.9, 1.1, 0.7), (17.0, 11.9, 1.6, 0.5), (-1.5, 14.7, 0.9, 0.5)):
        gdec(a, x, -0.0285, z, w, h, "+y", ASPHALT)
    for (x, z, rot) in ((-3.0, 11.85, 4), (12.5, 14.35, -3), (20.0, 12.2, 2)):           # skid marks
        for dz in (-0.42, 0.42):
            gdec(a, x, -0.0283, z + dz, 3.2, 0.12, "+y", SLATE, rot=rot)
    for (x0, x1) in ((XA, -12.0), (-12.0, 2.9), (4.7, 10.1), (11.9, 24.0), (24.0, XB)):
        painted = -13 < x0 < 25
        gbox(a, x0, x1, -0.03, 0.16, 13.1, 13.4, KERB)
        if painted:
            n = int((x1 - x0) / 0.6)
            for i in range(n):
                xa = x0 + i * 0.6
                col = INK if i % 2 else PAINT_YELLOW
                gdec(a, xa + 0.3, 0.065, 13.402, 0.6, 0.19, "+z", col)
                gdec(a, xa + 0.3, 0.065, 13.098, 0.6, 0.19, "-z", col)
            a.grect(x0 + 0.02, 13.14, x1 - 0.02, 13.36, 0.162, LIME_DARK)
            nb = int((x1 - x0) / 2.4)
            for i in range(nb):
                bx = x0 + 1.2 + i * 2.4
                gico(a, (bx, 0.3, 13.25), 0.22, FOLIAGE, scale=(1.3, 0.9, 0.7))
                gico(a, (bx + 0.12, 0.42, 13.22), 0.07, NEON_PINK)
                gico(a, (bx - 0.14, 0.38, 13.3), 0.06, PINK)
        else:
            a.grect(x0, 13.12, x1, 13.38, 0.162, LIME_DARK)
    a.grect(XA, 12.94, XB, 13.0, -0.0285, PAINT_YELLOW)
    a.grect(XA, 13.5, XB, 13.56, -0.0285, PAINT_YELLOW)
    z = 10.62
    while z < 15.95:
        if not (12.95 < z + 0.16 < 13.55):
            a.grect(3.0, z, 4.6, min(z + 0.32, 15.95), -0.026, WHITE)
        z += 0.6


def near_side(a, fs, rng):
    """Dusty near shoulder z 9.15..10.36 (walk line z 9.8), brick landing + rangoli at the
    door, pyau, cycle, milestone-free (the milestone is across the road)."""
    a.grect(XA, 9.15, XB, 10.36, -0.004, DUST_LT)
    a.grect(-12.0, 9.68, 2.7, 9.92, -0.003, TRACK)                                    # foot-worn track
    a.grect(4.9, 9.68, 24.0, 9.92, -0.003, TRACK)
    for (x, z, rr) in ((-9.5, 10.15, 0.35), (-4.4, 9.45, 0.3), (7.8, 10.2, 0.32), (17.5, 9.5, 0.4), (21.5, 10.1, 0.3)):
        a.gblob(x, z, rr, -0.0035, DUST, rng, n=7)
    # brick landing in front of the door
    a.grect(2.72, 9.15, 4.88, 10.34, 0.002, BRICK_RED)
    for k in range(1, 5):
        gdec(a, 3.8, 0.004, 9.15 + k * 0.24, 2.16, 0.02, "+y", MORTAR)
    for k in range(9):
        gdec(a, 2.72 + k * 0.24, 0.0042, 9.75, 0.02, 1.19, "+y", MORTAR)
    # pyau (free drinking water) west of the door: brick stand, two matkas, glasses, board
    px, pz = 1.45, 9.42
    gbox(a, px - 0.5, px + 0.5, 0.0, 0.42, pz - 0.18, pz + 0.18, BRICK_RED, bevel=0.015)
    gbox(a, px - 0.53, px + 0.53, 0.42, 0.47, pz - 0.2, pz + 0.2, WHITEWASH)
    for dx, cl in ((-0.25, RED), (0.25, None)):
        a.place(lambda b, cl=cl: matka_geo(b, 0.17, cl), loc=B(px + dx, 0.47, pz))
    for dx in (-0.45, 0.45):
        gtube(a, (px + dx, 0.47, pz + 0.1), (px + dx, 0.56, pz + 0.1), 0.03, STEEL, r1=0.035, seg=8)
    framed_board(a, (px, 0.27, pz + 0.19), 0.5, 0.2, "pyau")
    # cycle leaning on the low wall east of the door
    at(a, 6.95, 9.38, 0, lambda b: cycle_geo(b), y=0.0)


def courtyard(a, fs, rng):
    """Open-air charpai courtyard x 9.3..15, z 0.3..7.9 (Layout3 tables 2-4): lime-washed
    earth floor with a brick edge, low boundary walls (front z 8.0..8.3, east x 15.05..15.35),
    corner pillars with pots, bamboo poles carrying zig-zag fairy lights. Nothing else inside."""
    x0, x1, z0, z1 = COURTYARD
    a.grect(9.15, 0.3, 15.05, 8.0, -0.002, WHITEWASH)
    a.grect(9.25, 0.4, 14.95, 7.9, -0.0015, DUST_LT)
    a.grect(9.25, 3.8, 14.6, 4.3, -0.001, TRACK)                                     # worn aisle path
    rc = (9.75, 4.05)
    for k, (rad, col, n) in enumerate(((0.36, MARIGOLD, 16), (0.28, NEON_PINK, 8), (0.2, PAINT_YELLOW, 16),
                                        (0.11, DADO, 8))):
        y = -0.0005 + 0.0004 * k
        pts = []
        for q in range(16 if n == 8 else n):
            rr = rad if (n != 8 or q % 2 == 0) else rad * 0.62
            t = 2 * math.pi * q / (16 if n == 8 else n)
            pts.append((rc[0] + rr * math.cos(t), rc[1] + rr * math.sin(t)))
        gpoly(a, pts, y, col)
    ax0, ax1, az0, az1 = ANNEX
    for k in range(14):                                                              # faint broom marks
        bx, bz, bw, br = rng.uniform(9.6, 14.7), rng.uniform(0.6, 7.6), rng.uniform(0.5, 1.1), rng.uniform(0, 180)
        if ax0 <= bx <= ax1 and az0 <= bz <= az1:
            continue                                                                 # under the annex tiles
        gdec(a, bx, -0.001, bz, bw, 0.03, "+y", DUST, rot=br)
    # KITCHEN ANNEX floor (the kadai station): flush checker tiles (decal, never
    # raised; walk points stay at y 0) with mortar joints and a brick-red edge line at the front
    nx, nz = 8, 7
    tw, td = (ax1 - ax0) / nx, (az1 - az0) / nz
    for i in range(nx):
        for j in range(nz):
            a.grect(ax0 + i * tw, az0 + j * td, ax0 + (i + 1) * tw, az0 + (j + 1) * td, 0.0012,
                    TILE_A if (i + j) % 2 else TILE_B)
    for i in range(1, nx):
        x = ax0 + i * tw
        a.grect(x - 0.012, az0, x + 0.012, az1 - 0.05, 0.0016, MORTAR)
    for j in range(1, nz):
        z = az0 + j * td
        a.grect(ax0, z - 0.012, ax1, z + 0.012, 0.0016, MORTAR)
    a.grect(ax1 - 0.03, az0, ax1, az1 - 0.05, 0.0016, MORTAR)
    a.grect(ax0, az1 - 0.05, ax1, az1, 0.0016, BRICK_RED)

    def low_wall_x(xa, xb, zc):
        gbox(a, xa, xb, 0.0, 0.13, zc - 0.18, zc + 0.18, BRICK_RED)
        gbox(a, xa, xb, 0.13, 0.43, zc - 0.15, zc + 0.15, KURTA)
        gbox(a, xa - 0.02, xb + 0.02, 0.43, 0.5, zc - 0.2, zc + 0.2, CONCRETE)
        n = int((xb - xa) / 0.55)
        for i in range(n):
            gdec(a, xa + (i + 0.5) * (xb - xa) / n, 0.27, zc + 0.153, 0.13, 0.13, "+z",
                 (RED, PAINT_YELLOW, GREEN, BLUE, NEON_PINK)[i % 5], rot=45)

    def low_wall_z(za, zb, xc):
        gbox(a, xc - 0.18, xc + 0.18, 0.0, 0.13, za, zb, BRICK_RED)
        gbox(a, xc - 0.15, xc + 0.15, 0.13, 0.43, za, zb, KURTA)
        gbox(a, xc - 0.2, xc + 0.2, 0.43, 0.5, za - 0.02, zb + 0.02, CONCRETE)
        n = int((zb - za) / 0.55)
        for i in range(n):
            gdec(a, xc + 0.153, 0.27, za + (i + 0.5) * (zb - za) / n, 0.13, 0.13, "+x",
                 (BLUE, NEON_PINK, RED, PAINT_YELLOW, GREEN)[i % 5], rot=45)

    low_wall_x(9.2, 15.2, 8.15)
    # east wall with the AC family hall's door gap z 3.5..4.6 (Layout3.HALL_DOOR_Z; core-and-feel
    # C6.1): open in both layouts, two gate pillars at (15.2, 3.29) and (15.2, 4.81)
    low_wall_z(0.35, 3.5, 15.2)
    low_wall_z(4.6, 8.0, 15.2)
    a.grect(15.05, 3.5, 15.4, 4.6, 0.001, MORTAR)                                    # threshold

    def pillar(x, z, h=0.85):
        gbox(a, x - 0.21, x + 0.21, 0.0, h, z - 0.21, z + 0.21, BRICK_RED, bevel=0.02)
        gbox(a, x - 0.25, x + 0.25, h, h + 0.08, z - 0.25, z + 0.25, CONCRETE, bevel=0.015)
        gdec(a, x, h * 0.55, z + 0.213, 0.2, 0.2, "+z", KURTA, rot=45)
        gdec(a, x + 0.213, h * 0.55, z, 0.2, 0.2, "+x", KURTA, rot=45)
        a.place(lambda b: mini_pot(b, (0, 0, 0)), loc=B(x, h + 0.08, z))
    for (x, z) in ((15.2, 8.15), (12.2, 8.15), (15.2, 3.29), (15.2, 4.81)):
        pillar(x, z)
    # bamboo poles for the overhead lights (on the boundary walls, outside the seats), plus
    # one on the store's low x = 9 wall just past the side gate's front post (WEST_POLE)
    front = [(9.45, 8.15), (11.35, 8.15), (13.3, 8.15), (15.2, 6.2)]
    for (x, z) in front + [(15.2, 8.15), COURTYARD_WEST_POLE]:
        gtube(a, (x, 0.5 if (x, z) != (15.2, 8.15) else 0.93, z), (x, 2.75, z), 0.035, BAMBOO, seg=6)
        gball(a, (x, 2.75, z), 0.04, BAMBOO, seg=6, rings=3)
    # Overhead strings (polish round 2026-10-20). They used to zig-zag from the verandah
    # fascia (z 0.42) over the KITCHEN ANNEX to the front poles: at the game camera (ortho,
    # -50 / 45 deg) a string 2.7 m up draws over the floor ~1.6 m behind it, so every leg
    # crossed the FAMILY DHABA / OPEN 24 HRS board and hung over the kadai station and
    # the annex cooks (the west leg over the third tandoor cook too). Now they
    # make a criss-cross canopy over the front half of the courtyard (tables 2-3): the west
    # pole and the east pole (15.2, 6.2) each fan out to the front poles, and one string
    # spans the courtyard between them. Checked with the game projection (scratch
    # fl_check.py): every bulb and wire draws >= 0.5 m (screen) clear of the annex counters,
    # cooks, handi lid / ladle and steam, the three verandah boards, table set 4 and the
    # tandoor. Bulbs stay one "fairy_bulb_courtyard_zig" node (FairyLights twinkles it).
    W = (COURTYARD_WEST_POLE[0], 2.66, COURTYARD_WEST_POLE[1])
    F = [(x, 2.66, z) for (x, z) in front]
    main_rng, fs.rng = fs.rng, random.Random(29)            # own colour / phase stream ...
    for chain in ((W, F[3]), (F[1], W, F[2]), (F[0], F[3], F[1])):
        fs.string("courtyard_zig", swag_line(list(chain), sag_per_m=0.045), spacing=0.4, r=0.045)
    fs.rng = main_rng
    # ... while the shared stream skips exactly what the old zig-zag drew, so every string
    # built after this one (west yard, lot, gumti, ...) keeps its colours and phases
    old = [(9.3, 2.84, 0.42), F[0], (10.4, 2.84, 0.42), F[1], (12.3, 2.84, 0.42), F[2], (14.2, 2.84, 0.42), F[3],
           (15.15, 2.84, 0.42)]
    main_rng.randrange(len(FAIRY_MIX))
    for _ in resample(swag_line(old, sag_per_m=0.045), 0.4, 0.5):
        main_rng.uniform(0.0, 0.497)
    fs.string("courtyard_front", swag_line([F[0], F[1], F[2], (15.2, 2.66, 8.15), F[3]], sag_per_m=0.07),
              spacing=0.36, r=0.045)


def west_yard(a, fs, rng):
    """West yard x -7.45..-0.3, z -0.3..9.15 in front of the west block's CEMENT ad: neem tree
    on a chabutra with decor charpais, the outdoor cooking line (clay tandoor with smoke,
    bhatti + steel kettle, kulhad stacks, matkas), plastic chairs, a scooter."""
    # brick edging along the front and the west side
    gbox(a, -7.6, -0.3, -0.02, 0.09, 9.0, 9.15, BRICK_RED)
    gbox(a, -7.7, -7.55, -0.02, 0.09, -0.3, 9.15, BRICK_RED)
    for k in range(12):
        gdec(a, -7.2 + k * 0.6, 0.092, 9.075, 0.08, 0.08, "+y", WHITEWASH)
    # neem on a chabutra (lights on trunk + branches)
    neem_tree(a, fs, -5.4, 3.0, key="neem")
    # decor charpai + table set and loose charpais (non-interactive)
    at(a, -2.6, 2.6, 0, table_geo)
    at(a, -2.6, 1.65, 0, charpai_geo)
    at(a, -2.6, 3.55, 0, charpai_geo)
    at(a, -5.6, 5.6, 90, charpai_geo)
    at(a, -1.35, 5.5, 0, charpai_geo)
    gbox(a, -1.75, -0.95, 0.42, 0.5, 5.25, 5.75, RED, bevel=0.03)                        # folded razai
    # cooking line along the front (z ~8.2-8.6)
    at(a, -1.25, 8.35, 0, tandoor_out_geo)
    at(a, -2.75, 8.4, 0, bhatti_geo)
    gbox(a, -3.95, -3.45, 0.0, 0.32, 8.2, 8.62, WOOD, bevel=0.02)                     # stool + kulhads
    at(a, -3.7, 8.41, 0, lambda b: kulhad_stack_geo(b, 4), y=0.32)
    at(a, -4.35, 8.5, 0, lambda b: kulhad_stack_geo(b, 3))
    gbox(a, -5.65, -4.75, 0.0, 0.32, 8.25, 8.7, WOOD, bevel=0.02)                      # matka stand
    for k, cl in enumerate((RED, None, BLUE)):
        a.place(lambda b, cl=cl: matka_geo(b, 0.18, cl), loc=B(-5.5 + k * 0.3, 0.32, 8.47))
    at(a, -6.6, 8.35, 0, lambda b: scooter_geo(b, BLUE))
    at(a, -6.95, 6.6, 30, lambda b: chair_stack_geo(b, 5, GREEN))
    for (x, z, yaw) in ((-4.1, 6.4, 160), (-3.4, 6.6, -150)):
        at(a, x, z, yaw, lambda b: plastic_chair_geo(b, RED))
    # sacks of flour by the block, firewood stack
    for (x, z, s) in ((-0.9, 0.2, 1.0), (-1.3, 0.35, 0.85), (-0.85, 0.65, 0.8)):
        gico(a, (x, 0.22 * s, z), 0.3 * s, ROPE, scale=(1.0, 0.85, 0.75), subdiv=1)
    for k in range(8):
        y = 0.08 + (k // 4) * 0.13
        gtube(a, (-7.2, y, 0.4 + (k % 4) * 0.13), (-6.2, y, 0.38 + (k % 4) * 0.13), 0.065, TRUNK, seg=6)
    # pennant strings over the yard (block parapet -> front poles)
    for x in (-7.3, -4.0, -0.6):
        gtube(a, (x, 0.0, 9.05), (x, 2.6, 9.05), 0.035, BAMBOO, seg=6)
        gball(a, (x, 2.6, 9.05), 0.04, BAMBOO, seg=6, rings=3)
    gbunting(a, (-7.3, 2.55, 9.05), (-0.6, 2.55, 9.05), 0.3, 18)
    for (x, xb) in ((-7.3, -6.0), (-4.0, -3.3), (-0.6, -1.0)):
        gbunting(a, (x, 2.55, 9.05), (xb, TERR_Y + 0.4, -0.3), 0.35, 14,
                 colors=(SAFFRON, WHITE, GREEN, PINK, PAINT_YELLOW), depth=0.18)
    # festive lights: front poles swag + diagonals to the block parapet
    fs.string("yard_front", swag_line([(-7.3, 2.5, 9.1), (-4.0, 2.5, 9.1), (-0.6, 2.5, 9.1)], sag_per_m=0.06),
              spacing=0.34)
    fs.string("yard_zig", swag_line([(-7.3, 2.45, 9.1), (-5.6, TERR_Y + 0.35, -0.25), (-4.0, 2.45, 9.1),
                                     (-2.3, TERR_Y + 0.35, -0.25), (-0.6, 2.45, 9.1)], sag_per_m=0.05),
              spacing=0.42)


def neem_tree(a, fs, x, z, k=1.0, key="neem"):
    R = 1.0 * k
    gtube(a, (x, -0.03, z), (x, 0.4, z), R, BRICK_RED, seg=14)
    gtube(a, (x, 0.4, z), (x, 0.47, z), R + 0.05, WHITEWASH, seg=14)
    gtube(a, (x, 0.13, z), (x, 0.28, z), R + 0.006, WHITEWASH, seg=14, caps=False)
    for i in range(12):
        cyl_dec(a, x, 0.205, z, R + 0.012, 2 * math.pi * i / 12, 0.1, 0.1, RED, rot=45)
    T0, T1 = 0.45, 2.2 * k
    gtube(a, (x, T0, z), (x, T1, z), 0.2 * k, TRUNK, r1=0.15 * k, seg=8)
    for (y0, y1, col) in ((0.48, 0.74, WHITEWASH), (0.74, 0.96, RED), (0.96, 1.2, WHITEWASH)):
        f0 = (y0 - T0) / (T1 - T0)
        f1 = (y1 - T0) / (T1 - T0)
        gtube(a, (x, y0, z), (x, y1, z), 0.2 * k - 0.05 * k * f0 + 0.012, col,
              r1=0.2 * k - 0.05 * k * f1 + 0.012, seg=8, caps=False)
    gtube(a, (x, 1.42, z), (x, 1.47, z), 0.19 * k, RED, seg=8, caps=False)              # kalava threads
    tips = ((-1.25, 3.25, 0.45), (1.15, 3.35, -0.4), (0.25, 3.6, 1.05), (-0.35, 3.45, -1.05), (0.9, 3.05, 0.8))
    for (bx, by, bz) in tips:
        gtube(a, (x, T1 - 0.15, z), (x + bx * k, by * k, z + bz * k), 0.1 * k, TRUNK, r1=0.045 * k, seg=6)
    crown = ((0, 4.05, 0, 1.15, NEEM), (-1.15, 3.75, 0.45, 0.9, NEEM_LT), (1.05, 3.8, -0.35, 0.9, NEEM),
             (0.3, 4.45, 0.9, 0.8, NEEM_LT), (-0.45, 4.35, -0.95, 0.8, FOLIAGE), (0.95, 3.5, 0.95, 0.65, NEEM_LT),
             (-0.95, 3.4, -0.75, 0.65, NEEM), (0.05, 4.85, 0.0, 0.7, NEEM_LT))
    for (dx, dy, dz, r, col) in crown:
        gico(a, (x + dx * k, dy * k, z + dz * k), r * k, col, scale=(1.0, 0.72, 1.0), subdiv=1)
    # lights: spiral up the trunk, then out along every branch
    pts = []
    n = 110
    for i in range(n + 1):
        t = i / n
        y = 0.5 + (T1 - 0.6) * t
        rr = 0.2 * k - 0.05 * k * (y - T0) / (T1 - T0) + 0.04
        ang = 2 * math.pi * 6.0 * t
        pts.append((x + rr * math.cos(ang), y, z + rr * math.sin(ang)))
    fs.string(key + "_trunk", pts, spacing=0.17, r=0.04, colors=FAIRY_GOLDS)
    for (bx, by, bz) in tips:
        p0 = Vector((x, T1 - 0.1, z))
        p1 = Vector((x + bx * k, by * k - 0.1, z + bz * k))
        fs.string(key + "_branches", swag_line([p0, p1], sag_per_m=0.04), spacing=0.22, r=0.04)
        mid = p0.lerp(p1, 0.65)
        fs.string(key + "_branches", straight(mid, mid - Vector((0, 0.7, 0)), 3), spacing=0.2, r=0.035, wire=True)


def east_side(a, fs, rng):
    """Strip in front of the courtyard (z 8.3..9.15): chair stack, the PUNCTURE corner (moved here
    from the hidden plot east of the courtyard, core-and-feel C8.3, 2026-11-01: compressor, grey
    tyre stack, two tyres leaning on the low wall, tubes hanging under the PUNCTURE board, all in
    x 11.0..13.8, z 8.35..9.1) and the hand pump with a bucket. The land east of the courtyard
    (x 15.4..21.8, z 0.3..7.9) is kept empty for the AC family hall (family_hall.glb); its two trees
    went and the red scooter now stands outside the hall's south wall."""
    # hand pump on a concrete platform + puddle + bucket (front strip)
    hx, hz = 14.4, 8.75
    gbox(a, hx - 0.32, hx + 0.32, 0.0, 0.1, hz - 0.3, hz + 0.3, CONCRETE)
    a.gblob(hx - 0.45, hz + 0.3, 0.35, 0.003, GLASS, rng, n=7)
    gtube(a, (hx, 0.1, hz), (hx, 0.95, hz), 0.065, DADO, seg=8)
    gbox(a, hx - 0.09, hx + 0.09, 0.88, 1.18, hz - 0.09, hz + 0.09, DADO)
    gtube(a, (hx, 1.1, hz), (hx + 0.55, 1.32, hz), 0.03, DARK_STEEL, seg=5)
    gtube(a, (hx + 0.55, 1.32, hz), (hx + 0.62, 1.2, hz), 0.025, DARK_STEEL, seg=5)
    gtube(a, (hx - 0.03, 0.72, hz + 0.08), (hx - 0.2, 0.68, hz + 0.25), 0.035, DADO, seg=5)
    gtube(a, (hx - 0.24, 0.1, hz + 0.24), (hx - 0.24, 0.38, hz + 0.24), 0.13, BLUE, r1=0.16, seg=10)
    gtube(a, (hx - 0.24, 0.33, hz + 0.24), (hx - 0.24, 0.35, hz + 0.24), 0.155, WHITE, seg=10, caps=False)
    at(a, 16.85, 8.75, 0, lambda b: scooter_geo(b, RED))
    at(a, 10.2, 8.72, 0, lambda b: chair_stack_geo(b, 4, BLUE))
    # puncture corner on the front strip (x 11.0..13.8, z 8.35..9.1)
    gbox(a, 11.05, 11.7, 0.0, 0.5, 8.5, 8.95, RED, bevel=0.03)                          # compressor
    gtube(a, (11.15, 0.55, 8.72), (11.6, 0.55, 8.72), 0.17, DARK_STEEL, seg=10)
    gtube(a, (11.37, 0.5, 8.72), (11.37, 0.82, 8.72), 0.035, DARK_STEEL, seg=5)
    wire(a, [(11.6, 0.4, 8.95), (11.75, 0.1, 9.05), (12.0, 0.03, 9.05)], r=0.018, color=TYRE)   # air hose
    for k in range(4):                                                                 # grey tyre stack
        y = k * 0.17
        gtube(a, (13.4, y, 8.73), (13.4, y + 0.16, 8.73), 0.34, DARK_STEEL, seg=12)
        gdisc(a, 13.4, y + 0.162, 8.73, 0.25, SLATE, n=12)
        gdisc(a, 13.4, y + 0.164, 8.73, 0.15, CONCRETE, n=10)
    for k in range(2):                                                                 # tyres leaning on the wall
        x = 12.05 + k * 0.5
        gtube(a, (x, 0.35, 8.4), (x, 0.35, 8.58), 0.34, DARK_STEEL, seg=12)
        gdisc(a, x, 0.35, 8.585, 0.22, SLATE, n=12, facing="+z")
        gdisc(a, x, 0.35, 8.59, 0.12, STEEL, n=10, facing="+z")
    gtube(a, (11.85, 0.0, 8.95), (11.85, 1.55, 8.95), 0.03, DARK_STEEL, seg=4)          # board poles
    gtube(a, (12.95, 0.0, 8.95), (12.95, 1.55, 8.95), 0.03, DARK_STEEL, seg=4)
    framed_board(a, (12.4, 1.38, 8.97), 1.2, 0.36, "puncture")
    gtube(a, (11.85, 1.08, 8.99), (12.95, 1.08, 8.99), 0.018, WOOD, seg=4)              # tube bar
    for k in range(3):                                                                 # hanging tubes
        gtube(a, (12.1 + 0.3 * k, 0.92, 9.0), (12.1 + 0.3 * k, 0.93, 9.0), 0.12, DARK_STEEL, seg=10, caps=False)


def tree(a, x, z, k=1.0, cols=(FOLIAGE, LIME_DARK, LIME)):
    gtube(a, (x, 0.0, z), (x, 1.6 * k, z), 0.17 * k, TRUNK, r1=0.11 * k, seg=7)
    for (dx, dy, dz, r, c) in ((0, 2.3, 0, 1.15, cols[0]), (0.6, 2.0, 0.4, 0.75, cols[1]),
                               (-0.5, 2.6, -0.3, 0.75, cols[2]), (0.1, 2.9, 0.5, 0.6, cols[1])):
        gico(a, (x + dx * k, dy * k, z + dz * k), r * k, c, scale=(1, 0.85, 1), subdiv=1)


def truck_parking(a, fs, rng):
    """Dusty TRUCK PARKING lot across the highway: 4 bays (Layout3.PARK_BAYS_X, 2.9 wide,
    noses on z 18.0, 7.4 deep), whitewashed stones + lime lines on the dividers, painted bay
    numbers at the back, tyre tracks, the walkway (x 1.75..5.85) to the zebra crossing with
    the TRUCK PARKING board over it, and a decorated lorry parked outside the bays."""
    lx0, lx1, lz0, lz1 = PARK_LOT
    a.grect(XA, 16.14, XB, 17.6, -0.006, DUST_LT)                                     # far shoulder
    a.grect(-12.0, 16.48, 24.0, 16.72, -0.005, TRACK)                                  # foot track
    a.grect(lx0, lz0, lx1, lz1, -0.008, DUST_LOT)
    a.grect(lx1, lz0, 19.5, lz1, -0.009, DUST_LOT)                                     # overflow strip
    a.grect(WALKWAY_X[0] + 0.25, 17.6, WALKWAY_X[1] - 0.25, 25.6, -0.007, DUST_LT)    # walkway
    W = PARK_BAY_W
    edges = sorted({round(x + s * W / 2, 3) for x in PARK_BAYS_X for s in (-1, 1)})
    for xe in edges:
        gdec(a, xe, -0.0065, PARK_NOSE_Z + PARK_DEPTH / 2, 0.08, PARK_DEPTH - 0.2, "+y", WHITEWASH)
        for k in range(10):
            stone(a, xe, PARK_NOSE_Z + 0.3 + k * 0.76, WHITEWASH if k % 2 == 0 else RED, rng=rng)
    zb = PARK_NOSE_Z + PARK_DEPTH
    for i, bx in enumerate(PARK_BAYS_X):
        gbox(a, bx - W / 2 + 0.1, bx + W / 2 - 0.1, -0.01, 0.12, zb - 0.05, zb + 0.1, WHITEWASH)   # stop log
        gdec(a, bx, -0.0066, PARK_NOSE_Z + 0.08, W - 0.3, 0.07, "+y", WHITEWASH)                  # mouth line
        # tyre tracks (two lanes) + oil stain
        for dx in (-0.62, 0.62):
            gdec(a, bx + dx, -0.0062, PARK_NOSE_Z + 3.2, 0.3, 6.0, "+y", TRACK)
        a.gblob(bx + rng.uniform(-0.3, 0.3), PARK_NOSE_Z + rng.uniform(2.0, 4.5), 0.35, -0.006, DUST_DARK, rng, n=7)
        # bay number board at the back (faces +Z)
        gtube(a, (bx - 0.35, 0.0, zb + 0.25), (bx - 0.35, 0.95, zb + 0.25), 0.03, DARK_STEEL, seg=4)
        gtube(a, (bx + 0.35, 0.0, zb + 0.25), (bx + 0.35, 0.95, zb + 0.25), 0.03, DARK_STEEL, seg=4)
        gbox(a, bx - 0.45, bx + 0.45, 0.55, 1.05, zb + 0.2, zb + 0.24, WHITEWASH)
        pdec(a, (bx, 0.8, zb + 0.24), (1, 0, 0), (0, 1, 0), 0.82, 0.42, RED, 0.002)
        ptext(a, str(i + 1), (bx, 0.8, zb + 0.24), (1, 0, 0), (0, 1, 0), 0.4, 0.34, WHITE, off=0.006, bold=0.05)
    # curved entry tracks from the lane into the bays (reverse-in arcs)
    for bx in PARK_BAYS_X:
        for k in range(5):
            t = k / 5
            gdec(a, bx - 2.0 - 2.2 * t, -0.0061, 17.2 - 0.5 * t * t, 0.9, 0.22, "+y", TRACK, rot=-12 - 20 * t)
    # oil drums at the walkway corners (red/white), a spare tyre (grey), a water drum
    for (x, z) in ((WALKWAY_X[0] + 0.5, 24.9), (WALKWAY_X[1] - 0.5, 24.9)):
        gtube(a, (x, 0.0, z), (x, 0.8, z), 0.26, RED, seg=12)
        for y in (0.18, 0.5):
            gtube(a, (x, y, z), (x, y + 0.12, z), 0.262, WHITEWASH, seg=12, caps=False)
    # TRUCK PARKING board over the walkway (two poles, faces +Z, high enough for walkers)
    bx, bz = PARK_BOARD
    BW, Y0, Y1 = 3.5, 3.45, 4.25
    for sx in (-1, 1):
        x = bx + sx * (BW / 2 - 0.12)
        gtube(a, (x, 0.0, bz - 0.05), (x, Y1 + 0.1, bz - 0.05), 0.06, DARK_STEEL, seg=6)
        gbox(a, x - 0.15, x + 0.15, -0.02, 0.12, bz - 0.2, bz + 0.1, CONCRETE)
        for (yy, col) in ((0.3, PAINT_YELLOW), (0.6, INK), (0.9, PAINT_YELLOW), (1.2, INK)):
            gtube(a, (x, yy, bz - 0.05), (x, yy + 0.3, bz - 0.05), 0.064, col, seg=6, caps=False)
    gbox(a, bx - BW / 2, bx + BW / 2, Y0, Y1, bz - 0.1, bz - 0.02, BLUE, bevel=0.02)
    R, U = (1, 0, 0), (0, 1, 0)
    c = Vector((bx, (Y0 + Y1) / 2, bz - 0.02))
    pdec(a, c, R, U, BW - 0.08, Y1 - Y0 - 0.08, WHITE, 0.003)
    pdec(a, c, R, U, BW - 0.16, Y1 - Y0 - 0.16, BLUE, 0.005)
    pdisc(a, c + Vector((-BW / 2 + 0.42, 0, 0)), R, U, 0.27, WHITE, n=16, off=0.007)
    ptext(a, "P", c + Vector((-BW / 2 + 0.42, 0, 0)), R, U, 0.3, 0.36, BLUE, off=0.009, bold=0.06)
    ptext(a, "TRUCK PARKING", c + Vector((0.27, 0.06, 0)), R, U, BW - 1.05, 0.36, WHITE, off=0.008, bold=0.05)
    ptext(a, "DHABA RUSH  24 HRS", c + Vector((0.27, -0.24, 0)), R, U, BW - 1.3, 0.12, PAINT_YELLOW, off=0.008,
          bold=0.03)
    frame = [(bx - BW / 2 + 0.05, Y0 + 0.04, bz + 0.03), (bx + BW / 2 - 0.05, Y0 + 0.04, bz + 0.03),
             (bx + BW / 2 - 0.05, Y1 - 0.04, bz + 0.03), (bx - BW / 2 + 0.05, Y1 - 0.04, bz + 0.03),
             (bx - BW / 2 + 0.05, Y0 + 0.04, bz + 0.03)]
    fs.string("parking_board", frame, spacing=0.2, r=0.045, chase=True, wire=False, start=0.0)
    gbunting(a, (bx - BW / 2 + 0.12, Y1 + 0.08, bz - 0.05), (bx + BW / 2 - 0.12, Y1 + 0.08, bz - 0.05), 0.12, 10)
    # decorated lorry parked outside the bays (east overflow strip), nose to the highway
    at(a, 15.9, 18.35 + 2.32, 90, lambda b: truck_geo(b, cab=MARIGOLD, body=TRUCK_TEAL, trim=PAINT_YELLOW,
                                                         crown=RED, lod=0))


def lot_corner(a, fs, rng):
    """Village corner left of the lot: peepal on a chabutra (white-red band, lights),
    paan gumti, milestone NH 44; sugarcane cart on the right of the lot."""
    px, pz = PEEPAL
    gtube(a, (px, -0.03, pz), (px, 0.4, pz), 1.3, BRICK_RED, seg=14)
    gtube(a, (px, 0.4, pz), (px, 0.47, pz), 1.35, WHITEWASH, seg=14)
    gtube(a, (px, 0.12, pz), (px, 0.3, pz), 1.305, KURTA, seg=14, caps=False)
    for (dx, dz, r) in ((0, 0, 0.34), (0.24, 0.15, 0.21), (-0.21, -0.12, 0.19)):
        gtube(a, (px + dx, 0.45, pz + dz), (px + dx * 0.4, 2.5, pz + dz * 0.4), r, TRUNK, r1=r * 0.6, seg=8)
    for (y0, y1, col) in ((0.5, 0.8, WHITEWASH), (0.8, 1.05, RED), (1.05, 1.35, WHITEWASH)):
        gtube(a, (px, y0, pz), (px, y1, pz), 0.42, col, r1=0.4, seg=10, caps=False)
    branches = ((-1.4, 3.3, 0.5), (1.3, 3.4, -0.4), (0.3, 3.8, 1.2), (-0.4, 3.5, -1.1))
    for (bx, by, bz) in branches:
        gtube(a, (px, 2.4, pz), (px + bx, by, pz + bz), 0.13, TRUNK, r1=0.07, seg=6)
    crowns = ((0, 4.2, 0, 1.6, FOLIAGE), (-1.4, 3.8, 0.5, 1.2, LIME_DARK), (1.3, 3.9, -0.4, 1.2, LIME_DARK),
              (0.3, 4.8, 1.0, 1.1, LIME), (-0.6, 4.5, -1.1, 1.1, FOLIAGE), (1.0, 3.5, 1.2, 0.9, LIME),
              (-1.1, 3.4, -0.9, 0.9, LIME), (0.0, 5.2, 0.0, 0.85, LIME_DARK))
    for (dx, y, dz, r, col) in crowns:
        gico(a, (px + dx, y, pz + dz), r, col, scale=(1.0, 0.8, 1.0), subdiv=1)
    # small shrine stone with a tilak + diya at the foot of the peepal
    gbox(a, px + 0.55, px + 0.85, 0.47, 0.85, pz + 0.75, pz + 0.95, SAFFRON, bevel=0.04)
    gdisc(a, px + 0.7, 0.75, pz + 0.951, 0.04, RED, n=8, facing="+z")
    gtube(a, (px + 0.45, 0.47, pz + 1.0), (px + 0.45, 0.52, pz + 1.0), 0.05, CLAY, r1=0.06, seg=8)
    pts = []
    for i in range(81):
        t = i / 80
        ang = 2 * math.pi * 4.5 * t
        pts.append((px + 0.46 * math.cos(ang), 0.5 + 1.9 * t, pz + 0.46 * math.sin(ang)))
    fs.string("peepal_trunk", pts, spacing=0.2, r=0.04, colors=FAIRY_GOLDS)
    # paan gumti in front of the peepal (faces +X, toward the camera)
    gx, gz, gyaw = GUMTI[0], GUMTI[1], 90
    at(a, gx, gz, gyaw, gumti_geo)
    edge = local_pts([(-0.75, 2.0, 1.12), (0.0, 2.0, 1.12), (0.75, 2.0, 1.12)], gx, gz, gyaw)
    fs.string("gumti", swag_line(edge, sag_per_m=0.08), spacing=0.17, r=0.04, chase=True)
    # milestone NH 44: white body, yellow top. Core-and-feel 2026-11-01: turned to face +Z (the
    # camera reads +X and +Z faces alike) so its face plane is z MILESTONE.z + 0.11 = 17.01 and
    # Layout3.MILESTONE_LABEL (-5.6, 0.62, 17.02) sits 1 cm in front of it; the baked text is its
    # own top-level node `milestone_text` (code hides it on NH 48 and adds a Label3D there).
    mx, mz = MILESTONE
    R, U = (1, 0, 0), (0, 1, 0)
    gbox(a, mx - 0.24, mx + 0.24, 0.0, 0.6, mz - 0.11, mz + 0.11, WHITEWASH, bevel=0.015)
    gtube(a, (mx, 0.6, mz - 0.11), (mx, 0.6, mz + 0.11), 0.24, PAINT_YELLOW, seg=16)
    gbox(a, mx - 0.27, mx + 0.27, -0.02, 0.08, mz - 0.13, mz + 0.13, CONCRETE)
    mt = MILESTONE_TEXT[0] if MILESTONE_TEXT else a
    ptext(mt, "NH 44", (mx, 0.69, mz + 0.11), R, U, 0.36, 0.11, INK, off=0.008, bold=0.04)
    ptext(mt, "DELHI", (mx, 0.45, mz + 0.11), R, U, 0.38, 0.1, INK, off=0.006, bold=0.035)
    ptext(mt, "120 km", (mx, 0.3, mz + 0.11), R, U, 0.38, 0.09, INK, off=0.006, bold=0.03)
    # sugarcane-juice cart right of the lot
    at(a, 13.0, 18.25, 0, cart_geo)
    for k in range(3):                                                                 # stools
        x = 12.3 + k * 0.6
        gtube(a, (x, 0.0, 17.45), (x, 0.38, 17.45), 0.12, RED, r1=0.14, seg=8)


def epole(a, x, z, h=6.0):
    """Grey concrete LT pole with a cross-arm along Z and three insulators. Returns the
    three wire attach points (Godot)."""
    gbox(a, x - 0.2, x + 0.2, -0.03, 0.16, z - 0.2, z + 0.2, CONCRETE, bevel=0.02)
    gtube(a, (x, 0.0, z), (x, h, z), 0.11, POLE, r1=0.065, seg=4)
    gbox(a, x - 0.05, x + 0.05, h - 0.42, h - 0.33, z - 0.62, z + 0.62, DARK_STEEL)
    pts = []
    for dz in (-0.52, 0.0, 0.52):
        gtube(a, (x, h - 0.33, z + dz), (x, h - 0.2, z + dz), 0.03, WHITE, r1=0.02, seg=5)
        pts.append((x, h - 0.2, z + dz))
    gdec(a, x + 0.08, 2.4, z, 0.16, 0.22, "+x", WHITE)                                    # danger plate
    gdec(a, x + 0.085, 2.4, z, 0.1, 0.08, "+x", RED)
    return pts


def power_lines(a):
    # core-and-feel 2026-11-01: the east poles moved from x 18.8 / 18.4 to 26.0 / 25.6: the near one
    # (with the transformer) stood in front of the AC family hall's glass door and its wires drew
    # across the hall from the game camera (and ambient walkers on z 10.15 walked through it)
    far = [(-24.0, 17.25), (-9.4, 17.25), (25.6, 17.25), (32.0, 17.25)]
    near = [(-23.0, 10.12), (-8.6, 10.12), (26.0, 10.12), (33.0, 10.12)]
    fp = [epole(a, x, z) for (x, z) in far]
    np_ = [epole(a, x, z, 5.6) for (x, z) in near]
    for P in (fp, np_):
        for i in range(len(P) - 1):
            if i == 1:
                continue                  # no span in front of the dhaba / over the crossing (outer spans only)
            for j in range(3):
                p0, p1 = Vector(P[i][j]), Vector(P[i + 1][j])
                L = (p1 - p0).length
                wire(a, gsag(p0, p1, 0.03 * L + 0.25, max(5, int(L / 2.5))), r=0.012)
    for (i, j) in ((1, 1), (2, 2)):                                                    # across the highway
        p0, p1 = Vector(np_[i][1]), Vector(fp[j][1])
        wire(a, gsag(p0, p1, 0.5, 8), r=0.012)
    # pole-mounted transformer on the east near pole
    x, z = near[2]
    gbox(a, x + 0.12, x + 0.62, 3.2, 3.95, z - 0.3, z + 0.3, STEEL, bevel=0.03)
    for k in range(4):
        gdec(a, x + 0.625, 3.3 + k * 0.17, z, 0.5, 0.05, "+x", DARK_STEEL)
    gtube(a, (x, 3.1, z), (x + 0.4, 3.1, z), 0.03, DARK_STEEL, seg=4)


def background(a, rng):
    """Temple on the left, village trees, haystacks, a far house."""
    # small white temple with a saffron flag (left of the west yard)
    tx, tz = -11.2, 1.2
    gbox(a, tx - 1.3, tx + 1.3, 0.0, 0.4, tz - 1.3, tz + 1.3, WHITEWASH)
    for k in range(4):
        gdec(a, tx - 0.9 + k * 0.6, 0.2, tz + 1.302, 0.4, 0.06, "+z", SAFFRON)
    gbox(a, tx - 0.85, tx + 0.85, 0.4, 1.85, tz - 0.85, tz + 0.85, WHITEWASH)
    gdec(a, tx, 0.95, tz + 0.852, 0.5, 0.9, "+z", MAROON)
    gdec(a, tx, 1.5, tz + 0.856, 0.62, 0.1, "+z", SAFFRON)
    for k, (h0, h1, w) in enumerate(((1.85, 2.45, 0.78), (2.45, 3.0, 0.62), (3.0, 3.5, 0.46), (3.5, 3.9, 0.3))):
        gtube(a, (tx, h0, tz), (tx, h1, tz), w, WHITEWASH if k % 2 == 0 else KURTA, r1=w * 0.82, seg=8)
    gtube(a, (tx, 3.9, tz), (tx, 4.0, tz), 0.22, SAFFRON, r1=0.2, seg=8)
    gball(a, (tx, 4.08, tz), 0.12, GOLD, seg=8, rings=5)
    gtube(a, (tx + 0.15, 3.9, tz), (tx + 0.15, 5.2, tz), 0.018, DARK_STEEL, seg=4)
    a.face([B(tx + 0.15, 5.2, tz), B(tx + 0.85, 5.0, tz), B(tx + 0.15, 4.75, tz)], SAFFRON, normal=(0, -1, 0))
    for k in range(5):                                                                 # bells string
        gball(a, (tx - 0.5 + k * 0.25, 1.92, tz + 0.95), 0.04, GOLD, seg=6, rings=3)
    # trees (kept off the yards, courtyard and the lot)
    # (core-and-feel 2026-11-01: three trees went: (-10.5, 19.2), whose crown hid the NH 48 camel
    # cart's corner of the lot; (23.0, 1.0), whose crown cut into the AC family hall's north-east
    # corner; (21.5, 23.5), whose crown covered the camel cart's recommended spot in the lot's
    # overflow strip)
    for (x, z, k) in ((-3.0, -9.5, 1.3), (3.5, -8.4, 1.1), (9.0, -10.5, 1.4), (16.5, -8.0, 1.2), (-9.0, -10.0, 1.1),
                      (-10.2, -4.6, 1.2), (-9.4, 7.4, 1.0), (-14.0, 21.4, 1.2), (-15.0, 6.0, 1.3)):
        tree(a, x, z, k)
    for (x, z) in ((6.0, -9.0), (20.0, -4.0), (-13.0, -2.0)):
        gico(a, (x, 0.5, z), 0.9, GOLD, scale=(1.0, 0.75, 1.0), subdiv=1)
        gico(a, (x, 1.05, z), 0.45, GOLD_DARK, scale=(1.0, 0.8, 1.0), subdiv=0)
    # wild bushes along the shoulders (with flowers)
    for (x, z) in ((-11.0, 9.5), (-11.6, 17.0), (21.0, 9.5), (24.0, 16.9), (-14.5, 9.6)):
        gico(a, (x, 0.28, z), 0.32, FOLIAGE, scale=(1.2, 0.85, 0.9), subdiv=1)
        gico(a, (x + 0.15, 0.48, z - 0.05), 0.08, NEON_PINK)
        gico(a, (x - 0.12, 0.42, z + 0.1), 0.07, MARIGOLD)


# ------------------------------------------------------------------ entry point
def build_dog(mat):
    return dog_geo(Asset("dog")).finish(mat, 40)


def build_world_ext(mat):
    """Returns (singles, groups): singles = [tandoor_lock, dog]; groups = [dhaba_v3,
    street_v3] as multi-node world groups (main mesh first, then fairy bulbs + wire)."""
    fs_d = FairySet("dhaba", seed=7)
    dh = build_dhaba_v3(mat, extra=lambda a: ext_dhaba(a, fs_d))
    st, fs_s, mt = build_street_v3(mat)
    groups = []
    for (obj, fs, more) in ((dh, fs_d, []), (st, fs_s, [mt])):
        names, objs = fs.parts(mat)
        g = Group(obj.name, [obj.name] + [m.name for m in more] + names, [obj] + more + objs, 30)
        g.kind = "world"
        g.fairy = fs.count
        groups.append(g)
    return [build_tandoor_lock(mat), build_dog(mat)], groups


# ------------------------------------------------------------------ core-and-feel world art (2026-11-01)
# docs/core-and-feel/build-plan.md section 4.1 (W1-ART1). Frozen points of plan 2.3 (Layout3), baked
# here; movable points are where code places a prop (origin on the ground unless noted).
HALL = (15.4, 21.8, 0.3, 7.9)                 # HALL_MIN / HALL_MAX (x0, x1, z0, z1)
HALL_DOOR = (3.5, 4.6)                        # HALL_DOOR_Z: gap in the courtyard's east low wall
HALL_TABLES_P = ((17.25, 2.1), (17.25, 6.1), (20.15, 2.1))
HALL_DECOR_P = (20.15, 6.1)                   # obstacle rect x 19.55..20.75, z 5.5..6.7
HALL_SIGN_P = (18.6, 2.35, 0.47)              # Label3D point on the north-wall board (W2-WORLD)
HALL_N_WALL = (0.15, 0.45)                    # north wall z (tall, y 2.8); Layout3.HALL_WALLS
HALL_E_WALL = (21.65, 21.95)                  # east low wall x
HALL_S_WALL = (7.75, 8.05)                    # south low wall z; glass door x 18.4..19.4
HALL_DOOR_X = (18.4, 19.4)
HALL_WALL_H, HALL_LOW_H = 2.8, 0.5
SHAADI_GATE_P = (3.8, 0.0, 9.15)              # SHAADI_GATE (frozen); gateway posts at x 2.89 / 4.71


def build_family_hall(mat):
    """C6.1 AC family hall, WORLD-COORD (origin = world origin), shown by code in the family layout:
    tiled floor x 15.35..21.65, z 0.45..7.75 (flush, y <= 0.002: walk points stay at y 0), a tall
    north wall (z 0.15..0.45, y 2.8, cream with a wood dado) carrying two split ACs and the blank
    maroon sign board at HALL_SIGN (field face z 0.4665; Label3D "AC FAMILY HALL / एसी फ़ैमिली हॉल" at
    z 0.47), low (0.5 m) east and south walls with a closed glass door (x 18.4..19.4; open frame
    with shine streaks so the hall stays visible), and the decor at HALL_DECOR (water cooler, a
    garlanded framed photo on a side table, two potted plants) inside x 19.55..20.75, z 5.5..6.7.
    Fairy lights: fairy_bulb_hall + fairy_wire_hall along the north wall top. The west side is the
    courtyard's east low wall in street_v3 (door gap z 3.5..4.6 between gate pillars)."""
    a = Asset("family_hall")
    fs = FairySet("hall", seed=41)
    # ---- floor: cream / tan checker like the kitchen annex, a maroon border band, threshold
    fx0, fx1, fz0, fz1 = 15.35, HALL_E_WALL[0], HALL_N_WALL[1], HALL_S_WALL[0]
    a.grect(fx0, fz0, fx1, fz1, 0.001, TILE_A)
    nx, nz = 8, 9
    tw, td = (fx1 - fx0) / nx, (fz1 - fz0) / nz
    for i in range(nx):
        for j in range(nz):
            if (i + j) % 2:
                a.grect(fx0 + i * tw, fz0 + j * td, fx0 + (i + 1) * tw, fz0 + (j + 1) * td, 0.0015, TILE_B)
    B_ = 0.12
    for (x0, z0, x1, z1) in ((fx0, fz0, fx1, fz0 + B_), (fx1 - B_, fz0, fx1, fz1), (fx0, fz1 - B_, fx1, fz1)):
        a.grect(x0, z0, x1, z1, 0.002, JACKET)
    a.grect(15.05, HALL_DOOR[0], 15.42, HALL_DOOR[1], 0.0022, MORTAR)                   # threshold
    # ---- north wall (tall), inner face z 0.45 faces +Z
    nz0, nz1 = HALL_N_WALL
    gbox(a, 15.4, HALL_E_WALL[1], 0.0, HALL_WALL_H, nz0, nz1, WALL_CREAM)
    gbox(a, 15.36, HALL_E_WALL[1] + 0.04, HALL_WALL_H, HALL_WALL_H + 0.09, nz0 - 0.04, nz1 + 0.04, CONCRETE)
    gbox(a, 15.38, HALL_E_WALL[1] + 0.02, HALL_WALL_H + 0.09, HALL_WALL_H + 0.11, nz0 - 0.02, nz1 + 0.02, KERB)
    F = nz1 + 0.002
    wx0, wx1 = 15.4, HALL_E_WALL[0]
    wc, ww = (wx0 + wx1) / 2, wx1 - wx0
    gdec(a, wc, 0.45, F, ww, 0.9, "+z", WOOD)                                           # wood dado
    gdec(a, wc, 0.92, F + 0.002, ww, 0.05, "+z", GOLD)
    gdec(a, wc, 0.05, F + 0.002, ww, 0.1, "+z", TRUNK)
    gdec(a, wc, 2.72, F + 0.002, ww, 0.06, "+z", JACKET)                                 # cornice line
    for k in range(12):                                                                  # dado panels
        x = wx0 + (k + 0.5) * ww / 12
        gdec(a, x, 0.47, F + 0.003, ww / 12 - 0.12, 0.62, "+z", TILE_B)
    # two split ACs (white, a vent slot, a status light) with their pipes running into the wall
    for ax in (16.35, 20.85):
        gbox(a, ax - 0.48, ax + 0.48, 2.17, 2.47, nz1, nz1 + 0.24, WHITE, bevel=0.04)
        gdec(a, ax, 2.235, nz1 + 0.243, 0.84, 0.05, "+z", DARK_STEEL)
        gdec(a, ax, 2.4, nz1 + 0.243, 0.7, 0.02, "+z", STEEL)
        gdisc(a, ax + 0.36, 2.33, nz1 + 0.244, 0.018, NEON_CYAN, n=6, facing="+z")
        gdec(a, ax, 2.31, nz1 + 0.244, 0.18, 0.05, "+z", CONCRETE)
        gtube(a, (ax + 0.5, 2.25, nz1 + 0.06), (ax + 0.62, 2.25, nz1 + 0.06), 0.022, WHITE, seg=5)
        gtube(a, (ax + 0.62, 2.25, nz1 + 0.06), (ax + 0.62, 1.4, nz1 + 0.06), 0.022, WHITE, seg=5)
    # blank sign board (W2-WORLD adds the Label3D at HALL_SIGN): gold frame, maroon field
    sx, sy, sz = HALL_SIGN_P
    gbox(a, sx - 1.25, sx + 1.25, sy - 0.31, sy + 0.31, nz1, nz1 + 0.012, GOLD, bevel=0.005)
    gdec(a, sx, sy, nz1 + 0.0145, 2.4, 0.52, "+z", MAROON)
    gdec(a, sx, sy - 0.235, nz1 + 0.0155, 2.3, 0.015, "+z", GOLD)
    for dx in (-1.13, 1.13):
        gdisc(a, sx + dx, sy, nz1 + 0.0155, 0.04, PAINT_YELLOW, n=8, facing="+z")
    # two framed pictures under the ACs (a hill and sun; a lotus pond)
    for (px, kind) in ((16.35, 0), (20.85, 1)):
        c = Vector((px, 1.5, F + 0.004))
        R, U = (1, 0, 0), (0, 1, 0)
        pdec(a, c, R, U, 0.74, 0.54, GOLD_DARK, 0.0)
        pdec(a, c, R, U, 0.64, 0.44, GLASS if kind == 0 else DADO, 0.002)
        if kind == 0:
            ppoly(a, c + Vector((0, -0.22, 0)), R, U, [(-0.32, 0.0), (-0.08, 0.26), (0.1, 0.1), (0.32, 0.3), (0.32, 0.0)],
                  LIME_DARK, 0.004)
            pdisc(a, c + Vector((0.14, 0.1, 0)), R, U, 0.07, MARKER_TOP, n=10, off=0.005)
        else:
            for k, dx in enumerate((-0.15, 0.0, 0.15)):
                pdisc(a, c + Vector((dx, -0.05, 0)), R, U, 0.07, PINK if k != 1 else NEON_PINK, n=8, off=0.004,
                      sy=0.6)
            pdec(a, c + Vector((0, -0.16, 0)), R, U, 0.6, 0.05, NOTE_DARK, 0.004)
    # ---- low east wall (outer face +X faces the camera) and south wall with the glass door
    ex0, ex1 = HALL_E_WALL
    gbox(a, ex0, ex1, 0.0, 0.12, nz1, HALL_S_WALL[1], TRUNK)
    gbox(a, ex0 + 0.02, ex1 - 0.02, 0.12, HALL_LOW_H - 0.07, nz1, HALL_S_WALL[1], WALL_CREAM)
    gbox(a, ex0 - 0.03, ex1 + 0.03, HALL_LOW_H - 0.07, HALL_LOW_H, nz1 - 0.02, HALL_S_WALL[1] + 0.03, PAVER)
    gdec(a, ex1 - 0.018, 0.3, (nz1 + HALL_S_WALL[1]) / 2, HALL_S_WALL[1] - nz1, 0.03, "+x", GOLD)
    sz0, sz1 = HALL_S_WALL
    for (x0, x1) in ((15.35, HALL_DOOR_X[0]), (HALL_DOOR_X[1], ex0)):
        gbox(a, x0, x1, 0.0, 0.12, sz0, sz1, TRUNK)
        gbox(a, x0, x1, 0.12, HALL_LOW_H - 0.07, sz0 + 0.02, sz1 - 0.02, WALL_CREAM)
        gbox(a, x0 - 0.02, x1 + 0.02, HALL_LOW_H - 0.07, HALL_LOW_H, sz0 - 0.03, sz1 + 0.03, PAVER)
        gdec(a, (x0 + x1) / 2, 0.3, sz1 - 0.018, x1 - x0, 0.03, "+z", GOLD)
    # SE corner pillar with a pot (like the courtyard's)
    cx_, cz_ = ex0 + 0.15, sz1 - 0.15
    gbox(a, cx_ - 0.2, cx_ + 0.2, 0.0, 0.8, cz_ - 0.2, cz_ + 0.2, WALL_CREAM, bevel=0.02)
    gbox(a, cx_ - 0.24, cx_ + 0.24, 0.8, 0.88, cz_ - 0.24, cz_ + 0.24, PAVER, bevel=0.015)
    gdec(a, cx_, 0.45, cz_ + 0.203, 0.18, 0.18, "+z", JACKET, rot=45)
    gdec(a, cx_ + 0.203, 0.45, cz_, 0.18, 0.18, "+x", JACKET, rot=45)
    a.place(lambda b: mini_pot(b, (0, 0, 0)), loc=B(cx_, 0.88, cz_))
    # closed glass door: steel frame, two leaves with brass pull bars, a frosted band with a blue
    # snowflake, diagonal shine streaks on otherwise open panes (the hall stays visible behind it)
    dx0, dx1 = HALL_DOOR_X
    dz = (sz0 + sz1) / 2
    DH = 2.1
    for x in (dx0 + 0.035, dx1 - 0.035, (dx0 + dx1) / 2):
        gbox(a, x - 0.035, x + 0.035, 0.0, DH, dz - 0.04, dz + 0.04, STEEL)
    gbox(a, dx0, dx1, DH - 0.07, DH, dz - 0.05, dz + 0.05, STEEL)
    gbox(a, dx0, dx1, 0.0, 0.16, dz - 0.03, dz + 0.03, DARK_STEEL)                         # kick plates
    gbox(a, dx0 - 0.05, dx1 + 0.05, DH, DH + 0.24, dz - 0.06, dz + 0.06, JACKET, bevel=0.01)  # transom
    gdec(a, (dx0 + dx1) / 2, DH + 0.12, dz + 0.062, 0.98, 0.04, "+z", GOLD)
    lw = (dx1 - dx0) / 2
    for k in (0, 1):
        lx = dx0 + lw * (k + 0.5)
        gdec(a, lx, 1.3, dz + 0.002, lw - 0.08, 0.22, "+z", GLASS)                          # frosted band
        gdisc(a, lx, 1.3, dz + 0.004, 0.07, BLUE, n=6, facing="+z", rot=0.0)
        gdisc(a, lx, 1.3, dz + 0.006, 0.035, WHITE, n=6, facing="+z", rot=0.5)
        bx = lx + (0.13 if k == 0 else -0.13)
        gtube(a, (bx, 0.75, dz + 0.07), (bx, 1.15, dz + 0.07), 0.016, GOLD, seg=5)            # pull bar
        for (y0, d) in ((0.5, 0.0), (1.6, 0.08)):                                         # shine streaks
            pts = [(lx - 0.16 + d, y0, dz + 0.003), (lx - 0.08 + d, y0, dz + 0.003),
                   (lx + 0.12 + d, y0 + 0.36, dz + 0.003), (lx + 0.04 + d, y0 + 0.36, dz + 0.003)]
            a.face([B(*p) for p in pts], WHITE, normal=(0, -1, 0))
    # ---- decor at HALL_DECOR (inside the obstacle rect)
    hx, hz = HALL_DECOR_P
    # water cooler (steel, blue top, two taps, a chained steel glass)
    wx, wz = hx - 0.28, hz - 0.3
    gbox(a, wx - 0.22, wx + 0.22, 0.0, 0.92, wz - 0.2, wz + 0.2, STEEL, bevel=0.03)
    gbox(a, wx - 0.23, wx + 0.23, 0.78, 0.95, wz - 0.21, wz + 0.21, WALL_BLUE, bevel=0.02)
    gdec(a, wx, 0.55, wz + 0.202, 0.3, 0.22, "+z", DADO)
    for dx in (-0.08, 0.08):
        gbox(a, wx + dx - 0.025, wx + dx + 0.025, 0.42, 0.47, wz + 0.2, wz + 0.27, DARK_STEEL)
    gbox(a, wx - 0.16, wx + 0.16, 0.2, 0.24, wz + 0.2, wz + 0.32, DARK_STEEL)                # drip tray
    gtube(a, (wx + 0.12, 0.95, wz), (wx + 0.12, 1.04, wz), 0.035, STEEL, r1=0.04, seg=8)
    # framed photo of the founder on a small side table, garlanded, a diya
    tx, tz = hx + 0.3, hz - 0.3
    gbox(a, tx - 0.24, tx + 0.24, 0.55, 0.6, tz - 0.2, tz + 0.2, WOOD, bevel=0.012)
    for sx_ in (-1, 1):
        for sz_ in (-1, 1):
            gbox(a, tx + sx_ * 0.19 - 0.025, tx + sx_ * 0.19 + 0.025, 0.0, 0.55, tz + sz_ * 0.15 - 0.025,
                 tz + sz_ * 0.15 + 0.025, TRUNK)
    pc = Vector((tx, 0.88, tz + 0.02))
    Rv = Vector((0.94, 0.0, -0.34)).normalized()                                       # turned to the camera
    Uv = Vector((0.0, 0.97, -0.24))
    Uv = (Uv - Rv * Uv.dot(Rv)).normalized()
    pdec(a, pc, Rv, Uv, 0.36, 0.48, GOLD_DARK, 0.0)
    pdec(a, pc, Rv, Uv, 0.28, 0.4, KHAKI, 0.003)
    pdisc(a, pc + Uv * 0.06, Rv, Uv, 0.07, TRUNK, n=8, off=0.005)
    pdec(a, pc - Uv * 0.1, Rv, Uv, 0.18, 0.14, TRUNK, 0.005)
    gtube(a, (tx, 0.6, tz - 0.1), (tx - 0.04, 0.66, tz - 0.08), 0.04, DARK_STEEL, seg=4)     # stand foot
    nv = _n(Rv, Uv)
    for i in range(9):                                                                   # garland
        t = math.pi * (0.1 + 0.8 * i / 8)
        p = pc + Rv * (0.2 * math.cos(t)) + Uv * (0.26 - 0.32 * math.sin(t)) + nv * 0.03
        flower(a, B(p.x, p.y, p.z), 0.03, (MARIGOLD, PAINT_YELLOW, RED)[i % 3])
    gtube(a, (tx + 0.16, 0.6, tz + 0.1), (tx + 0.16, 0.63, tz + 0.1), 0.04, CLAY, r1=0.05, seg=6)  # diya
    gico(a, (tx + 0.16, 0.67, tz + 0.1), 0.02, FIRE, scale=(1, 1.6, 1))
    # two potted plants (front corners of the rect)
    for (px, pz, k) in ((hx - 0.38, hz + 0.33, 1.0), (hx + 0.38, hz + 0.36, 0.85)):
        gtube(a, (px, 0.0, pz), (px, 0.32 * k, pz), 0.13 * k, CLAY, r1=0.17 * k, seg=8)
        gtube(a, (px, 0.3 * k, pz), (px, 0.35 * k, pz), 0.18 * k, BRICK, seg=8, caps=False)
        gdisc(a, px, 0.33 * k, pz, 0.16 * k, MUD, n=8)
        for (dx, dy, dz_, r, col) in ((0, 0.62, 0, 0.2, LEAF), (0.12, 0.5, 0.06, 0.15, FOLIAGE),
                                      (-0.1, 0.52, -0.05, 0.15, LEAF_LIGHT), (0.02, 0.8, 0.02, 0.13, LIME_DARK)):
            gico(a, (px + dx * k, dy * k, pz + dz_ * k), r * k, col, scale=(1, 0.9, 1), subdiv=0)
    # ---- fairy lights along the north wall top (inner edge)
    xs = [15.5 + k * (21.75 - 15.5) / 6 for k in range(7)]
    fs.string("hall", swag_line([(x, HALL_WALL_H - 0.02, nz1 + 0.06) for x in xs], sag_per_m=0.09), spacing=0.3,
              r=0.045)
    names, objs = fs.parts(mat)
    o = a.finish(mat, 30)
    g = Group("family_hall", ["family_hall"] + names, [o] + objs, 30)
    g.kind = "world"
    g.fairy = fs.count
    return g


def _flower_line(a, pts, r, colors, step):
    """Marigold beads every `step` m along the Godot polyline pts."""
    for i, p in enumerate(resample(pts, step, 0.5)):
        flower(a, B(p.x, p.y, p.z), r, colors[i % len(colors)])


def build_deco_baraat(mat):
    """C6.4 Shaadi gate, WORLD-COORD (origin = world origin), shown by code during the baraat window
    and for good once owned. A marigold arch over the door: it springs from the gateway posts' gold
    caps (post centres x 2.89 / 4.71 on z 9.0, y 2.5: the posts are the arch's poles; under the
    tin awning they are hidden from the game camera, so the flowers go where it looks) and rises to
    y 3.3 over SHAADI_GATE (3.8, 0, 9.15), above the awning and the name board, so the board's text
    (y 2.2..2.5) stays clear; a rose-and-marigold medallion at its crown; short ladis hanging from
    it no lower than y 2.42 (the awning's back edge is y 2.38). Marigold curtains on the near wall
    either side: strands from swagged ropes (post -> a bamboo pole on the wall pillars at x 1.4 /
    7.6), left x 1.6..2.6, right x 6.5..7.45 (off the pillar at 6.85): on screen the seats board
    (x 5.12..5.88, z 9.48..8.72, in front of the curtain plane z 9.14) stays clear, and the door gap
    x 3.0..4.6 stays walkable. Fairy lights: fairy_bulb_baraat."""
    a = Asset("deco_baraat")
    fs = FairySet("baraat", seed=53)
    Z = 8.96                       # arch plane: + 0.04 = the gateway posts' centre line z 9.0
    GOLDS = (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK, MARIGOLD, RED)
    # The gateway posts (x 2.78..3.0 / 4.6..4.82, gold caps to y 2.5) are the arch's poles: under the
    # tin awning they are hidden from the game camera anyway, so the flowers go where it looks.
    # arch: half-ellipse centre (3.8, 2.5), half-width 0.91 (post centres 2.89 / 4.71), rise 0.8 ->
    # crown y 3.3, red cloth-wrapped bamboo under two rows of marigolds
    cx, cy, hw, rise = 3.8, 2.5, 0.91, 0.8
    arc = [Vector((cx - hw * math.cos(math.pi * i / 16), cy + rise * math.sin(math.pi * i / 16), Z + 0.04))
           for i in range(17)]
    for i in range(16):
        gtube(a, tuple(arc[i]), tuple(arc[i + 1]), 0.045, RED, seg=5, caps=False)
    outer = [Vector((cx - (hw + 0.07) * math.cos(math.pi * i / 16), cy + (rise + 0.07) * math.sin(math.pi * i / 16),
                     Z + 0.08)) for i in range(17)]
    inner = [Vector((cx - (hw - 0.07) * math.cos(math.pi * i / 16), cy + (rise - 0.07) * math.sin(math.pi * i / 16),
                     Z + 0.08)) for i in range(17)]
    _flower_line(a, outer, 0.05, GOLDS, 0.1)
    _flower_line(a, inner, 0.045, (PAINT_YELLOW, MARIGOLD, PINK), 0.11)
    # crown medallion: red disc, marigold ring, pink rose centre
    mc = (cx, cy + rise + 0.02, Z + 0.16)
    gdisc(a, mc[0], mc[1], mc[2], 0.24, RED, n=12, facing="+z")
    for k in range(12):
        t = 2 * math.pi * k / 12
        flower(a, B(mc[0] + 0.2 * math.cos(t), mc[1] + 0.2 * math.sin(t), mc[2] + 0.02), 0.045, (MARIGOLD, PAINT_YELLOW)[k % 2])
    gdisc(a, mc[0], mc[1], mc[2] + 0.01, 0.1, NEON_PINK, n=10, facing="+z")
    gdisc(a, mc[0], mc[1], mc[2] + 0.02, 0.05, PAINT_YELLOW, n=8, facing="+z")
    # ladis hanging from the inner arch into the doorway (bottom >= 2.42: the awning's back edge is at
    # y 2.38 and slopes down toward the road)
    for t in (0.2, 0.32, 0.44, 0.56, 0.68, 0.8):
        p = Vector((cx - (hw - 0.07) * math.cos(math.pi * t), cy + (rise - 0.07) * math.sin(math.pi * t), Z + 0.08))
        n_ = max(1, int((p.y - 2.42) / 0.09))
        for j in range(1, n_ + 1):
            flower(a, B(p.x, p.y - j * 0.09, p.z), 0.036, (MARIGOLD, RED, PAINT_YELLOW)[j % 3])
    # curtains: swagged marigold ropes from the staves to bamboo poles on the wall pillars
    ZC = 9.14                      # curtain plane, just in front of the wall face (z 9.15 cap edge 9.2)
    # right side: strands only where the game camera sees them clear of the seats board (screen
    # x > the board's right end: x >= 6.5 on this plane) and off the pillar at x 6.85 (6.6..7.1)
    for (px, x_post, strands, y0) in ((1.4, 2.78, [1.62 + 0.15 * k for k in range(7)], 0.93),
                                      (7.6, 4.82, [6.5, 7.17, 7.31, 7.45], 0.5)):
        gtube(a, (px, y0, ZC - 0.02), (px, 2.25, ZC - 0.02), 0.035, BAMBOO, seg=6)
        gball(a, (px, 2.25, ZC - 0.02), 0.04, BAMBOO, seg=6, rings=3)
        rope = gsag((x_post, 2.2, ZC), (px, 2.15, ZC), 0.22, 14)
        wire(a, rope, r=0.012, color=ROPE)
        _flower_line(a, rope, 0.04, GOLDS, 0.13)
        for sx_ in strands:
            # rope height at sx_ (linear search on the polyline)
            yb = min(rope, key=lambda q: abs(q.x - sx_)).y
            n_ = int((yb - 0.62) / 0.12)
            for j in range(1, n_ + 1):
                col = (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK, RED)[(j + int(sx_ * 10)) % 4]
                flower(a, B(sx_, yb - j * 0.12, ZC), 0.04, col)
        fs.string("baraat", [Vector(q) + Vector((0, -0.03, 0.03)) for q in rope], spacing=0.26, r=0.042, wire=False)
    fs.string("baraat", [Vector(q) + Vector((0, 0.0, 0.07)) for q in outer], spacing=0.2, r=0.045, wire=False)
    names, objs = fs.parts(mat)
    o = a.finish(mat, 30)
    g = Group("deco_baraat", ["deco_baraat"] + names, [o] + objs, 30)
    g.kind = "world"
    g.fairy = fs.count
    return g


HOARD_W, HOARD_H, HOARD_Y0 = 2.6, 1.3, 2.0       # main board 2.6 x 1.3 at y 2.0..3.3
HOARD_POLE_X, HOARD_POLE_H = 1.0, 3.2
HOARD_L2 = (1.8, 0.34, 1.55)                     # level-2 strip w, h, bottom y
HOARD_FACE = 0.045                               # board face plane: Godot local z +0.045


def _star(a, c, r_out, r_in, depth, front, side, rot=0.0):
    """5-point star prism facing -Y (Godot +Z), centre c (Blender)."""
    cx, cy, cz = c
    pts = []
    for k in range(10):
        t = math.pi / 2 + rot + math.pi * k / 5
        rr = r_out if k % 2 == 0 else r_in
        pts.append((cx + rr * math.cos(t), cz + rr * math.sin(t)))
    f_front = [a.bm.verts.new((x, cy - depth / 2, z)) for (x, z) in pts]
    f_back = [a.bm.verts.new((x, cy + depth / 2, z)) for (x, z) in pts]
    cfv = a.bm.verts.new((cx, cy - depth / 2, cz))
    cbv = a.bm.verts.new((cx, cy + depth / 2, cz))
    uvf, uvs = swatch_uv(front), swatch_uv(side)
    made = []
    for i in range(10):
        j = (i + 1) % 10
        made.append((a.bm.faces.new([cfv, f_front[j], f_front[i]]), uvf))
        made.append((a.bm.faces.new([cbv, f_back[i], f_back[j]]), uvs))
        made.append((a.bm.faces.new([f_front[i], f_front[j], f_back[j], f_back[i]]), uvs))
    for f, uv in made:
        for loop in f.loops:
            loop[a.uv].uv = uv
    return a


def build_hoarding(mat):
    """C5.3 highway hoarding (signboard levels), faces Godot +Z, origin on the ground between the
    two poles. Nodes (all with their origin at the model origin, so each is shown or hidden as a
    whole by level):
      hoarding_l1      poles, footings, braces and the main board 2.6 x 1.3 at y 2.0..3.3: red frame,
                       yellow field, a cream text panel 2.24 x 0.88 centred (0, 2.65) at z 0.048; child
                       empty text_l1 at (0, 2.65, 0.050), 2 mm in front of that panel, for the Label3D
                       "DHABA RUSH · 1 KM / ← ढाबा रश होटल" (the arrow points west: the hoarding stands
                       east of the dhaba since W3-LOOK)
      hoarding_l2      a cream strip 1.8 x 0.34 (y 1.55..1.89) hung under the board; child empty
                       text_l2 at (0, 1.72, 0.047) ("PARKING · 24 HRS" / "AC FAMILY HALL")
      hoarding_l3      an empty whose child mesh fairy_bulb_hoarding is the bulb frame round the board
      hoarding_l4      a second small board 1.2 x 0.45 on top (y 3.38..3.83), painted kulhad + roti
      hoarding_star_1  gold star left of it (levels 5-6), hoarding_star_2 right of it
    Labels: dark ink (maroon/brown) reads best on the cream panels."""
    keys = ("hoarding_l1", "hoarding_l2", "hoarding_l4", "hoarding_star_1", "hoarding_star_2")
    P = Parts("hoarding", {k: (0, 0, 0) for k in keys})
    l1, l2, l4, s1, s2 = (P[k] for k in keys)
    fy = -HOARD_FACE                                  # Blender y of the board face
    yc = HOARD_Y0 + HOARD_H / 2
    # ---- l1: poles, footings, braces, board
    for sx in (-1, 1):
        x = sx * HOARD_POLE_X
        l1.tube((x, 0.06, 0.0), (x, 0.06, HOARD_POLE_H), 0.065, DARK_STEEL, seg=6)
        l1.rbox((0.34, 0.34, 0.14), (x, 0.06, 0.07), CONCRETE, bevel=0.02)
        l1.beam((x, 0.06, 1.2), (x * 0.25, 0.06, HOARD_Y0 + 0.05), 0.04, DARK_STEEL)
        for (z, col) in ((0.3, PAINT_YELLOW), (0.6, INK), (0.9, PAINT_YELLOW)):
            l1.tube((x, 0.06, z), (x, 0.06, z + 0.3), 0.068, col, seg=6, caps=False)
    l1.rbox((HOARD_W, 0.08, HOARD_H), (0, 0.0, yc), DARK_STEEL, bevel=0.015)
    l1.decal((0, fy - 0.001, yc), HOARD_W, HOARD_H, "-y", RED)
    l1.decal((0, fy - 0.002, yc), HOARD_W - 0.14, HOARD_H - 0.14, "-y", PAINT_YELLOW)
    l1.decal((0, fy - 0.003, yc), HOARD_W - 0.36, HOARD_H - 0.42, "-y", CREAM)
    for k in range(10):                                                               # painted margin dots
        l1.decal((-HOARD_W / 2 + 0.25 + k * (HOARD_W - 0.5) / 9, fy - 0.003, HOARD_Y0 + 0.12), 0.07, 0.07, "-y",
                 (RED, GREEN, BLUE, NEON_PINK)[k % 4], rot=45)
    # ---- l2: strip hung under the board
    w2, h2, y2 = HOARD_L2
    for sx in (-1, 1):
        l2.rod((sx * (w2 / 2 - 0.12), fy + 0.01, y2 + h2), (sx * (w2 / 2 - 0.12), fy + 0.01, HOARD_Y0 + 0.02), 0.014,
               DARK_STEEL, seg=4)
    l2.rbox((w2, 0.04, h2), (0, fy + 0.02, y2 + h2 / 2), JACKET, bevel=0.01)
    l2.decal((0, fy - 0.001, y2 + h2 / 2), w2 - 0.08, h2 - 0.08, "-y", CREAM)
    # ---- l4: small board on top with a painted kulhad and roti
    yb4, w4, h4 = HOARD_Y0 + HOARD_H + 0.08, 1.2, 0.45
    for sx in (-1, 1):
        l4.block((0.05, 0.05, 0.12), (sx * 0.42, 0.0, HOARD_Y0 + HOARD_H - 0.02), DARK_STEEL, nb=False)
    l4.rbox((w4, 0.06, h4), (0, 0.0, yb4 + h4 / 2), DARK_STEEL, bevel=0.012)
    l4.decal((0, fy + 0.006, yb4 + h4 / 2), w4, h4, "-y", GOLD)
    l4.decal((0, fy + 0.005, yb4 + h4 / 2), w4 - 0.08, h4 - 0.08, "-y", MAROON)
    kc = (-0.22, fy + 0.004, yb4 + 0.17)                                              # kulhad
    l4.face([(kc[0] - 0.09, kc[1], kc[2] - 0.1), (kc[0] + 0.09, kc[1], kc[2] - 0.1), (kc[0] + 0.12, kc[1], kc[2] + 0.07),
             (kc[0] - 0.12, kc[1], kc[2] + 0.07)], CLAY, normal=(0, -1, 0))
    l4.decal((kc[0], kc[1] - 0.001, kc[2] + 0.05), 0.24, 0.035, "-y", BRICK)
    for k, (dx, dz) in enumerate(((-0.05, 0.14), (0.02, 0.2), (-0.02, 0.27))):        # steam
        disc(l4, (kc[0] + dx, kc[1] - 0.001, kc[2] + dz), 0.035 - 0.006 * k, WHITE, n=6)
    disc(l4, (0.24, fy + 0.003, yb4 + h4 / 2), 0.15, ROTI, n=10)                       # roti
    for (dx, dz) in ((-0.05, 0.04), (0.06, -0.03), (0.0, -0.07)):
        disc(l4, (0.24 + dx, fy + 0.002, yb4 + h4 / 2 + dz), 0.025, CHAI, n=6)
    # ---- stars (levels 5-6) on the top edge, either side of the small board
    for (S, x) in ((s1, -0.98), (s2, 0.98)):
        S.block((0.05, 0.05, 0.12), (x, 0.0, HOARD_Y0 + HOARD_H - 0.02), DARK_STEEL, nb=False)
        _star(S, (x, 0.0, HOARD_Y0 + HOARD_H + 0.26), 0.22, 0.09, 0.05, GOLD, GOLD_DARK)
    g = P.finish(mat, 30)
    # ---- l3: bulb frame round the main board (an empty hoarding_l3 with the bulb mesh as child)
    fs = FairySet("hoarding", seed=61)
    x0, x1 = -HOARD_W / 2 - 0.02, HOARD_W / 2 + 0.02
    z0, z1 = HOARD_Y0 - 0.02, HOARD_Y0 + HOARD_H + 0.02
    gz = HOARD_FACE + 0.035                                                           # Godot z, in front
    fs.string("hoarding", [(x0, z0, gz), (x1, z0, gz), (x1, z1, gz), (x0, z1, gz), (x0, z0, gz)], spacing=0.26,
              r=0.045, wire=False, start=0.0)
    names, objs = fs.parts(mat)
    g.names += names
    g.objs += objs
    g.extras.append(("hoarding_l3", (0.0, 0.0, 0.0)))
    # text_l1 sits 2 mm in front of l1's cream panel (decal at fy - 0.003, Godot z 0.048); at fy - 0.002 it lay
    # 1 mm behind the panel and the panel hid its Label3D (W1-FIX-other). text_l2: 1 mm in front of its strip.
    g.extras.append(("text_l1", (0.0, -(HOARD_FACE + 0.005), yc)))
    g.extras.append(("text_l2", (0.0, -(HOARD_FACE + 0.002), y2 + h2 / 2)))
    g.parents = {"fairy_bulb_hoarding": "hoarding_l3", "text_l1": "hoarding_l1", "text_l2": "hoarding_l2"}
    return g


def build_dog_sit(mat):
    """C8.3 sitting street dog (the sleeping dog's swatches), faces Godot +Z, origin on the ground
    under its middle. Nodes: body, head (pivot at the neck: code turns it about Y toward walkers),
    tail (pivot at the root: code wags it about Y, the tail sweeps the ground)."""
    P = Parts("dog_sit", {"body": (0, 0, 0), "head": (0, -0.07, 0.4), "tail": (0, 0.2, 0.08)})
    b, h, t = P["body"], P["head"], P["tail"]
    # haunches + hind legs folded, chest up, two straight front legs with white paws
    b.ell((0, 0.09, 0.13), (0.14, 0.16, 0.13), DOG, seg=10, rings=6)
    for s in (-1, 1):
        b.ell((s * 0.12, 0.04, 0.08), (0.05, 0.14, 0.075), DOG, seg=8, rings=5)          # thighs
        b.ell((s * 0.11, -0.06, 0.025), (0.04, 0.07, 0.025), WHITE, seg=6, rings=3)       # hind paws
    chest = frame((0, -0.45, 1.0), (0, -1, 0))
    b.ell((0, -0.02, 0.26), (0.18, 0.1, 0.105), DOG, frame=chest, seg=10, rings=6)
    b.ell((0, -0.1, 0.27), (0.11, 0.05, 0.07), WHITE, frame=chest, seg=8, rings=5)         # chest patch
    for s in (-1, 1):
        b.tube((s * 0.05, -0.09, 0.24), (s * 0.055, -0.12, 0.03), 0.032, DOG, r1=0.026, seg=6)
        b.ell((s * 0.055, -0.14, 0.02), (0.035, 0.05, 0.022), WHITE, seg=6, rings=3)      # front paws
    b.ell((0, -0.07, 0.38), (0.06, 0.06, 0.06), DOG, seg=8, rings=5)                     # neck
    # head (built in model space; Parts moves its origin to the neck)
    hc = Vector((0, -0.11, 0.46))
    h.ell(tuple(hc), (0.085, 0.09, 0.075), DOG, seg=10, rings=6)
    h.ell((0, -0.2, 0.44), (0.045, 0.06, 0.038), DOG, seg=8, rings=5)                   # snout
    h.ell((0, -0.19, 0.425), (0.04, 0.05, 0.02), WHITE, seg=6, rings=3)                  # muzzle
    h.ell((0, -0.258, 0.45), (0.02, 0.016, 0.016), HAIR, seg=6, rings=3)                 # nose
    for s in (-1, 1):
        h.ell((s * 0.04, -0.175, 0.485), (0.014, 0.008, 0.014), HAIR, seg=6, rings=3)     # eyes
        h.cyl(0.035, 0.08, (s * 0.05, -0.09, 0.52), TRUNK, seg=4, r2=0.004, rot=(-12, s * 18, 0))  # ears up
    # tail (root at the rump, curled forward along the ground)
    limb(t, [(0, 0.2, 0.08), (0.06, 0.27, 0.035), (0.16, 0.24, 0.025), (0.22, 0.12, 0.025)],
         [0.03, 0.026, 0.022, 0.018], DOG, seg=6, joint_seg=6, joint_rings=4)
    t.ell((0.235, 0.08, 0.025), (0.03, 0.04, 0.02), WHITE, seg=6, rings=3)
    return P.finish(mat, 40)


def camel_geo(b):
    """Seated camel (kush pose), Blender local, facing +X, centre of its body at the origin's x."""
    CAM, CAM_D = DOG, DUST_DARK
    b.ell((0, 0, 0.42), (0.55, 0.3, 0.28), CAM, seg=12, rings=6)                       # body
    b.ell((-0.05, 0, 0.72), (0.27, 0.22, 0.2), CAM, seg=10, rings=6)                   # hump
    b.ell((-0.05, 0, 0.62), (0.32, 0.33, 0.12), RED, seg=12, rings=4)                  # saddle cloth
    b.ell((-0.05, 0, 0.6), (0.33, 0.335, 0.03), PAINT_YELLOW, seg=12, rings=3)         # its border
    for (x, s) in ((0.35, -1), (0.35, 1), (-0.35, -1), (-0.35, 1)):                    # folded legs
        b.ell((x, s * 0.26, 0.1), (0.24, 0.08, 0.09), CAM_D, seg=8, rings=4)
    neck = [(0.45, 0, 0.5), (0.68, 0, 0.62), (0.8, 0, 0.88), (0.86, 0, 1.08)]
    limb(b, neck, [0.13, 0.1, 0.085, 0.075], CAM, seg=8, joint_seg=8, joint_rings=4)
    b.ell((0.98, 0, 1.12), (0.18, 0.085, 0.09), CAM, frame=frame((1, 0, -0.25), (0, 0, 1)), seg=10, rings=5)
    b.ell((1.14, 0, 1.08), (0.05, 0.06, 0.05), CAM_D, seg=6, rings=4)                  # muzzle
    for s in (-1, 1):
        b.ell((0.94, s * 0.075, 1.17), (0.02, 0.012, 0.016), HAIR, seg=6, rings=3)       # eyes
        b.cyl(0.025, 0.06, (0.86, s * 0.06, 1.18), CAM_D, seg=4, r2=0.006, rot=(s * -20, 0, 0))   # ears
    for k in range(9):                                                                 # bead necklace
        t = 2 * math.pi * k / 9
        flower(b, (0.72 + 0.11 * math.cos(t) * 0.5, 0.11 * math.sin(t), 0.7 + 0.11 * math.cos(t)), 0.03,
               (MARIGOLD, RED, PAINT_YELLOW)[k % 3])
    b.rod((1.12, 0.04, 1.1), (0.9, 0.05, 0.62), 0.008, RED, seg=3)                      # nose rope
    return b


CAMEL_S = 1.3                                  # a seated camel stands taller than a chibi traveller


def build_camel_cart(mat):
    """C6.3 NH 48 camel cart: a flat wooden cart on two tyre wheels with sacks, a rolled durrie and
    a matka, its shafts resting on a seated camel (static) with a red saddle cloth. Faces Godot +X,
    origin at the cart centre on the ground. About 4.3 m long (x -0.88..+3.4, the camel's nose at
    the +X end), 1.48 m wide over the wheels, 1.6 m tall at the camel's head."""
    a = Asset("camel_cart")
    # cart platform, side rails, wheels, axle
    a.rbox((1.75, 1.2, 0.08), (0, 0, 0.66), WOOD, bevel=0.015)
    for s in (-1, 1):
        a.box((1.75, 0.05, 0.12), (0, s * 0.58, 0.76), TRUNK)
        for x in (-0.6, 0.0, 0.6):
            a.block((0.05, 0.05, 0.14), (x, s * 0.58, 0.7), TRUNK, nb=False)
        a.wheel(0.42, 0.14, (0.0, s * 0.67, 0.42), seg=12)
        a.wheel(0.18, 0.16, (0.0, s * 0.67, 0.42), STEEL, seg=8)
    a.rod((0.0, -0.74, 0.42), (0.0, 0.74, 0.42), 0.04, DARK_STEEL, seg=6)
    a.box((1.6, 0.9, 0.04), (0, 0, 0.6), TRUNK)
    # load: jute sacks, a rolled striped durrie, a clay matka
    for (x, y, s, z) in ((-0.5, -0.25, 1.0, 0.84), (-0.5, 0.25, 0.95, 0.84), (0.05, -0.2, 0.9, 0.84),
                         (-0.25, 0.0, 0.85, 0.98)):
        a.ico(0.24 * s, (x, y, z), ROPE, subdiv=1, scale=(1.15, 0.85, 0.7))
    a.tube((0.45, -0.45, 0.82), (0.45, 0.45, 0.82), 0.12, RED, seg=8)
    for y in (-0.25, 0.0, 0.25):
        a.tube((0.45, y - 0.03, 0.82), (0.45, y + 0.03, 0.82), 0.123, PAINT_YELLOW, seg=8, caps=False)
    a.place(lambda b: matka_geo(b, 0.17, RED), loc=(0.6, 0.3, 0.7))
    # shafts from the platform to the camel's flanks
    for s in (-1, 1):
        a.tube((0.82, s * 0.4, 0.64), (1.55, s * 0.42, 0.5), 0.035, TRUNK, seg=5)
        a.tube((-0.88, s * 0.4, 0.66), (-0.82, s * 0.4, 0.66), 0.04, TRUNK, seg=5)
    a.place(camel_geo, loc=(1.78, 0.0, 0.0), s=CAMEL_S)
    return a.finish(mat, 30)


def build_bus_baraat(mat):
    """C6.4 baraat bus: the state bus body (bus_geo) in white with a broad maroon band and marigold
    stripes; on the roof (what the game camera sees most) a maroon wedding cloth with a gold border
    and marigold motifs inside the rack, marigold swags along both rack rails; marigold swags along
    the window strip on both sides; a blank cream side banner with a marigold frame on both sides
    between the wheels (for a Label3D: centre Godot local (0.3, 0.92, +-1.114) facing +-Z, field
    2.5 x 0.3); balloon bunches tied to the mirror arms and the rear corners. Everything stays
    inside the plain bus's bounds (Traffic measures vehicles from them) and under its roof rack
    (build_assets prints the check)."""
    b = Asset("bus_baraat")
    bus_geo(b, body=WHITE, s1=MAROON, s2=MARIGOLD, luggage=False)
    # roof: wedding cloth inside the rack (rack rails x -2.4..2.0, y +-0.9, z 2.56)
    b.rbox((4.2, 1.66, 0.05), (-0.2, 0.0, 2.485), MAROON, bevel=0.02)
    b.decal((-0.2, 0.0, 2.5115), 4.0, 1.46, "+z", GOLD)
    b.decal((-0.2, 0.0, 2.512), 3.86, 1.32, "+z", MAROON)
    for k in range(5):
        b.decal((-1.8 + k * 0.8, 0.0, 2.5125), 0.36, 0.36, "+z", (MARIGOLD, PAINT_YELLOW)[k % 2], rot=45)
        b.decal((-1.8 + k * 0.8, 0.0, 2.513), 0.16, 0.16, "+z", NEON_PINK, rot=45)
    for s_ in (-1, 1):                                                   # swags along the rack rails
        for i in range(2):
            x0, x1 = -2.4 + i * 2.2, -2.4 + (i + 1) * 2.2
            pts = sag((x0, s_ * 0.93, 2.56), (x1, s_ * 0.93, 2.56), 0.06, 7)
            for j, p in enumerate(pts[1:-1]):
                flower(b, p, 0.045, (MARIGOLD, PAINT_YELLOW, MARIGOLD_DARK)[j % 3])
    H = 1.105
    for s in (-1, 1):
        side = "+y" if s > 0 else "-y"
        Y = s * H
        # banner: marigold frame, maroon line, cream field (between the wheels)
        b.decal((0.3, Y + s * 0.006, 0.92), 2.66, 0.42, side, MARIGOLD)
        b.decal((0.3, Y + s * 0.007, 0.92), 2.56, 0.34, side, MAROON)
        b.decal((0.3, Y + s * 0.008, 0.92), 2.5, 0.3, side, CREAM)
        # marigold swags along the top of the window strip
        for i in range(3):
            x0, x1 = -2.9 + i * 1.9, -2.9 + (i + 1) * 1.9
            pts = sag((x0, Y + s * 0.035, 2.1), (x1, Y + s * 0.035, 2.1), 0.22, 7)
            for j, p in enumerate(pts[1:-1]):
                flower(b, p, 0.042, (MARIGOLD, PAINT_YELLOW, RED)[j % 3])
    # balloon bunches: on the mirror arms (front) and at the rear corners, outside the body
    for (x, s, front) in ((3.4, -1, True), (3.4, 1, True), (-3.29, -1, False), (-3.29, 1, False)):
        bunch = (((0.0, 0.0, 0.0, RED), (-0.05, -0.06, 0.12, PAINT_YELLOW), (0.04, 0.05, 0.2, NEON_PINK)) if front
                 else ((0.0, 0.0, 0.0, PAINT_YELLOW), (0.0, -0.12, 0.1, RED), (0.0, 0.1, 0.18, NEON_PINK)))
        yc_ = 1.16 if front else 1.0
        for (dx, dy, dz, col) in bunch:
            b.ico(0.08, (x + dx, s * (yc_ + dy), 2.1 + dz), col, subdiv=0, scale=(1, 1, 1.25))
        b.rod((x, s * yc_, 2.02), (x, s * yc_, 1.75 if front else 1.6), 0.008, WHITE, seg=3)
    return b.finish(mat)


def build_core_feel_ext(mat):
    """(singles, groups) of the W1-ART1 world art (core-and-feel)."""
    singles = [build_camel_cart(mat), build_bus_baraat(mat)]
    groups = [build_family_hall(mat), build_deco_baraat(mat), build_hoarding(mat), build_dog_sit(mat)]
    return singles, groups
