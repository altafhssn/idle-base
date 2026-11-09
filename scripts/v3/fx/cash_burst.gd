class_name CashBurst
extends Node3D
## J1 sale cash burst + J2 origin FX (spec section 6) + critic additions:
## a white square sparkle trail behind every bill and a single white motion
## streak on about 1 bill in 5.
##
## Bills are pooled 3D notes (ART model `banknote`, else a code-built green
## card). Their path is computed in SCREEN space and each frame they are
## placed with camera.project_position() a fixed distance in front of the
## camera, so they draw above the whole world, under every CanvasLayer (HUD,
## panels), and keep flying correctly while the camera pans or zooms.
## The 2D bits (glow puff, flash, sparkles, trail, streak) go on the FX
## "under HUD" CanvasLayer that Fx passes in.
##
## Depth: bills sit DEPTH metres in front of the near plane with depth test
## ON. Nothing in the world is that close to the camera (the rig sits 30 m
## back), so this is equivalent to no_depth_test + high render priority for
## world occlusion, while bills still occlude each other correctly (with
## no_depth_test a multi-surface glb could draw its back faces on top).
## Set BILLS_NO_DEPTH_TEST to true to force the literal spec behaviour.

const BILLS_NO_DEPTH_TEST := false
const MODEL_ID := "banknote"

const P1 := 0.35                 # phase 1: fan out (ease-out cubic)
const P2 := 0.70                 # phase 2: drift toward the HUD + shrink, hide
const END_SCALE := 0.08
## World width of a bill = 0.8 x character height (110 px at gameplay zoom).
const BILL_W := 0.8
const DEPTH := 2.5
const MAX_BILLS := 48

const TRAIL_EVERY := 0.035
const TRAIL_FROM := 0.03
const TRAIL_TO := 0.5
const TRAIL_LIFE := 0.2
const STREAK_CHANCE := 0.2
const STREAK_FROM := 0.04
const STREAK_TO := 0.30

## Under-HUD 2D particle pool (set by Fx before the first burst).
var particles: FxParticles2D
## Bill size multiplier (Fx sets world_fx_scale() x 1.4 before each burst so
## the notes keep the reference's ~150 px at gameplay zoom whatever s_game is).
var world_mult: float = 1.0
## Under-HUD node that owns the streak sprites (set by Fx).
var streak_parent: Node2D

var _pivots: Array[Node3D] = []
var _streaks: Array[Sprite2D] = []
var _base: Array[Basis] = []
var _alive := PackedByteArray()
var _has_streak := PackedByteArray()
var _age := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _size := PackedFloat32Array()
var _dz := PackedFloat32Array()
var _trail_t := PackedFloat32Array()
var _k := PackedFloat32Array()
var _s0 := PackedVector2Array()
var _s1 := PackedVector2Array()
var _s2 := PackedVector2Array()
var _cur := PackedVector2Array()
var _prev := PackedVector2Array()
var _axis := PackedVector3Array()
var _cursor: int = 0
var _live: int = 0

static var _fb_white: BoxMesh
static var _fb_green: BoxMesh
static var _fb_oval: CylinderMesh


func _init() -> void:
	name = "CashBurst"
	# After CameraRig (priority 100) so bills use this frame's camera.
	process_priority = 200


## Creates n pooled bills up front (avoids a hitch on the first sale).
func warm(n: int) -> void:
	while _pivots.size() < mini(n, MAX_BILLS):
		_add_slot()


