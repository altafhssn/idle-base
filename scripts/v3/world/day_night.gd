class_name DayNight
extends Node
## Day / night cycle (owner request 2026-10-21). Data: economy_v3.json
## "daynight". One cycle = cycle_s game seconds (Refs.clock, so --speed
## scales it); phase 0..1 with 0 = dawn. The colour-key table ("keys", each
## {t, sun, sun_energy, sun_pitch, sun_yaw, amb, amb_energy, bg, shadow,
## night}) is interpolated (wrapping 1 -> 0) and applied to the sun, the
## ambient light, the background colour and the shadow opacity. `night`
## (0 = bright day, 1 = deep night) drives everything else, all cheap:
##   - FairyLights: bulb boost / twinkle floor up (shared shader params)
##   - NightGlow quads (unshaded additive, merged, one shared material):
##     the chai bhatti / tandoor / kadai fire mouths (flicker, children of
##     the station props so they pop in with them), warm pools at the gate,
##     the gumti, the parking board and under the bus shelter's tube light,
##     a halo behind the rooftop signboard
##   - Traffic.set_night(f): headlight / tail-light glows and beams (pooled
##     with the vehicles), more lorries and fewer buses in the through
##     traffic and the parked mix; Sim.night_f: fuller (so fewer) stop buses
##     - the ARRIVAL ACCOUNT is untouched, so arrivals / min stay the same.
## Frozen at the bright-day phase ("day_phase") until the tutorial is done
## (the tutorial looks and times exactly as before), then it runs. The phase
## is saved (Game.day_phase, "day_phase"; old saves load at day_phase).
## Night glows are hidden outright while night is 0 (no draw calls by day).
## GRAPHICS LOW (`low`, set by Main3): each key's sun energy, ambient energy
## and ambient colour are multiplied by GfxQuality.LOW_LIGHT (by key name), so
## LOW without sun shadows is as bright as HIGH (docs/optimise/report.md 6.14).

signal band_changed(band: String)

## Fire-mouth glows per station come from the pack: the station's economy
## "fx.fires" = [[[x, y, z] prop-local point, radius, pool radius], ...].
const FIRE_COLOR := Color(1.0, 0.45, 0.12)
const FIRE_POOL_COLOR := Color(0.75, 0.32, 0.08)
const GfxQuality := preload("res://scripts/v3/core/gfx_quality.gd")

var env: Environment
var sun: DirectionalLight3D
var sim: Sim
var fairy: FairyLights
## Current phase (mirrors Game.day_phase) and night factor 0..1.
var phase: float = 0.25
var night: float = 0.0
var frozen: bool = false
## Debug: phase forced by --time (still runs after the tutorial).
var forced: float = -1.0
## GRAPHICS LOW: the LOW_LIGHT multipliers apply (Main3 sets it before setup
## and through set_low).
var low: bool = false

var _cfg: Dictionary = {}
var _keys: Array = []
var _cycle_s: float = 600.0
var _day_phase: float = 0.25
var _last_clock: float = -1.0
var _glow_mat: ShaderMaterial
var _glows: Array[MeshInstance3D] = []
var _fires_done: Dictionary = {}
var _glow_on: bool = false
var _band: String = ""
var _fairy_boost: Vector2 = Vector2(1.25, 2.6)
var _fairy_low: Vector2 = Vector2(0.6, 0.75)
var _applied_phase: float = -1.0
## Seconds spent in each band (logged with --stats).
var band_time: Dictionary = {}


func setup(p_env: Environment, p_sun: DirectionalLight3D, p_sim: Sim, p_fairy: FairyLights) -> void:
	env = p_env
	sun = p_sun
	sim = p_sim
	fairy = p_fairy
	_cfg = Game.daynight_cfg()
	_cycle_s = maxf(10.0, float(_cfg.get("cycle_s", 600.0)))
	_day_phase = Game.day_phase_default()
	_keys = _parse_keys(_cfg.get("keys", []))
	var lights: Dictionary = _cfg.get("lights", {}) if _cfg.get("lights", {}) is Dictionary else {}
	_fairy_boost = Vector2(float(lights.get("fairy_boost_day", 1.25)), float(lights.get("fairy_boost_night", 2.6)))
	_fairy_low = Vector2(float(lights.get("fairy_low_day", 0.6)), float(lights.get("fairy_low_night", 0.75)))
	_glow_mat = NightGlow.make_material(float(lights.get("glow_gain", 1.0)))
	_build_static_glows(lights)
	phase = Game.day_phase if Game.is_tutorial_done() else _day_phase
	if forced >= 0.0:
		phase = forced
		Game.day_phase = phase
	_apply(true)


