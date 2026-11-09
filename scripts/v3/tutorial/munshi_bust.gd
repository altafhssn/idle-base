class_name MunshiBust
extends Control
## Munshi-ji's waist-up 3D bust for the dialogue (spec J15 + critic notes).
##
## The ART models munshi_<pose>.glb (idle, cheer, worried, point, namaste,
## ledger) render in a transparent SubViewport with its own World3D; a
## TextureRect shows it, so the whole bust fades as ONE layer (the ref's
## per-material fade is an artefact we do not copy). All six poses are
## instanced once; a pose switch is a visibility toggle with a small hop.
##
## 2D layer (this Control): entrances / transitions move `enter_off`; the
## idle sway rolls 0 → 3.5° → 0 around a pivot below the box over 2.0 s with
## +7 px down-drift; the talk bob dips/leans while text types.
## 3D layer: head yaw ±8° (+2° roll) leading the body by 0.2 s, a dhaba
## head-wobble burst every few seconds, a talk nod, and the wave bob on
## `cheer` — each only when the model has a `head` / `arm_r` node.
## Until the ART glbs exist a small procedural Munshi-ji stands in.
## 2D art (4 Nov): when the narrator sprites exist (SPRITE_PATH, one per pose)
## they replace the 3D bust: no SubViewport, and the head wobble becomes a
## small tilt of the sprite; the 2D sway, bob and entrances are unchanged.
## 3D Rani (5 Nov): when her busts exist (MODEL_PREFIX + pose, built by
## tools/blender/v3_chars.py build_rani with Munshi-ji's nodes and pivots)
## they win over the 2D art and the old munshi_* glbs; the rig is the same.
##
## DialogueBox owns placement (layout_for) and fades `modulate` on dismiss.

signal pose_changed(pose: String)

const GfxQuality := preload("res://scripts/v3/core/gfx_quality.gd")
const POSES := ["idle", "cheer", "worried", "point", "namaste", "ledger"]
## 2D narrator art, cut from the owner's character sheet: one PNG per pose,
## each RECT-sized and drawn 1:1, head centre at _head_px(), hair top 58 px
## down, mirrored so the gestures reach towards screen centre.
static var SPRITE_PATH: String = ThemePack.textures_dir() + "narrator/narrator_%s.png"
## Rani's 3D busts: rani_<pose>.glb in the pack's models (Models.exists).
const MODEL_PREFIX := "rani_"
## Framing (fix 0.3.4: the old square 576 px view, fitted to the idle pose,
## was only ±0.81 m wide around the head, so the point / ledger / cheer arms
## were cut by the view's own edge in mid-screen: a flat white wedge with no
## hand). Now a fixed window in model space (metres; x from the head centre,
## y up from the waist), wide enough for every pose's hands (the point
## finger reaches x ≈ -1.1 m, the cheer ledger x ≈ +0.95 m) and drawn 1:1,
## PPM screen px per metre (head ~210 px wide, ref 150-180 of 576).
const PPM := 340.0
const WIN_X := Vector2(-1.25, 0.95)
const WIN_Y := Vector2(-0.05, 1.47)
const RECT := Vector2(748.0, 517.0)   # (WIN_X span, WIN_Y span) x PPM, whole px
## Model height that sits on the dialogue box top: mid-belly, so the box
## cuts the round jacket (buttons showing), not the kurta hem.
const CUT_Y := 0.1
## Camera: level at about eye height, CAM_DIST m away, with an off-axis
## frustum framing the window (no looking up at him from his belly).
const CAM_DIST := 5.5
const CAM_Y := 1.05
## Yaw that makes the exported glb face the camera (+Z). Use PI if it faces −Z.
const FACING_YAW := 0.0
## Slight turn toward screen centre (he stands right of centre); more turns
## the face into profile and the ear pencil out past the cheek.
const TURN_YAW := -0.12
## Head centre x as a fraction of the viewport width (ref ≈ 425/576).
const HEAD_X := 0.735
const PIVOT_BELOW := 260.0

