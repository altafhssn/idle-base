"""Dhaba Rush — procedural low-poly asset builder.

Run headless (from the project root):
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
      -P tools/blender/build_assets.py -- themes/dhaba/models [--sheet docs/art/asset_sheet.png]

Every asset is built from primitives into one mesh, flat shaded, UV-mapped onto
a shared 48-swatch palette atlas (one material, one texture), and exported as
.glb (+Y up, no Draco) for Godot. With --sheet, three review renders are also
written next to the sheet: asset_sheet.png, world_preview.png (game camera) and
world_top.png (orthographic top view of the assembled layout).

v0.3 assets (dhaba_v3, street_v3, tandoor_lock, station props, banknote/sikka/marker/
cash_brick, the cow, travellers/staff/waiters with named body parts, tray/tray_rack/pass items,
dog and the munshi_* busts) are built by the v3_*.py helper modules next to this file (see
build_v3()). v3_exterior.py builds the Indian highway exterior, truck parking and the fairy
lights (fairy_bulb_* nodes inside dhaba_v3.glb / street_v3.glb; docs in its header).
DHABA_V3_RENDERS=world,views,sheet,vehicles,munshi,chars limits the review renders;
DHABA_PROFILE=1 prints triangles per exterior section. When the --sheet
file name starts with "v3", the v0.3 review renders are written next to it instead of the
legacy ones (v3_world_preview.png, v3_sheet.png, v3_view_*.png, v3_munshi*.png,
v3_characters*.png).

Axes: Blender X = Godot X, Blender Z = Godot Y (up), Blender -Y = Godot +Z
(toward the camera side of the compound). Godot (x, y, z) == Blender (x, -z, y).
Characters and props face -Y (Godot +Z); vehicles face +X. Origins sit on the
ground (z = 0) at the footprint centre, except WORLD-COORD assets (ground,
compound, scenery, wall_wire, wall_bulbs) whose origin is the world origin.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# ------------------------------------------------------------------ palette
PALETTE = [
    "4A4A52", "F2F2E9", "E8B77A", "C9935A", "9DB36A", "4E8A3E", "7A4E2D", "A8673A",  # 0-7
    "9FB4BF", "B8643A", "FFF1D6", "2E8C8C", "D9412B", "F5C431", "2F9E5A", "2D6FD1",  # 8-15
    "F28C28", "C98A5C", "8D5A3B", "2B2420", "F7F4EE", "FF9933", "E86A9A", "7B5EA7",  # 16-23
    "C9CDD2", "5E646B", "B5653A", "FF6A1A", "A0622D", "E3A72F", "E9C27B", "E4D3A8",  # 24-31
    "6FBF73", "A9D8E6", "2A2A2A", "FFF2A8", "D69C64", "2F6B3A", "2B3A67", "8A2C2C",  # 32-39
    "6E7C8C", "9A9187", "FF4FA3", "38E1FF", "B5543A", "3B4A5C", "FFD23F", "A6D96A",  # 40-47
    # v0.3 diorama swatches (rows 6-9): cleaner, more saturated tones for the store rebuild
    "D6BC9F", "BFA285", "F4D58D", "26A69A", "C9553B", "EBD8BB", "FFF5DF", "8E2436",  # 48-55 (floor tiles calmer 2026-11-04, art audit S2)
    "F7C548", "C98B1C", "86D07A", "2C6E55", "FFB23F", "FF8A1F", "E0611A", "F4C9A4",  # 56-63
    "D99A6A", "F08A7A", "4167A8", "B89B62", "5D6170", "DEDAD3", "B4AFA8", "86A94A",  # 64-71
    "5DA238", "3F8A34", "F6F2EA", "DBC7A2", "D9B36A", "BDB8B0", "C64A3A", "8FA9BF",  # 72-79
    # v0.3 exterior row (2026-10-19, Indian highway restyle): unpaved dust, lot dust, Sintex
    # tank grey, mango-leaf green, painted-wall blue, pastel plaster pink, tyre tracks, truck teal
    "D9BF8E", "C9A872", "474B55", "2E7D32", "5C9BD6", "F2A7B8", "BC9566", "3FB8BE",  # 80-87
    # 2026-10-20 exterior + fairy lights: tandoor smoke, neem greens, concrete pole, pastel
    # green wall, cream wall, lime-wash white, street-dog tan
    "DED8CE", "4F9B30", "8CC84B", "A7A59C", "9ED98B", "FFE6B0", "FFFDF6", "D9A066",  # 88-95
]
(ASPHALT, LINE, DUST, DUST_DARK, GRASS, LEAF, TRUNK, WOOD, TIN, RUST, CREAM, TEAL, RED, YELLOW,
 GREEN, BLUE, ORANGE, SKIN1, SKIN2, HAIR, WHITE, SAFFRON, PINK, PURPLE, STEEL, DARK_STEEL, CLAY,
 FIRE, CHAI, DAL, ROTI, ROPE, CASH, GLASS, TYRE, BULB, MUD, DARK_GREEN, NAVY, MAROON,
 SLATE, GRAVEL, NEON_PINK, NEON_CYAN, BRICK, TARP, PAINT_YELLOW, LEAF_LIGHT) = range(48)
(TILE_A, TILE_B, PLASTER, DADO, BRICK_RED, MORTAR, KURTA, JACKET,
 GOLD, GOLD_DARK, NOTE, NOTE_DARK, MARKER_TOP, MARIGOLD, MARIGOLD_DARK, SKIN_L,
 SKIN_M, BLUSH, DENIM, KHAKI, ROAD, PAVER, KERB, LIME,
 LIME_DARK, FOLIAGE, COW, HORN, BAMBOO, CONCRETE, ROOF_RED, TIN_BLUE) = range(48, 80)
(DUST_LT, DUST_LOT, TANK, MANGO, WALL_BLUE, WALL_PINK, TRACK, TRUCK_TEAL) = range(80, 88)
(SMOKE, NEEM, NEEM_LT, POLE, WALL_GREEN, WALL_CREAM, WHITEWASH, DOG) = range(88, 96)
COLS, ROWS, SW = 8, 12, 16
assert len(PALETTE) == COLS * ROWS

# World-coord assets: origin = world origin, geometry placed at world positions.
WORLD_ASSETS = {"ground", "compound", "scenery", "wall_wire", "wall_bulbs"}
# Triangle budgets per asset family (checked and reported after the build).
BUDGETS = {"compound": 3000, "scenery": 6000, "ground": 800, "road": 400,
           "wall_wire": 600, "wall_bulbs": 700}
VEHICLES = {"bike", "car", "car_red", "car_blue", "car_taxi", "auto", "truck", "truck_green", "bus", "car_ambassador"}
CANOPIES = {"canopy_red", "canopy_teal", "canopy_yellow", "canopy_blue", "canopy_pink"}


def budget_for(name):
    if name in BUDGETS:
        return BUDGETS[name]
    if name in VEHICLES:
        return 2600
    if name in CANOPIES:
        return 400
    return 800


def build_palette_image():
    img = bpy.data.images.new("palette", COLS * SW, ROWS * SW, alpha=False)
    px = [0.0] * (COLS * SW * ROWS * SW * 4)
    for idx, hexv in enumerate(PALETTE):
        r, g, b = (int(hexv[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        col, row = idx % COLS, idx // COLS
        for y in range(SW):
            for x in range(SW):
                # image rows start at the bottom; put swatch row 0 at the top
                py = (ROWS - 1 - row) * SW + y
                pxi = (py * COLS * SW + col * SW + x) * 4
                px[pxi:pxi + 4] = [r, g, b, 1.0]
    img.pixels = px
    return img


def swatch_uv(idx):
    col, row = idx % COLS, idx // COLS
    u = (col + 0.5) / COLS
    v = 1.0 - (row + 0.5) / ROWS
    return (u, v)


def ensure_nodes(idblock):
    # Blender 5 node trees always exist; older versions need use_nodes (deprecated in 5.x).
    if getattr(idblock, "node_tree", None) is None:
        idblock.use_nodes = True


def make_material(img):
    mat = bpy.data.materials.new("palette")
    ensure_nodes(mat)
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.15
    return mat


# ------------------------------------------------------------------ builder
def mat4(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return (Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
            @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))


def B(x, y, z):
    """Godot position -> Blender position."""
    return (x, -z, y)


_FACING = {"+x": (1, 0, 0), "-x": (-1, 0, 0), "+y": (0, 1, 0), "-y": (0, -1, 0), "+z": (0, 0, 1)}


class Asset:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _paint(self, verts, color):
        faces = {f for v in verts for f in v.link_faces}
        uv = swatch_uv(color)
        for f in faces:
            for loop in f.loops:
                loop[self.uv].uv = uv

    # -- solids
    def box(self, size, loc, color, rot=(0, 0, 0), nb=False):
        """size=(x,y,z), loc = centre. nb drops the (hidden) bottom face."""
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat4(loc, rot, size))
        self._paint(r["verts"], color)
        if nb:
            zmin = min(v.co.z for v in r["verts"])
            faces = {f for v in r["verts"] for f in v.link_faces}
            bot = [f for f in faces if all(abs(v.co.z - zmin) < 1e-6 for v in f.verts)]
            bmesh.ops.delete(self.bm, geom=bot, context="FACES_ONLY")
        return self

    def block(self, size, base, color, rot=(0, 0, 0), nb=None):
        """Box whose base (bottom centre) sits at `base`. Ground-standing unrotated
        blocks drop their bottom face automatically."""
        if nb is None:
            nb = base[2] <= 1e-4 and tuple(rot) == (0, 0, 0)
        return self.box(size, (base[0], base[1], base[2] + size[2] / 2), color, rot, nb=nb)

    def cyl(self, r, h, base, color, seg=8, rot=(0, 0, 0), r2=None, nb=False):
        """Cylinder/cone standing on `base` (bottom centre), axis +Z before `rot`.
        nb drops the bottom cap (for things resting on a surface)."""
        r2 = r if r2 is None else r2
        m = mat4(base, rot) @ Matrix.Translation((0, 0, h / 2))
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r2, depth=h, matrix=m)
        self._paint(res["verts"], color)
        if nb:
            vs = set(res["verts"])
            zmin = min(v.co.z for v in vs)
            bot = [f for f in {f for v in vs for f in v.link_faces}
                   if len(f.verts) > 2 and all(abs(v.co.z - zmin) < 1e-6 for v in f.verts)]
            bmesh.ops.delete(self.bm, geom=bot, context="FACES_ONLY")
        return self

    def wheel(self, r, w, centre, color=TYRE, seg=10, axis="y"):
        rot = {"y": (90, 0, 0), "x": (0, 90, 0), "z": (0, 0, 0)}[axis]
        m = mat4(centre, rot)
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r, depth=w, matrix=m)
        self._paint(res["verts"], color)
        return self

    def ball(self, r, centre, color, seg=8, rings=5, scale=(1, 1, 1)):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r,
                                        matrix=mat4(centre, (0, 0, 0), scale))
        self._paint(res["verts"], color)
        return self

    def ico(self, r, centre, color, subdiv=1, scale=(1, 1, 1), rot=(0, 0, 0)):
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=r,
                                         matrix=mat4(centre, rot, scale))
        self._paint(res["verts"], color)
        return self

    def beam(self, p0, p1, t, color, t2=None):
        """Square-section bar from p0 to p1 (t = width, t2 = height)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        q = d.to_track_quat("X", "Z")
        m = (Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4()
             @ Matrix.Diagonal((d.length, t, t2 if t2 else t, 1.0)))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        self._paint(r["verts"], color)
        return self

    def rod(self, p0, p1, r, color, seg=6):
        """Cylinder from p0 to p1."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        q = d.to_track_quat("Z", "Y")
        m = Matrix.Translation(p0) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, d.length / 2))
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r, depth=d.length, matrix=m)
        self._paint(res["verts"], color)
        return self

    # -- v0.3 helpers: rounded boxes and oriented ellipsoids (used with finish(smooth=...))
    def _paint_new(self, before, color):
        uv = swatch_uv(color)
        for f in self.bm.faces:
            if f not in before:
                for loop in f.loops:
                    loop[self.uv].uv = uv

    def rbox(self, size, loc, color, rot=(0, 0, 0), bevel=0.03, seg=1):
        """Box centred at loc with bevelled (rounded) edges. bevel is clamped to the
        smallest half-size so thin slabs still work."""
        before = set(self.bm.faces)
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=mat4(loc, rot, size))
        bev = min(bevel, 0.45 * min(size))
        if bev > 1e-4:
            vs = r["verts"]
            edges = list({e for v in vs for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=vs + edges, offset=bev, offset_type="OFFSET",
                            segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        self._paint_new(before, color)
        return self

    def ell(self, centre, radii, color, frame=None, seg=10, rings=6):
        """Ellipsoid with semi-axes `radii` along the columns of `frame` (3x3, default
        world axes)."""
        m = Matrix.Translation(Vector(centre))
        if frame is not None:
            m = m @ frame.to_4x4()
        m = m @ Matrix.Diagonal((radii[0], radii[1], radii[2], 1.0))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=1.0, matrix=m)
        self._paint(res["verts"], color)
        return self

    def tube(self, p0, p1, r0, color, r1=None, seg=8, caps=True):
        """Tapered cylinder from p0 (radius r0) to p1 (radius r1)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        q = d.to_track_quat("Z", "Y")
        m = Matrix.Translation(p0) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, d.length / 2))
        res = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg,
                                    radius1=r0, radius2=r0 if r1 is None else r1, depth=d.length, matrix=m)
        self._paint(res["verts"], color)
        return self

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    # -- flat pieces (the palette material is double-sided)
    def face(self, pts, color, up=False, normal=None):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.normal_update()
        want = Vector((0, 0, 1)) if up else (Vector(normal) if normal is not None else None)
        if want is not None and f.normal.dot(want) < 0:
            f.normal_flip()
        uv = swatch_uv(color)
        for loop in f.loops:
            loop[self.uv].uv = uv
        return self

    def decal(self, c, w, h, facing, color, rot=0.0):
        """Flat w x h rectangle centred at c, facing an axis ('+x','-x','+y','-y','+z').
        u runs along the face's horizontal, v up (or +Y for '+z'); rot spins it in-plane."""
        a = math.radians(rot)
        ca, sa = math.cos(a), math.sin(a)
        pts = []
        for (u, v) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            u2, v2 = u * ca - v * sa, u * sa + v * ca
            if facing == "-y":
                p = (c[0] + u2, c[1], c[2] + v2)
            elif facing == "+y":
                p = (c[0] - u2, c[1], c[2] + v2)
            elif facing == "+x":
                p = (c[0], c[1] + u2, c[2] + v2)
            elif facing == "-x":
                p = (c[0], c[1] - u2, c[2] + v2)
            else:
                p = (c[0] + u2, c[1] + v2, c[2])
            pts.append(p)
        return self.face(pts, color, normal=_FACING[facing])

    # -- composition
    def place(self, fn, loc=(0, 0, 0), rz=0.0, s=1.0, rot=None):
        """Run fn(self) and move only the geometry it added (reuse of builders).
        `rot` (degrees, x/y/z) overrides the plain z spin `rz`."""
        before = set(self.bm.verts)
        fn(self)
        verts = [v for v in self.bm.verts if v not in before]
        r = rot if rot is not None else (0, 0, rz)
        bmesh.ops.transform(self.bm, matrix=mat4(loc, r, (s, s, s)), verts=verts)
        return self

    # -- Godot-space helpers for WORLD-COORD assets: size=(x, y_up, z), base=(x, y, z)
    def gblock(self, size, base, color, ry=0.0, nb=None):
        return self.block((size[0], size[2], size[1]), B(*base), color, rot=(0, 0, ry), nb=nb)

    def grect(self, x0, z0, x1, z1, y, color):
        """Flat axis-aligned rectangle on the ground (Godot x/z) at height y."""
        return self.face([B(x0, y, z0), B(x1, y, z0), B(x1, y, z1), B(x0, y, z1)], color, up=True)

    def gblob(self, x, z, r, y, color, rng, n=9, jit=0.22, sx=1.0, sz=1.0):
        """Irregular flat patch on the ground (Godot x/z)."""
        pts = []
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = r * (1 + rng.uniform(-jit, jit))
            pts.append(B(x + math.cos(a) * rr * sx, y, z + math.sin(a) * rr * sz))
        return self.face(pts, color, up=True)

    def finish(self, material, smooth=None):
        """smooth=None: flat shaded (v0.2 look). smooth=degrees: smooth shading with edges
        sharper than that angle split (rounded parts read soft, boxes stay crisp)."""
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for p in mesh.polygons:
            p.use_smooth = smooth is not None
        if smooth is not None:
            mesh.set_sharp_from_angle(angle=math.radians(smooth))
        mesh.materials.append(material)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def sag(p0, p1, s, n):
    """n+1 points of a hanging string from p0 to p1 (Blender coords) sagging s."""
    p0, p1 = Vector(p0), Vector(p1)
    out = []
    for i in range(n + 1):
        t = i / n
        p = p0.lerp(p1, t)
        p.z -= s * 4 * t * (1 - t)
        out.append(p)
    return out


