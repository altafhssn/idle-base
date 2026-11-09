"""Dhaba Rush v0.3 art helpers shared by the v3_* builder modules.

Loaded by build_assets.py with importlib (by path). build_assets injects its own globals
(Asset, the palette constants, B, mat4, ...) into this module before anything runs, so the
names below resolve at call time.

Multi-part models (characters, Munshi-ji, the cow) are built as one Asset per named part.
Every part gets its own Blender object whose origin is the part's pivot (joint); the parts
are exported together as top-level nodes of one .glb, so in Godot:

    model = Models.make("pinky")          # root Node3D, origin at the feet
    model.get_node("arm_l")               # MeshInstance3D, origin at the left shoulder

Pivots are given in Blender model space (x right, -y = Godot +Z forward, z up).
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector


class Group:
    """A finished multi-part model: `objs[i]` is part `names[i]` (object named
    '<model>__<part>' in Blender; exported as '<part>'). `extras` are empty nodes
    (sockets) exported next to the parts: list of (node name, Blender location)."""

    def __init__(self, name, names, objs, smooth):
        self.name = name
        self.names = names
        self.objs = objs
        self.smooth = smooth
        self.display = None          # merged single-mesh copy for review renders
        self.extras = []
        self.kind = "parts"          # "parts" (characters) or "fairy" (light strings)

    def tris(self):
        return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.objs)


class Parts:
    """Builder for a multi-part model. parts[p] is an Asset in MODEL space; finish()
    moves each part's geometry so its origin is the pivot."""

    def __init__(self, name, pivots):
        self.name = name
        self.order = list(pivots.keys())
        self.pivots = {k: Vector(v) for k, v in pivots.items()}
        self.parts = {k: Asset(name + "__" + k) for k in self.order}

    def __getitem__(self, k):
        return self.parts[k]

    def finish(self, mat, smooth=40):
        objs = []
        for k in self.order:
            a = self.parts[k]
            piv = self.pivots[k]
            if a.bm.verts:
                bmesh.ops.translate(a.bm, vec=-piv, verts=list(a.bm.verts))
            o = a.finish(mat, smooth)
            o.location = piv
            objs.append(o)
        return Group(self.name, list(self.order), objs, smooth)


