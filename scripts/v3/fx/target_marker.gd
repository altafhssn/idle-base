class_name TargetMarker
extends Node3D
## J10 tutorial target marker: hovers over the target, its TIP level with
## the staff member's head (~1.05 m).
## Owner, 9 Nov ("change the arrow indicator", then "a different colour"):
## a chunky GREEN down arrow with a white sticker outline (was a spinning
## saffron pyramid that blended into the sandy yard). It is flat, so it
## always turns to face the camera instead of spinning.
## Pop-in scale 0 -> 1.1 -> 1.0 over 0.3 s (back ease-out, grows from the tip);
## idle bob +-8-10 px (sine, 0.9 s); exit scales to 0 over 0.45 s (ease-in
## quad), optionally after a delay.
## Uses the ART model `marker` when USE_GLB (normalised: x/z extent = SIDE),
## else the code-built arrow.

const MODEL_ID := "marker"
## The old ART glb (a squat pyramid); the code-built arrow is used.
const USE_GLB := false
## Top-face side (m). Corner-on, the screen width is SIDE x sqrt(2) = 1.05 m,
## 35% of the 2.97 m wide FOCUS view (6.44 m tall on the 576x1248 canvas).
const SIDE := 0.74
const HEIGHT := 1.0
## Tip height above the given world point (a floor point): staff head top.
const TIP_HEIGHT := 1.05
## +-9 px at tutorial zoom = 0.046 m of screen = 0.072 m of world height.
const BOB := 0.072
const BOB_PERIOD := 0.9
## The arrow (m; tip at the origin, pointing down): overall width, head
## height, shaft width and height, slab depth and the white outline's width.
const ARROW_W := 0.62
const HEAD_H := 0.42
const SHAFT_W := 0.28
const SHAFT_H := 0.42
const DEPTH := 0.16
const OUTLINE := 0.05
const POP_TIME := 0.3
const EXIT_TIME := 0.45

const FACE_COLOR := Color("2EBD4E")           # green
const SIDE_COLOR := Color("1E8C38")           # dark green
const OUTLINE_COLOR := Color("FFFDF6")        # white

const ST_HIDDEN := 0
const ST_SHOWN := 1
const ST_EXIT := 2

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 face_color : source_color = vec4(0.18, 0.74, 0.31, 1.0);
uniform vec4 side_color : source_color = vec4(0.12, 0.55, 0.22, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 0.99, 0.96, 1.0);