def bunting(a, p0, p1, s, flags, colors, depth=0.24, wire=HAIR, normal=(0, -1, 0)):
    """String of triangular flags between p0 and p1."""
    pts = sag(p0, p1, s, flags * 2)
    for i in range(0, 2 * flags, 4):                      # wire: one thin rod per two flags
        a.rod(pts[i], pts[min(i + 4, 2 * flags)], 0.012, wire, seg=3)
    for i in range(flags):
        l, m, r = pts[2 * i], pts[2 * i + 1], pts[2 * i + 2]
        lw, rw = l.lerp(m, 0.15), r.lerp(m, 0.15)
        tip = m.copy()
        tip.z -= depth
        a.face([lw, rw, tip], colors[i % len(colors)], normal=normal)


# ------------------------------------------------------------------ characters
def person(a, h=1.0, skin=SKIN1, top=BLUE, legs=NAVY, hair=HAIR, extra=None):
    """Chibi person ~h tall, facing -Y."""
    s = h / 1.0
    a.block((0.13 * s, 0.14 * s, 0.32 * s), (-0.09 * s, 0, 0), legs)
    a.block((0.13 * s, 0.14 * s, 0.32 * s), (0.09 * s, 0, 0), legs)
    a.block((0.36 * s, 0.24 * s, 0.34 * s), (0, 0, 0.3 * s), top)
    a.block((0.1 * s, 0.11 * s, 0.3 * s), (-0.23 * s, 0, 0.33 * s), top, rot=(0, -8, 0))
    a.block((0.1 * s, 0.11 * s, 0.3 * s), (0.23 * s, 0, 0.33 * s), top, rot=(0, 8, 0))
    a.ball(0.055 * s, (-0.24 * s, 0, 0.32 * s), skin, seg=6, rings=4)
    a.ball(0.055 * s, (0.24 * s, 0, 0.32 * s), skin, seg=6, rings=4)
    a.ball(0.2 * s, (0, 0, 0.82 * s), skin, seg=10, rings=6)
    a.ball(0.205 * s, (0, 0.03 * s, 0.9 * s), hair, seg=10, rings=6, scale=(1, 1, 0.6))
    # eyes
    a.box((0.035 * s, 0.02 * s, 0.05 * s), (-0.07 * s, -0.19 * s, 0.84 * s), HAIR)
    a.box((0.035 * s, 0.02 * s, 0.05 * s), (0.07 * s, -0.19 * s, 0.84 * s), HAIR)
    if extra:
        extra(a, s)
    return a


def build_characters(mat):
    out = []

    def bhaiya_extra(a, s):
        a.ball(0.2 * s, (0, -0.05 * s, 0.42 * s), WHITE, scale=(1, 0.9, 0.9))  # belly
        a.box((0.2 * s, 0.03 * s, 0.035 * s), (0, -0.2 * s, 0.75 * s), HAIR)  # moustache
        a.block((0.08 * s, 0.26 * s, 0.3 * s), (-0.12 * s, 0, 0.42 * s), RED, rot=(0, 20, 0))  # gamchha
        a.block((0.38 * s, 0.26 * s, 0.22 * s), (0, 0, 0.42 * s), SAFFRON)  # vest
    out.append(person(Asset("bhaiya"), 1.15, SKIN1, WHITE, NAVY, HAIR, bhaiya_extra).finish(mat))

    def chotu_extra(a, s):
        a.block((0.38 * s, 0.26 * s, 0.1 * s), (0, 0, 0.26 * s), NAVY)  # shorts band
    out.append(person(Asset("chotu"), 0.8, SKIN2, ORANGE, NAVY, HAIR, chotu_extra).finish(mat))

    out.append(person(Asset("customer_a"), 1.0, SKIN1, BLUE, NAVY, HAIR).finish(mat))

    def saree(a, s):
        a.cyl(0.21 * s, 0.4 * s, (0, 0, 0), PINK, seg=8, r2=0.17 * s)
        a.block((0.08 * s, 0.26 * s, 0.4 * s), (0.12 * s, 0, 0.3 * s), YELLOW, rot=(0, -25, 0))
        a.ball(0.1 * s, (0, 0.17 * s, 0.92 * s), HAIR, seg=6, rings=4)  # bun
    out.append(person(Asset("customer_b"), 1.0, SKIN2, PINK, PINK, HAIR, saree).finish(mat))

    def driver(a, s):
        a.ball(0.23 * s, (0, 0.02 * s, 0.98 * s), RED, seg=10, rings=6, scale=(1, 1, 0.75))  # pagdi
        a.ball(0.14 * s, (0, -0.13 * s, 0.7 * s), HAIR, seg=8, rings=4, scale=(1, 0.6, 0.8))  # beard
    out.append(person(Asset("customer_c"), 1.05, SKIN1, WHITE, WHITE, HAIR, driver).finish(mat))

    def teen(a, s):
        a.block((0.36 * s, 0.3 * s, 0.07 * s), (0, -0.05 * s, 1.02 * s), YELLOW)  # cap
        a.block((0.24 * s, 0.16 * s, 0.03 * s), (0, -0.22 * s, 1.02 * s), YELLOW)
    out.append(person(Asset("customer_d"), 0.95, SKIN2, GREEN, NAVY, HAIR, teen).finish(mat))
    return out


# ------------------------------------------------------------------ vehicles (face +X)
TRUCK_ART = [YELLOW, GREEN, BLUE, PINK, SAFFRON, PAINT_YELLOW, WHITE, ORANGE, RED]
# Tailgate slogan (core-and-feel C8.1, 2026-11-01): two lines, each fitted into a w x h box at its
# centre height. One line (1.46 x 0.2 at y 1.6) measured 12.0 px tall at the tutorial follow framing
# and the rear tarpaulin hump hid its middle from the game camera; two lines lower on the tailgate
# measure ~15 px and stay clear of the hump (v3_render prints the figure).
TRUCK_HORN_LINES = (("HORN OK", 1.45), ("PLEASE", 1.21))
TRUCK_HORN_TEXT = (1.3, 0.2)
# Truck header board lean in degrees (+ = top toward +X). The brief asked for 15 deg forward,
# but that turns the face away from the 52 deg camera (seen at ~40% height); leaning it
# back 15 deg shows the full crown art. Override with DHABA_HEADER_TILT for comparisons.
HEADER_TILT = float(os.environ.get("DHABA_HEADER_TILT", "-15"))


def truck_header(t, crown):
    """Forward-facing header board over the cab, built at the origin (0.08 thick,
    1.7 wide in Y, 0.5 tall); truck_geo places and tilts it."""
    t.box((0.08, 1.7, 0.5), (0, 0, 0), crown)
    fx = 0.041
    t.decal((fx, 0, 0), 1.7, 0.5, "+x", PAINT_YELLOW)                       # border
    t.decal((fx + 0.004, 0, 0), 1.56, 0.36, "+x", crown)
    for i, col in enumerate((RED, BLUE, PAINT_YELLOW, GREEN, PINK)):
        col = WHITE if col == crown else col
        t.decal((fx + 0.008, -0.6 + i * 0.3, 0), 0.2, 0.2, "+x", col, rot=45)  # diamonds
    for i, col in enumerate((PAINT_YELLOW, PINK, SAFFRON, PINK, PAINT_YELLOW)):   # pennants
        y = -0.6 + i * 0.3
        t.face([(0, y - 0.11, 0.25), (0, y + 0.11, 0.25), (0, y, 0.47)], col, normal=(1, 0, 0))
    return t


def truck_geo(t, cab=ORANGE, body=RED, trim=PAINT_YELLOW, crown=GREEN, wseg=10, lod=0):
    """Decorated Indian goods truck: 4.4 long (X), 1.8 wide, ~2.6 high, faces +X."""
    art = [c for c in TRUCK_ART if c != body]
    for x in (-1.6, -0.9, 1.35):
        for y in (-0.76, 0.76):
            t.wheel(0.38, 0.26, (x, y, 0.38), seg=wseg)
            if lod == 0:
                t.wheel(0.16, 0.28, (x, y, 0.38), STEEL, seg=6)
    t.block((4.0, 1.2, 0.22), (-0.05, 0, 0.4), DARK_STEEL)                  # chassis
    # cab x 0.95..2.15
    t.block((1.2, 1.76, 1.33), (1.55, 0, 0.62), cab)
    F = 2.155
    t.decal((F, 0, 1.62), 1.5, 0.5, "+x", GLASS)                            # windscreen
    t.decal((F + 0.004, 0, 1.62), 0.05, 0.5, "+x", cab)
    t.decal((F, 0, 1.3), 1.74, 0.1, "+x", trim)
    t.decal((F, 0, 0.98), 1.0, 0.34, "+x", STEEL)                            # grille
    for z in (0.9, 0.98, 1.06):
        t.decal((F + 0.004, 0, z), 0.92, 0.03, "+x", DARK_STEEL)
    for y in (-0.66, 0.66):
        t.wheel(0.12, 0.06, (F + 0.02, y, 0.98), BULB, seg=8, axis="x")       # headlights
        t.decal((F, y * 1.22, 0.98), 0.08, 0.14, "+x", ORANGE)              # indicators
    t.block((0.18, 1.86, 0.2), (2.22, 0, 0.36), DARK_STEEL)                 # bumper
    for i in range(7):
        t.decal((2.315, -0.78 + i * 0.26, 0.46), 0.13, 0.17, "+x", (RED, WHITE, PAINT_YELLOW)[i % 3], rot=25)
    for s in (-1, 1):
        side = "+y" if s > 0 else "-y"
        Y = s * 0.885
        t.decal((1.75, Y, 1.62), 0.6, 0.45, side, GLASS)                     # side window
        t.decal((1.55, Y, 1.25), 1.12, 0.08, side, trim)
        t.decal((1.45, Y, 0.98), 0.2, 0.2, side, crown, rot=45)
        t.beam((2.05, s * 0.88, 1.78), (2.25, s * 1.08, 1.82), 0.035, DARK_STEEL)  # mirror arm
        t.block((0.05, 0.14, 0.32), (2.25, s * 1.1, 1.48), STEEL)
        # cab doors on both sides (right-hand drive: the driver's door is on Godot +Z): outline,
        # handle, grab rail and two steps so riders visibly climb down here
        Yd = s * 0.889
        for (cx, cz, w, h) in ((1.33, 1.28, 0.03, 1.2), (2.07, 1.28, 0.03, 1.2), (1.7, 1.875, 0.77, 0.03),
                               (1.7, 0.69, 0.77, 0.03)):
            t.decal((cx, Yd, cz), w, h, side, DARK_STEEL)
        t.block((0.12, 0.05, 0.035), (1.45, s * 0.905, 1.3), STEEL)                 # handle
        t.rod((1.25, s * 0.93, 0.85), (1.25, s * 0.93, 1.6), 0.02, STEEL, seg=5)  # grab rail
        for (z, d) in ((0.48, 0.16), (0.24, 0.24)):                                 # steps
            t.block((0.34, d, 0.05), (1.94, s * (0.86 + d / 2), z), DARK_STEEL)
            t.decal((1.94, s * (0.86 + d) + s * 0.001, z + 0.025), 0.32, 0.03, side, PAINT_YELLOW)
    # visor (cab colour) + forward-facing header board (the camera sees the cab front)
    t.block((1.4, 1.84, 0.2), (1.62, 0, 1.95), cab)
    for i, col in enumerate((RED, GREEN, BLUE, PINK, SAFFRON)):
        t.decal((2.325, -0.72 + i * 0.36, 2.05), 0.26, 0.12, "+x", PAINT_YELLOW if col == cab else col)
    t.place(lambda a: truck_header(a, crown), loc=(2.2, 0, 2.2), rot=(0, HEADER_TILT, 0))
    # cargo body x -2.2..0.9 (top slab in body colour, yellow lips on the long top edges)
    t.block((3.1, 1.8, 1.3), (-0.65, 0, 0.62), body)
    t.block((3.14, 1.84, 0.08), (-0.65, 0, 1.9), body)
    for s in (-1, 1):
        t.decal((-0.65, s * 0.89, 1.982), 3.14, 0.06, "+z", PAINT_YELLOW)
    for s in (-1, 1):
        side = "+y" if s > 0 else "-y"
        Y = s * 0.905
        t.decal((-0.65, Y, 0.74), 3.0, 0.14, side, trim)
        t.decal((-0.65, Y, 1.36), 3.0, 0.12, side, PAINT_YELLOW)          # band between rows
        for row, z in enumerate((1.08, 1.64)):
            for i in range(5):
                x = -1.9 + i * 0.6
                k = i + row * 5 + (3 if s > 0 else 0)
                c1 = art[k % len(art)]
                c2 = art[(k + 4) % len(art)]
                t.decal((x, Y, z), 0.5, 0.36, side, c1)
                if lod == 0 or row == 0:
                    t.decal((x, Y + s * 0.004, z), 0.2, 0.2, side, c2, rot=45)
    Bx = -2.205                                                              # tailgate
    t.decal((Bx, 0, 1.3), 1.6, 1.0, "-x", PAINT_YELLOW)
    t.decal((Bx - 0.004, 0, 1.7), 1.5, 0.05, "-x", RED)                      # painted top band
    t.decal((Bx - 0.004, 0, 0.92), 0.5, 0.12, "-x", BLUE)
    for y in (-0.5, 0.5):
        t.decal((Bx - 0.004, y * 1.2, 0.95), 0.2, 0.2, "-x", GREEN, rot=45)
        t.decal((Bx, y * 1.4, 0.72), 0.2, 0.12, "-x", RED)                 # tail lights
    tg = globals().get("text_geo")
    if tg is not None and lod == 0:                                          # painted slogan, two lines
        for (line, zc) in TRUCK_HORN_LINES:
            tg(t, line, (Bx - 0.006, zc, 0.0), (0, 0, 1), (0, 1, 0), TRUCK_HORN_TEXT[0], TRUCK_HORN_TEXT[1], RED,
               bold=0.05)
    else:
        for (line, zc) in TRUCK_HORN_LINES:
            t.decal((Bx - 0.004, 0, zc), 0.9, 0.16, "-x", RED)
    for i in range(5):
        t.decal((Bx, -0.4 + i * 0.2, 0.72), 0.16, 0.12, "-x", WHITE if i % 2 else HAIR)
    t.block((0.12, 1.8, 0.16), (-2.22, 0, 0.36), DARK_STEEL)
    # tarpaulin load + ropes
    for j, x in enumerate((-1.72, -0.65, 0.42)):
        # humps leave ~0.19 m of body-coloured rim on each side; the middle one is blue
        t.ball(0.62, (x, 0, 1.96), (BLUE, PAINT_YELLOW, BLUE)[j] if body != BLUE else (GREEN, PAINT_YELLOW, GREEN)[j],
               seg=8, rings=5, scale=(1.15, 1.15, 0.62))                      # bright tirpal (no dark humps)
        pts = [Vector((x, 0.75 * math.cos(math.radians(a)), 1.95 + 0.42 * math.sin(math.radians(a))))
               for a in (0, 50, 90, 130, 180)]
        for i in range(len(pts) - 1):
            t.beam(pts[i], pts[i + 1], 0.035, RED if j == 1 else PAINT_YELLOW)
    # mudflaps, fuel tank, battery box
    for x in (-2.02, 0.92):
        for s in (-1, 1):
            t.block((0.03, 0.32, 0.38), (x, s * 0.76, 0.1), HAIR)
            t.decal((x - 0.017, s * 0.76, 0.3), 0.22, 0.1, "-x", RED)
    t.wheel(0.17, 0.55, (0.35, -0.6, 0.42), STEEL, seg=8, axis="x")
    t.block((0.4, 0.25, 0.25), (0.35, 0.62, 0.3), DARK_STEEL)
    return t