def export_group(g, outdir):
    """Exports the parts of `g` as top-level nodes named after the parts (plus the
    socket empties in g.extras).

    g.extras items are (name, Blender location) or (name, location, Blender Euler radians):
    a socket can carry a rotation (seats_board's text_socket lies in the tilted face).
    g.parents (optional, core-and-feel 2026-11-01) maps a part or socket name to the name of
    another part or socket: that node is exported as its child instead of top level
    (hoarding_l3 is an empty whose child mesh is fairy_bulb_hoarding). Parents are expected
    at the model origin with no rotation, so a child keeps its model-space transform."""
    bpy.ops.object.select_all(action="DESELECT")
    for o, n in zip(g.objs, g.names):
        o.name = n
    for o in g.objs:
        o.select_set(True)
    empties = []
    for ex in g.extras:
        n, loc = ex[0], ex[1]
        e = bpy.data.objects.new(n, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.1
        e.location = Vector(loc)
        if len(ex) > 2 and ex[2] is not None:
            e.rotation_euler = ex[2]
        bpy.context.scene.collection.objects.link(e)
        e.select_set(True)
        empties.append(e)
    by_name = dict(zip(g.names, g.objs))
    by_name.update({e.name: e for e in empties})
    parented = []
    for child, parent in getattr(g, "parents", {}).items():
        c, p = by_name.get(child), by_name.get(parent)
        if c is None or p is None:
            continue
        bpy.context.view_layer.update()
        mw = c.matrix_world.copy()
        c.parent = p
        c.matrix_parent_inverse = p.matrix_world.inverted()
        c.matrix_world = mw
        parented.append(c)
    bpy.context.view_layer.objects.active = g.objs[0]
    path = os.path.join(outdir, g.name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_draco_mesh_compression_enable=False, export_animations=False,
        export_cameras=False, export_lights=False, export_vertex_color="ACTIVE",
    )
    for c in parented:
        if c in empties:
            continue                 # a socket under a part: removed with the other empties
        mw = c.matrix_world.copy()
        c.parent = None
        c.matrix_world = mw
    for e in empties:
        bpy.data.objects.remove(e, do_unlink=True)
    for o, n in zip(g.objs, g.names):
        o.name = g.name + "__" + n
    return path


# ------------------------------------------------------------------ baked text
_FONTS = {}


def _font(fname="Baloo2.ttf"):
    if fname not in _FONTS:
        p = os.path.join(_HERE, "..", "..", "assets", "fonts", fname)
        f = None
        if os.path.exists(p):
            try:
                f = bpy.data.fonts.load(p, check_existing=True)
            except RuntimeError:
                f = None
        _FONTS[fname] = f
    return _FONTS[fname]


def flower(a, p, r, color):
    """10-tri bead (pentagonal bipyramid) for marigolds, stones, beads (Blender coords)."""
    return a.ball(r, p, color, seg=5, rings=2)


def text_geo(a, text, centre, right, up, w, h, color, bold=0.03, res=None, spacing=1.0,
             font="Baloo2.ttf", lift=0.0):
    """Bakes `text` (Latin only: Blender does not shape Devanagari) as flat geometry into
    Asset `a`, fitted (uniform scale) into a w x h box centred at `centre` in the plane
    spanned by the unit Godot vectors `right` and `up`; it faces right x up. All args in
    Godot space. Returns the (width, height) actually used."""
    if res is None:                       # ~30 tris/glyph at res 1, ~50 at res 2
        res = 2 if h >= 0.25 else 1
    cu = bpy.data.curves.new("txt_tmp", "FONT")
    cu.body = text
    f = _font(font)
    if f is not None:
        cu.font = f
    cu.size = 1.0
    cu.align_x = "CENTER"
    cu.resolution_u = res
    cu.offset = bold
    cu.space_character = spacing
    cu.space_line = 0.85
    ob = bpy.data.objects.new("txt_tmp", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    vs = [v.co.copy() for v in me.vertices]
    polys = [list(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.curves.remove(cu)
    if not vs:
        return (0.0, 0.0)
    x0, x1 = min(v.x for v in vs), max(v.x for v in vs)
    y0, y1 = min(v.y for v in vs), max(v.y for v in vs)
    bw, bh = max(x1 - x0, 1e-4), max(y1 - y0, 1e-4)
    s = min(w / bw, h / bh)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    R = Vector(B(*right)).normalized()
    U = Vector(B(*up)).normalized()
    N = R.cross(U).normalized()
    C = Vector(B(*centre)) + N * lift
    bv = [a.bm.verts.new(C + R * ((v.x - cx) * s) + U * ((v.y - cy) * s)) for v in vs]
    uv = swatch_uv(color)
    for p in polys:
        try:
            fc = a.bm.faces.new([bv[i] for i in p])
        except ValueError:
            continue
        fc.normal_update()
        if fc.normal.dot(N) < 0:
            fc.normal_flip()
        for loop in fc.loops:
            loop[a.uv].uv = uv
    return (bw * s, bh * s)


# ------------------------------------------------------------------ fairy lights
# Linear RGB of the bulb colours: warm white, marigold, red, green, blue, pink.
FAIRY_WARM, FAIRY_MARIGOLD, FAIRY_RED, FAIRY_GREEN, FAIRY_BLUE, FAIRY_PINK = (
    (1.0, 0.82, 0.5), (1.0, 0.5, 0.06), (1.0, 0.12, 0.08), (0.2, 0.92, 0.28), (0.22, 0.48, 1.0),
    (1.0, 0.3, 0.68))
FAIRY_MIX = (FAIRY_WARM, FAIRY_MARIGOLD, FAIRY_RED, FAIRY_GREEN, FAIRY_BLUE, FAIRY_PINK)
FAIRY_GOLDS = (FAIRY_WARM, FAIRY_MARIGOLD, FAIRY_WARM, FAIRY_MARIGOLD, FAIRY_RED)


def gsag(p0, p1, s, n):
    """n+1 Godot points of a string hanging from p0 to p1 (Godot) with sag s."""
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(Vector((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t - s * 4 * t * (1 - t),
                           p0[2] + (p1[2] - p0[2]) * t)))
    return out


def resample(poly, spacing, start=0.5):
    """Points every `spacing` metres along a Godot polyline (first one at start*spacing)."""
    pts = [Vector(p) for p in poly]
    out = []
    d = spacing * start
    acc = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        L = (b - a).length
        while d <= acc + L + 1e-6 and L > 1e-6:
            out.append(a.lerp(b, (d - acc) / L))
            d += spacing
        acc += L
    return out


_FAIRY_MAT = []


def fairy_material():
    """Unlit material for the bulbs: exported as KHR_materials_unlit, colour = COLOR_0, so
    Godot's importer gives an UNSHADED StandardMaterial3D with albedo-from-vertex-colour
    (bulbs show their colours with no code). The twinkle needs the shader
    res://themes/dhaba/models/fairy_bulb.gdshader (see docs in v3_exterior.py)."""
    if not _FAIRY_MAT:
        m = bpy.data.materials.new("fairy_bulb")
        ensure_nodes(m)
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
        bg = nt.nodes.new("ShaderNodeBackground")
        ca = nt.nodes.new("ShaderNodeVertexColor")
        ca.layer_name = "Color"
        nt.links.new(ca.outputs["Color"], bg.inputs["Color"])
        nt.links.new(bg.outputs[0], out.inputs["Surface"])
        _FAIRY_MAT.append(m)
    return _FAIRY_MAT[0]


class FairySet:
    """Fairy-light strings of one area, exported as extra nodes of a WORLD-COORD glb:
      fairy_bulb_<key>   one mesh node per string key (strings added with the same key are
                         merged): its bulbs (12-tri beads) with the unlit `fairy_bulb`
                         material and a per-vertex COLOR_0 (RGBA16 unorm in the glb):
                           rgb = bulb colour (linear),
                           a   = animation code: a < 0.5 -> twinkle, phase = 2a (random);
                                 a >= 0.5 -> chase, step = 4 * (2a - 1) in 0..3 along the string
      fairy_wire_<name>  the dark wires of every string of the area (palette mesh)."""

    def __init__(self, name, seed=5):
        self.name = name
        self.rng = random.Random(seed)
        self.wire = Asset("fairy_wire_" + name)
        self.strings = []
        self.count = 0

    def string(self, key, poly, spacing=0.32, r=0.05, colors=FAIRY_MIX, chase=False, wire=True,
               wire_r=0.006, drop=0.0, start=0.5):
        """poly: Godot polyline the wire follows; bulbs every `spacing` m hang `drop` below it."""
        if wire:
            for i in range(len(poly) - 1):
                p0, p1 = Vector(B(*poly[i])), Vector(B(*poly[i + 1]))
                if (p1 - p0).length > 1e-4:
                    self.wire.tube(p0, p1, wire_r, DARK_GREEN, seg=3, caps=False)
        pts = resample(poly, spacing, start)
        k0 = self.rng.randrange(len(colors))
        bulbs = []
        for i, p in enumerate(pts):
            col = colors[(k0 + i) % len(colors)]
            if chase:
                code = 0.5 + 0.5 * ((i % 4) / 4.0)
            else:
                code = self.rng.uniform(0.0, 0.497)
            bulbs.append((Vector((p.x, p.y - drop, p.z)), col, code))
        self.strings.append((key, bulbs, r))
        self.count += len(bulbs)
        return len(bulbs)

    def parts(self, mat):
        """(names, objects) of the bulb meshes + the wire mesh."""
        merged = {}
        for (key, bulbs, r) in self.strings:
            merged.setdefault(key, []).extend((p, col, code, r) for (p, col, code) in bulbs)
        names, objs = [], []
        bulb_mat = fairy_material()
        for key, bulbs in merged.items():
            a = Asset(self.name + "__fairy_bulb_" + key)
            cl = a.bm.verts.layers.float_color.new("Color")
            for (p, col, code, r) in bulbs:
                # 12-tri bead; colour exactly the verts the op returns (bmesh reuses freed slots,
                # so index ranges are not safe)
                res = bmesh.ops.create_uvsphere(a.bm, u_segments=6, v_segments=2, radius=r,
                                                matrix=Matrix.Translation(Vector(B(p.x, p.y, p.z))))
                a._paint(res["verts"], WHITE)
                for v in res["verts"]:
                    v[cl] = (col[0], col[1], col[2], code)
            o = a.finish(bulb_mat)
            try:
                o.data.color_attributes.active_color_name = "Color"
            except (AttributeError, TypeError):
                try:
                    o.data.color_attributes.active_color = o.data.color_attributes["Color"]
                except Exception:
                    pass
            try:
                o.data.color_attributes.render_color_index = 0
            except Exception:
                pass
            names.append("fairy_bulb_" + key)
            objs.append(o)
        if self.wire.bm.verts:
            w = self.wire.finish(mat, 30)
            names.append("fairy_wire_" + self.name)
            objs.append(w)
        return names, objs

    def finish(self, mat):
        names, objs = self.parts(mat)
        g = Group(self.name, names, objs, 30)
        g.kind = "fairy"
        return g


def merge_objects(name, objs, mat, smooth=None):
    """Single-mesh copy of several objects (world transforms applied) for renders."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for o in objs:
        me = o.data
        mw = o.matrix_basis.copy()
        uvd = me.uv_layers.active.data
        vmap = [bm.verts.new(mw @ v.co) for v in me.vertices]
        for p in me.polygons:
            try:
                f = bm.faces.new([vmap[i] for i in p.vertices])
            except ValueError:
                continue
            for loop, li in zip(f.loops, p.loop_indices):
                loop[uvl].uv = uvd[li].uv
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = smooth is not None
    if smooth is not None:
        mesh.set_sharp_from_angle(angle=math.radians(smooth))
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ------------------------------------------------------------------ orientation helpers
def frame(x_dir, z_hint=(0, 0, 1)):
    """3x3 matrix whose columns are an orthonormal frame: X along x_dir, Z as close to
    z_hint as possible."""
    x = Vector(x_dir).normalized()
    z = Vector(z_hint)
    z = (z - x * z.dot(x))
    if z.length < 1e-5:
        z = Vector((0, 1, 0)) if abs(x.z) > 0.9 else Vector((0, 0, 1))
        z = (z - x * z.dot(x))
    z.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()




def limb(a, pts, radii, color, seg=10, joint_seg=10, joint_rings=6, end_ball=False):
    """Chain of tapered tubes through pts with a ball at every inner joint (and
    optionally at the ends) so bends stay closed."""
    for i in range(len(pts) - 1):
        a.tube(pts[i], pts[i + 1], radii[i], color, r1=radii[i + 1], seg=seg, caps=False)
    rng = range(len(pts)) if end_ball else range(1, len(pts) - 1)
    for i in rng:
        a.ball(radii[i], pts[i], color, seg=joint_seg, rings=joint_rings)
    return a




def disc(a, centre, r, color, n=10, facing="-y", rot=0.0):
    """Flat n-gon facing an axis (like decal(), but round)."""
    cx, cy, cz = centre
    pts = []
    for k in range(n):
        t = rot + 2 * math.pi * k / n
        u, v = r * math.cos(t), r * math.sin(t)
        if facing == "-y":
            pts.append((cx + u, cy, cz + v))
        elif facing == "+y":
            pts.append((cx - u, cy, cz + v))
        elif facing == "+x":
            pts.append((cx, cy + u, cz + v))
        elif facing == "-x":
            pts.append((cx, cy - u, cz + v))
        else:
            pts.append((cx + u, cy + v, cz))
    return a.face(pts, color, normal=_FACING[facing])