const SWAY_PERIOD := 2.0
const SWAY_DEG := 3.5
const SWAY_DRIFT := 7.0
const HEAD_YAW_DEG := 8.0
const HEAD_ROLL_DEG := 2.0
const HEAD_LEAD := 0.2
const WOBBLE_DEG := 7.0
const WOBBLE_HZ := 3.2
const WOBBLE_TIME := 0.7
const TALK_PERIOD := 0.45
const TALK_DIP := 10.0
const TALK_LEAN := 8.0
const TALK_NOD_DEG := 7.0
const WAVE_DEG := 9.0
const WAVE_PERIOD := 1.05
const HOP_PX := 8.0
const HOP_TIME := 0.18
const CHAIN_STEP := 0.17
const ENTER_FROM := Vector2(175.0, 60.0)
const OVERSHOOT := 9.0

var rest_pos: Vector2 = Vector2.ZERO
var enter_off: Vector2 = Vector2.ZERO

var _vp: SubViewport
var _tex: TextureRect
var _cam: Camera3D
var _pivot: Node3D
var _models: Dictionary = {}       # pose -> Node3D
var _sprites: Dictionary = {}      # pose -> TextureRect (2D art)
var _two_d: bool = false
var _heads: Dictionary = {}        # pose -> Node3D or null
var _head_bases: Dictionary = {}   # pose -> Vector3
var _arms: Dictionary = {}         # pose -> Node3D or null
var _arm_bases: Dictionary = {}    # pose -> Vector3

var _pose: String = "idle"
var _cur_head: Node3D
var _cur_arm: Node3D
var _head_base: Vector3 = Vector3.ZERO
var _arm_base: Vector3 = Vector3.ZERO
var _t: float = 0.0
var _talking: bool = false
var _talk_t: float = 0.0
var _talk_k: float = 0.0
var _wob_t: float = -1.0
var _wob_next: float = 3.0
var _hop: float = 0.0
var _move_tw: Tween
var _pose_tw: Tween
## GRAPHICS LOW (GfxQuality): no MSAA, the 3D redrawn at most
## GfxQuality.BUST_LOW_HZ times a second (_redraw_t: game seconds since the
## last redraw).
var _low: bool = false
var _redraw_t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = RECT
	pivot_offset = Vector2(_head_px(), RECT.y + PIVOT_BELOW)
	_two_d = not has_rani_models() and ResourceLoader.exists(SPRITE_PATH % "idle")
	if _two_d:
		_build_sprites()
		visible = false
		modulate.a = 0.0
		set_process(false)
		return
	_vp = SubViewport.new()
	_vp.name = "BustView"
	_vp.size = Vector2i(RECT)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_tex = TextureRect.new()
	_tex.name = "BustTex"
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_world()
	visible = false
	modulate.a = 0.0
	set_process(false)


# ================================================================ placement
## Rest placement: head centred at HEAD_X of the width, model height CUT_Y
## on the dialogue box top; the lower body continues behind the box.
## `head_x` (screen px) overrides HEAD_X of the width; DialogueBox passes one
## that follows the box on wide windows.
func layout_for(box_top: float, vp: Vector2, head_x: float = -1.0) -> void:
	size = RECT
	pivot_offset = Vector2(_head_px(), RECT.y + PIVOT_BELOW)
	var hx := head_x if head_x >= 0.0 else vp.x * HEAD_X
	rest_pos = Vector2(hx - _head_px(), box_top - (WIN_Y.y - CUT_Y) * PPM)
	if not is_processing():
		position = rest_pos + enter_off


# ================================================================ public API
## Head centre x inside the rect, px.
func _head_px() -> float:
	return -WIN_X.x * PPM


func current_pose() -> String:
	return _pose


func set_pose(p: String) -> void:
	if _two_d:
		if not _sprites.has(p):
			p = "idle"
		for k in _sprites:
			(_sprites[k] as TextureRect).visible = (str(k) == p)
		_pose = p
		pose_changed.emit(p)
		return
	if not _models.has(p):
		p = "idle"
	for k in _models:
		(_models[k] as Node3D).visible = (str(k) == p)
	_pose = p
	_cur_head = _heads.get(p) as Node3D
	_cur_arm = _arms.get(p) as Node3D
	_head_base = _head_bases.get(p, Vector3.ZERO)
	_arm_base = _arm_bases.get(p, Vector3.ZERO)
	pose_changed.emit(p)


func set_talking(on: bool) -> void:
	if on and not _talking:
		_talk_t = 0.0
	_talking = on