def bus_geo(b, body=CREAM, s1=GREEN, s2=ORANGE, wseg=10, lod=0, luggage=True):
    """Indian state bus: 6.5 long (X), 2.2 wide, ~2.7 high, faces +X, 6 wheels."""
    for x in (2.2, -1.6, -2.5):
        for y in (-0.97, 0.97):
            b.wheel(0.45, 0.3, (x, y, 0.45), seg=wseg)
            if lod == 0:
                b.wheel(0.2, 0.32, (x, y, 0.45), STEEL, seg=6)
    b.block((6.5, 2.2, 1.96), (0, 0, 0.4), body)                             # z 0.4..2.36
    b.block((6.3, 2.0, 0.1), (0, 0, 2.36), body)                             # roof crown
    H = 1.105
    for s in (-1, 1):
        side = "+y" if s > 0 else "-y"
        Y = s * H
        b.decal((2.2, Y, 0.62), 1.05, 0.44, side, HAIR)                      # wheel arches
        b.decal((-2.05, Y, 0.62), 1.95, 0.44, side, HAIR)
        b.decal((0, Y, 0.95), 6.5, 0.12, side, s2)
        b.decal((0, Y, 1.2), 6.5, 0.2, side, s1)
        b.decal((-0.2, Y, 1.75), 5.7, 0.6, side, GLASS)                      # window strip
        for i in range(8):
            b.decal((-2.7 + i * 0.72, Y + s * 0.004, 1.75), 0.08, 0.6, side, body)
        b.decal((0, Y, 2.18), 6.5, 0.07, side, s2)
    b.decal((2.95, H + 0.004, 1.28), 0.5, 1.66, "+y", TARP)                 # door (kerb side)
    b.decal((2.95, H + 0.008, 1.75), 0.38, 0.5, "+y", GLASS)
    b.decal((2.95, H + 0.008, 1.05), 0.38, 0.6, "+y", GLASS)
    for (cx, cz, w, h) in ((2.68, 1.28, 0.04, 1.7), (3.22, 1.28, 0.04, 1.7), (2.95, 2.13, 0.58, 0.04)):
        b.decal((cx, H + 0.012, cz), w, h, "+y", PAINT_YELLOW)
    b.rod((2.62, H + 0.05, 0.75), (2.62, H + 0.05, 1.8), 0.02, STEEL, seg=5)     # grab rail
    b.block((0.5, 0.22, 0.06), (2.95, H + 0.1, 0.3), DARK_STEEL)                # step
    b.decal((2.95, -H, 1.75), 0.45, 0.6, "-y", GLASS)                        # driver window
    for (cx, cz, w, h) in ((2.68, 1.4, 0.035, 1.3), (3.2, 1.4, 0.035, 1.3), (2.94, 0.76, 0.55, 0.035)):
        b.decal((cx, -H - 0.004, cz), w, h, "-y", HAIR)                       # driver door outline
    b.block((0.1, 0.04, 0.03), (2.78, -H - 0.02, 1.35), STEEL)
    F = 3.255
    b.decal((F, 0, 1.69), 1.95, 0.76, "+x", GLASS)                          # windscreen
    b.decal((F + 0.004, 0, 1.69), 0.06, 0.76, "+x", body)
    b.decal((F, 0, 2.22), 1.4, 0.16, "+x", HAIR)                            # destination board
    tg = globals().get("text_geo")
    if tg is not None and lod == 0:
        tg(b, "DELHI", (F + 0.006, 2.22, 0.0), (0, 0, -1), (0, 1, 0), 1.0, 0.11, PAINT_YELLOW, bold=0.04)
    else:
        b.decal((F + 0.004, 0, 2.22), 0.9, 0.06, "+x", PAINT_YELLOW)
    b.decal((F, 0, 1.2), 2.2, 0.2, "+x", s1)
    b.decal((F, 0, 0.95), 2.2, 0.12, "+x", s2)
    b.decal((F, 0, 0.7), 1.0, 0.22, "+x", DARK_STEEL)
    for y in (-0.75, 0.75):
        b.wheel(0.12, 0.05, (F + 0.01, y, 0.72), BULB, seg=8, axis="x")
    b.block((0.16, 2.24, 0.22), (3.3, 0, 0.3), DARK_STEEL)
    for s in (-1, 1):
        b.beam((3.2, s * 1.1, 2.15), (3.5, s * 1.25, 2.05), 0.04, DARK_STEEL)
        b.block((0.05, 0.12, 0.35), (3.5, s * 1.25, 1.72), HAIR)
    Bk = -3.255
    b.decal((Bk, 0, 1.8), 1.8, 0.5, "-x", GLASS)
    b.decal((Bk, 0, 1.2), 2.2, 0.2, "-x", s1)
    b.decal((Bk, 0, 0.95), 2.2, 0.12, "-x", s2)
    for y in (-0.85, 0.85):
        b.decal((Bk, y, 0.72), 0.2, 0.25, "-x", RED)
    b.block((0.14, 2.2, 0.2), (-3.3, 0, 0.3), DARK_STEEL)
    if lod == 0:                                                             # rear ladder
        for y in (0.5, 0.8):
            b.beam((-3.31, y, 0.6), (-3.31, y, 2.56), 0.04, DARK_STEEL)
        for z in (0.9, 1.3, 1.7, 2.1):
            b.beam((-3.31, 0.48, z), (-3.31, 0.82, z), 0.035, DARK_STEEL)
    # roof luggage rack
    for y in (-0.9, 0.9):
        b.beam((-2.4, y, 2.56), (2.0, y, 2.56), 0.05, DARK_STEEL)
        for x in (-2.3, -0.8, 0.7, 1.9):
            b.block((0.05, 0.05, 0.12), (x, y, 2.46), DARK_STEEL)
    for x in (-2.4, 2.0):
        b.beam((x, -0.9, 2.56), (x, 0.9, 2.56), 0.05, DARK_STEEL)
    if luggage:                    # (bus_baraat dresses its roof instead: core-and-feel C6.4)
        b.block((0.9, 0.8, 0.28), (-1.6, 0.3, 2.46), RED)
        b.block((0.6, 0.6, 0.24), (-0.55, -0.4, 2.46), BLUE)
        b.ball(0.4, (0.4, 0.2, 2.5), ROPE, seg=6, rings=4, scale=(1.3, 1.0, 0.55))   # luggage bundle
        b.block((0.5, 0.5, 0.22), (1.3, -0.2, 2.46), PAINT_YELLOW)
    return b


def build_vehicles(mat):
    out = []
    b = Asset("bike")
    b.wheel(0.27, 0.1, (-0.5, 0, 0.27))
    b.wheel(0.27, 0.1, (0.55, 0, 0.27))
    b.box((0.9, 0.12, 0.12), (0.02, 0, 0.42), DARK_STEEL, rot=(0, -10, 0))
    b.box((0.42, 0.28, 0.2), (0.1, 0, 0.62), RED)          # tank
    b.box((0.5, 0.26, 0.1), (-0.3, 0, 0.66), HAIR)         # seat
    b.box((0.06, 0.06, 0.45), (0.5, 0, 0.62), DARK_STEEL, rot=(0, 18, 0))
    b.box((0.06, 0.62, 0.06), (0.56, 0, 0.86), DARK_STEEL)  # handlebar
    b.ball(0.07, (0.62, 0, 0.75), BULB, seg=6, rings=4)
    b.box((0.3, 0.22, 0.12), (-0.55, 0, 0.5), RED)          # mudguard
    out.append(b.finish(mat))

    def car(name, body, stripe, roof=None):
        c = Asset(name)
        for x in (-0.75, 0.75):
            for y in (-0.55, 0.55):
                c.wheel(0.26, 0.18, (x, y, 0.26))
        c.block((2.4, 1.15, 0.5), (0, 0, 0.22), body)
        c.block((1.35, 1.0, 0.42), (-0.15, 0, 0.72), GLASS)
        c.block((1.45, 1.06, 0.07), (-0.15, 0, 1.12), roof if roof is not None else body)
        for x in (-0.82, -0.15, 0.52):
            c.block((0.08, 1.04, 0.42), (x, 0, 0.72), body)
        c.box((0.04, 0.22, 0.12), (1.2, -0.38, 0.5), BULB)
        c.box((0.04, 0.22, 0.12), (1.2, 0.38, 0.5), BULB)
        c.box((0.04, 0.2, 0.1), (-1.2, -0.4, 0.52), RED)
        c.box((0.04, 0.2, 0.1), (-1.2, 0.4, 0.52), RED)
        c.box((0.06, 1.18, 0.1), (1.2, 0, 0.3), DARK_STEEL)  # bumper
        c.box((2.0, 0.04, 0.08), (0, -0.585, 0.5), stripe)    # stripe
        c.decal((1.231, 0, 0.42), 0.3, 0.08, "+x", PAINT_YELLOW)   # number plates
        c.decal((-1.221, 0, 0.42), 0.3, 0.08, "-x", PAINT_YELLOW)
        return c.finish(mat)

    out.append(car("car", WHITE, RED))
    out.append(car("car_red", RED, WHITE))
    out.append(car("car_blue", BLUE, WHITE))
    out.append(car("car_taxi", HAIR, YELLOW, roof=YELLOW))         # kaali-peeli taxi
    out.append(ambassador_geo(Asset("car_ambassador")).finish(mat, 35))

    au = Asset("auto")                                           # auto-rickshaw, faces +X
    au.wheel(0.2, 0.12, (0.62, 0, 0.2))
    au.wheel(0.2, 0.12, (-0.45, -0.5, 0.2))
    au.wheel(0.2, 0.12, (-0.45, 0.5, 0.2))
    au.block((1.7, 1.1, 0.35), (0, 0, 0.18), GREEN)              # tub
    au.block((0.5, 0.7, 0.55), (0.6, 0, 0.3), YELLOW)            # nose
    au.block((0.06, 0.9, 0.45), (0.36, 0, 0.6), GLASS)           # windscreen
    au.block((1.25, 1.12, 0.06), (-0.1, 0, 1.3), YELLOW)         # canopy roof
    au.box((1.3, 0.06, 0.75), (-0.1, 0.56, 0.95), YELLOW)        # canopy side
    au.box((0.06, 1.1, 0.75), (-0.74, 0, 0.95), YELLOW)          # canopy back
    au.block((0.6, 0.9, 0.12), (-0.35, 0, 0.53), HAIR)           # seat
    au.box((0.04, 0.6, 0.04), (0.45, 0, 0.82), DARK_STEEL)       # handlebar
    au.ball(0.06, (0.86, 0, 0.5), BULB, seg=6, rings=4)
    out.append(au.finish(mat))

    out.append(truck_geo(Asset("truck"), cab=ORANGE, body=RED, trim=PAINT_YELLOW, crown=GREEN).finish(mat))
    out.append(truck_geo(Asset("truck_green"), cab=BLUE, body=GREEN, trim=PAINT_YELLOW, crown=RED).finish(mat))
    out.append(bus_geo(Asset("bus")).finish(mat))
    return out


def ambassador_geo(c):
    """Story (4 Nov): Simran's father's white Hindustan Ambassador, faces +X like the other
    cars and fits their size (2.5 x 1.2 m): a rounded body with a domed bonnet and boot, a
    curved roof over a glass cabin, chrome grille, bumpers and side strip, round headlamps."""
    for x in (-0.78, 0.78):
        for y in (-0.55, 0.55):
            c.wheel(0.25, 0.17, (x, y * 0.96, 0.25))
    c.rbox((2.46, 1.16, 0.46), (0, 0, 0.47), WHITE, bevel=0.14, seg=2)                 # body
    c.rbox((0.62, 1.08, 0.16), (0.88, 0, 0.72), WHITE, bevel=0.07, seg=2)             # bonnet dome
    c.rbox((0.52, 1.08, 0.16), (-0.94, 0, 0.72), WHITE, bevel=0.07, seg=2)            # boot dome
    c.rbox((1.2, 1.0, 0.36), (-0.12, 0, 0.87), SLATE, bevel=0.12, seg=2)              # tinted cabin
    c.rbox((1.04, 1.04, 0.1), (-0.14, 0, 1.06), WHITE, bevel=0.05, seg=2)             # curved roof
    for x in (-0.66, -0.12, 0.42):                                                     # pillars
        c.rbox((0.07, 1.02, 0.32), (x, 0, 0.87), WHITE, bevel=0.025)
    c.rbox((0.06, 0.62, 0.2), (1.24, 0, 0.5), STEEL, bevel=0.02)                      # grille
    for y in (-0.08, 0.0, 0.08):
        c.box((0.065, 0.02, 0.17), (1.245, y, 0.5), DARK_STEEL)
    for y in (-0.42, 0.42):                                                            # round lamps
        c.wheel(0.085, 0.05, (1.22, y, 0.56), color=STEEL, seg=10, axis="x")
        c.ball(0.065, (1.25, y, 0.56), BULB, seg=8, rings=4)
        c.box((0.04, 0.16, 0.08), (-1.235, y, 0.55), RED)                              # tail lamps
    for x in (1.28, -1.28):                                                            # bumpers
        c.rbox((0.08, 1.2, 0.09), (x, 0, 0.32), STEEL, bevel=0.03)
    for y in (-0.585, 0.585):                                                          # side strips
        c.box((2.0, 0.02, 0.035), (0, y, 0.58), STEEL)
    c.decal((1.33, 0, 0.42), 0.3, 0.08, "+x", LINE)                                    # number plates
    c.decal((-1.33, 0, 0.42), 0.3, 0.08, "-x", LINE)
    return c


# ------------------------------------------------------------------ dhaba props
def plant_geo(a, k=1.0):
    """Gamla (clay pot) with a leafy plant, ~0.8*k tall, origin bottom centre."""
    a.cyl(0.2 * k, 0.32 * k, (0, 0, 0), CLAY, seg=8, r2=0.26 * k)
    a.cyl(0.235 * k, 0.04 * k, (0, 0, 0.13 * k), CREAM, seg=8)
    a.cyl(0.29 * k, 0.07 * k, (0, 0, 0.3 * k), BRICK, seg=8)
    a.cyl(0.25 * k, 0.012 * k, (0, 0, 0.37 * k), CHAI, seg=8)
    a.ico(0.2 * k, (0, 0, 0.52 * k), DARK_GREEN, subdiv=1, scale=(1, 1, 0.9))
    for i in range(7):
        ang = i * 360 / 7 + 10
        r = 0.14 * k
        cx, cy = r * math.cos(math.radians(ang)), r * math.sin(math.radians(ang))
        a.ico(0.26 * k, (cx, cy, (0.5 + 0.08 * (i % 2)) * k), LEAF if i % 2 else LEAF_LIGHT, subdiv=0,
              scale=(1.0, 0.36, 0.16), rot=(0, -38 - 8 * (i % 3), ang))
    a.ico(0.18 * k, (0.02 * k, -0.02 * k, 0.68 * k), LEAF_LIGHT, subdiv=0, scale=(0.7, 0.7, 0.9))
    a.ball(0.045 * k, (0.12 * k, -0.15 * k, 0.72 * k), SAFFRON, seg=5, rings=3)
    a.ball(0.045 * k, (-0.15 * k, 0.05 * k, 0.74 * k), PINK, seg=5, rings=3)
    return a


def mini_pot(a, base):
    """Cheap pillar-top pot (~0.45 tall)."""
    x, y, z = base
    a.cyl(0.13, 0.18, (x, y, z), CLAY, seg=6, r2=0.17)
    a.ico(0.2, (x, y, z + 0.3), LEAF, subdiv=0, scale=(1, 1, 0.8))
    a.ico(0.13, (x + 0.06, y - 0.06, z + 0.42), LEAF_LIGHT, subdiv=0)
    return a


def canopy(name, main, trim, accent):
    """Shamiana over a table set: 4.2 (X) x 3.6 (Godot Z) footprint, origin centre."""
    a = Asset(name)
    HX, HY = 2.1, 1.8          # roof eaves
    PX, PY = 2.0, 1.7          # poles
    VX, VY = 2.12, 1.82        # valance, just outside the eave so the high camera sees it
    EAVE, PEAK = 3.2, 3.9      # high enough to see the front diners, thalis and cash pile
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * PX, sy * PY
            a.block((0.2, 0.2, 0.12), (x, y, 0), GRAVEL)
            a.cyl(0.055, EAVE + 0.06, (x, y, 0), ROTI, seg=6)
    corners = [(-HX, -HY), (HX, -HY), (HX, HY), (-HX, HY)]
    apex = Vector((0, 0, PEAK))
    BAND = 0.17                # fraction of each hip covered by the trim band (~0.35 m on the slope)
    ring = [Vector((x, y, EAVE)).lerp(apex, BAND) for (x, y) in corners]
    for i in range(4):          # 4 solid facets + a trim band along each eave (12 tris)
        j = (i + 1) % 4
        (x0, y0), (x1, y1) = corners[i], corners[j]
        out = Vector(((x0 + x1) / 2, (y0 + y1) / 2, 1.0))
        a.face([(x0, y0, EAVE), (x1, y1, EAVE), ring[j], ring[i]], trim, normal=out)
        a.face([ring[i], ring[j], apex], main, normal=out)
    for (x, y) in corners:                                                    # hip ridges
        a.beam((x, y, EAVE + 0.02), (0, 0, PEAK + 0.02), 0.04, trim)
    # valance strips + scallops (4 sides)
    top, bot = EAVE, EAVE - 0.28
    sides = [((-VX, -VY), (VX, -VY), (0, -1, 0)), ((VX, VY), (-VX, VY), (0, 1, 0)),
             ((VX, -VY), (VX, VY), (1, 0, 0)), ((-VX, VY), (-VX, -VY), (-1, 0, 0))]
    for (p0, p1, nrm) in sides:
        P0, P1 = Vector((p0[0], p0[1], 0)), Vector((p1[0], p1[1], 0))
        a.face([P0 + Vector((0, 0, bot)), P1 + Vector((0, 0, bot)), P1 + Vector((0, 0, top)),
                P0 + Vector((0, 0, top))], trim, normal=nrm)
        L = (P1 - P0).length
        cnt = max(4, round(L / 0.5))
        for k in range(cnt):
            c0 = P0.lerp(P1, k / cnt)
            c1 = P0.lerp(P1, (k + 1) / cnt)
            ctr = (c0 + c1) / 2
            rad = (c1 - c0).length / 2
            d = (c1 - c0).normalized()
            pts = [ctr + d * (-rad)]
            for ang in (240, 300):
                pts.append(ctr + d * (rad * math.cos(math.radians(ang))) + Vector((0, 0, rad * math.sin(math.radians(ang)))))
            pts.append(ctr + d * rad)
            pts = [p + Vector((0, 0, bot)) for p in pts]
            col = trim if k % 2 == 0 else main
            a.face([pts[0], pts[1], pts[2], pts[3]], col, normal=nrm)
    a.cyl(0.025, 0.32, (0, 0, PEAK - 0.02), STEEL, seg=5)                  # finial + pennant
    a.ball(0.07, (0, 0, PEAK + 0.3), PAINT_YELLOW, seg=6, rings=4)
    a.face([(0, 0, PEAK + 0.22), (0, 0, PEAK + 0.06), (0.32, 0, PEAK + 0.14)], accent, normal=(0, -1, 0))
    return a