## Phase of a named moment ("dawn", "day", "dusk", "night") from "shots".
func shot_phase(label: String) -> float:
	var sh: Variant = _cfg.get("shots", {})
	if sh is Dictionary:
		return float((sh as Dictionary).get(label, _day_phase))
	return _day_phase


## Jumps to a phase (debug / capture): applied at once.
func set_phase(p: float) -> void:
	phase = fposmod(p, 1.0)
	Game.day_phase = phase
	_apply(true)


## GRAPHICS tier changed (Main3.apply_graphics): the light is re-applied now.
func set_low(on: bool) -> void:
	low = on
	_apply(true)


## "dawn" / "day" / "dusk" / "night" for the current phase (night >= 0.6,
## else by the side of the day it is on).
func band() -> String:
	if night >= 0.6:
		return "night"
	if night <= 0.02 and phase >= 0.08 and phase <= 0.52:
		return "day"
	return "dawn" if phase < 0.3 or phase > 0.9 else "dusk"


func _process(_delta: float) -> void:
	var clk: float = Refs.clock
	if _last_clock < 0.0:
		_last_clock = clk
	var d: float = maxf(0.0, clk - _last_clock)
	_last_clock = clk
	if not bool(_cfg.get("enabled", true)):
		return
	if Game.is_tutorial_done():
		if not frozen:
			phase = fposmod(phase + d / _cycle_s, 1.0)
			Game.day_phase = phase
	elif forced < 0.0 and not frozen:
		phase = _day_phase     # the tutorial: bright day, frozen
	var b: String = band()
	band_time[b] = float(band_time.get(b, 0.0)) + d
	if b != _band:
		_band = b
		band_changed.emit(b)
	_attach_fires()
	_apply(false)


# ================================================================ apply
func _apply(force: bool) -> void:
	if not force and absf(phase - _applied_phase) < 0.00005:
		return
	_applied_phase = phase
	var k: Dictionary = _sample(phase)
	night = float(k["night"])
	if sun != null:
		sun.light_color = k["sun"]
		sun.light_energy = float(k["sun_energy"]) * (float(k["low_sun"]) if low else 1.0)
		sun.rotation_degrees = Vector3(float(k["sun_pitch"]), float(k["sun_yaw"]), 0.0)
		sun.shadow_opacity = float(k["shadow"])
	if env != null:
		if low:
			# The tint is a linear-light multiplier: the renderer converts the
			# (sRGB) ambient colour to linear before lighting with it.
			env.ambient_light_color = ((k["amb"] as Color).srgb_to_linear() * (k["low_amb_tint"] as Color)).linear_to_srgb()
		else:
			env.ambient_light_color = k["amb"]
		env.ambient_light_energy = float(k["amb_energy"]) * (float(k["low_amb"]) if low else 1.0)
		env.background_color = k["bg"]
	if fairy != null:
		fairy.set_brightness(lerpf(_fairy_low.x, _fairy_low.y, night), 1.0)
		fairy.set_boost(lerpf(_fairy_boost.x, _fairy_boost.y, night))
		fairy.set_lit(night > 0.02)
	_glow_mat.set_shader_parameter("night", night)
	var on: bool = night > 0.01
	if on != _glow_on or force:
		_glow_on = on
		for g in _glows:
			if is_instance_valid(g):
				g.visible = on
	if sim != null:
		sim.night_f = night
		if sim.traffic != null:
			sim.traffic.set_night(night, band())