## Fires one burst. origin = the paying traveller's chest in screen px,
## hud = the HUD cash icon in screen px, k = reference-px -> screen-px scale
## (includes the current camera zoom, see Fx.world_px_scale()).
func burst(origin: Vector2, hud: Vector2, k: float) -> void:
	if not is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	_origin_fx(origin, k)
	var n: int = 5
	var r: float = randf()
	if r < 0.2:
		n = 4
	elif r > 0.8:
		n = 6
	for b in n:
		var i: int = _take()
		if i < 0:
			break
		var s0: Vector2 = origin + Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0)) * k
		# Stratified fan, tight and slightly up-left (ref 36.8-37.2 / 110.1 s:
		# -125..-70 deg): the notes overlap into one tumbling bundle.
		var f: float = (float(b) + randf()) / float(n)
		var deg: float = lerpf(-122.0, -72.0, f)
		var s1: Vector2 = s0 + Vector2.from_angle(deg_to_rad(deg)) * (randf_range(250.0, 350.0) * k)
		var to_hud: Vector2 = hud - s1
		var d2: float = minf(to_hud.length(), randf_range(120.0, 200.0) * k)
		var s2: Vector2 = s1 + to_hud.normalized() * d2
		var ax := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if ax.length_squared() < 0.01:
			ax = Vector3.UP
		_alive[i] = 1
		_age[i] = 0.0
		_s0[i] = s0
		_s1[i] = s1
		_s2[i] = s2
		_cur[i] = s0
		_prev[i] = s0
		_axis[i] = ax.normalized()
		var spin_deg: float = randf_range(400.0, 800.0)
		_spin[i] = deg_to_rad(spin_deg) * (1.0 if randf() < 0.5 else -1.0)
		_base[i] = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		_size[i] = randf_range(0.92, 1.08)
		_dz[i] = float(b) * 0.06
		_trail_t[i] = TRAIL_FROM
		_k[i] = k
		_has_streak[i] = 1 if randf() < STREAK_CHANCE else 0
		_live += 1
		_place(i, cam, 0.0)
		_pivots[i].visible = true


func live_count() -> int:
	return _live


func _process(delta: float) -> void:
	if _live == 0:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in _pivots.size():
		if _alive[i] == 0:
			continue
		var t: float = _age[i] + delta
		_age[i] = t
		if t >= P2:
			_kill(i)
			continue
		_place(i, cam, t)
		var k: float = _k[i]
		# Sparkle trail: small white squares left behind the bill.
		if particles != null and t >= TRAIL_FROM and t <= TRAIL_TO:
			_trail_t[i] -= delta
			if _trail_t[i] <= 0.0:
				_trail_t[i] += TRAIL_EVERY
				var o: Vector2 = _prev[i] + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)) * k
				var sz: float = randf_range(4.0, 6.0) * k
				particles.emit(FxTex.white(), o, o + Vector2(0.0, 6.0 * k), TRAIL_LIFE, Color(1.0, 0.86, 0.35, 1.0),
						Vector2(sz, sz), Vector2(sz, sz) * 0.4, 0.95, 0.0, FxParticles2D.MOVE_OUT, 0.0, randf() * TAU)
		# Occasional single motion streak.
		if _has_streak[i] == 1:
			var sp: Sprite2D = _streaks[i]
			var v: Vector2 = _cur[i] - _prev[i]
			if t >= STREAK_FROM and t <= STREAK_TO and v.length_squared() > 0.25:
				var dir: Vector2 = v.normalized()
				var length: float = 80.0 * k
				sp.position = _cur[i] - dir * (length * 0.5 + 20.0 * k)
				sp.rotation = dir.angle()
				sp.scale = Vector2(length, 9.0 * k) / 64.0
				var a: float = 0.6 * (1.0 - (t - STREAK_FROM) / (STREAK_TO - STREAK_FROM))
				sp.modulate = Color(1.0, 1.0, 1.0, a)
				sp.visible = true
			else:
				sp.visible = false


func _place(i: int, cam: Camera3D, t: float) -> void:
	var p: Vector2
	var sc: float = 1.0
	if t < P1:
		p = _s0[i].lerp(_s1[i], FxMath.out_cubic(t / P1))
	else:
		var u: float = FxMath.in_quad((t - P1) / (P2 - P1))
		p = _s1[i].lerp(_s2[i], u)
		sc = lerpf(1.0, END_SCALE, u)
	_prev[i] = _cur[i]
	_cur[i] = p
	var pos: Vector3 = cam.project_position(p, cam.near + DEPTH + _dz[i])
	var b: Basis = Basis(_axis[i], _spin[i] * t) * _base[i]
	var s: float = sc * _size[i] * world_mult
	_pivots[i].global_transform = Transform3D(b.scaled(Vector3(s, s, s)), pos)


func _kill(i: int) -> void:
	_alive[i] = 0
	_pivots[i].visible = false
	_streaks[i].visible = false
	_live -= 1


func _take() -> int:
	var n: int = _pivots.size()
	for k in n:
		var i: int = (_cursor + k) % n
		if _alive[i] == 0:
			_cursor = (i + 1) % n
			return i
	if n < MAX_BILLS:
		_add_slot()
		return n
	return -1