def build_dhaba(mat):
    out = []
    # ---- kitchen shed: 8.4 (X) x 3.0 deep, open front (-Y = Godot +Z), back wall at +Y.
    # Built in the original frame, then shifted Godot +0.85 (Blender -0.85) so the back
    # face sits at world z ~4.73 (behind the dining zone) and the open front at ~7.75.
    HUT_SHIFT = -0.85

    def hut_geo(h):
        h.block((8.4, 0.25, 2.7), (0, 1.375, 0), MUD)                          # back wall
        h.block((8.44, 0.29, 0.3), (0, 1.375, 0), BRICK)
        h.block((8.44, 0.29, 0.2), (0, 1.375, 2.5), CREAM)
        for sx in (-1, 1):
            x = sx * 4.075
            h.block((0.25, 0.9, 2.7), (x, 1.05, 0), MUD)                          # roofed part
            h.block((0.29, 0.94, 0.3), (x, 1.05, 0), BRICK)
            h.block((0.25, 2.1, 1.0), (x, -0.45, 0), MUD)                         # low front part
            h.block((0.3, 2.16, 0.08), (x, -0.45, 1.0), CREAM)
        W = 1.245                                                                 # inner face of back wall
        # back-wall detail kept below ~1.95 m, the height the 52 deg camera sees under the roof
        h.decal((1.9, W, 1.4), 1.3, 0.95, "-y", TEAL)                            # window
        h.decal((1.9, W - 0.004, 1.4), 1.08, 0.76, "-y", GLASS)
        h.decal((1.9, W - 0.008, 1.4), 0.06, 0.76, "-y", TEAL)
        h.decal((1.9, W - 0.008, 1.4), 1.08, 0.06, "-y", TEAL)
        h.decal((-0.1, W, 1.55), 0.9, 0.6, "-y", HAIR)                           # menu board
        for i in range(4):
            h.decal((-0.1, W - 0.004, 1.75 - i * 0.13), 0.7, 0.05, "-y", ROTI if i % 2 else WHITE)
        h.decal((3.3, W, 1.5), 0.45, 0.6, "-y", SAFFRON)                         # deity poster
        h.decal((3.3, W - 0.004, 1.5), 0.32, 0.45, "-y", RED)
        h.decal((-2.2, W, 1.25), 3.2, 0.9, "-y", WHITE)                          # tiled splashback
        for z in (1.15, 1.6):                                                      # shelves
            h.block((3.2, 0.34, 0.05), (-2.2, 1.07, z), WOOD)
        for (x, r, ht, col) in ((-3.4, 0.17, 0.26, STEEL), (-2.85, 0.13, 0.2, STEEL), (-2.35, 0.15, 0.3, STEEL),
                                (-1.8, 0.11, 0.16, CLAY), (-1.2, 0.13, 0.22, STEEL)):
            h.cyl(r, ht, (x, 1.07, 1.2), col, seg=6, nb=True)
        for i, col in enumerate((RED, PAINT_YELLOW, GREEN, ORANGE, RED)):
            h.cyl(0.065, 0.17, (-3.4 + i * 0.4, 1.07, 1.65), col, seg=5, nb=True)
        h.block((2.2, 0.6, 0.8), (0.1, 0.9, 0), WOOD)                            # prep counter
        h.block((2.26, 0.64, 0.05), (0.1, 0.9, 0.8), STEEL)
        h.cyl(0.26, 0.36, (-0.45, 0.9, 0.85), STEEL, seg=8, nb=True)               # big patila
        h.face([(-0.45 + 0.23 * math.cos(a * math.pi / 4), 0.9 + 0.23 * math.sin(a * math.pi / 4), 1.215)
                for a in range(8)], DAL, up=True)
        h.cyl(0.2, 0.12, (0.45, 0.9, 0.85), ROPE, seg=6, nb=True)                  # onion basket
        h.ico(0.12, (0.45, 0.9, 0.98), RED, subdiv=0, scale=(1, 1, 0.6))           # onions
        h.face([(0.95 + 0.14 * math.cos(k * math.pi / 3), 0.85 + 0.14 * math.sin(k * math.pi / 3), 0.856)
                for k in range(6)], CREAM, up=True)                                # chakla
        h.cyl(0.18, 0.62, (3.6, 0.95, 0), RED, seg=8, nb=True)                     # gas cylinder
        h.cyl(0.09, 0.08, (3.6, 0.95, 0.62), STEEL, seg=6, nb=True)
        h.ico(0.3, (2.9, 1.0, 0.28), ROPE, subdiv=0, scale=(1, 0.8, 1.0))       # flour sacks
        h.ico(0.24, (3.15, 0.55, 0.22), ROPE, subdiv=0, scale=(1, 0.8, 1.0))
        h.cyl(0.27, 0.72, (-3.55, 0.85, 0), BLUE, seg=8, nb=True)                  # water drum
        # posts + lean-to tin roof over the back strip only (y 1.6 .. 0.6), rising to the front
        for x in (-1.4, 1.4):
            h.block((0.14, 0.14, 2.95), (x, 0.62, 0), WOOD)
        zb, zf, yb, yf = 2.75, 3.0, 1.6, 0.6
        ang = math.degrees(math.atan2(zb - zf, yb - yf))
        span = math.hypot(zb - zf, yb - yf)
        h.box((8.9, span, 0.06), (0, (yb + yf) / 2, (zb + zf) / 2), BLUE, rot=(ang, 0, 0))
        for i in range(18):                                                        # corrugation ribs
            x = -4.08 + i * 0.48
            h.face([(x - 0.025, yb, zb + 0.04), (x + 0.025, yb, zb + 0.04), (x + 0.025, yf, zf + 0.04),
                    (x - 0.025, yf, zf + 0.04)], TIN, up=True)
        h.beam((-4.45, yf - 0.02, zf - 0.06), (4.45, yf - 0.02, zf - 0.06), 0.1, WOOD, 0.14)  # fascia
        h.cyl(0.13, 1.7, (2.9, 1.0, 2.1), DARK_STEEL, seg=6)                       # chimney
        h.cyl(0.24, 0.14, (2.9, 1.0, 3.8), DARK_STEEL, seg=6, r2=0.06)
        h.rod((0, yf - 0.04, zf - 0.1), (0, yf - 0.04, 2.66), 0.012, HAIR, seg=3)  # hanging bulb
        h.ball(0.08, (0, yf - 0.04, 2.6), BULB, seg=6, rings=4)
        bunting(h, (-4.25, yf - 0.1, 2.94), (4.25, yf - 0.1, 2.94), 0.16, 16,
                (RED, PAINT_YELLOW, GREEN, SAFFRON, BLUE, PINK))

    h = Asset("hut_1")
    h.place(hut_geo, loc=(0, HUT_SHIFT, 0))
    out.append(h.finish(mat))

    # Counters: 1.6 wide (X), 0.8 deep, 0.85 high. Front faces -Y (camera).
    def counter(a, top=CREAM, front=TEAL):
        a.block((1.6, 0.8, 0.8), (0, 0, 0), WOOD)
        a.block((1.64, 0.84, 0.06), (0, 0, 0.8), top)
        a.block((1.4, 0.02, 0.35), (0, -0.41, 0.25), front)

    def flames(a, cx, cy, z, ring):
        """Burner fire: a glowing disc plus 5 little FIRE/SAFFRON cones in a ring."""
        a.face([(cx + (ring + 0.04) * math.cos(k * math.pi / 4), cy + (ring + 0.04) * math.sin(k * math.pi / 4), z + 0.003)
                for k in range(8)], FIRE, up=True)
        for k in range(5):
            ang = 2 * math.pi * k / 5 + 0.3
            a.cyl(0.05, 0.1, (cx + ring * math.cos(ang), cy + ring * math.sin(ang), z), FIRE if k % 2 else SAFFRON,
                  seg=4, r2=0.0, nb=True)

    c = Asset("station_chai")
    counter(c)
    c.cyl(0.22, 0.12, (-0.35, 0.05, 0.86), DARK_STEEL, seg=8)        # stove
    flames(c, -0.35, 0.05, 0.98, 0.15)
    c.cyl(0.18, 0.3, (-0.35, 0.05, 1.04), STEEL, seg=8, r2=0.14)     # kettle (on a trivet, fire below)
    c.box((0.22, 0.05, 0.05), (-0.12, 0.05, 1.21), STEEL, rot=(0, -35, 0))
    c.cyl(0.03, 0.12, (-0.35, 0.05, 1.34), DARK_STEEL, seg=6)
    for i in range(4):
        c.cyl(0.05, 0.12, (0.15 + i * 0.13, -0.12, 0.86), GLASS, seg=6)
        c.cyl(0.045, 0.08, (0.15 + i * 0.13, -0.12, 0.87), CHAI, seg=6)
    c.cyl(0.12, 0.18, (0.55, 0.2, 0.86), YELLOW, seg=8)              # sugar tin
    out.append(c.finish(mat))

    t = Asset("station_tandoor")
    t.block((0.7, 0.8, 0.8), (0.42, 0, 0), WOOD)
    t.block((0.74, 0.84, 0.06), (0.42, 0, 0.8), CREAM)
    for i in range(4):
        t.cyl(0.16, 0.02, (0.42, -0.05, 0.86 + i * 0.025), ROTI, seg=10)
    K = 1.15                                                          # drum scaled up x1.15
    tx = -0.4
    t.cyl(0.42 * K, 0.95 * K, (tx, 0.05, 0), CLAY, seg=10, r2=0.32 * K, nb=True)  # tandoor drum
    t.cyl(0.33 * K, 0.02, (tx, 0.05, 0.94 * K), HAIR, seg=10, nb=True)
    t.cyl(0.28, 0.04, (tx, 0.05, 0.94 * K + 0.005), FIRE, seg=8, nb=True)          # glowing mouth
    t.cyl(0.17, 0.15, (tx, 0.05, 0.94 * K + 0.04), SAFFRON, seg=6, r2=0.0, nb=True)  # flame
    t.cyl(0.44 * K, 0.1 * K, (tx, 0.05, 0.25 * K), DUST_DARK, seg=10)
    t.box((0.04, 0.04, 0.7), (-0.08, -0.36, 1.12), DARK_STEEL, rot=(0, -30, 0))  # sariya
    out.append(t.finish(mat))

    # charpai + dining_table are built by v3_props (v0.3 style, same footprint)

    # ---- canopies
    for (name, main, trim, accent) in (("canopy_red", RED, PAINT_YELLOW, ORANGE),
                                       ("canopy_teal", TEAL, SAFFRON, NEON_CYAN),
                                       ("canopy_yellow", YELLOW, RED, PAINT_YELLOW),
                                       ("canopy_blue", BLUE, PAINT_YELLOW, NEON_CYAN),
                                       ("canopy_pink", PINK, TEAL, NEON_PINK)):
        out.append(canopy(name, main, trim, accent).finish(mat))

    # ---- string lights: 4.2 m along +X hung from the canopy valance (anchors at 3.05,
    # sag 0.35); bulbs are a separate mesh so Godot can make them emissive. The string
    # sits 0.1 m out (Godot +Z) so it hangs in front of the +Z valance, not behind it.
    SY, SH, SS = -0.1, 3.05, 0.35
    wire = Asset("string_wire")
    pts = sag((-2.1, SY, SH), (2.1, SY, SH), SS, 6)
    for i in range(len(pts) - 1):
        wire.beam(pts[i], pts[i + 1], 0.03, HAIR)
    out.append(wire.finish(mat))
    bulbs = Asset("string_bulbs")
    for i in range(13):                                                       # 0.3 m apart
        x = -1.8 + 0.3 * i
        z = SH - SS * (1 - (x / 2.1) ** 2)
        bulbs.ball(0.1, (x, SY, z - 0.1), BULB, seg=4, rings=2)               # 8-tri octahedra
    out.append(bulbs.finish(mat))

    # ---- cashier desk (Godot label at local (0, 2.3, 0.1) sits on the yellow board)
    cd = Asset("cashier_desk")
    cd.block((1.8, 0.8, 0.9), (0, 0, 0), WOOD)
    cd.block((1.86, 0.86, 0.05), (0, 0, 0.9), CHAI)
    cd.block((1.7, 0.04, 0.72), (0, -0.41, 0.1), BLUE)                       # front panel
    cd.decal((0, -0.432, 0.78), 1.7, 0.06, "-y", PAINT_YELLOW)
    cd.decal((0, -0.432, 0.16), 1.7, 0.06, "-y", PAINT_YELLOW)
    cd.wheel(0.17, 0.02, (0, -0.43, 0.47), PAINT_YELLOW, seg=10)              # rupee medallion
    cd.decal((0, -0.442, 0.47), 0.12, 0.16, "-y", BLUE)
    cd.block((0.5, 0.42, 0.12), (0.3, 0.04, 0.95), DARK_STEEL)              # cash register
    cd.box((0.44, 0.28, 0.1), (0.3, 0.1, 1.12), HAIR, rot=(-18, 0, 0))
    for i in range(3):
        cd.decal((0.18 + i * 0.12, 0.1, 1.177), 0.08, 0.16, "+z", WHITE if i != 1 else PAINT_YELLOW)
    cd.rod((0.3, -0.08, 1.07), (0.3, -0.08, 1.3), 0.025, DARK_STEEL, seg=4)
    cd.box((0.24, 0.05, 0.13), (0.3, -0.08, 1.34), HAIR)
    cd.decal((0.3, -0.106, 1.34), 0.2, 0.09, "-y", NEON_CYAN)
    cd.block((0.32, 0.24, 0.04), (-0.3, 0.05, 0.95), RED)                    # ledger
    cd.block((0.28, 0.2, 0.012), (-0.3, 0.05, 0.99), WHITE)
    cd.cyl(0.05, 0.06, (-0.65, -0.18, 0.95), STEEL, seg=6, r2=0.03)           # bell
    cd.cyl(0.04, 0.1, (-0.7, 0.2, 0.95), SAFFRON, seg=6)  # pen stand
    # sign board 2.0 x 0.55 centred at 2.3 (room for "Rs 1,250/min" at font 64, ~2 m)
    for x in (-0.95, 0.95):                                                    # posts beside the desk
        cd.block((0.07, 0.07, 2.62), (x, 0.0, 0), DARK_STEEL)
    cd.block((2.16, 0.04, 0.66), (0, 0.045, 1.97), RED)
    cd.block((2.0, 0.06, 0.55), (0, 0.0, 2.025), PAINT_YELLOW)
    for i, col in enumerate((RED, PAINT_YELLOW, GREEN, SAFFRON, PINK, BLUE, RED)):  # little top flags
        x = -0.9 + i * 0.3
        cd.face([(x - 0.08, 0.0, 2.63), (x + 0.08, 0.0, 2.63), (x, 0.0, 2.78)], col, normal=(0, -1, 0))
    cd.block((0.42, 0.42, 0.95), (1.25, 0.05, 0), BLUE)                      # water cooler
    cd.block((0.45, 0.45, 0.05), (1.25, 0.05, 0.95), WHITE)
    cd.cyl(0.15, 0.36, (1.25, 0.05, 1.0), GLASS, seg=8)
    cd.cyl(0.07, 0.06, (1.25, 0.05, 1.36), BLUE, seg=6)
    for x, col in ((1.17, RED), (1.33, BLUE)):
        cd.box((0.05, 0.06, 0.06), (x, -0.19, 0.72), col)
    cd.block((0.3, 0.12, 0.02), (1.25, -0.24, 0.55), STEEL)
    cd.cyl(0.17, 0.48, (0, 0.75, 0), RED, seg=8, r2=0.2)                       # plastic stool
    cd.cyl(0.21, 0.04, (0, 0.75, 0.48), RED, seg=8)
    out.append(cd.finish(mat))

    # ---- chai tapri kiosk ~2.2 x 1.4 (Godot label "Chai Tapri" at local (0, 2.75, 0.2))
    tp = Asset("chai_tapri")
    tp.block((2.2, 0.1, 2.3), (0, 0.65, 0), WOOD)                            # back panel
    for sx in (-1, 1):
        # counter-height side walls (open above) + corner posts up to the roof
        side = "+x" if sx > 0 else "-x"
        tp.block((0.1, 1.4, 1.0), (sx * 1.05, 0, 0), WOOD)
        tp.block((0.14, 1.44, 0.05), (sx * 1.05, 0, 1.0), CREAM)
        for py in (-0.66,):                                               # front posts (back panel covers the rear)
            tp.block((0.1, 0.1, 2.3), (sx * 1.07, py, 0), WOOD)
        X = sx * 1.101                                                        # chai poster
        tp.decal((X, -0.05, 0.52), 0.9, 0.62, side, PAINT_YELLOW)
        tp.decal((X + sx * 0.004, -0.08, 0.55), 0.2, 0.24, side, RED)        # cup
        tp.decal((X + sx * 0.004, -0.08 + sx * 0.14, 0.57), 0.08, 0.12, side, RED)  # handle
        tp.decal((X + sx * 0.004, -0.08, 0.39), 0.34, 0.05, side, RED)       # saucer
        tp.decal((X + sx * 0.008, -0.08 + sx * 0.14, 0.57), 0.03, 0.05, side, PAINT_YELLOW)
    tp.block((2.36, 1.56, 0.1), (0, 0, 2.3), RED)                            # roof slab
    tp.block((2.0, 0.26, 0.04), (0, 0.48, 1.55), CHAI)                       # back shelf
    for i, col in enumerate((RED, PAINT_YELLOW, GREEN, BLUE)):
        tp.block((0.22, 0.12, 0.26), (-0.75 + i * 0.5, 0.5, 1.59), col)       # packets
    tp.decal((0, 0.594, 1.95), 1.3, 0.4, "-y", PAINT_YELLOW)                 # tea poster
    tp.decal((0, 0.59, 1.95), 0.9, 0.22, "-y", RED)
    tp.block((2.1, 0.5, 0.92), (0, -0.42, 0), WOOD)                           # counter
    tp.block((2.2, 0.6, 0.06), (0, -0.42, 0.92), CREAM)
    tp.decal((0, -0.675, 0.52), 1.9, 0.62, "-y", RED)
    tp.decal((0, -0.679, 0.82), 1.9, 0.06, "-y", PAINT_YELLOW)
    tp.decal((0, -0.679, 0.24), 1.9, 0.06, "-y", PAINT_YELLOW)
    tp.decal((0, -0.683, 0.53), 0.3, 0.3, "-y", WHITE, rot=45)                # cup emblem
    tp.decal((0, -0.687, 0.53), 0.14, 0.12, "-y", CHAI)
    tp.cyl(0.2, 0.1, (-0.55, -0.42, 0.98), DARK_STEEL, seg=8)                 # stove
    tp.cyl(0.2, 0.32, (-0.55, -0.42, 1.08), STEEL, seg=8, r2=0.14)            # big kettle
    tp.cyl(0.13, 0.05, (-0.55, -0.42, 1.4), STEEL, seg=8, r2=0.06)
    tp.ball(0.035, (-0.55, -0.42, 1.47), DARK_STEEL, seg=5, rings=3)
    tp.beam((-0.4, -0.42, 1.15), (-0.2, -0.42, 1.36), 0.05, STEEL)             # spout
    tp.beam((-0.75, -0.42, 1.2), (-0.72, -0.42, 1.5), 0.035, DARK_STEEL)      # handle
    tp.beam((-0.72, -0.42, 1.5), (-0.4, -0.42, 1.5), 0.035, DARK_STEEL)
    for i in range(4):                                                         # glasses of chai
        x = 0.02 + i * 0.14
        tp.cyl(0.045, 0.11, (x, -0.56, 0.98), GLASS, seg=6, r2=0.05)
        tp.decal((x, -0.56, 1.092), 0.06, 0.06, "+z", CHAI, rot=45)
    for i, x in enumerate((0.78, 0.96)):                                       # rusk jars
        tp.cyl(0.08, 0.18, (x, -0.32, 0.98), ROTI, seg=8)
        tp.cyl(0.085, 0.04, (x, -0.32, 1.16), RED if i == 0 else BLUE, seg=8)
    # striped awning: from the roof's front edge (y -0.78, z 2.3) down to (y -1.25, z 2.0)
    ya, yb2, za, zb2 = -0.78, -1.25, 2.3, 2.0
    n = 8
    for i in range(n):
        x0, x1 = -1.18 + 2.36 * i / n, -1.18 + 2.36 * (i + 1) / n
        tp.face([(x0, ya, za), (x1, ya, za), (x1, yb2, zb2), (x0, yb2, zb2)],
                RED if i % 2 == 0 else WHITE, up=True)
        tp.face([(x0, yb2, zb2), (x1, yb2, zb2), ((x0 + x1) / 2, yb2, zb2 - 0.14)],
                WHITE if i % 2 == 0 else RED, normal=(0, -1, 0))
    for sx in (-1, 1):
        tp.beam((sx * 1.05, -0.7, 1.75), (sx * 1.12, yb2 + 0.05, zb2 - 0.02), 0.04, WOOD)
    for i, col in enumerate((PINK, PAINT_YELLOW, BLUE, GREEN, ORANGE, NEON_CYAN)):  # snack strips
        x = -0.95 + i * 0.38
        for j in range(3):
            tp.decal((x, yb2 + 0.02, zb2 - 0.2 - j * 0.15), 0.11, 0.13, "-y",
                     col if j % 2 == 0 else TRUCK_ART[(i + 3) % len(TRUCK_ART)])
    # sign board on the roof: maroon face 2.7 x 0.62 centred ~2.77 high (label at local
    # (0, 2.75, 0.2), ~2.3 m wide at font 80), 0.06 yellow frame, 7 bulbs along the top
    tp.block((2.82, 0.06, 0.74), (0, -0.07, 2.4), PAINT_YELLOW)
    tp.block((2.7, 0.08, 0.62), (0, -0.11, 2.46), MAROON)
    for i in range(7):
        tp.ball(0.065, (-1.2 + i * 0.4, -0.1, 3.2), BULB, seg=4, rings=2)
    for sx in (-0.5, 0.5):                                                    # stools out front
        tp.cyl(0.1, 0.42, (sx, -1.45, 0), TRUNK, seg=6, r2=0.06)
        tp.cyl(0.18, 0.05, (sx, -1.45, 0.42), WOOD, seg=6)
    out.append(tp.finish(mat))

    # ---- padlock (unlock pads): ~0.55 tall, origin bottom centre, faces -Y
    pl = Asset("padlock")
    pl.wheel(0.19, 0.18, (0, 0, 0.19), PAINT_YELLOW, seg=12)
    pl.block((0.38, 0.18, 0.14), (0, 0, 0.19), PAINT_YELLOW)
    pl.block((0.4, 0.2, 0.04), (0, 0, 0.3), DAL)
    pl.wheel(0.05, 0.02, (0, -0.09, 0.2), HAIR, seg=8)
    pl.block((0.04, 0.02, 0.09), (0, -0.095, 0.09), HAIR)
    for x in (-0.12, 0.12):
        pl.cyl(0.035, 0.07, (x, 0, 0.33), STEEL, seg=8)
    prev = None
    for i in range(8):
        a = math.pi * i / 7
        p = Vector((0.12 * math.cos(a), 0, 0.4 + 0.12 * math.sin(a)))
        if prev is not None:
            pl.rod(prev - (p - prev) * 0.12, p + (p - prev) * 0.12, 0.035, STEEL, seg=6)
        prev = p
    out.append(pl.finish(mat))

    ct = Asset("cash_table")
    ct.block((1.0, 0.6, 0.06), (0, 0, 0.62), WOOD)
    for x in (-0.42, 0.42):
        for y in (-0.24, 0.24):
            ct.block((0.07, 0.07, 0.62), (x, y, 0), TRUNK)
    ct.block((0.3, 0.25, 0.18), (0.32, 0.12, 0.68), MAROON)          # galla box
    ct.block((0.75, 0.45, 0.03), (-0.1, -0.02, 0.68), STEEL)         # tray
    out.append(ct.finish(mat))

    # one note bundle 0.42 x 0.22 x 0.09 (stacked by CashPile). The long side runs along
    # Godot Z so two columns at CashPile's 0.34 m spacing sit side by side without overlap.
    cs = Asset("cash")
    cs.block((0.22, 0.42, 0.09), (0, 0, 0), CASH)
    cs.block((0.23, 0.08, 0.095), (0, 0, 0), PAINT_YELLOW)                   # paper band
    for y in (-0.13, 0.13):
        cs.decal((0, y, 0.091), 0.11, 0.09, "+z", DARK_GREEN)
    out.append(cs.finish(mat))

    pm = Asset("parking_mark")
    pm.block((0.12, 4.0, 0.015), (-1.1, 0, 0), LINE)
    pm.block((0.12, 4.0, 0.015), (1.1, 0, 0), LINE)
    pm.block((2.32, 0.12, 0.015), (0, -2.0, 0), LINE)
    out.append(pm.finish(mat))

    pu = Asset("pump")
    pu.block((0.8, 0.8, 0.14), (0, 0, 0), STEEL)
    pu.cyl(0.09, 0.95, (0, 0.1, 0.14), TEAL, seg=8)
    pu.block((0.22, 0.22, 0.28), (0, 0.1, 1.0), TEAL)
    pu.box((0.06, 0.06, 0.7), (0.25, 0.1, 1.2), DARK_STEEL, rot=(0, 60, 0))
    pu.box((0.06, 0.25, 0.06), (0, -0.08, 0.78), TEAL)
    pu.cyl(0.16, 0.25, (-0.05, -0.28, 0.14), RED, seg=8, r2=0.19)    # balti
    pu.block((1.1, 0.9, 0.01), (0.1, -0.1, 0), GLASS)                # puddle
    out.append(pu.finish(mat))

    # ---- highway billboard: navy face 4.6 x 2.0 centred at 3.7 (bottom 2.7, so trucks pass
    # under it). Text at local (0, 3.7, 0.16). One 0.2 m pole in front at local (-0.2, z +0.3)
    # stops under the board; a cranked arm carries it to a mast and rails hidden behind the face.
    sb = Asset("signboard")
    CZ, HW, HH = 3.7, 2.3, 1.0
    PXo, PYo, PTOP = -0.2, -0.3, 2.42
    sb.block((0.4, 0.4, 0.2), (PXo, PYo, 0), GRAVEL)
    sb.cyl(0.1, PTOP, (PXo, PYo, 0), STEEL, seg=8)
    sb.cyl(0.13, 0.08, (PXo, PYo, PTOP - 0.04), DARK_STEEL, seg=8)
    sb.beam((PXo, PYo, PTOP), (PXo, 0.16, PTOP), 0.12, DARK_STEEL)              # cantilever arm
    sb.beam((PXo, 0.16, PTOP - 0.06), (PXo, 0.16, CZ + 0.8), 0.12, DARK_STEEL)   # rear mast
    for z in (CZ - 0.55, CZ + 0.55):                                             # rear rails
        sb.beam((-HW + 0.3, 0.12, z), (HW - 0.3, 0.12, z), 0.08, DARK_STEEL)
    sb.beam((-HW + 0.1, 0.03, CZ - HH - 0.06), (HW - 0.1, 0.03, CZ - HH - 0.06), 0.1, DARK_STEEL)  # sill
    sb.block((2 * HW + 0.12, 0.06, 2 * HH + 0.12), (0, 0.08, CZ - HH - 0.06), DARK_STEEL)
    sb.block((2 * HW, 0.12, 2 * HH), (0, 0, CZ - HH), NAVY)

    def neon_rect(hx, hz, col, t):
        y = -0.06 - t / 2
        z0, z1 = CZ - hz, CZ + hz
        sb.beam((-hx, y, z0), (hx, y, z0), t, col)
        sb.beam((-hx, y, z1), (hx, y, z1), t, col)
        sb.beam((-hx, y, z0 - t / 2), (-hx, y, z1 + t / 2), t, col)
        sb.beam((hx, y, z0 - t / 2), (hx, y, z1 + t / 2), t, col)
    neon_rect(2.22, 0.92, NEON_PINK, 0.11)
    neon_rect(2.07, 0.78, NEON_CYAN, 0.08)
    za, ya = CZ - HH - 0.12, -0.04                                               # arrow under the board
    sb.beam((-2.0, ya, za), (1.92, ya, za), 0.12, PAINT_YELLOW)
    sb.beam((2.02, ya, za), (1.74, ya, za + 0.2), 0.12, PAINT_YELLOW)
    sb.beam((2.02, ya, za), (1.74, ya, za - 0.2), 0.12, PAINT_YELLOW)
    for i in range(11):                                                        # chaser bulbs
        sb.ball(0.08, (-2.0 + i * 0.4, -0.02, CZ + HH + 0.1), BULB, seg=6, rings=3)
    out.append(sb.finish(mat))

    lp = Asset("lamp")
    lp.cyl(0.07, 3.0, (0, 0, 0), DARK_STEEL, seg=6)
    lp.box((0.6, 0.06, 0.06), (0.25, 0, 3.0), DARK_STEEL)
    lp.ball(0.14, (0.5, 0, 2.9), BULB, seg=8, rings=4)
    lp.cyl(0.16, 0.08, (0.5, 0, 2.98), DARK_STEEL, seg=8, r2=0.05)
    out.append(lp.finish(mat))

    fb = Asset("famous_board")
    fb.box((3.6, 0.12, 1.2), (0, 0, 0.6), RED)
    fb.box((3.4, 0.13, 1.0), (0, -0.01, 0.6), YELLOW)
    for x in (-1.6, 1.6):
        fb.cyl(0.05, 0.4, (x, 0.1, -0.3), DARK_STEEL, seg=6)
    out.append(fb.finish(mat))

    out.append(plant_geo(Asset("plant_pot")).finish(mat))

    # Food icons (order bubbles and flying plates), ~0.3 wide.
    ic = Asset("icon_chai")
    ic.cyl(0.09, 0.22, (0, 0, 0), GLASS, seg=8, r2=0.11)
    ic.cyl(0.095, 0.16, (0, 0, 0.02), CHAI, seg=8, r2=0.105)
    out.append(ic.finish(mat))
    ir = Asset("icon_roti")
    ir.cyl(0.17, 0.03, (0, 0, 0), STEEL, seg=10)
    ir.cyl(0.14, 0.02, (0, 0, 0.03), ROTI, seg=10)
    ir.cyl(0.13, 0.02, (0.02, 0.01, 0.05), ROTI, seg=10)
    ir.box((0.06, 0.06, 0.03), (0.03, -0.02, 0.08), YELLOW)
    out.append(ir.finish(mat))
    return out


