class_name CharacterRig
extends Node3D
## Procedural animation for the v0.3 character glbs (no AnimationPlayer).
## ART exports every character with separate nodes named body, head, arm_l,
## arm_r, leg_l, leg_r (pivots at the joints, origin at the feet, facing +Z).
## This rig gives them: a 0.48 s walk cycle (legs / arms swing, step bob,
## side sway), a small idle breathe, snap turns (45 ms), a few poses and a
## blob shadow (0.55 x height, 35 % black, unshaded). A model without those
## parts (old single-mesh glb or the Models fallback box) still bobs and sways
## as one piece.
##
## The rig is a child of the character node: the owner moves the owner node,
## the rig only handles yaw (face / set_yaw) and the limbs.
##
## API: setup(model_id, height), walk(on), face(dir), face_yaw(yaw),
##      set_yaw(yaw), play(pose) with pose "idle" | "serve" | "pay" | "turn90"
##      | "sit" | "eat" | "carry" | "sad" | "sip" | "phone" | "doze" | "look"
##      | "slap", set_sit_height(seat_top_y), find_socket(name).
## Seated-dhaba poses (2026-10-19): "sit" lifts the model onto a charpai (the
## chibi's hips are lower than the seat) and swings the legs forward; "eat" is
## "sit" plus a munch loop (right hand to the mouth, chewing nod); "carry"
## holds both forearms out under a tray (no arm swing while walking); "sad"
## drops the head (the traveller who found no seat).
## Core-and-feel C6.6 (seated idles while waiting for food; all seated, like
## "sit"): "sip" raises the right hand to the mouth with the steel water
## tumbler a dhaba puts down when you sit (a code CylinderMesh on arm_r),
## "phone" holds a small dark phone up in front of the face (arm_r ~ -2.0,
## head bowed to it), "doze" droops the head (SAD_HEAD) with a slow nod,
## "look" turns the head +-0.5 rad to look about. C8.1: "slap" (the tandoor
## cook) leans in and thrusts the right arm at the drum every SLAP_PERIOD s,
## the first thrust at once (the tandoor_slap sound plays as a ticket starts).