## Interpolated key at phase p (keys sorted by t; wraps from the last key
## to the first + 1).
func _sample(p: float) -> Dictionary:
	if _keys.is_empty():
		return _day_key()
	var n: int = _keys.size()
	var i: int = 0
	while i < n and float((_keys[i] as Dictionary)["t"]) <= p:
		i += 1
	var a: Dictionary
	var b: Dictionary
	var ta: float
	var tb: float
	if i == 0:
		a = _keys[n - 1]
		b = _keys[0]
		ta = float(a["t"]) - 1.0
		tb = float(b["t"])
	elif i == n:
		a = _keys[n - 1]
		b = _keys[0]
		ta = float(a["t"])
		tb = float(b["t"]) + 1.0
	else:
		a = _keys[i - 1]
		b = _keys[i]
		ta = float(a["t"])
		tb = float(b["t"])
	var u: float = 0.0 if tb - ta <= 0.00001 else clampf((p - ta) / (tb - ta), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var out: Dictionary = {}
	for key in a.keys():
		var va: Variant = a[key]
		var vb: Variant = b.get(key, va)
		if va is Color:
			out[key] = (va as Color).lerp(vb as Color, u)
		elif key == "t":
			out[key] = p
		else:
			out[key] = lerpf(float(va), float(vb), u)
	return out


func _day_key() -> Dictionary:
	var d: Dictionary = {"t": 0.0, "sun": Color(1.0, 0.95, 0.86), "sun_energy": Main3.SUN_ENERGY, "sun_pitch": -50.0,
			"sun_yaw": -70.0, "amb": Color(1.0, 0.96, 0.9), "amb_energy": Main3.AMBIENT_ENERGY,
			"bg": Color(0.60, 0.74, 0.50), "shadow": 0.5, "night": 0.0}
	_add_low(d, "day")
	return d


## The key's GRAPHICS LOW multipliers (GfxQuality.LOW_LIGHT), as plain
## float / Color fields so _sample interpolates them with the rest.
static func _add_low(k: Dictionary, key_name: String) -> void:
	var m: Dictionary = GfxQuality.low_light(key_name, float(k["night"]))
	k["low_sun"] = float(m["sun"])
	k["low_amb"] = float(m["amb"])
	k["low_amb_tint"] = m["amb_tint"] as Color


static func _color(v: Variant, def: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return def


func _parse_keys(src: Variant) -> Array:
	var out: Array = []
	if not (src is Array):
		return out
	var d: Dictionary = _day_key()
	for v in (src as Array):
		if not (v is Dictionary):
			continue
		var e: Dictionary = v
		var k: Dictionary = {
			"t": clampf(float(e.get("t", 0.0)), 0.0, 1.0),
			"sun": _color(e.get("sun"), d["sun"]),
			"sun_energy": float(e.get("sun_energy", d["sun_energy"])),
			"sun_pitch": float(e.get("sun_pitch", d["sun_pitch"])),
			"sun_yaw": float(e.get("sun_yaw", d["sun_yaw"])),
			"amb": _color(e.get("amb"), d["amb"]),
			"amb_energy": float(e.get("amb_energy", d["amb_energy"])),
			"bg": _color(e.get("bg"), d["bg"]),
			"shadow": float(e.get("shadow", d["shadow"])),
			"night": clampf(float(e.get("night", 0.0)), 0.0, 1.0),
		}
		_add_low(k, str(e.get("name", "")))
		out.append(k)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["t"]) < float(y["t"]))
	return out


# ================================================================ glows
## Fixed pools / halos from "lights.glows": [{p: [x,y,z], kind: pool|bulb|fire, r, color}].
func _build_static_glows(lights: Dictionary) -> void:
	var gl: Variant = lights.get("glows", [])
	if not (gl is Array) or (gl as Array).is_empty():
		return
	var b := NightGlow.Builder.new()
	for v in (gl as Array):
		if not (v is Dictionary):
			continue
		var e: Dictionary = v
		var pa: Array = e.get("p", [0, 0, 0])
		var p := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var r: float = float(e.get("r", 1.0))
		var c: Color = _color(e.get("color"), Color(1.0, 0.7, 0.35))
		match str(e.get("kind", "pool")):
			"pool":
				b.pool(p, r, c)
			"fire":
				b.glow(p, r, c, true)
			_:
				b.glow(p, r, c, false)
	var mi := NightGlow.make_instance(b.commit(), _glow_mat)
	mi.name = "NightGlows"
	add_child(mi)
	_glows.append(mi)


## Fire-mouth glows on every built station's prop (once per station).
func _attach_fires() -> void:
	if sim == null:
		return
	for id: String in Game.station_ids():
		var fires: Variant = (Game.station_def(id).get("fx", {}) as Dictionary).get("fires", []) if Game.station_def(id).get("fx", {}) is Dictionary else []
		if not (fires is Array) or (fires as Array).is_empty():
			continue
		if _fires_done.has(id):
			continue
		var st: StationNode = sim.get_station(id)
		if st == null or st.prop == null:
			continue
		_fires_done[id] = true
		var b := NightGlow.Builder.new()
		for v in fires:
			var e: Array = v
			var gp: Vector3 = Vector3(float(e[0][0]), float(e[0][1]), float(e[0][2]))
			b.glow(gp, float(e[1]), FIRE_COLOR, true)
			var pr: float = float(e[2])
			if pr > 0.0:
				b.pool(Vector3(gp.x, 0.06, gp.z), pr, FIRE_POOL_COLOR)
		var mi := NightGlow.make_instance(b.commit(), _glow_mat, 1.0)
		mi.name = "FireGlow"
		mi.visible = _glow_on
		st.prop.add_child(mi)
		_glows.append(mi)