# ------------------------------------------------------------------ environment (Godot coords)
GATE_HALF = 1.6
WALL_X0, WALL_X1, WALL_Z0, WALL_Z1 = -10.0, 10.0, -5.0, 10.0


def build_ground(mat):
    g = Asset("ground")
    rng = random.Random(11)
    g.block((100, 100, 0.04), (0, 0, -0.04), DUST, nb=True)
    for zc in (-14.8, -10.2):                                                 # road shoulders
        g.grect(-50, zc - 0.42, 50, zc + 0.42, 0.008, DUST_DARK)
    g.gblob(15.6, -4.0, 4.2, 0.008, DUST_DARK, rng, n=10, jit=0.08, sx=1.0, sz=1.4)  # truck yard dirt
    # (x, z, r, sx, sz, kind) all outside the compound, road, parking and truck yard.
    # Radius capped at 2.4; kind 'g' grass, 'L' grass with a lighter centre (only 3),
    # 'd'/'v' bare dirt / gravel patches so the ground isn't dotted with lily pads.
    patches = [
        (-16, -1.5, 2.4, 1.0, 1.0, "d"), (-15, 6.5, 2.2, 1.2, 1.0, "g"), (-22, 2, 2.4, 1, 1.2, "g"),
        (-14.5, 13.5, 2.0, 1.3, 1, "g"), (-6, 15.6, 2.4, 1.3, 1.0, "d"), (3, 15.8, 2.4, 1.2, 1.0, "d"),
        (10, 15, 2.4, 1.2, 1.0, "v"), (-21, 17, 2.4, 1, 1, "g"), (15.5, 7.5, 2.4, 1.1, 1.0, "d"),
        (24, 6, 2.4, 1, 1.2, "g"), (16, 15.5, 2.4, 1.2, 1, "g"), (26, -3, 2.4, 1, 1.0, "v"),
        (-20, -21, 2.4, 1.5, 0.9, "g"), (-2, -21.5, 2.4, 1.6, 0.9, "d"), (16, -20.5, 2.4, 1.5, 0.9, "g"),
        (-34, -24, 2.4, 1.6, 1, "L"), (34, -24, 2.4, 1.6, 1, "L"), (-30, 8, 2.4, 1, 1.4, "L"),
        (32, 12, 2.4, 1, 1.3, "g"), (-24, -5, 2.4, 1.3, 0.7, "g"), (0, 27, 2.4, 1.6, 1, "g"),
    ]
    for (x, z, r, sx, sz, kind) in patches:
        col = {"g": GRASS, "L": GRASS, "d": DUST_DARK, "v": GRAVEL}[kind]
        g.gblob(x, z, r, 0.011, col, rng, sx=sx, sz=sz)
        if kind == "L":
            g.gblob(x + 0.4, z + 0.3, r * 0.5, 0.016, LEAF_LIGHT, rng, n=7, sx=sx, sz=sz)
    # grass tufts (3 blades, 6 tris) outside the walls and along the road shoulders
    spots = []
    for i in range(8):
        spots.append((-10.45 - rng.uniform(0, 0.35), -4.2 + i * 1.9 + rng.uniform(-0.4, 0.4)))  # left wall
        spots.append((10.45 + rng.uniform(0, 0.35), 1.6 + i * 1.1 + rng.uniform(-0.3, 0.3)))    # right wall
    for i in range(9):
        spots.append((-9.2 + i * 2.3 + rng.uniform(-0.5, 0.5), 10.45 + rng.uniform(0, 0.4)))   # front wall
    for i in range(10):
        spots.append((-24 + i * 5.1 + rng.uniform(-1.2, 1.2), -15.1 - rng.uniform(0, 0.5)))    # far shoulder
    for x in (-19.5, -16.0, -13.2, -11.2, 11.3, 13.5, 21.0, 24.5):
        spots.append((x + rng.uniform(-0.6, 0.6), -10.0 + rng.uniform(-0.15, 0.25)))          # near shoulder
    for (x, z) in spots:
        k = rng.uniform(0.75, 1.15)
        for j in range(3):
            a = rng.uniform(0, math.pi) + j * math.pi / 3
            d = Vector((math.cos(a), math.sin(a), 0)) * 0.07 * k
            lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 0)) * k
            base = Vector(B(x, 0, z))
            tip = base + lean + Vector((0, 0, rng.uniform(0.3, 0.45) * k))
            mid = base.lerp(tip, 0.5) + lean * 0.3
            col = (GRASS, LEAF, DARK_GREEN)[(j + int(x * 7)) % 3]
            g.face([base - d, base + d, mid + d * 0.45], col, normal=(d.y, -d.x, 0))
            g.face([base - d, mid + d * 0.45, tip], col, normal=(d.y, -d.x, 0))
    return g.finish(mat)