const WALK_CYCLE := 0.48          # s per full stride (left + right step)
const TURN_TIME := 0.045          # snap turn, ref 35-50 ms
const LEG_SWING := 0.5            # rad
const ARM_SWING := 0.42           # rad
const BOB := 0.026                # x height: ~2 px step bob at follow zoom
const SWAY := 0.022               # x height: ~3.5 px side sway at follow zoom
const ROLL := 0.05                # rad body roll while walking
const WALK_BLEND := 0.08          # s to blend in / out of the walk
const POSE_K := 16.0              # arm pose blend speed (1/s)
const BREATHE_PERIOD := 2.2       # s
const SHADOW_QUAD := 0.62         # quad size x height (the visible blob is ~0.55 x height)
const SHADOW_ALPHA := 0.35
const TURN90_HOLD := 0.4          # s the clerk stays turned before turning back
const HIP_FRAC := 0.29            # hip pivot height / model height (ART: 0.30 s of a 1.03 s chibi)
const SIT_LEG := -1.35            # rad: legs swung forward while seated
const SIT_BLEND := 0.22           # s to sit down / stand up
const CARRY_ARM := -1.2           # rad: forearms out under the tray (ART tray_socket assumes ~-1.2)
const MUNCH_PERIOD := 1.05        # s per bite
const SAD_HEAD := 0.38            # rad head droop
## Seated idles (C6.6) and the roti slap (C8.1).
const SEATED_POSES := ["sit", "eat", "sip", "phone", "doze", "look"]
const SIP_ARM := -1.95            # rad: tumbler at the mouth
const PHONE_ARM := -2.0           # rad: phone up in front of the face
const PHONE_HEAD := 0.24          # rad: head bowed to the phone
const DOZE_NOD := 0.07            # rad slow nod while dozing
const DOZE_PERIOD := 2.6          # s per nod
const LOOK_YAW := 0.5             # rad head turn either way
const LOOK_PERIOD := 2.6          # s per look left and right
const SLAP_PERIOD := 1.2          # s between two slaps
const SLAP_LEAN := 0.2            # rad body lean toward the drum
const SLAP_ARM_REST := -0.7       # rad: right forearm out over the drum
const SLAP_ARM_HIT := -1.55       # rad: arm thrust at the drum wall
## Hand position on arm_r (x height, below the shoulder pivot) for the props.
const HAND_DROP := 0.24
## Art audit (4 Nov): idle staff glance about now and then and shift their
## weight (C5); the stride follows the walk speed (C7).
const GLANCE_S := 1.8              # s per glance (left, then right)
const GLANCE_YAW := 0.45           # rad
const GLANCE_GAP := Vector2(6.0, 12.0)  # s between glances
const SHIFT := 0.012               # x height: idle weight shift
const SHIFT_PERIOD := 4.5          # s
const STRIDE_REF_SPEED := 1.9      # m/s walked at WALK_CYCLE
## Height (m) per model id; speed and shadow scale with it.
const HEIGHTS := {
	"trav_trucker": 1.12, "trav_family_m": 1.08, "trav_family_f": 1.0,
	"trav_biker": 1.06, "trav_student": 0.98,
	"pinky": 1.0, "munna": 1.05, "bablu": 1.0, "tandoor_wala": 1.08,
	"customer_a": 1.0, "customer_b": 1.0, "customer_c": 1.05, "customer_d": 0.95,
	"raju": 1.05, "pappu": 1.03, "sonu": 1.04,
	"lassi_wala": 1.06, "bhurji_wala": 1.04, "dal_wala": 1.0,
	# menu-expansion helpers (QA round 2): the lassi's 2nd / 3rd cook and the
	# kadai's 3rd (station menus: Shera / Kamla / Kallu cook at the kadai;
	# tinku, chhotu and rani are retired with the bhurji / dal stations)
	"neetu": 0.99, "bittu": 1.04, "kallu": 1.06,
	# core-and-feel (build plan 4.2; chotu dropped, C8.4; sonu and bittu
	# rebuilt as adults at scale 1.0): fans (C3.5), baraat guests (C6.4),
	# waiters 3 and 4 (Lakhan, Gopal), the tandoor cook Balwant (C8.1)
	"trav_elder": 1.02, "trav_sardar": 1.12, "trav_farmer": 1.05, "trav_techie": 1.01,
	"trav_baraati_m": 1.08, "trav_baraati_f": 1.0,
	"gopal": 1.05, "lakhan": 1.06, "balwant": 1.1,
	# the chai cart's waiter (9 Nov; a lad of about 18 at Raju's height, so
	# waiter 1 walks at the same speed on the cart as in the shack)
	"chhotu": 1.05,
}
const DEFAULT_HEIGHT := 1.05

static var _shadow_mesh: PlaneMesh = null
static var _shadow_mat: StandardMaterial3D = null
static var _exists: Dictionary = {}
static var _tumbler_mesh: Mesh = null
static var _phone_mesh: Mesh = null

var model: Node3D = null
var model_id: String = ""
var height: float = 1.0
## Idle breathe / sway strength (staff use ~0.5: "staff idle sway is small").
var idle_amount: float = 1.0
## Walk speed (m/s) for the stride: > 0 scales the cycle so faster walkers
## step faster (art audit C7). 0 = WALK_CYCLE.
var stride_speed: float = 0.0
## Leg swing multiplier (waiters 1.3: a longer stride).
var leg_swing_mult: float = 1.0
## Idle staff glance about and shift their weight (art audit C5).
var idle_glance: bool = false
## Top of the model (m) measured from its meshes at setup (art audit C8).
var visual_height: float = 0.0
var _glance_rng := RandomNumberGenerator.new()
var _glance_at: float = 0.0
var _glance_left: float = 0.0
## How far the model rises while seated (set_sit_height computes it).
var sit_lift: float = 0.14