// COLOR.r picks the part: 1 = arrow face, 0.5 = arrow side, 0 = outline.
void fragment() {
	float k = COLOR.r;
	ALBEDO = k > 0.75 ? face_color.rgb : (k > 0.25 ? side_color.rgb : outline_color.rgb);
}
"""

var _spinner: Node3D
var _state: int = ST_HIDDEN
var _t: float = 0.0
var _clock: float = 0.0
var _scale: float = 0.0
var _exit_delay: float = 0.0
var _exit_from: float = 1.0

static var _mesh: ArrayMesh
static var _mat: ShaderMaterial


func _init() -> void:
	name = "TargetMarker"
	visible = false


func _ready() -> void:
	_build()


## Shows (or re-pops) the marker with its tip at world_pos.y + tip_height.
func show_at(world_pos: Vector3, tip_height: float = TIP_HEIGHT) -> void:
	_build()
	global_position = world_pos + Vector3(0.0, tip_height, 0.0)
	_state = ST_SHOWN
	_t = 0.0
	_scale = 0.0
	_spinner.scale = Vector3(0.001, 0.001, 0.001)
	visible = true


## Scales out over 0.45 s after `delay` seconds. No-op if not showing.
func hide_marker(delay: float = 0.0) -> void:
	if _state != ST_SHOWN:
		return
	_state = ST_EXIT
	_t = 0.0
	_exit_delay = maxf(delay, 0.0)
	_exit_from = maxf(_scale, 0.001)


## Hides at once, no animation.
func hide_now() -> void:
	_state = ST_HIDDEN
	visible = false


func is_showing() -> bool:
	return _state == ST_SHOWN


func _process(delta: float) -> void:
	if _state == ST_HIDDEN:
		return
	_t += delta
	_clock = fmod(_clock + delta, BOB_PERIOD * 100.0)
	var s: float = 1.0
	if _state == ST_SHOWN:
		if _t < POP_TIME:
			s = FxMath.out_back(_t / POP_TIME)
	else:
		var u: float = (_t - _exit_delay) / EXIT_TIME
		if u >= 1.0:
			_state = ST_HIDDEN
			visible = false
			return
		s = _exit_from
		if u > 0.0:
			s = _exit_from * (1.0 - FxMath.in_quad(u))
	_scale = s
	var sv: float = maxf(s, 0.001)
	_spinner.scale = Vector3(sv, sv, sv)
	_spinner.position = Vector3(0.0, sin(TAU * _clock / BOB_PERIOD) * BOB, 0.0)
	# Face the camera (flat arrow): turn about Y toward it.
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var d: Vector3 = cam.global_position - global_position
		_spinner.rotation = Vector3(0.0, atan2(d.x, d.z), 0.0)


func _build() -> void:
	if _spinner != null:
		return
	_spinner = Node3D.new()
	_spinner.name = "Spinner"
	add_child(_spinner)
	if USE_GLB and Models.exists(MODEL_ID):
		var model: Node3D = Models.make(MODEL_ID)
		_spinner.add_child(model)
		FxModel.normalise_width(model, SIDE, Vector3(0.5, 0.0, 0.5))
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _arrow()
		mi.material_override = _material()
		_spinner.add_child(mi)
	FxModel.no_shadows(_spinner)


static func _material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = SHADER_CODE
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("face_color", FACE_COLOR)
		_mat.set_shader_parameter("side_color", SIDE_COLOR)
		_mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
	return _mat


## The arrow outline in its own plane (x right, y up), tip at the origin.
static func _arrow_pts() -> PackedVector2Array:
	var w: float = ARROW_W * 0.5
	var sw: float = SHAFT_W * 0.5
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, HEAD_H), Vector2(sw, HEAD_H), Vector2(sw, HEAD_H + SHAFT_H),
			Vector2(-sw, HEAD_H + SHAFT_H), Vector2(-sw, HEAD_H), Vector2(-w, HEAD_H)])


## `pts` grown outward by `d` (mitred corners).
static func _grow(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n: int = pts.size()
	var area: float = 0.0
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var sgn: float = 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in n:
		var p0: Vector2 = pts[(i - 1 + n) % n]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % n]
		var n0: Vector2 = (p1 - p0).normalized()
		n0 = Vector2(n0.y, -n0.x) * sgn
		var n1: Vector2 = (p2 - p1).normalized()
		n1 = Vector2(n1.y, -n1.x) * sgn
		var m: Vector2 = n0 + n1
		m = m / maxf(m.dot(n0), 0.35)
		out.append(p1 + m * d)
	return out


## The chunky arrow: a slab DEPTH thick (front face toward +Z), its sides,
## and a white outline slab OUTLINE wider sitting just behind it. COLOR.r
## tells the shader which part a triangle is.
static func _arrow() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = _arrow_pts()
	_slab(st, pts, -DEPTH * 0.5, DEPTH * 0.5, 1.0, 0.5)
	_slab(st, _grow(pts, OUTLINE), -DEPTH * 0.53, DEPTH * 0.37, 0.0, 0.0)
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


## One extruded arrow polygon from z0 (back) to z1 (front): the head triangle
## (points 0, 1, 6) and the shaft quad (2, 3, 4, 5) on both faces, plus a
## side quad per edge.
static func _slab(st: SurfaceTool, p: PackedVector2Array, z0: float, z1: float, face_k: float, side_k: float) -> void:
	var tris: Array = [[0, 1, 6], [2, 3, 4], [2, 4, 5]]
	for t in tris:
		var a: Vector2 = p[t[0]]
		var b: Vector2 = p[t[1]]
		var c: Vector2 = p[t[2]]
		_tri(st, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(c.x, c.y, z1), Vector3(a.x, a.y, z1 - 1.0), face_k)
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(c.x, c.y, z0), Vector3(a.x, a.y, z0 + 1.0), face_k)
	var n: int = p.size()
	for i in n:
		var a: Vector2 = p[i]
		var b: Vector2 = p[(i + 1) % n]
		var e: Vector2 = (b - a).normalized()
		var mid := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
		# The polygon runs counter-clockwise: the inside is to the left of each edge.
		var inner2: Vector2 = mid + Vector2(-e.y, e.x) * 0.05
		var inner := Vector3(inner2.x, inner2.y, (z0 + z1) * 0.5)
		var fa := Vector3(a.x, a.y, z1)
		var fb := Vector3(b.x, b.y, z1)
		var ba := Vector3(a.x, a.y, z0)
		var bb := Vector3(b.x, b.y, z0)
		_tri(st, fa, fb, bb, inner, side_k)
		_tri(st, fa, bb, ba, inner, side_k)


## Adds one triangle wound so its front faces away from `inner` (a point on
## the inside), with vertex colour (k, 0, 0).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inner: Vector3, k: float) -> void:
	var nrm: Vector3 = (c - a).cross(b - a)
	var centroid: Vector3 = (a + b + c) / 3.0
	if nrm.dot(centroid - inner) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
	var col := Color(k, 0.0, 0.0)
	for v in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)