def build_road(mat):
    r = Asset("road")
    r.block((100, 4.0, 0.035), (0, 0, 0), ASPHALT, nb=True)
    for i in range(25):
        r.decal((-48 + i * 4 + 1, 0, 0.042), 2.0, 0.14, "+z", LINE)          # dashed centre line
    for y in (-1.78, 1.78):
        r.decal((0, y, 0.042), 100, 0.12, "+z", LINE)                         # edge lines
    for (x, y, w, h) in ((-17, 0.9, 1.6, 0.9), (6, -1.0, 1.2, 0.7), (21, 0.6, 2.0, 0.8), (-31, -0.8, 1.4, 1.0)):
        r.decal((x, y, 0.039), w, h, "+z", TARP)                              # repair patches
    return r.finish(mat)


def build_compound(mat):
    c = Asset("compound")
    rng = random.Random(5)
    # ---- zone floors (top ~0.02)
    c.gblock((19.2, 0.02, 9.2), (0, 0, 0), DUST_DARK)                        # dining packed earth
    for (x, z, r) in ((5.6, -0.2, 0.9), (-4.0, -0.3, 1.0), (7.5, 3.4, 0.8)):
        c.gblob(x, z, r, 0.026, MUD, rng, n=7, sx=1.3)                       # trodden patches
    # lighter customer path: gate -> down the x 0.4..1.2 corridor between canopy poles -> cashier
    path = [(0.0, -4.6), (0.8, -3.4), (0.8, 3.9), (2.2, 5.9)]
    PW, PYH = 0.55, 0.024
    for (x0, z0), (x1, z1) in zip(path, path[1:]):
        d = Vector((x1 - x0, z1 - z0))
        n = Vector((-d.y, d.x)).normalized() * PW
        c.face([B(x0 + n.x, PYH, z0 + n.y), B(x1 + n.x, PYH, z1 + n.y),
                B(x1 - n.x, PYH, z1 - n.y), B(x0 - n.x, PYH, z0 - n.y)], DUST, up=True)
    for (x, z) in path[1:-1]:                                                 # rounded joints
        c.face([B(x + PW * math.cos(k * math.pi / 4), PYH, z + PW * math.sin(k * math.pi / 4))
                for k in range(8)], DUST, up=True)
    # kitchen slate flagstones x -9.6..-0.8, z 4.6..9.6
    c.gblock((8.8, 0.012, 5.0), (-5.2, 0, 7.1), DARK_STEEL)
    tw, td, gap = 1.1, 1.0, 0.07
    for row in range(5):
        z0 = 4.6 + row * td
        off = (tw / 2) if row % 2 else 0.0
        x = -9.6 - off
        k = 0
        while x < -0.8:
            xa, xb = max(x + gap / 2, -9.6 + gap / 2), min(x + tw - gap / 2, -0.8 - gap / 2)
            if xb - xa > 0.15:
                col = TIN if (row * 3 + k) % 7 == 0 else SLATE
                c.grect(xa, z0 + gap / 2, xb, z0 + td - gap / 2, 0.022, col)
            x += tw
            k += 1
    # front yard x -0.8..9.6, z 4.6..9.6: 1 m pavers in two close sandy tones, half-paver
    # stagger per row, the DUST_DARK base showing through as grout
    c.gblock((10.4, 0.012, 5.0), (4.4, 0, 7.1), DUST_DARK)
    pw, g = 1.0, 0.04
    for row in range(5):
        z0, z1 = 4.6 + row * pw, 4.6 + (row + 1) * pw
        x = -0.8 - (pw / 2 if row % 2 else 0.0)
        k = 0
        while x < 9.6 - 1e-6:
            xa, xb = max(x, -0.8) + g, min(x + pw, 9.6) - g
            if xb - xa > 0.12:
                colr = ROTI if (k * 7 + row * 3) % 5 in (0, 2) else ROPE
                c.grect(xa, z0 + g, xb, z1 - g, 0.022, colr)
            x += pw
            k += 1
    for i in range(4):                                                        # stepping-stone slabs
        t = 0.12 + i * 0.25
        x, z = 0.0 + 2.2 * t, 4.6 + 1.4 * t
        a = math.atan2(1.4, 2.2) + math.pi / 2
        u, v = Vector((math.cos(a), math.sin(a))) * 0.34, Vector((-math.sin(a), math.cos(a))) * 0.2
        c.face([B(x - u.x - v.x, 0.03, z - u.y - v.y), B(x + u.x - v.x, 0.03, z + u.y - v.y),
                B(x + u.x + v.x, 0.03, z + u.y + v.y), B(x - u.x + v.x, 0.03, z - u.y + v.y)], CREAM, up=True)
    # parking gravel apron x -10.5..10.5, z -10.3..-5.2
    c.gblock((21.0, 0.02, 5.1), (0, 0, -7.75), GRAVEL)
    for i in range(22):
        x = rng.uniform(-10.2, 10.2)
        z = rng.uniform(-10.1, -5.4)
        c.gblob(x, z, rng.uniform(0.08, 0.16), 0.026, SLATE if i % 2 else DUST_DARK, rng, n=5, jit=0.3)
    c.gblock((3.2, 0.03, 0.8), (0, 0, -5.0), STEEL)                          # gate threshold

    # ---- wall: mud body, brick plinth, cream cap, chunky pillars
    T, H = 0.3, 0.7
    WALLC = CLAY

    def run(x0, z0, x1, z1):
        cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
        L = abs(x1 - x0) + abs(z1 - z0)
        alx = abs(x1 - x0) > 1e-6

        def sz(w):
            return (L, w) if alx else (w, L)
        a, b = sz(T)
        c.gblock((a, H, b), (cx, 0, cz), WALLC)
        a, b = sz(T + 0.06)
        c.gblock((a, 0.16, b), (cx, 0, cz), BRICK)
        a, b = sz(T + 0.08)
        c.gblock((a, 0.08, b), (cx, H, cz), MUD)

    run(WALL_X0, WALL_Z0, -GATE_HALF - 0.3, WALL_Z0)
    run(GATE_HALF + 0.3, WALL_Z0, WALL_X1, WALL_Z0)
    run(WALL_X0, WALL_Z1, WALL_X1, WALL_Z1)
    run(WALL_X0, WALL_Z0, WALL_X0, WALL_Z1)
    run(WALL_X1, WALL_Z0, WALL_X1, WALL_Z1)

    def pillar(x, z):
        c.gblock((0.46, 0.95, 0.46), (x, 0, z), BRICK)
        c.gblock((0.56, 0.08, 0.56), (x, 0.95, z), CREAM)
        c.cyl(0.2, 0.16, B(x, 1.03, z), CREAM, seg=4, r2=0.02, rot=(0, 0, 45))

    pillars = ([(x, WALL_Z0) for x in (-10.0, -7.4, -4.8, 4.8, 7.4, 10.0)]
               + [(x, WALL_Z1) for x in (-10.0, -7.5, -5.0, -2.5, 0.0, 2.5, 5.0, 7.5, 10.0)]
               + [(sx, z) for sx in (WALL_X0, WALL_X1) for z in (-2.5, 0.0, 2.5, 5.0, 7.5)])
    pots = {(-7.5, WALL_Z1), (-2.5, WALL_Z1), (2.5, WALL_Z1), (7.5, WALL_Z1), (WALL_X1, 2.5), (WALL_X0, 0.0)}
    for (x, z) in pillars:
        if (x, z) in pots:
            c.gblock((0.46, 0.95, 0.46), (x, 0, z), BRICK)
            c.gblock((0.56, 0.08, 0.56), (x, 0.95, z), CREAM)
            mini_pot(c, B(x, 1.03, z))
        else:
            pillar(x, z)
    # gate: tall pillars with lanterns, a saffron arch and a marigold garland
    for sx in (-1, 1):
        x = sx * (GATE_HALF + 0.3)
        c.gblock((0.6, 2.3, 0.6), (x, 0, WALL_Z0), BRICK)
        c.gblock((0.66, 0.2, 0.66), (x, 0, WALL_Z0), CREAM)
        c.gblock((0.72, 0.1, 0.72), (x, 2.3, WALL_Z0), CREAM)
        c.gblock((0.22, 0.26, 0.22), (x, 2.4, WALL_Z0), BULB)
        c.cyl(0.2, 0.18, B(x, 2.66, WALL_Z0), DARK_STEEL, seg=4, r2=0.02, rot=(0, 0, 45))
        c.decal(B(x, 1.3, WALL_Z0 + 0.305), 0.36, 0.36, "-y", SAFFRON, rot=45)
    # flat arch board (0.45 tall, 0.1 thick, red) with yellow strips along both edges on
    # the +Z face; top edge peaks at 3.15
    AH, AT, APEX = 0.45, 0.1, 3.15
    zf, zb = WALL_Z0 + AT / 2, WALL_Z0 - AT / 2
    arc = []
    for i in range(9):
        t = i / 8
        top = 2.36 + (APEX - 2.36) * math.sin(math.pi * t)
        arc.append((-1.75 + 3.5 * t, top - AH, top))
    for (xa, la, ta), (xb, lb, tb) in zip(arc, arc[1:]):
        c.face([B(xa, la, zf), B(xb, lb, zf), B(xb, tb, zf), B(xa, ta, zf)], RED, normal=(0, -1, 0))
        c.face([B(xa, la, zb), B(xb, lb, zb), B(xb, tb, zb), B(xa, ta, zb)], RED, normal=(0, 1, 0))
        c.face([B(xa, ta, zf), B(xb, tb, zf), B(xb, tb, zb), B(xa, ta, zb)], RED, up=True)
        c.face([B(xa, la, zf), B(xb, lb, zf), B(xb, lb, zb), B(xa, la, zb)], RED, normal=(0, 0, -1))
        zs = zf + 0.004
        for (ea, eb, d0, d1) in ((ta, tb, -0.1, -0.04), (la, lb, 0.04, 0.1)):   # edge strips
            c.face([B(xa, ea + d0, zs), B(xb, eb + d0, zs), B(xb, eb + d1, zs), B(xa, ea + d1, zs)],
                   PAINT_YELLOW, normal=(0, -1, 0))
    for i in range(5):                                                        # "lettering" dashes
        t = 0.3 + i * 0.1
        x = -1.75 + 3.5 * t
        mid = 2.36 + (APEX - 2.36) * math.sin(math.pi * t) - AH / 2
        c.decal(B(x, mid, WALL_Z0 + AT / 2 + 0.006), 0.22, 0.12, "-y", PAINT_YELLOW)
    gar = sag(B(-1.55, 2.2, WALL_Z0 + 0.12), B(1.55, 2.2, WALL_Z0 + 0.12), 0.38, 8)
    for i, p in enumerate(gar[1:-1]):
        c.ball(0.09, p, ORANGE if i % 2 else PAINT_YELLOW, seg=5, rings=3)
    # painted panels: wall-top triangle border on the inner faces the camera sees
    # (back wall faces +Z, right wall faces -X), ads on the outer faces of front/left walls.
    cols = (RED, PAINT_YELLOW, GREEN, BLUE, PINK, SAFFRON)
    k = 0
    for (x0, x1) in ((WALL_X0 + 0.4, -GATE_HALF - 0.7), (GATE_HALF + 0.7, WALL_X1 - 0.4)):
        n = int((x1 - x0) / 0.42)
        for i in range(n):
            x = x0 + (i + 0.5) * (x1 - x0) / n
            zf = WALL_Z0 + T / 2 + 0.004
            c.face([B(x - 0.15, 0.66, zf), B(x + 0.15, 0.66, zf), B(x, 0.44, zf)], cols[k % 6], normal=(0, -1, 0))
            k += 1
    n = int((WALL_Z1 - WALL_Z0 - 0.8) / 0.42)
    for i in range(n):
        z = WALL_Z0 + 0.4 + (i + 0.5) * (WALL_Z1 - WALL_Z0 - 0.8) / n
        xf = WALL_X1 - T / 2 - 0.004
        c.face([B(xf, 0.66, z - 0.15), B(xf, 0.66, z + 0.15), B(xf, 0.44, z)], cols[k % 6], normal=(-1, 0, 0))
        k += 1
    ads = [(PAINT_YELLOW, RED), (TEAL, WHITE), (RED, PAINT_YELLOW), (BLUE, WHITE), (GREEN, PAINT_YELLOW)]
    for i, xc in enumerate((-8.75, -3.75, 1.25, 6.25)):
        bg, fg = ads[i % len(ads)]
        zf = WALL_Z1 + T / 2 + 0.004
        c.decal(B(xc, 0.36, zf), 1.7, 0.46, "-y", WHITE)
        c.decal(B(xc, 0.36, zf + 0.004), 1.56, 0.34, "-y", bg)
        c.decal(B(xc - 0.3, 0.36, zf + 0.008), 0.7, 0.1, "-y", fg)
    for i, zc in enumerate((-3.75, 3.75)):
        bg, fg = ads[(i + 3) % len(ads)]
        xf = WALL_X0 - T / 2 - 0.004
        c.decal(B(xf, 0.36, zc), 1.7, 0.46, "-x", WHITE)
        c.decal(B(xf - 0.004, 0.36, zc), 1.56, 0.34, "-x", bg)
        c.decal(B(xf - 0.008, 0.36, zc + 0.3), 0.7, 0.1, "-x", fg)
    return c.finish(mat)


def build_wall_lights(mat):
    """WORLD-COORD festoon lights along the walls the camera sees (both back-wall runs and
    the right wall), hung 0.28 m inside the wall line between pillar caps (y 1.05, sag 0.25),
    plus one span from each gate lantern (y 2.4) to the first pillar. 'wall_bulbs' is separate
    so Godot can give it the emissive bulb material."""
    IN, CAP, SAG, STEP = 0.28, 1.05, 0.25, 0.42
    zb, xr = WALL_Z0 + IN, WALL_X1 - IN
    spans = []
    for xs in ((-10.0, -7.4, -4.8), (4.8, 7.4, 10.0)):
        pts = [(min(max(x, WALL_X0 + IN), xr), CAP, zb) for x in xs]
        spans += list(zip(pts, pts[1:]))
    zs = (-5.0, -2.5, 0.0, 2.5, 5.0, 7.5, 10.0)
    pts = [(xr, CAP, min(max(z, zb), WALL_Z1 - IN)) for z in zs]
    spans += list(zip(pts, pts[1:]))
    for sx in (-1, 1):
        spans.append(((sx * (GATE_HALF + 0.4), 2.42, zb), (sx * 4.8, CAP, zb)))
    wire, bulbs = Asset("wall_wire"), Asset("wall_bulbs")
    for (p0, p1) in spans:
        a, b = Vector(B(*p0)), Vector(B(*p1))
        pts = sag(a, b, SAG, 3)
        for i in range(3):
            wire.beam(pts[i], pts[i + 1], 0.03, HAIR)
        n = max(2, round((b - a).length / STEP))
        for i in range(n):
            t = (i + 0.5) / n
            p = a.lerp(b, t)
            p.z -= SAG * 4 * t * (1 - t) + 0.09
            bulbs.ball(0.08, p, BULB, seg=4, rings=2)
    return [wire.finish(mat), bulbs.finish(mat)]