var _body: Node3D = null
var _head: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _rest_body: Vector3 = Vector3.ZERO
var _rest_head: Vector3 = Vector3.ZERO
var _rest_arm_l: Vector3 = Vector3.ZERO
var _rest_arm_r: Vector3 = Vector3.ZERO
var _rest_leg_l: Vector3 = Vector3.ZERO
var _rest_leg_r: Vector3 = Vector3.ZERO
var _rest_model: Vector3 = Vector3.ZERO

var _walking: bool = false
var _walk_w: float = 0.0
var _phase: float = 0.0
var _t: float = 0.0
var _pose: String = "idle"
var _arm_l_off: float = 0.0
var _arm_r_off: float = 0.0
var _yaw: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _turn_u: float = 1.0          # 0..1 progress of the current snap turn
var _turn90_left: float = 0.0
var _turn90_home: float = 0.0
var _shadow: MeshInstance3D = null
var _sit_w: float = 0.0
var _sad_w: float = 0.0
## Seconds since the current pose started (seated idles, slap).
var _pose_t: float = 0.0
var _head_x_off: float = 0.0
var _head_y_off: float = 0.0
var _lean: float = 0.0
## Hand props on arm_r (built on first use, shown only in their pose).
var _tumbler: MeshInstance3D = null
var _phone: MeshInstance3D = null
## trav_elder's walking stick (node `stick`, a child of arm_l in the glb):
## hidden while he sits (laid aside), or it would pass down through the seat.
var _stick: Node3D = null


# ================================================================ statics
## True when model <id> exists in the pack or the kit (cached).
static func model_exists(id: String) -> bool:
	if id == "":
		return false
	if not _exists.has(id):
		_exists[id] = Models.exists(id)
	return bool(_exists[id])


## First id in `ids` whose glb exists; else the first id (Models.make then
## builds its fallback box).
static func first_existing(ids: Array) -> String:
	for v in ids:
		var id: String = str(v)
		if model_exists(id):
			return id
	if ids.is_empty():
		return ""
	return str(ids[0])


static func height_of(id: String) -> float:
	return float(HEIGHTS.get(id, DEFAULT_HEIGHT))


static func _get_shadow_mesh() -> PlaneMesh:
	if _shadow_mesh == null:
		_shadow_mesh = PlaneMesh.new()
		_shadow_mesh.size = Vector2(1.0, 1.0)
	return _shadow_mesh