## Starts rendering (call before any entrance). GRAPHICS LOW (GfxQuality):
## no MSAA and the 3D redrawn at most BUST_LOW_HZ times a second (_process:
## every frame at LOW's 30 fps cap, every 2nd frame at 60); the 2D sway, bob
## and entrances run every frame.
func activate() -> void:
	visible = true
	_low = GfxQuality.is_low()
	if _vp != null:
		_vp.msaa_3d = Viewport.MSAA_DISABLED if _low else Viewport.MSAA_2X
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE if _low else SubViewport.UPDATE_ALWAYS
	_redraw_t = 0.0
	set_process(true)


## Stops rendering and hides (after the dialogue group faded out).
func deactivate() -> void:
	_kill(_move_tw)
	_kill(_pose_tw)
	_talking = false
	_talk_k = 0.0
	visible = false
	modulate.a = 0.0
	enter_off = Vector2.ZERO
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	set_process(false)


## Entrance when the box opens (J15 +0.30 s):
##   right        fade 0.17 s (ease-out) while sliding from (+175, +60) px over
##                0.20 s (cubic out) with a 9 px x-overshoot
##   bottom       rise from below the box edge, 0.3 s back-out
##   bottom_right the same from the bottom-right (ad-deal line)
##   none         appear in place
## `chain` poses play first (0.17 s each), then `pose`, then `then_pose`.
func enter(kind: String, pose: String, chain: Array = [], then_pose: String = "", then_delay: float = 0.0) -> void:
	activate()
	_kill(_move_tw)
	var first: String = str(chain[0]) if not chain.is_empty() else pose
	set_pose(first)
	var rest: Array = chain.slice(1)
	var land := 0.2
	match kind:
		"none":
			enter_off = Vector2.ZERO
			modulate.a = 1.0
			land = 0.0
		"bottom", "bottom_right":
			var dx := 150.0 if kind == "bottom_right" else 0.0
			enter_off = Vector2(dx, RECT.y * 0.6)
			modulate.a = 0.0
			_move_tw = create_tween().set_parallel(true)
			_move_tw.tween_property(self, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_move_tw.tween_property(self, "enter_off", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			land = 0.3
		_:
			enter_off = ENTER_FROM
			modulate.a = 0.0
			_move_tw = create_tween().set_parallel(true)
			_move_tw.tween_property(self, "modulate:a", 1.0, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_move_tw.tween_property(self, "enter_off", Vector2(-OVERSHOOT, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_move_tw.chain().tween_property(self, "enter_off", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_schedule_poses(rest, pose, first != pose or not rest.is_empty(), land, then_pose, then_delay)


## Pose change between two lines of one session (J15 + critic):
##   swap        in-place switch with a small hop
##   crouch      drop ~15% of screen height (0.12 s), hold 0.15 s, spring back 0.13 s
##   dip         sink below the box edge in 0.1 s, pop back in 0.15 s
##   gesture     0.5 s chain of poses (e.g. hands up → chin → arms crossed)
##   fade_rise   fade out 0.1 s while the box empties, rise from the bottom
##               edge ~0.3 s later (critic's 39.1–39.6 transition)
##   slide_right fade out 0.1 s, then the `right` entrance
func transition(kind: String, pose: String, chain: Array = [], then_pose: String = "", then_delay: float = 0.0) -> void:
	activate()
	_kill(_move_tw)
	var first: String = str(chain[0]) if not chain.is_empty() else pose
	var rest: Array = chain.slice(1)
	var delay := 0.0
	match kind:
		"crouch":
			modulate.a = 1.0
			var drop := get_viewport_rect().size.y * 0.15
			_move_tw = create_tween()
			_move_tw.tween_property(self, "enter_off", Vector2(0.0, drop), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			_move_tw.tween_callback(_pose_pop.bind(first))
			_move_tw.tween_interval(0.15)
			_move_tw.tween_property(self, "enter_off", Vector2(0.0, -10.0), 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_move_tw.tween_property(self, "enter_off", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			delay = 0.4
		"dip":
			modulate.a = 1.0
			_move_tw = create_tween()
			_move_tw.tween_property(self, "enter_off", Vector2(0.0, RECT.y * 0.85), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_move_tw.tween_callback(_pose_pop.bind(first))
			_move_tw.tween_property(self, "enter_off", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay = 0.25
		"fade_rise":
			_move_tw = create_tween()
			_move_tw.tween_property(self, "modulate:a", 0.0, 0.1)
			_move_tw.tween_interval(0.2)
			_move_tw.tween_callback(_rise_prep.bind(first))
			_move_tw.tween_property(self, "modulate:a", 1.0, 0.12)
			_move_tw.parallel().tween_property(self, "enter_off", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay = 0.6
		"slide_right":
			_kill(_pose_tw)
			_move_tw = create_tween()
			_move_tw.tween_property(self, "modulate:a", 0.0, 0.1)
			_move_tw.tween_callback(enter.bind("right", pose, chain, then_pose, maxf(then_delay - 0.1, 0.0)))
			return
		"gesture":
			modulate.a = 1.0
			enter_off = Vector2.ZERO
			_pose_pop(first)
			delay = CHAIN_STEP
		_:
			modulate.a = 1.0
			_move_tw = create_tween()
			_move_tw.tween_property(self, "enter_off", Vector2(0.0, 18.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_move_tw.tween_callback(_pose_pop.bind(first))
			_move_tw.tween_property(self, "enter_off", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			delay = 0.1
	_schedule_poses(rest, pose, first != pose or not rest.is_empty(), delay, then_pose, then_delay)


# ================================================================ internals
func _rise_prep(p: String) -> void:
	enter_off = Vector2(0.0, RECT.y * 0.6)
	set_pose(p)


func _pose_pop(p: String) -> void:
	set_pose(p)
	_hop = 1.0


## Plays `chain`, then `final` (if needed), then `then_pose` at then_delay
## (measured from the line start).
func _schedule_poses(chain: Array, final: String, need_final: bool, start_delay: float, then_pose: String, then_delay: float) -> void:
	_kill(_pose_tw)
	if chain.is_empty() and not need_final and then_pose == "":
		return
	_pose_tw = create_tween()
	var elapsed := 0.0
	if start_delay > 0.0:
		_pose_tw.tween_interval(start_delay)
		elapsed += start_delay
	for p in chain:
		_pose_tw.tween_callback(_pose_pop.bind(str(p)))
		_pose_tw.tween_interval(CHAIN_STEP)
		elapsed += CHAIN_STEP
	if need_final or not chain.is_empty():
		_pose_tw.tween_callback(_pose_pop.bind(final))
	if then_pose != "":
		_pose_tw.tween_interval(maxf(then_delay - elapsed, 0.05))
		_pose_tw.tween_callback(_pose_pop.bind(then_pose))


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


func _process(delta: float) -> void:
	_t += delta
	if _low and _vp != null:
		# Time-based, so the bust animates the same at 30 or 60 fps. The 0.75
		# lets a slightly short frame at the cap still redraw.
		var every: float = 1.0 / GfxQuality.BUST_LOW_HZ
		_redraw_t += delta
		if _redraw_t >= every * 0.75:
			_redraw_t = minf(_redraw_t - every, every)
			if _redraw_t < 0.0:
				_redraw_t = 0.0
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Idle sway: seamless 2.0 s, roll 0 → 3.5° → 0 around the low pivot.
	var s := 0.5 - 0.5 * cos(TAU * _t / SWAY_PERIOD)
	rotation = deg_to_rad(SWAY_DEG) * s
	# Talk bob: dip over 0.15 s, return over 0.3 s, looping while typing.
	var tk := 0.0
	if _talking:
		_talk_t = fmod(_talk_t + delta, TALK_PERIOD)
		if _talk_t < 0.15:
			tk = _talk_t / 0.15
		else:
			tk = 1.0 - (_talk_t - 0.15) / (TALK_PERIOD - 0.15)
		tk = smoothstep(0.0, 1.0, tk)
	_talk_k = lerpf(_talk_k, tk, 1.0 - exp(-20.0 * delta))
	var hop_y := 0.0
	if _hop > 0.0:
		_hop = maxf(_hop - delta / HOP_TIME, 0.0)
		hop_y = -HOP_PX * sin(PI * (1.0 - _hop))
	position = rest_pos + enter_off + Vector2(-TALK_LEAN * _talk_k, SWAY_DRIFT * s + TALK_DIP * _talk_k + hop_y)
	# Head-wobble burst (the dhaba "haan-ji" tilt), every 3.5–6 s.
	var wob := 0.0
	if _pose != "worried":
		if _wob_t < 0.0:
			_wob_next -= delta
			if _wob_next <= 0.0:
				_wob_t = 0.0
		else:
			_wob_t += delta
			var u := _wob_t / WOBBLE_TIME
			if u >= 1.0:
				_wob_t = -1.0
				_wob_next = randf_range(3.5, 6.0)
			else:
				wob = deg_to_rad(WOBBLE_DEG) * sin(TAU * WOBBLE_HZ * _wob_t) * (1.0 - u)
	if _two_d:
		var spr := _sprites.get(_pose) as TextureRect
		if spr != null:
			spr.rotation = wob * 0.3
		return
	var ph := TAU * (_t + HEAD_LEAD) / SWAY_PERIOD
	if _cur_head != null:
		var yaw := deg_to_rad(HEAD_YAW_DEG) * sin(ph)
		var roll := deg_to_rad(HEAD_ROLL_DEG) * sin(ph) + wob
		_cur_head.rotation = _head_base + Vector3(deg_to_rad(TALK_NOD_DEG) * _talk_k, yaw, roll)
	else:
		_pivot.rotation = Vector3(0.0, FACING_YAW + TURN_YAW + deg_to_rad(3.0) * sin(ph), wob * 0.35)
	if _cur_arm != null:
		if _pose == "cheer":
			_cur_arm.rotation = _arm_base + Vector3(0.0, 0.0, deg_to_rad(WAVE_DEG) * sin(TAU * _t / WAVE_PERIOD))
		else:
			_cur_arm.rotation = _arm_base


# ================================================================ 2D art
## One TextureRect per pose, filling the rect 1:1; only the current one shows.
## Pivot on the dialogue box line, so the wobble tilts her from the waist.
func _build_sprites() -> void:
	for p in POSES:
		var pose: String = p
		if not ResourceLoader.exists(SPRITE_PATH % pose):
			continue
		var t := TextureRect.new()
		t.name = "Narrator_" + pose
		t.texture = load(SPRITE_PATH % pose) as Texture2D
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.size = RECT
		t.pivot_offset = Vector2(_head_px(), (WIN_Y.y - CUT_Y) * PPM)
		t.visible = (pose == "idle")
		add_child(t)
		_sprites[pose] = t
	set_pose("idle")


# ================================================================ 3D world
func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.5
	_cam = Camera3D.new()
	_cam.name = "BustCam"
	_cam.environment = env
	_vp.add_child(_cam)
	_cam.current = true
	# Key + rim kept below clipping: the cream kurta must still shade (at
	# 0.6 + 1.05 + 0.45 the sleeves burnt out to flat white shapes).
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, 25.0, 0.0)
	key.light_energy = 0.85
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 160.0, 0.0)
	rim.light_energy = 0.3
	_vp.add_child(rim)
	_pivot = Node3D.new()
	_pivot.name = "Munshi"
	_vp.add_child(_pivot)
	_pivot.rotation = Vector3(0.0, FACING_YAW + TURN_YAW, 0.0)
	for p in POSES:
		var pose: String = p
		var m := _make_pose(pose)
		_pivot.add_child(m)
		m.visible = (pose == "idle")
		_models[pose] = m
		var h := _find_part(m, ["head", "Head", "HEAD", "munshi_head"])
		_heads[pose] = h
		_head_bases[pose] = h.rotation if h != null else Vector3.ZERO
		var a := _find_part(m, ["arm_r", "arm_R", "ArmR", "arm.R"])
		_arms[pose] = a
		_arm_bases[pose] = a.rotation if a != null else Vector3.ZERO
	set_pose("idle")
	_fit_camera()


## True when Rani's 3D busts are in the build (the idle one decides).
static func has_rani_models() -> bool:
	return Models.exists(MODEL_PREFIX + "idle")


func _make_pose(pose: String) -> Node3D:
	var id := MODEL_PREFIX + pose
	if not Models.exists(id):
		id = "munshi_" + pose
	var m: Node3D
	if Models.exists(id):
		m = Models.make(id)
	else:
		m = _placeholder(pose)
	m.name = pose
	return m


func _find_part(root: Node, names: Array) -> Node3D:
	for n in names:
		var f := root.find_child(str(n), true, false)
		if f is Node3D:
			return f as Node3D
	return null


## Level camera at CAM_Y, CAM_DIST in front of the head; the off-axis
## frustum shows exactly WIN_X x WIN_Y at the model's depth (z = 0).
func _fit_camera() -> void:
	var cx := 0.0
	var h := _heads.get("idle") as Node3D
	if h != null:
		cx = h.global_position.x
	var near := 0.5
	var k := near / CAM_DIST
	var win := RECT / PPM
	var mid := Vector2(WIN_X.x + win.x * 0.5, WIN_Y.y - win.y * 0.5)
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.set_frustum(win.y * k, Vector2(mid.x, mid.y - CAM_Y) * k, near, CAM_DIST + 4.0)
	_cam.position = Vector3(cx, CAM_Y, CAM_DIST)
	_cam.rotation = Vector3.ZERO


# ================================================================ stand-in
## Procedural Munshi-ji until the ART glbs land: round build, cream kurta,
## maroon Nehru jacket, white Gandhi topi, thin moustache, red bahi-khata.
## Origin at the waist; ~1.5 m tall bust; faces +Z; parts named head / arm_r.
func _placeholder(pose: String) -> Node3D:
	var root := Node3D.new()
	var kurta := Color("#EFE6D2")
	var jacket := Color("#7A1F2B")
	var skin := Color("#C68A5A")
	var dark := Color("#2B1B12")
	var cap := Color("#F7F4EA")
	var khata := Color("#B3261E")
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.15
	root.add_child(_mesh(body, kurta, Vector3(0.0, 0.32, 0.0)))
	var jk := CylinderMesh.new()
	jk.top_radius = 0.38
	jk.bottom_radius = 0.43
	jk.height = 0.72
	root.add_child(_mesh(jk, jacket, Vector3(0.0, 0.33, 0.0)))
	var head := Node3D.new()
	head.name = "head"
	head.position = Vector3(0.0, 0.98, 0.0)
	root.add_child(head)
	var hs := SphereMesh.new()
	hs.radius = 0.26
	hs.height = 0.5
	head.add_child(_mesh(hs, skin, Vector3(0.0, 0.2, 0.0)))
	var topi := BoxMesh.new()
	topi.size = Vector3(0.4, 0.13, 0.24)
	head.add_child(_mesh(topi, cap, Vector3(0.0, 0.42, -0.02), Vector3(0.0, 0.0, 6.0)))
	var mo := BoxMesh.new()
	mo.size = Vector3(0.16, 0.025, 0.03)
	head.add_child(_mesh(mo, dark, Vector3(0.0, 0.13, 0.245)))
	var eye := SphereMesh.new()
	eye.radius = 0.03
	eye.height = 0.06
	head.add_child(_mesh(eye, dark, Vector3(-0.08, 0.24, 0.225)))
	head.add_child(_mesh(eye, dark, Vector3(0.08, 0.24, 0.225)))
	# Arms: pivots at the shoulders; arm_r is screen-left (his right).
	var rot_r := Vector3(0.0, 0.0, -12.0)
	var rot_l := Vector3(0.0, 0.0, 12.0)
	match pose:
		"cheer":
			rot_r = Vector3(0.0, 0.0, -150.0)
		"point":
			rot_r = Vector3(-80.0, 0.0, -25.0)
		"namaste":
			rot_r = Vector3(-62.0, 0.0, 28.0)
			rot_l = Vector3(-62.0, 0.0, -28.0)
		"worried":
			rot_r = Vector3(-20.0, 0.0, 160.0)
			rot_l = Vector3(-20.0, 0.0, -160.0)
		"ledger":
			rot_l = Vector3(-70.0, 0.0, -10.0)
	root.add_child(_arm("arm_r", Vector3(-0.42, 0.72, 0.0), rot_r, jacket, skin))
	root.add_child(_arm("arm_l", Vector3(0.42, 0.72, 0.0), rot_l, jacket, skin))
	var book := BoxMesh.new()
	book.size = Vector3(0.3, 0.38, 0.06)
	if pose == "ledger":
		root.add_child(_mesh(book, khata, Vector3(0.12, 0.5, 0.42), Vector3(-15.0, 0.0, 8.0)))
	else:
		root.add_child(_mesh(book, khata, Vector3(0.47, 0.22, 0.05), Vector3(0.0, 0.0, 6.0)))
	return root


func _arm(arm_name: String, at: Vector3, rot_deg: Vector3, sleeve: Color, skin: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = arm_name
	pivot.position = at
	pivot.rotation_degrees = rot_deg
	var cm := CapsuleMesh.new()
	cm.radius = 0.1
	cm.height = 0.6
	pivot.add_child(_mesh(cm, sleeve, Vector3(0.0, -0.27, 0.0)))
	var hand := SphereMesh.new()
	hand.radius = 0.09
	hand.height = 0.18
	pivot.add_child(_mesh(hand, skin, Vector3(0.0, -0.6, 0.0)))
	return pivot


func _mesh(mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