def build_scenery(mat):
    s = Asset("scenery")
    rng = random.Random(3)

    def tree(x, z, k=1.0, kind=0):
        bx, by = x, -z
        if kind == 0:                                     # round neem / peepal
            s.cyl(0.15 * k, 1.3 * k, (bx, by, 0), TRUNK, seg=5, r2=0.1 * k)
            s.ico(0.95 * k, (bx, by, 1.85 * k), LEAF, subdiv=1, scale=(1, 1, 0.85))
            s.ico(0.55 * k, (bx + 0.45 * k, by - 0.3 * k, 2.4 * k), LEAF_LIGHT, subdiv=0)
        elif kind == 1:                                   # tall ashoka cone
            s.cyl(0.1 * k, 0.6 * k, (bx, by, 0), TRUNK, seg=5)
            s.cyl(0.7 * k, 1.5 * k, (bx, by, 0.5 * k), DARK_GREEN, seg=7, r2=0.3 * k)
            s.cyl(0.5 * k, 1.3 * k, (bx, by, 1.75 * k), DARK_GREEN, seg=7, r2=0.02)
        elif kind == 2:                                   # palm
            pts = [Vector((bx, by, 0)), Vector((bx + 0.15 * k, by, 1.2 * k)),
                   Vector((bx + 0.4 * k, by - 0.1 * k, 2.3 * k)), Vector((bx + 0.7 * k, by - 0.2 * k, 3.2 * k))]
            for i in range(3):
                s.rod(pts[i], pts[i + 1], (0.14 - 0.02 * i) * k, WOOD, seg=5)
            top = pts[-1]
            for i in range(7):
                a = math.radians(i * 360 / 7 + 15)
                d = Vector((math.cos(a), math.sin(a), 0))
                side = Vector((-d.y, d.x, 0)) * 0.22 * k
                mid = top + d * 0.8 * k + Vector((0, 0, 0.2 * k))
                tip = top + d * 1.6 * k - Vector((0, 0, 0.55 * k))
                s.face([top, mid + side, tip, mid - side], LEAF if i % 2 else LEAF_LIGHT, up=True)
        else:                                             # low bush
            s.ico(0.6 * k, (bx, by, 0.3 * k), LEAF if rng.random() < 0.5 else DARK_GREEN, subdiv=0,
                  scale=(1.2, 1.0, 0.75))

    # hills far behind the road (Godot z < -20)
    for (x, z, rx, rz, ry, col) in ((-34, -38, 12, 6, 6, DARK_GREEN), (-12, -42, 14, 7, 8, LEAF),
                                    (10, -40, 12, 6, 6.5, DARK_GREEN), (30, -36, 11, 6, 5, LEAF),
                                    (-22, -30, 7, 4, 3.2, LEAF), (20, -29, 8, 4, 3.0, LEAF)):
        s.ico(1.0, B(x, 0, z), col, subdiv=1, scale=(rx, rz, ry))
    # behind the road (z -15..-19): trees + power poles with wires
    xs = list(range(-32, 34, 6))
    for i, x in enumerate(xs):
        tree(x + rng.uniform(-1.2, 1.2), -16.6 - (i % 3) * 0.9, 0.95 + (i % 3) * 0.15, (0, 1, 0, 2)[i % 4])
    poles = list(range(-30, 32, 10))
    for x in poles:
        s.cyl(0.08, 4.6, B(x, 0, -15.6), TRUNK, seg=5)
        s.beam(B(x - 0.7, 4.4, -15.6), B(x + 0.7, 4.4, -15.6), 0.08, TRUNK)
    for i in range(len(poles) - 1):
        for dx in (-0.6, 0.6):
            ps = sag(B(poles[i] + dx, 4.45, -15.6), B(poles[i + 1] + dx, 4.45, -15.6), 0.5, 2)
            for j in range(len(ps) - 1):
                s.beam(ps[j], ps[j + 1], 0.025, HAIR)
    # outside the compound: left (x < -11.5), front (z > 11.5), right (x > 11.5)
    # front row (z > 11.5) with x < 5 stays low (kind 3, k <= 0.7): the game camera's eye is
    # at about (-9.6, 14.2), so anything tall there fills the bottom of the screen (HUD area).
    # The tall trees that used to stand there move back to z >= 15.
    for (x, z, k, kind) in ((-13.0, -3.0, 1.0, 0), (-14.2, 1.8, 1.15, 1), (-12.6, 5.2, 0.95, 2), (-15.5, 8.6, 1.2, 0),
                            (-13.0, 12.2, 0.7, 3), (-18.5, 4.0, 1.3, 0), (-19.0, -6.0, 1.1, 1),
                            (-7.0, 12.8, 0.7, 3), (-2.5, 12.6, 0.6, 3), (3.5, 12.9, 0.7, 3), (8.5, 12.8, 1.0, 1),
                            (13.0, 13.4, 1.1, 0), (13.2, 4.2, 1.0, 2), (16.5, 6.8, 1.2, 0), (21.0, -2.5, 1.1, 1),
                            (21.5, -8.5, 1.0, 0), (19.0, 11.0, 1.0, 1),
                            (-14.0, 15.6, 1.0, 1), (-7.5, 16.5, 1.1, 0), (-1.5, 15.4, 0.9, 2), (4.0, 16.2, 1.2, 0)):
        tree(x, z, k, kind)
    for (x, z, k) in ((-11.2, 3.5, 0.6), (-11.0, 9.0, 0.7), (-4.2, 11.0, 0.6), (5.5, 11.0, 0.7),
                      (11.0, 7.5, 0.65), (-11.3, -8.0, 0.6)):
        tree(x, z, k, 3)
    # truck yard on the right outside the wall (x 12..19, z -9..1): bus + 2 trucks, nosed toward +Z
    s.place(lambda a: bus_geo(a, wseg=8, lod=1), loc=B(13.3, 0, -4.4), rz=-90)
    s.place(lambda a: truck_geo(a, ORANGE, RED, PAINT_YELLOW, GREEN, wseg=8, lod=1), loc=B(15.9, 0, -5.2), rz=-90)
    s.place(lambda a: truck_geo(a, BLUE, GREEN, PAINT_YELLOW, RED, wseg=8, lod=1), loc=B(18.2, 0, -4.6), rz=-90)
    for (x, z, col) in ((12.4, -8.6, BLUE), (12.9, -8.9, RED), (19.3, 0.2, BLUE)):
        s.cyl(0.28, 0.85, B(x, 0, z), col, seg=8)                            # oil drums
    for i in range(3):
        s.wheel(0.42, 0.24, B(18.9, 0.12 + i * 0.25, -8.6), TYRE, seg=8, axis="z")
    # NH48 milestone near the road (white stone, yellow dome), facing +Z
    mx, mz = -12.6, -9.7
    s.gblock((0.52, 0.62, 0.22), (mx, 0, mz), WHITE)
    s.wheel(0.26, 0.22, B(mx, 0.62, mz), PAINT_YELLOW, seg=10, axis="y")
    s.decal(B(mx, 0.66, mz + 0.115), 0.3, 0.07, "-y", HAIR)
    s.decal(B(mx, 0.42, mz + 0.115), 0.36, 0.06, "-y", HAIR)
    s.decal(B(mx, 0.28, mz + 0.115), 0.24, 0.06, "-y", HAIR)
    for (x, z, k) in ((-12.0, -12.0 + 3.0, 0.5), (11.8, -9.4, 0.45), (-24, 12, 0.7), (26, 2, 0.6)):
        s.ico(k, B(x, k * 0.2, z), GRAVEL, subdiv=0, scale=(1.3, 1.0, 0.6))   # rocks
    # crash barrier on the far shoulder: 0.3 m rail centred 0.6 high on posts every 4 m
    BZ = -15.0
    s.gblock((100.0, 0.3, 0.08), (0, 0.45, BZ + 0.06), STEEL)
    s.decal(B(0, 0.6, BZ + 0.10 + 0.002), 100.0, 0.06, "-y", DARK_STEEL)
    for i in range(25):
        s.gblock((0.12, 0.62, 0.12), (-48 + i * 4, 0, BZ - 0.04), DARK_STEEL)
    return s.finish(mat)


def build_environment(mat):
    return [build_ground(mat), build_compound(mat), build_road(mat), build_scenery(mat)] + build_wall_lights(mat)


# ------------------------------------------------------------------ export
def export(obj, outdir):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(outdir, obj.name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_draco_mesh_compression_enable=False, export_animations=False,
        export_cameras=False, export_lights=False, export_vertex_color="ACTIVE",
    )
    return path


# ------------------------------------------------------------------ review renders
SKY = (0.98, 0.84, 0.66)
# Godot sun: rotation_degrees (-50, -70, 0) -> light travels along (0.604, -0.766, -0.220) (Godot).
SUN_TO_LIGHT_BL = Vector((-0.604, -0.220, 0.766)).normalized()


def setup_render(w, h, bg=SKY, ambient=0.75, sun=3.2):
    """EEVEE with a sun along the game's DirectionalLight and a warm flat ambient."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    for attr, val in (("taa_render_samples", 16), ("use_shadows", True), ("use_gtao", True),
                      ("shadow_ray_count", 1), ("shadow_step_count", 4)):
        if hasattr(ee, attr):
            setattr(ee, attr, val)
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = scene.world or bpy.data.worlds.new("w")
    scene.world = world
    ensure_nodes(world)
    bgn = world.node_tree.nodes.get("Background")
    bgn.inputs[0].default_value = (bg[0], bg[1], bg[2], 1.0)
    bgn.inputs[1].default_value = ambient
    sun_obj = bpy.data.objects.get("review_sun")
    if sun_obj is None:
        ld = bpy.data.lights.new("review_sun", "SUN")
        sun_obj = bpy.data.objects.new("review_sun", ld)
        scene.collection.objects.link(sun_obj)
    sun_obj.data.energy = sun
    sun_obj.data.angle = math.radians(3)
    sun_obj.data.color = (1.0, 0.95, 0.86)
    sun_obj.rotation_euler = SUN_TO_LIGHT_BL.to_track_quat("Z", "Y").to_euler()
    return scene


def make_camera(name, ortho=None, fov=None):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.sensor_fit = "HORIZONTAL"
        cd.angle = math.radians(fov)
    cd.clip_start = 0.1
    cd.clip_end = 500
    cam = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(cam)
    return cam


def look_at(cam, eye, target):
    cam.location = Vector(eye)
    d = Vector(target) - Vector(eye)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


# Placement values the preview assumes. These are the art director's proposed code values
# (Layout.SIGN, Layout.PILE_OFFSET, main.gd STRING_LIGHT_SIDES), not necessarily what
# scripts/ currently holds; this tool never edits game code.
PREVIEW_SIGN = tuple(float(v) for v in os.environ.get("DHABA_PREVIEW_SIGN", "-1.0,-5.9").split(","))
PREVIEW_PILE_OFFSET = (1.35, 0.7)
PREVIEW_STRING_SIDES = (1.8,)
# Label3D uses the project font (ui/main_font.tres: Baloo 2 at weight 800). Blender draws
# Baloo 2 caps 0.415 BU tall at text size 1 and its capHeight is 0.602 em, so 1 em = 0.69 BU;
# the file is the variable font's default (regular) instance, so widths get x1.08 for 800.
_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
LABEL_FONTS = (os.path.join(_HERE, "..", "..", "assets", "fonts", "Baloo2.ttf"),)
LABEL_BU_PER_EM, LABEL_BOLD_X = 0.69, 1.08


def _flat_mat(name, rgb, emit=1.0):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        ensure_nodes(m)
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        em.inputs["Strength"].default_value = emit
        out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def _label_font():
    for p in LABEL_FONTS:
        if os.path.exists(p):
            try:
                return bpy.data.fonts.load(p, check_existing=True)
            except RuntimeError:
                pass
    return None


def render_world(objs, persp_path, top_path):
    """Assemble the v2 layout from the exported meshes and render the game view + top view."""
    scene = bpy.context.scene
    for o in objs:
        o.hide_render = True
    tmp = []
    bulb_mat = _flat_mat("preview_bulb", (1.0, 0.93, 0.7))     # main.gd's unshaded bulb colour

    def put(name, gx, gz, gy=0.0, ry=0.0, s=1.0):
        src = bpy.data.objects[name]
        o = bpy.data.objects.new(name + "_v", src.data)
        scene.collection.objects.link(o)
        o.location = B(gx, gy, gz)
        o.rotation_euler = (0, 0, math.radians(ry))
        o.scale = (s, s, s)
        if name.endswith("bulbs"):
            o.material_slots[0].link = "OBJECT"
            o.material_slots[0].material = bulb_mat
        tmp.append(o)
        return o

    font = _label_font()

    def label(text, px, gx, gy, gz, rgb):
        """Approximation of a code Label3D (pixel_size 0.006, centred, facing +Z)."""
        td = bpy.data.curves.new("lbl_" + text[:8], "FONT")
        td.body = text
        bold = 1.0
        if font is not None:
            td.font = font
            td.size = px * 0.006 / LABEL_BU_PER_EM
            bold = LABEL_BOLD_X
        else:
            td.size = px * 0.006
        td.align_x = "CENTER"
        td.align_y = "CENTER"
        lo = bpy.data.objects.new(td.name, td)
        lo.data.materials.append(_flat_mat("lbl_%d_%d_%d" % tuple(int(c * 255) for c in rgb), rgb))
        scene.collection.objects.link(lo)
        lo.location = B(gx, gy, gz)
        lo.rotation_euler = (math.radians(90), 0, 0)
        lo.scale = (bold, 1.0, 1.0)
        tmp.append(lo)

    for n in ("ground", "compound", "scenery", "wall_wire", "wall_bulbs"):
        put(n, 0, 0)
    put("road", 0, -12.5)
    put("hut_1", -5.2, 5.4)
    tables = [(-1.6, 1.8), (3.2, 1.8), (-1.6, -2.4)]
    for i, (tx, tz) in enumerate(tables):
        put("dining_table", tx, tz)
        put("charpai", tx, tz - 0.95)
        put("charpai", tx, tz + 0.95)
        put(("canopy_red", "canopy_teal", "canopy_yellow")[i], tx, tz)
        for side in PREVIEW_STRING_SIDES:
            put("string_wire", tx, tz + side)
            put("string_bulbs", tx, tz + side)
        put("customer_" + "abcd"[i], tx - 0.42, tz - 0.95, 0.42, 0)
        put("customer_" + "dcba"[i], tx + 0.42, tz + 0.95, 0.42, 180)
        px, pz = tx + PREVIEW_PILE_OFFSET[0], tz + PREVIEW_PILE_OFFSET[1]
        for k in range(5):                                       # CashPile.refresh() layout
            put("cash", px + (k % 2) * 0.34 - 0.17, pz, (k // 2) * 0.07, (-8, 6, 12, -5, 3)[k])
    put("padlock", 3.2, -2.4, 1.2, 0, 1.4)
    put("station_chai", -7.6, 8.2)
    put("station_tandoor", -5.2, 8.2)
    put("bhaiya", -5.2, 7.0, 0, 0, 1.2)
    put("cashier_desk", 2.2, 6.4)
    put("chotu", 1.0, 6.8)
    put("chai_tapri", 6.6, 7.4)
    put("signboard", *PREVIEW_SIGN)
    label("DHABA RUSH\nढाबा", 110, PREVIEW_SIGN[0], 3.7, PREVIEW_SIGN[1] + 0.16, (1.0, 0.9, 0.3))
    label("₹ 1,250/min", 64, 2.2, 2.3, 6.4 + 0.1, (0.25, 0.12, 0.02))
    label("Chai Tapri", 80, 6.6, 2.75, 7.4 + 0.2, (1.0, 0.95, 0.85))
    put("pump", 8.6, -3.6)
    put("plant_pot", 9.0, 4.4)
    put("plant_pot", -0.2, 4.2)
    for (lx, lz) in ((-9.4, -4.4), (9.4, -4.4), (9.4, 9.4), (-0.4, 9.4)):
        put("lamp", lx, lz)
    for i, x in enumerate((-2.8, 0.4, 3.6, -6.0, 6.8)):
        put("parking_mark", x, -7.8, 0.03)
    put("car", -2.8, -7.8, 0, -90)
    put("truck", 0.4, -7.8, 0, -90)
    put("truck_green", 3.6, -7.8, 0, -90)
    put("car_red", -8.0, -11.7)
    put("auto", 9.0, -11.7)
    put("bus", 22.0, -13.3, 0, 180)

    setup_render(720, 1280)
    target = Vector((-0.5, 0.0, 2.6))
    yaw, pitch, dist = math.radians(-38), math.radians(52), 24.0
    off = Vector((math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))) * dist
    eye = target + off
    cam = make_camera("game_cam", fov=40)
    look_at(cam, B(*eye), B(*target))
    scene.camera = cam
    scene.render.filepath = persp_path
    bpy.ops.render.render(write_still=True)

    setup_render(1400, 1400)
    top = make_camera("top_cam", ortho=56)
    top.location = B(3.0, 80.0, -3.5)
    top.rotation_euler = (0, 0, 0)
    scene.camera = top
    scene.render.filepath = top_path
    bpy.ops.render.render(write_still=True)

    extra = os.environ.get("DHABA_CLOSEUPS")
    if extra:
        os.makedirs(extra, exist_ok=True)
        setup_render(900, 900)
        for (nm, tx, tz, d) in (("yard", 4.4, 7.2, 9), ("kitchen", -5.2, 6.8, 9), ("gate", -1.0, -6.5, 11),
                                ("tables", 0.8, -0.2, 11), ("truckyard", 15.6, -4.5, 12),
                                ("parking", 1.6, -7.6, 8)):
            t2 = Vector((tx, 0.0, tz))
            look_at(cam, B(*(t2 + off * (d / dist))), B(*t2))
            scene.camera = cam
            scene.render.filepath = os.path.join(extra, nm + ".png")
            bpy.ops.render.render(write_still=True)
    for o in tmp + [cam, top]:
        bpy.data.objects.remove(o, do_unlink=True)
    for o in objs:
        o.hide_render = False


def render_sheet(objs, path, maxw=34.0):
    """Contact sheet of every non-world asset: shelf-packed rows (tallest first), each
    row pushed forward far enough that the next row's tallest item cannot hide it."""
    scene = bpy.context.scene
    items = [o for o in objs if o.name not in WORLD_ASSETS and o.name != "road"]
    for o in objs:
        o.hide_render = o not in items

    def bbox(o):
        xs = [v[0] for v in o.bound_box]
        ys = [v[1] for v in o.bound_box]
        zs = [v[2] for v in o.bound_box]
        return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)

    items.sort(key=lambda o: -(bbox(o)[5]))
    gap, tilt = 1.0, 32.0
    rows, cur, curw = [], [], 0.0
    for o in items:
        x0, x1 = bbox(o)[:2]
        w = max(x1 - x0, 0.9)
        if cur and curw + w > maxw:
            rows.append(cur)
            cur, curw = [], 0.0
        cur.append(o)
        curw += w + gap
    if cur:
        rows.append(cur)

    label_mat = bpy.data.materials.new("label")
    label_mat.diffuse_color = (0.12, 0.08, 0.06, 1)
    ensure_nodes(label_mat)
    lb = label_mat.node_tree.nodes.get("Principled BSDF")
    lb.inputs["Base Color"].default_value = (0.05, 0.03, 0.02, 1)
    lb.inputs["Roughness"].default_value = 1.0
    labels = []
    cy = 0.0
    for ri, row in enumerate(rows):
        depth = max(bbox(o)[3] - bbox(o)[2] for o in row)
        cx = 0.0
        for o in row:
            x0, x1, y0, y1, z0, z1 = bbox(o)
            w = max(x1 - x0, 0.9)
            o.location = (cx - x0 + (w - (x1 - x0)) / 2, cy - y1, 0)
            o.rotation_euler = (0, 0, 0)
            o.scale = (1, 1, 1)
            td = bpy.data.curves.new(o.name + "_lbl", "FONT")
            td.body = o.name
            td.size = 0.34
            td.align_x = "CENTER"
            lo = bpy.data.objects.new(o.name + "_lbl", td)
            lo.data.materials.append(label_mat)
            scene.collection.objects.link(lo)
            lo.location = (cx + w / 2, cy - (y1 - y0) - 0.5, 0.01)
            labels.append(lo)
            cx += w + gap
        cy -= depth + 0.9
        if ri + 1 < len(rows):
            nh = max(bbox(o)[5] for o in rows[ri + 1])
            cy -= nh * math.tan(math.radians(tilt)) + 0.3

    setup_render(2400, 1600, bg=(0.95, 0.9, 0.82), ambient=0.9, sun=2.6)
    bpy.context.view_layer.update()
    cam = make_camera("sheet_cam", ortho=10)
    rot = Euler((math.radians(tilt), 0, 0))
    cam.rotation_euler = rot
    rm = rot.to_matrix()
    inv = rm.inverted()
    pts = []
    for o in items + labels:
        for v in o.bound_box:
            pts.append(inv @ (o.matrix_world @ Vector(v)))
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    cxv, cyv = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    wv, hv = max(xs) - min(xs), max(ys) - min(ys)
    aspect = scene.render.resolution_x / scene.render.resolution_y
    cam.data.ortho_scale = max(wv, hv * aspect) * 1.04
    cam.location = rm @ Vector((cxv, cyv, max(zs) + 30))
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ v0.3 helper modules
# Builders for the v0.3 rebuild live next to this file (v3_*.py). They are loaded by path and
# get this module's globals injected before they run, so they can use Asset, B, the palette
# constants etc. directly (and each later module also sees the earlier helpers' names).
V3_BUDGETS = {"dhaba_v3": 24000, "street_v3": 38000, "tandoor_lock": 3500, "chai_counter_v3": 4000,
              "tray": 300, "tray_rack": 1800, "pass_plate": 400, "pass_roti": 600, "charpai": 1200,
              "dining_table": 1000, "dog": 1200,
              "galla_desk": 3000, "tandoor_station": 3000, "banknote": 700, "banknote_saffron": 700,
              "sikka": 900, "marker": 900, "cash_brick": 2000, "cow": 2000,
              # menu expansion (docs/v3-menu-expansion.md §13.1) + station MENUS / kadai
              # (docs/v3-station-menus.md §10.1)
              "lassi_station": 3000, "kadai_station": 3200,
              "pass_lassi": 400, "pass_bhurji": 600, "pass_dal": 500,
              "pass_coffee": 400, "pass_green_tea": 400, "pass_kesar_doodh": 400, "pass_chaas": 400,
              "pass_mango_lassi": 400, "pass_patiala": 400,
              "pass_naan": 600, "pass_keema_paratha": 600, "pass_kulcha": 600,
              "pass_paneer": 500, "pass_chole": 500,
              "prop_coffee_kettle": 250, "prop_green_tea_jar": 250, "prop_milk_can": 250,
              "prop_naan_basket": 250, "prop_keema_pot": 250, "prop_kulcha_board": 250,
              "prop_chaas_jug": 250, "prop_mango_crate": 250, "prop_patiala_glass": 250,
              "prop_dal_handi": 250, "prop_paneer_block": 250, "prop_chole_sack": 250}