func _add_slot() -> void:
	var pivot := Node3D.new()
	pivot.name = "Bill%d" % _pivots.size()
	var model: Node3D
	if Models.exists(MODEL_ID):
		model = Models.make(MODEL_ID)
	else:
		model = _fallback_card()
	pivot.add_child(model)
	FxModel.normalise(model, BILL_W)
	FxModel.no_shadows(model)
	if BILLS_NO_DEPTH_TEST:
		Models.overlay(model, 14)
	pivot.visible = false
	add_child(pivot)
	var sp := Sprite2D.new()
	sp.texture = FxTex.glow()
	sp.visible = false
	if streak_parent != null:
		streak_parent.add_child(sp)
	else:
		add_child(sp)
	_pivots.append(pivot)
	_streaks.append(sp)
	_base.append(Basis.IDENTITY)
	_alive.append(0)
	_has_streak.append(0)
	_age.append(0.0)
	_spin.append(0.0)
	_size.append(1.0)
	_dz.append(0.0)
	_trail_t.append(0.0)
	_k.append(1.0)
	_s0.append(Vector2.ZERO)
	_s1.append(Vector2.ZERO)
	_s2.append(Vector2.ZERO)
	_cur.append(Vector2.ZERO)
	_prev.append(Vector2.ZERO)
	_axis.append(Vector3.UP)


## J2: glow puff, faint rising column, 1-2 frame flash quad, 2-4 sparkles.
func _origin_fx(o: Vector2, k: float) -> void:
	if particles == null:
		return
	var glow: Texture2D = FxTex.glow()
	var white: Texture2D = FxTex.white()
	var d: float = randf_range(80.0, 100.0) * k
	particles.emit(glow, o, o, 0.15, Color(0.45, 0.9, 0.55), Vector2(d, d) * 0.6, Vector2(d, d) * 1.4,
			0.8, 0.03, FxParticles2D.MOVE_LINEAR)
	particles.emit(glow, o, o + Vector2(0.0, -40.0 * k), 0.3, Color(0.92, 1.0, 0.94),
			Vector2(28.0, 56.0) * k, Vector2(22.0, 84.0) * k, 0.35, 0.05, FxParticles2D.MOVE_OUT)
	particles.emit(white, o, o, 0.04, Color(0.749, 0.957, 1.0), Vector2(60.0, 18.0) * k, Vector2(60.0, 18.0) * k,
			0.9, 0.0, FxParticles2D.MOVE_LINEAR, 0.0, randf() * TAU)
	var count: int = randi_range(2, 4)
	for j in count:
		var sz: float = randf_range(5.0, 8.0) * k
		var p: Vector2 = o + Vector2(randf_range(-22.0, 22.0), randf_range(-14.0, 10.0)) * k
		var col: Color = Color(1.0, 1.0, 1.0) if randf() < 0.5 else Color(0.55, 0.92, 0.5)
		particles.emit(white, p, p + Vector2(0.0, -20.0 * k), 0.25, col, Vector2(sz, sz), Vector2(sz, sz) * 0.7,
				1.0, 0.0, FxParticles2D.MOVE_OUT, 0.0, randf() * 0.8)


## Code-built stand-in until the ART `banknote` glb exists: a 1.57:1 card,
## white border (6% of width), light green face, dark teal centre oval.
## Unit width; FxModel.normalise() sizes it.
static func _fallback_card() -> Node3D:
	if _fb_white == null:
		_fb_white = BoxMesh.new()
		_fb_white.size = Vector3(1.0, 0.04, 0.637)
		_fb_white.material = FxModel.mat(Color(0.96, 0.97, 0.94))
		_fb_green = BoxMesh.new()
		_fb_green.size = Vector3(0.88, 0.05, 0.517)
		_fb_green.material = FxModel.mat(Color(0.494, 0.827, 0.541))
		_fb_oval = CylinderMesh.new()
		_fb_oval.top_radius = 0.13
		_fb_oval.bottom_radius = 0.13
		_fb_oval.height = 0.056
		_fb_oval.radial_segments = 16
		_fb_oval.rings = 1
		_fb_oval.material = FxModel.mat(Color(0.122, 0.369, 0.29))
	var root := Node3D.new()
	root.name = "banknote_fallback"
	var a := MeshInstance3D.new()
	a.mesh = _fb_white
	root.add_child(a)
	var g := MeshInstance3D.new()
	g.mesh = _fb_green
	root.add_child(g)
	var o := MeshInstance3D.new()
	o.mesh = _fb_oval
	o.scale = Vector3(1.4, 1.0, 1.0)
	root.add_child(o)
	return root