static func _get_shadow_mat() -> StandardMaterial3D:
	if _shadow_mat == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, SHADOW_ALPHA), Color(0, 0, 0, SHADOW_ALPHA), Color(0, 0, 0, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color.WHITE
		m.albedo_texture = tex
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shadow_mat = m
	return _shadow_mat


# ================================================================ setup
## Loads the model (Models.make with a fallback box), finds the parts and adds
## the blob shadow. `h` <= 0 uses HEIGHTS.
func setup(p_model_id: String, h: float = -1.0) -> void:
	model_id = p_model_id
	height = h if h > 0.0 else height_of(p_model_id)
	model = Models.make(p_model_id, Vector3(0.42 * height, height, 0.34 * height), Color(0.35, 0.55, 0.85))
	add_child(model)
	_rest_model = model.position
	visual_height = _measure_top(model)
	_glance_rng.seed = hash(p_model_id) ^ get_instance_id()
	_glance_at = _glance_rng.randf_range(2.0, 10.0)
	_body = _part("body")
	_head = _part("head")
	_arm_l = _part("arm_l")
	_arm_r = _part("arm_r")
	_leg_l = _part("leg_l")
	_leg_r = _part("leg_r")
	_stick = _part("stick")
	if _body != null:
		_rest_body = _body.rotation
	if _head != null:
		_rest_head = _head.rotation
	if _arm_l != null:
		_rest_arm_l = _arm_l.rotation
	if _arm_r != null:
		_rest_arm_r = _arm_r.rotation
	if _leg_l != null:
		_rest_leg_l = _leg_l.rotation
	if _leg_r != null:
		_rest_leg_r = _leg_r.rotation
	_no_cast_shadow(model)
	_shadow = MeshInstance3D.new()
	_shadow.name = "BlobShadow"
	_shadow.mesh = _get_shadow_mesh()
	_shadow.material_override = _get_shadow_mat()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var d: float = SHADOW_QUAD * height
	_shadow.scale = Vector3(d, 1.0, d)
	_shadow.position = Vector3(0.0, 0.015, 0.0)
	add_child(_shadow)
	_t = randf() * 10.0          # desync idles
	_phase = randf()


func has_parts() -> bool:
	return _body != null and _leg_l != null and _leg_r != null


func _part(part_name: String) -> Node3D:
	if model == null:
		return null
	var n: Node = model.find_child(part_name, true, false)
	return n as Node3D


func _no_cast_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_cast_shadow(c)


# ================================================================ API
func walk(on: bool) -> void:
	_walking = on


func is_walking() -> bool:
	return _walking


## Snap-turns (45 ms) to face `dir` (horizontal part only).
func face(dir: Vector3) -> void:
	if dir.x * dir.x + dir.z * dir.z < 0.000001:
		return
	face_yaw(atan2(dir.x, dir.z))


func face_yaw(y: float) -> void:
	if absf(angle_difference(_yaw, y)) < 0.01 and _turn_u >= 1.0:
		_yaw = y
		_yaw_to = y
		rotation.y = y
		return
	_yaw_from = _yaw
	_yaw_to = y
	_turn_u = 0.0


## Instant yaw (no turn), cancels a pending turn-back.
func set_yaw(y: float) -> void:
	_yaw = y
	_yaw_from = y
	_yaw_to = y
	_turn_u = 1.0
	_turn90_left = 0.0
	rotation.y = y


func get_yaw() -> float:
	return _yaw_to


## "idle" | "serve" (arms forward, pouring loop) | "pay" (hand held out) |
## "turn90" (snap ~90 deg, hold 0.4 s, snap back; then idle) | "sit" |
## "eat" (sit + munch) | "carry" (tray held out) | "sad" (head down) |
## seated idles "sip" | "phone" | "doze" | "look" | "slap" (tandoor cook).
func play(pose: String) -> void:
	if pose == "turn90":
		if _turn90_left <= 0.0:
			_turn90_home = _yaw_to
		face_yaw(_turn90_home + PI * 0.5)
		_turn90_left = TURN90_HOLD
		if _pose != "idle":
			_pose_t = 0.0
		_pose = "idle"
		_sync_props()
		return
	if pose != _pose:
		_pose_t = 0.0
	_pose = pose
	_sync_props()


func get_pose() -> String:
	return _pose


## Seat top height (m above the floor) the hips should rest on when sitting.
func set_sit_height(seat_top_y: float) -> void:
	sit_lift = maxf(0.0, seat_top_y + 0.03 - HIP_FRAC * height)


## True while (mostly) seated.
func is_sitting() -> bool:
	return _sit_w > 0.5


## A named empty / node inside the model (e.g. ART's "tray_socket"), or null.
func find_socket(socket_name: String) -> Node3D:
	return _part(socket_name)


# ================================================================ per frame
func _process(delta: float) -> void:
	_t += delta
	if _turn_u < 1.0:
		_turn_u = minf(1.0, _turn_u + delta / TURN_TIME)
		_yaw = lerp_angle(_yaw_from, _yaw_to, _turn_u)
		rotation.y = _yaw
	if _turn90_left > 0.0:
		_turn90_left -= delta
		if _turn90_left <= 0.0:
			face_yaw(_turn90_home)
	if model == null:
		return

	_walk_w = move_toward(_walk_w, 1.0 if _walking else 0.0, delta / WALK_BLEND)
	if _walking:
		var cyc: float = WALK_CYCLE if stride_speed <= 0.0 else clampf(WALK_CYCLE * STRIDE_REF_SPEED / stride_speed, 0.26, 0.6)
		_phase = fmod(_phase + delta / cyc, 1.0)
	var w: float = _walk_w
	var s: float = sin(_phase * TAU) * w
	var still: float = 1.0 - w
	var breathe: float = sin(_t * TAU / BREATHE_PERIOD) * idle_amount * still

	_pose_t += delta
	var sitting: bool = SEATED_POSES.has(_pose)
	_sit_w = move_toward(_sit_w, 1.0 if sitting else 0.0, delta / SIT_BLEND)
	_sad_w = move_toward(_sad_w, 1.0 if _pose == "sad" else 0.0, delta / 0.15)
	if _stick != null:
		_stick.visible = not sitting and _sit_w <= 0.0
	var sw: float = _sit_w
	var tl: float = 0.0
	var tr: float = 0.0
	var swing: float = 1.0
	var chew: float = 0.0
	var hx: float = 0.0
	var hy: float = 0.0
	var lean: float = 0.0
	if _pose == "serve":
		tl = -0.55
		tr = -1.05 + sin(_t * 9.0) * 0.12
	elif _pose == "pay":
		tr = -1.15
	elif _pose == "carry":
		tl = CARRY_ARM
		tr = CARRY_ARM
		swing = 0.0
	elif _pose == "eat":
		# Bite: the right hand rises to the mouth for ~40% of the cycle.
		var u: float = fmod(_t, MUNCH_PERIOD) / MUNCH_PERIOD
		var bite: float = clampf(sin(u * PI) * 1.6 - 0.3, 0.0, 1.0)
		tr = -0.45 - 1.65 * bite
		tl = -0.4
		chew = sin(_t * 13.0) * 0.06 * (1.0 - bite)
	elif _pose == "sip":
		# Sips from the tumbler: hand at the mouth, head tipped back a little.
		tl = -0.35
		tr = SIP_ARM + 0.08 * sin(_pose_t * TAU / 1.5)
		hx = -0.12
	elif _pose == "phone":
		tl = -0.55
		tr = PHONE_ARM
		hx = PHONE_HEAD
	elif _pose == "doze":
		tl = -0.3
		tr = -0.3
		hx = SAD_HEAD + DOZE_NOD * sin(_pose_t * TAU / DOZE_PERIOD)
	elif _pose == "look":
		tl = -0.35
		tr = -0.35
		hy = LOOK_YAW * sin(_pose_t * TAU / LOOK_PERIOD)
	elif sitting:
		tl = -0.35
		tr = -0.35
	elif _pose == "sad":
		tl = 0.1
		tr = 0.1
	elif _pose == "slap":
		# Lean in; the right arm thrusts at the drum wall in the first 0.3 of
		# each SLAP_PERIOD (at once when the pose starts); the left hand holds
		# the next roti over the counter.
		var su: float = fmod(_pose_t, SLAP_PERIOD) / SLAP_PERIOD
		var hit: float = sin(clampf(su / 0.3, 0.0, 1.0) * PI)
		tl = -0.6
		tr = lerpf(SLAP_ARM_REST, SLAP_ARM_HIT, hit)
		lean = SLAP_LEAN + 0.06 * hit
	if idle_glance and _pose == "idle" and not _walking:
		if _glance_left > 0.0:
			_glance_left -= delta
			hy = GLANCE_YAW * sin((1.0 - _glance_left / GLANCE_S) * TAU)
		elif _t >= _glance_at:
			_glance_left = GLANCE_S
			_glance_at = _t + _glance_rng.randf_range(GLANCE_GAP.x, GLANCE_GAP.y)
	var k: float = 1.0 - exp(-POSE_K * delta)
	_arm_l_off = lerpf(_arm_l_off, tl, k)
	_arm_r_off = lerpf(_arm_r_off, tr, k)
	var kh: float = 1.0 - exp(-8.0 * delta)
	_head_x_off = lerpf(_head_x_off, hx, kh)
	_head_y_off = lerpf(_head_y_off, hy, kh)
	_lean = lerpf(_lean, lean, kh)

	# Whole model: step bob (twice per stride), side sway, idle breathe, seat lift.
	var bob: float = (1.0 - absf(sin(_phase * TAU))) * BOB * height * w
	var shift: float = SHIFT * height * sin(_t * TAU / SHIFT_PERIOD) * still if idle_glance else 0.0
	model.position = _rest_model + Vector3(s * SWAY * height + shift, bob + breathe * 0.004 + sit_lift * sw, 0.0)

	if _body == null:
		# Single-mesh fallback: roll the whole model instead of the body.
		model.rotation = Vector3(chew - _sad_w * 0.12, 0.0, s * ROLL + breathe * 0.012)
		return
	_body.rotation = _rest_body + Vector3(0.04 * sw + _lean, 0.0, s * ROLL + breathe * 0.012)
	if _head != null:
		_head.rotation = _rest_head + Vector3(chew + _sad_w * SAD_HEAD + _head_x_off, _head_y_off, -s * ROLL * 0.5 + breathe * 0.02)
	if _arm_l != null:
		_arm_l.rotation = _rest_arm_l + Vector3(-s * ARM_SWING * swing + _arm_l_off, 0.0, 0.0)
	if _arm_r != null:
		_arm_r.rotation = _rest_arm_r + Vector3(s * ARM_SWING * swing + _arm_r_off, 0.0, 0.0)
	var leg_sit: float = SIT_LEG * sw
	if _leg_l != null:
		_leg_l.rotation = _rest_leg_l + Vector3(s * LEG_SWING * leg_swing_mult * (1.0 - sw) + leg_sit, 0.0, 0.0)
	if _leg_r != null:
		_leg_r.rotation = _rest_leg_r + Vector3(-s * LEG_SWING * leg_swing_mult * (1.0 - sw) + leg_sit - 0.08 * sw, 0.0, 0.0)


## Highest point of the model's meshes in the model's own space (m).
static func _measure_top(root: Node3D) -> float:
	var top: float = 0.0
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		var xf: Transform3D = e[1]
		for c in n.get_children():
			if c is Node3D:
				var cx: Transform3D = xf * (c as Node3D).transform
				if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
					var b: AABB = cx * (c as MeshInstance3D).get_aabb()
					top = maxf(top, b.end.y)
				stack.append([c, cx])
	return top


# ================================================================ hand props (C6.6)
## Shows the steel tumbler only while sipping and the phone only while on the
## phone (built on first use, parented to arm_r at the hand).
func _sync_props() -> void:
	if _pose == "sip" and _tumbler == null:
		_tumbler = _make_hand_prop(true)
	if _pose == "phone" and _phone == null:
		_phone = _make_hand_prop(false)
	if _tumbler != null:
		_tumbler.visible = _pose == "sip"
	if _phone != null:
		_phone.visible = _pose == "phone"


func _make_hand_prop(tumbler: bool) -> MeshInstance3D:
	if _arm_r == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Tumbler" if tumbler else "Phone"
	mi.mesh = _prop_mesh(tumbler)
	mi.position = Vector3(0.0, -HAND_DROP * height, 0.045 if tumbler else 0.04)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	_arm_r.add_child(mi)
	return mi


## One shared mesh per prop (every traveller's tumbler / phone).
static func _prop_mesh(tumbler: bool) -> Mesh:
	if tumbler and _tumbler_mesh != null:
		return _tumbler_mesh
	if not tumbler and _phone_mesh != null:
		return _phone_mesh
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.45
	if tumbler:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.034
		cm.bottom_radius = 0.028
		cm.height = 0.085
		cm.radial_segments = 8
		cm.rings = 1
		mat.albedo_color = Color(0.78, 0.8, 0.82)
		mat.metallic = 0.6
		cm.material = mat
		_tumbler_mesh = cm
		return cm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.055, 0.1, 0.012)
	mat.albedo_color = Color(0.1, 0.1, 0.12)
	bm.material = mat
	_phone_mesh = bm
	return bm