# core-and-feel build (docs/core-and-feel/build-plan.md section 4, 2026-11-01): W1-ART1 world art ...
V3_BUDGETS.update({"seats_board": 300, "plate_stool": 300, "tray_wide": 300, "family_hall": 6500,
                   "family_table": 900, "hoarding": 1600, "tv_set": 300, "dog_sit": 1200, "bus_baraat": 2000,
                   "deco_baraat": 4000, "camel_cart": 1800, "pass_plate": 450, "pass_kulhad": 450})
# ... and W1-ART2's people and NH 48 pass items (v3_chars.py, v3_dishes_nh48.py)
V3_BUDGETS.update({n: 1800 for n in ("trav_elder", "trav_sardar", "trav_farmer", "trav_techie", "trav_baraati_m",
                                     "trav_baraati_f", "gopal", "lakhan", "balwant", "sonu", "bittu")})
V3_BUDGETS.update({n: 550 for n in ("pass_missi_roti", "pass_lahsun_roti", "pass_baati", "pass_rabri",
                                    "pass_dal_baati", "pass_gatte", "pass_ker_sangri", "pass_laal_maas",
                                    "pass_shikanji")})
# Story (4 Nov): the father is a hero character seen up close on his visits (pagdi, shawl, cane).
V3_BUDGETS.update({"story_father": 2600, "story_simran": 2000})
# Story (5 Nov): Rani, the narrator, is a 3D bust shown alone and large in the dialogue box; the
# owner asked for better modelling at no more than the first draft's ~6100 triangles.
V3_BUDGETS.update({"rani_" + p: 6100 for p in ("idle", "cheer", "worried", "point", "namaste", "ledger")})
# Dhaba growth (6 Nov): the cart stage, the tin shack (world-coord, in place of dhaba_v3's 24000)
# and the construction set shown while a stage is being built.
V3_BUDGETS.update({"growth_cart": 2800, "growth_neem": 2600, "growth_bench": 300, "growth_cart_yard": 3200,
                   "growth_cash_box": 900, "growth_crate_table": 600, "growth_kulhad_crate": 900,
                   "growth_shack": 4200, "growth_shack_tin": 2000, "growth_scaffold": 1000,
                   "growth_bricks": 1200, "growth_sand": 500, "growth_cement": 500, "growth_barrow": 800,
                   "growth_ladder": 600, "growth_wall_rising": 1500, "growth_site_board": 1100,
                   "worker_mistri": 1800, "worker_majdoorin": 1800})
V3_CHAR_BUDGET, V3_BUST_BUDGET = 1800, 3000


def _load_helper(name, ns):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    for k, v in ns.items():
        if not (k.startswith("__") and k.endswith("__")):
            mod.__dict__[k] = v
    spec.loader.exec_module(mod)
    ns.update({k: v for k, v in mod.__dict__.items() if not k.startswith("__")})
    return mod


def build_v3(mat):
    """Returns (single-mesh objects, multi-part Groups) for every v0.3 asset. dhaba_v3 and
    street_v3 are Groups of kind "world": the static mesh plus fairy_bulb_* / fairy_wire_*
    nodes (v3_exterior)."""
    ns = dict(globals())
    common = _load_helper("v3_common", ns)
    chars = _load_helper("v3_chars", ns)
    props = _load_helper("v3_props", ns)
    _load_helper("v3_world", ns)
    ext = _load_helper("v3_exterior", ns)
    # core-and-feel: NH 48 pass items (W1-ART2's module), loaded by path only when the file exists
    nh48 = _load_helper("v3_dishes_nh48", ns) if os.path.exists(os.path.join(_HERE, "v3_dishes_nh48.py")) else None
    render = _load_helper("v3_render", ns)
    # Dhaba growth (6 Nov, docs/growth/plan.md): the cart, the shack and the construction set
    growth = _load_helper("v3_growth", ns) if os.path.exists(os.path.join(_HERE, "v3_growth.py")) else None
    w_singles, w_groups = ext.build_world_ext(mat)
    cf_singles, cf_groups = ext.build_core_feel_ext(mat)
    singles = (w_singles + props.build_props_v3(mat) + props.build_menu_items(mat)
               + props.build_unlock_props(mat) + [props.build_pass_kulhad(mat)] + props.build_core_feel_props(mat)
               + cf_singles + (list(nh48.build_nh48_dishes(mat)) if nh48 is not None else []))
    groups = (w_groups + chars.build_travellers(mat) + chars.build_staff(mat) + chars.build_waiters(mat)
              + [props.build_cow(mat)] + props.build_menu_stations(mat) + chars.build_menu_cooks(mat)
              + chars.build_menu_helpers(mat)
              + chars.build_munshi(mat) + chars.build_rani(mat) + props.build_core_feel_prop_groups(mat)
              + cf_groups)
    if growth is not None:
        for o in growth.build_growth_exports(mat):
            (groups if hasattr(o, "objs") else singles).append(o)
    return singles, groups, common, render


def _bounds(o):
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def _check_inside_bounds(objs, name, ref):
    """Prints whether model `name` stays inside model `ref`'s bounds (Traffic sizes vehicles from
    their bounds, so a decorated variant must not grow)."""
    by = {o.name: o for o in objs}
    if name not in by or ref not in by:
        return
    (a0, a1), (b0, b1) = _bounds(by[name]), _bounds(by[ref])
    ok = all(a0[i] >= b0[i] - 1e-4 and a1[i] <= b1[i] + 1e-4 for i in range(3))
    f = lambda v: "(%.3f, %.3f, %.3f)" % tuple(v)
    print("[check] %s inside %s bounds: %s  %s..%s vs %s..%s" % (name, ref, ok, f(a0), f(a1), f(b0), f(b1)))


def v3_budget(name):
    if name in V3_BUDGETS:
        return V3_BUDGETS[name]
    return V3_BUST_BUDGET if name.startswith("munshi_") else V3_CHAR_BUDGET


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = os.path.abspath(argv[0] if argv else "themes/dhaba/models")
    sheet = None
    if "--sheet" in argv:
        sheet = os.path.abspath(argv[argv.index("--sheet") + 1])
    os.makedirs(outdir, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    img = build_palette_image()
    img.filepath_raw = os.path.join(outdir, "palette.png")
    img.file_format = "PNG"
    img.save()
    mat = make_material(img)
    # baked-text helper (v3_common.text_geo) for the vehicle slogans built below
    globals()["text_geo"] = _load_helper("v3_common", dict(globals())).text_geo
    objs = build_characters(mat) + build_vehicles(mat) + build_dhaba(mat) + build_environment(mat)
    over = []
    for o in objs:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        p = export(o, outdir)
        lim = budget_for(o.name)
        flag = "" if tris <= lim else f"  OVER BUDGET ({lim})"
        if flag:
            over.append(o.name)
        print(f"[asset] {o.name:<16} {tris:>6} tris  {os.path.getsize(p) // 1024:>4} KB{flag}")
    # ---- v0.3 assets
    v3_singles, v3_groups, v3_common, v3_render = build_v3(mat)
    for o in v3_singles:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        p = export(o, outdir)
        lim = v3_budget(o.name)
        flag = "" if tris <= lim else f"  OVER BUDGET ({lim})"
        if flag:
            over.append(o.name)
        print(f"[asset] {o.name:<16} {tris:>6} tris  {os.path.getsize(p) // 1024:>4} KB{flag}")
    _check_inside_bounds(objs + v3_singles, "bus_baraat", "bus")
    for g in v3_groups:
        tris = g.tris()
        p = v3_common.export_group(g, outdir)
        lim = v3_budget(g.name)
        flag = "" if tris <= lim else f"  OVER BUDGET ({lim})"
        if flag:
            over.append(g.name)
        parts = ",".join("%s(%d)" % (n, sum(len(q.vertices) - 2 for q in o.data.polygons)) for n, o in zip(g.names, g.objs))
        if getattr(g, "kind", "") == "world":
            parts = "%s(%d) + %d fairy bulbs in %d nodes" % (g.names[0], sum(len(q.vertices) - 2 for q in g.objs[0].data.polygons),
                                                            getattr(g, "fairy", 0), len(g.names) - 1)
        print(f"[asset] {g.name:<16} {tris:>6} tris  {os.path.getsize(p) // 1024:>4} KB  nodes: {parts}{flag}")
    if over:
        print("[budget] over:", ", ".join(over))
    if sheet:
        os.makedirs(os.path.dirname(sheet), exist_ok=True)
        d = os.path.dirname(sheet)
        if os.path.basename(sheet).startswith("v3"):
            lookup = {o.name: o for o in objs}
            names = []
            for o in v3_singles:
                lookup[o.name] = o
                names.append(o.name)
            for g in v3_groups:
                if getattr(g, "kind", "") == "world" and g.name not in ("dhaba_v3", "street_v3"):
                    # core-and-feel world models shown by code (family_hall, deco_baraat): staged
                    # part by part where a view wants them, never in every world render
                    lookup[g.name] = g.objs[0]
                    v3_render.GROUPS[g.name] = g
                    continue
                if getattr(g, "kind", "") == "world":
                    # static mesh renders as is; the bulbs / wires are staged by v3_render
                    lookup[g.name] = g.objs[0]
                    v3_render.WORLD_EXTRAS.extend(g.objs[1:])
                    continue
                g.display = v3_common.merge_objects(g.name, g.objs, mat, g.smooth)
                lookup[g.name] = g.display
                names.append(g.name)
                v3_render.GROUPS[g.name] = g
            v3_render.SHEET_NAMES = set(names)
            v3_render.render_v3(lookup, v3_groups, v3_singles, d)
            print("[v3 renders]", d)
        else:
            render_world(objs, os.path.join(d, "world_preview.png"), os.path.join(d, "world_top.png"))
            print("[preview]", os.path.join(d, "world_preview.png"), os.path.join(d, "world_top.png"))
            render_sheet(objs, sheet)
            print("[sheet]", sheet)


main()
